"""Shared song and chart building, used by every authored song and by the importer.

An authored song (tools/song/songs/<id>.py) builds a Song: chart notes plus
event lists for SuperCollider. The importer builds charts from transcribed
notes with the same cleanup and difficulty code, so every chart in the game
follows one set of playability rules.

Chart file format (game/data/songs/<id>.json, or user://songs/<id>/chart.json):
  id, title, theme, bpm, beats_per_bar, beat_offset, duration, backing, lead,
  sections, source ("builtin" or "imported"), difficulties {easy, normal}, and
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


def write_chart(path: pathlib.Path, meta: dict, normal: list[dict]) -> dict:
    beat = 60.0 / meta["bpm"]
    # Easy leaves at least a beat and a quarter between notes (never under 0.5 s),
    # so even a song of plain quarter notes thins out noticeably.
    easy = easy_notes(normal, beat, meta.get("beat_offset", 0.0), spacing=max(0.5, beat * 1.25))
    chart = {**meta, "difficulties": {"easy": easy, "normal": normal}, "notes": normal}
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
