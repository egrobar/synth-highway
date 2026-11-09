"""Shared song and chart building, used by every authored song and by the importer.

An authored song (tools/song/songs/<id>.py) builds a Song: chart notes plus
event lists for SuperCollider. The importer builds charts from transcribed
notes with the same cleanup and difficulty code, so every chart in the game
follows one set of playability rules.

Chart file format (game/data/songs/<id>.json, or user://songs/<id>/chart.json):
  id, title, theme, bpm, beats_per_bar, beat_offset, duration, backing, lead,
  sections, source ("builtin" or "imported"), lanes ("home_row"), difficulties {easy, normal}
  (each note {t, d, p, l}: seconds, seconds, MIDI pitch, home-row lane 0-9), and
  notes (a copy of normal, for older readers).
Score event format (for tools/song/render_score.scd): [time, instrument, midi, seconds, amp, pan]
"""
from __future__ import annotations

import json
import pathlib
import random

ROOT = pathlib.Path(__file__).resolve().parents[2]
HOLD_MIN = 0.75  # must match Chart.HOLD_MIN_SECONDS in game/scripts/chart.gd
LANE_LOW, LANE_HIGH = 60, 79  # the Q row: C4 to G5
PCLASS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def pitch(name: str) -> int:
    """'C4' -> 60. Accepts sharps ('F#4') and flats ('Bb3')."""
    base = PCLASS[name[0]]
    accidental = name[1:-1]
    shift = accidental.count("#") - accidental.count("b")
    return (int(name[-1]) + 1) * 12 + base + shift


# ---------------------------------------------------------------- chart rules

def clean_notes(notes: list[dict], min_len: float = 0.08, min_spacing: float = 0.11) -> list[dict]:
    """Playable Normal: drops slivers, keeps onsets apart, and stops a note
    running into the next so holds read clearly."""
    notes = sorted((dict(n) for n in notes if n["d"] >= min_len), key=lambda n: n["t"])
    kept: list[dict] = []
    for n in notes:
        if kept and n["t"] - kept[-1]["t"] < min_spacing:
            if n["d"] > kept[-1]["d"]:
                kept[-1] = n
            continue
        kept.append(n)
    for a, b in zip(kept, kept[1:]):
        a["d"] = max(0.06, min(a["d"], b["t"] - a["t"] - 0.03))
    return [{"t": round(n["t"], 4), "d": round(n["d"], 4), "p": int(n["p"])} for n in kept]


def easy_notes(notes: list[dict], beat: float, beat_offset: float = 0.0, spacing: float = 0.42) -> list[dict]:
    """Easy keeps the notes that matter most, at least `spacing` seconds apart:
    holds first, then notes on the beat, then everything else."""
    def weight(n: dict) -> float:
        phase = ((n["t"] - beat_offset) / beat) % 1.0
        on_beat = min(phase, 1.0 - phase) < 0.08
        return n["d"] + (0.6 if n["d"] >= HOLD_MIN else 0.0) + (0.35 if on_beat else 0.0)

    chosen: list[dict] = []
    for n in sorted(notes, key=weight, reverse=True):
        if all(abs(n["t"] - c["t"]) >= spacing for c in chosen):
            chosen.append(n)
    return sorted(chosen, key=lambda n: n["t"])


def fold_to_lanes(notes: list[dict], shift: int = 0) -> list[dict]:
    """Moves notes onto the Q row. A whole-octave shift is chosen so most notes
    fit; any stragglers are folded in by octaves. Lanes are just keys to press,
    so this never changes what the player hears."""
    best_octave, best_fit = 0, -1
    for octave in range(-4, 5):
        fit = sum(1 for n in notes if LANE_LOW <= n["p"] + shift + octave * 12 <= LANE_HIGH)
        if fit > best_fit:
            best_octave, best_fit = octave, fit
    out = []
    for n in notes:
        p = n["p"] + shift + best_octave * 12
        while p < LANE_LOW:
            p += 12
        while p > LANE_HIGH:
            p -= 12
        out.append({**n, "p": p})
    return out


# ---------------------------------------------------------------- home-row lanes
#
# Every song is played on the same ten keys, the home row: A S D F G H J K L ;.
# Fingers rest on A S D F and J K L ; and the index fingers reach G and H, so
# hands never move between songs. A chart note's "l" is its lane, 0 (A) to 9 (;).
# Lanes follow the melody's shape: each step of the scale is one lane, higher
# notes further right. Easy uses only the eight resting keys (no G or H). On
# Normal, notes outside the key are sharps ("s": 1), played on the top-row key
# between two home keys, like a piano's black keys: W E R T Y U I O P.
NORMAL_LANES = list(range(10))
EASY_LANES = [0, 1, 2, 3, 6, 7, 8, 9]
MAJOR_SCALE = [0, 2, 4, 5, 7, 9, 11]
MINOR_SCALE = [0, 2, 3, 5, 7, 8, 10]
_KK_MAJOR = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
_KK_MINOR = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]


def melody_key(notes: list[dict]) -> tuple[int, list[int]]:
    """(tonic pitch class, scale) from the melody alone, weighting notes by length."""
    weights = [0.0] * 12
    for n in notes:
        weights[n["p"] % 12] += n["d"]

    def corr(profile: list[float], tonic: int) -> float:
        rotated = [profile[(i - tonic) % 12] for i in range(12)]
        ma, mb = sum(rotated) / 12, sum(weights) / 12
        num = sum((a - ma) * (b - mb) for a, b in zip(rotated, weights))
        den = (sum((a - ma) ** 2 for a in rotated) * sum((b - mb) ** 2 for b in weights)) ** 0.5
        return num / den if den else 0.0

    total = sum(weights) or 1.0

    def outside(tonic: int, scale: list[int]) -> float:
        return sum(w for pc, w in enumerate(weights) if (pc - tonic) % 12 not in scale) / total

    # The key that leaves the least of the melody out of key wins (so a tune on white keys
    # only never sprouts sharps); the profile correlation only breaks near-ties.
    candidates = [(outside(t, sc), -corr(prof, t), t, sc)
                  for t in range(12) for prof, sc in ((_KK_MAJOR, MAJOR_SCALE), (_KK_MINOR, MINOR_SCALE))]
    least = min(c[0] for c in candidates)
    chosen = min((c for c in candidates if c[0] <= least + 0.02), key=lambda c: c[1])
    return chosen[2], chosen[3]


def scale_positions(notes: list[dict]) -> list[tuple[int, bool]]:
    """Each note as (scale step, out of key). A note outside the key sits between its
    step and the next one up, the way a black key sits between two white keys."""
    tonic, scale = melody_key(notes)
    positions: list[tuple[int, bool]] = []
    for n in notes:
        octave, pc = divmod(n["p"] - tonic, 12)
        if pc in scale:
            positions.append((octave * 7 + scale.index(pc), False))
        else:
            positions.append((octave * 7 + max(i for i, s in enumerate(scale) if s < pc), True))
    return positions


def snapped_steps(notes: list[dict], positions: list[tuple[int, bool]]) -> list[int]:
    """For layouts without sharps: an out-of-key note goes to the neighbouring step that
    keeps the melody moving the way it moved, so a turn like E-D#-E stays a turn."""
    steps: list[int] = []
    prev_pitch, prev_step = None, None
    for n, (below, out_of_key) in zip(notes, positions):
        step = below
        if out_of_key:
            above = below + 1
            if prev_pitch is None or n["p"] == prev_pitch:
                step = prev_step if prev_step in (below, above) else above
            elif n["p"] > prev_pitch:
                step = above if above > prev_step or below <= prev_step else below
            else:
                step = below if below < prev_step or above >= prev_step else above
        steps.append(step)
        prev_pitch, prev_step = n["p"], step
    return steps


def _best_window(values: list[float], width: int, fits) -> int:
    lo, hi = int(min(values)), int(max(values))
    best_base, best_fit, best_gap = lo, -1, 0.0
    mean = sum(values) / len(values)
    for base in range(lo - width, hi + 1):
        fit = sum(1 for v in values if fits(v, base))
        # Prefer the window that holds the most notes, then the one centred on the melody.
        gap = abs((base + (width - 1) / 2) - mean)
        if fit > best_fit or (fit == best_fit and gap < best_gap):
            best_base, best_fit, best_gap = base, fit, gap
    return best_base


def assign_lanes(notes: list[dict], lanes: list[int]) -> tuple[list[dict], int]:
    """Adds "l" to every note, with no sharps. The window of len(lanes) scale steps that
    holds the most notes is chosen; notes outside it fold in by octaves.
    Returns (notes, folded count)."""
    if not notes:
        return notes, 0
    steps = snapped_steps(notes, scale_positions(notes))
    width = len(lanes)
    base = _best_window([float(s) for s in steps], width, lambda v, b: b <= v < b + width)
    out, folded = [], 0
    for n, s in zip(notes, steps):
        i = s - base
        if not 0 <= i < width:
            folded += 1
            while i < 0:
                i += 7
            while i >= width:
                i -= 7
        out.append({**n, "l": lanes[max(0, min(width - 1, i))]})
    return out, folded


def assign_lanes_with_sharps(notes: list[dict]) -> tuple[list[dict], int, int]:
    """All ten home keys, and out-of-key notes kept as sharps: "l" is the home key just
    below and "s": 1 marks it, played on the top-row key between that home key and the
    next (W between A and S, E between S and D, ... P between L and ;).
    Returns (notes, folded count, sharp count)."""
    positions = scale_positions(notes)
    width = 10
    values = [s + (0.5 if sharp else 0.0) for s, sharp in positions]
    # A sharp needs both neighbours on the board, so it fits only up to the second-last lane.
    base = _best_window(values, width, lambda v, b: b <= v <= b + width - 1 - (0.5 if v % 1 else 0))
    out, folded, sharps = [], 0, 0
    for n, (s, sharp) in zip(notes, positions):
        i = s - base
        top = width - 2 if sharp else width - 1
        if not 0 <= i <= top:
            folded += 1
            while i < 0:
                i += 7
            while i > top:
                i -= 7
        note = {**n, "l": max(0, min(top, i))}
        if sharp:
            note["s"] = 1
            sharps += 1
        out.append(note)
    return out, folded, sharps


def write_chart(path: pathlib.Path, meta: dict, normal: list[dict]) -> dict:
    beat = 60.0 / meta["bpm"]
    # Easy leaves at least a beat and a quarter between notes (never under 0.5 s),
    # so even a song of plain quarter notes thins out noticeably.
    easy = easy_notes(normal, beat, meta.get("beat_offset", 0.0), spacing=max(0.5, beat * 1.25))
    folded_normal = 0
    if any(out_of_key for _, out_of_key in scale_positions(normal)):
        # The melody leaves the key: Normal plays those notes as sharps on the top row.
        normal, folded_normal, sharps = assign_lanes_with_sharps(normal)
        print(f"   lanes: {sharps} sharps on the top row")
    else:
        # A melody that fits on the eight resting keys stays on them: G and H (index
        # reaches) come in only when the tune needs more than eight scale steps.
        resting, folded_resting = assign_lanes(normal, EASY_LANES)
        if folded_resting == 0:
            normal = resting
        else:
            normal, folded_normal = assign_lanes(normal, NORMAL_LANES)
    # Easy never has sharps: out-of-key notes snap to a neighbouring resting key.
    easy, _ = assign_lanes(easy, EASY_LANES)
    if folded_normal:
        print(f"   lanes: {folded_normal} of {len(normal)} notes folded by an octave to fit the home row")
    chart = {**meta, "lanes": "home_row", "difficulties": {"easy": easy, "normal": normal}, "notes": normal}
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(chart, indent=1))
    return chart


# ---------------------------------------------------------------- authored songs

class Song:
    """Builder for an original song: arrangement events plus the melody chart."""

    def __init__(self, song_id: str, title: str, theme: str, bpm: float, lead_patch: str,
                 beats_per_bar: int = 4, seed: int = 1987, lane_shift: int = 0):
        self.id, self.title, self.theme = song_id, title, theme
        self.bpm, self.beat, self.beats_per_bar = bpm, 60.0 / bpm, beats_per_bar
        self.lead_patch = lead_patch
        self.lane_shift = lane_shift
        self.rng = random.Random(seed)
        self.backing: list[list] = []
        self.lead: list[list] = []
        self.notes: list[dict] = []
        self.sections: list[dict] = []
        self.room = {"backing": [0.2, 0.6, 0.0], "lead": [0.3, 0.72, 0.16]}

    def at(self, bar: float, beat: float = 0.0) -> float:
        return (bar * self.beats_per_bar + beat) * self.beat

    def section(self, name: str, bar: int) -> None:
        self.sections.append({"name": name, "t": round(self.at(bar), 4)})

    def hit(self, t: float, inst: str, midi: int = 60, dur: float = 0.25, amp: float = 0.3,
            pan: float = 0.0, humanize: bool = True) -> None:
        if humanize:
            t = max(0.002, t + self.rng.uniform(-0.004, 0.004))
            amp *= self.rng.uniform(0.9, 1.08)
        self.backing.append([round(t, 4), inst, midi, round(dur, 4), round(amp, 4), round(pan, 3)])

    def melody(self, bar: int, bars: list[str], amp: float = 0.42) -> None:
        """Bars of 'E4:1 G4:0.5 r:1' tokens (durations in beats). Each note is
        one chart note and one lead-stem note, at exactly the same time."""
        for i, text in enumerate(bars):
            b = 0.0
            for token in text.split():
                name, beats = token.split(":")
                beats = float(beats)
                if name != "r":
                    t, d, p = self.at(bar + i, b), beats * self.beat, pitch(name)
                    self.notes.append({"t": round(t, 4), "d": round(d, 4), "p": p})
                    self.lead.append([round(t, 4), self.lead_patch, p, round(d, 4), amp, 0.0])
                b += beats

    def write(self, bars: int, tail: float = 3.0) -> None:
        duration = self.at(bars) + tail
        meta = {
            "id": self.id, "title": self.title, "theme": self.theme, "bpm": self.bpm,
            "beats_per_bar": self.beats_per_bar, "beat_offset": 0.0, "duration": round(duration, 4),
            "backing": f"res://assets/songs/{self.id}/backing.wav",
            "lead": f"res://assets/songs/{self.id}/lead.wav",
            "sections": self.sections, "source": "builtin",
        }
        normal = clean_notes(fold_to_lanes(self.notes, self.lane_shift) if self.lane_shift else self.notes)
        chart = write_chart(ROOT / f"game/data/songs/{self.id}.json", meta, normal)
        write_score(ROOT / f"tools/song/build/{self.id}.scd", duration, self.backing, self.lead, self.room)
        holds = sum(1 for n in normal if n["d"] >= HOLD_MIN)
        print(f"{self.id}: {len(normal)} notes ({len(chart['difficulties']['easy'])} on Easy), "
              f"{holds} holds, {len(self.backing)} backing events, {duration:.1f}s")


def write_score(path: pathlib.Path, duration: float, backing: list, lead: list, room: dict) -> None:
    """SuperCollider-readable score. `#[...]` keeps sclang's literal table from overflowing."""
    def literal(events: list) -> str:
        rows = [f"[{e[0]:.4f},{e[1]},{e[2]},{e[3]},{e[4]},{e[5] if len(e) > 5 else 0}]" for e in events]
        return "#[\n" + ",\n".join(rows) + "\n]"

    path.parent.mkdir(parents=True, exist_ok=True)
    backing = sorted(backing, key=lambda e: e[0])
    path.write_text(
        f"~duration = {duration:.4f};\n"
        f"~backingRoom = #{room['backing']};\n~leadRoom = #{room['lead']};\n"
        f"~backing = {literal(backing)};\n~lead = {literal(lead)};\n"
    )
