"""Charts a built-in song from its Suno stems: Easy, Normal and Hard, tied to the music.

Playtest (2026-11-11): "the notes aren't super well tied to the songs ... on easy felt almost
random. the big note hits often didn't have one." The first importer guessed the tune out of
the finished mix and thinned Easy by spacing alone. This one starts from the song's own stems
(Suno's "Extract Stems": lead vocals, backing vocals, drums, bass, guitar, keyboard, strings,
synth, other, brass, woodwinds; fetched into sources/suno_stems/<id>/) and charts what a
player hears:

  beats     tracked on the drums stem alone (clean transients), downbeats found from the kick
            pattern and the chord changes
  big hits  the drums' slams and crashes and the energy jumps into drops: they always get a
            note, and on Normal and Hard the biggest become power chords (two keys at once,
            "pw": 1 on each)
  lead      bar by bar, the stem carrying the tune (vocals first, else synth, keys, guitar,
            strings, brass, woodwinds), transcribed from that clean stem with Basic Pitch;
            rests in the lead are filled from the next most active line
  salience  every note scored by how hard it lands, where it sits in the bar, its length,
            phrase starts, melodic peaks and nearness to a big hit
  tiers     Hard: the whole line, with fills and power chords; Normal and Easy keep the most
            salient notes, each thinned until tools/song/difficulty.py (the game's model) puts
            it in its band: Easy 1-3.5, Normal 3.5-6.5, Hard 6.5 and up
  audio     lead.ogg is whichever stem leads each bar (so a hit plays what you just played),
            backing.ogg is everything else; both Ogg Vorbis as before

Usage: .venv-pipeline/bin/python tools/importer/stem_chart.py <song id> [--keep-audio] [--demucs]
Writes game/data/songs/<id>.json (keeping its title, region and station) and, unless
--keep-audio, game/assets/songs/<id>/{lead,backing}.ogg.

--demucs charts from sources/demucs_stems/<id>/ instead: four stems (vocals, drums, bass, other)
that tools/importer/demucs_stems.py separates from the song's original mix, for the songs whose
Suno stems aren't downloaded (the account's stem downloads ran out on 2026-11-11). Such a chart
says "stem_source": "demucs"; chart_all_stems.sh re-charts it once Suno stems arrive.
"""
from __future__ import annotations

import json
import math
import pathlib
import shutil
import subprocess
import sys
import tempfile

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "tools/song"))
sys.path.insert(0, str(HERE))
import difficulty  # noqa: E402
import songlib  # noqa: E402

SR = 22050
HOP = 512
STEMS = ["lead vocals", "backing vocals", "drums", "bass", "guitar", "keyboard", "strings", "synth", "other",
         "brass", "woodwinds"]
## Stems that can carry the tune, with how strongly each is preferred when several play.
MELODIC = {"lead vocals": 1.5, "synth": 1.0, "keyboard": 0.95, "guitar": 0.95, "strings": 0.85, "brass": 0.9,
           "woodwinds": 0.9, "other": 0.7, "backing vocals": 0.6}
BANDS = {"easy": (1.0, 3.5), "normal": (3.5, 6.5), "hard": (6.5, 10.0)}
# Normal is thinned to a little under its band's top: the menu rounds levels, and a Normal at 6.5
# showed "Lv 7", the same as the Hard beside it.
NORMAL_CEILING = BANDS["normal"][1] - 0.1


def log(*args) -> None:
    print("  ", *args, flush=True)


# ---------------------------------------------------------------- loading

STEM_DIRS = {"suno": "sources/suno_stems", "demucs": "sources/demucs_stems"}


def stem_files(song_id: str, source: str = "suno") -> dict[str, pathlib.Path]:
    folder = ROOT / STEM_DIRS[source] / song_id
    found = {}
    # Suno zips hold MP3 (WAV in older ones); demucs_stems.py writes FLAC.
    for f in [f for ext in ("mp3", "wav", "flac") for f in sorted(folder.glob(f"*.{ext}"))]:
        name = f.stem.split(" ", 1)[1].lower() if " " in f.stem else f.stem.lower()
        name = {"lead vocal": "lead vocals", "keyboards": "keyboard"}.get(name, name)
        found[name] = f
    return found


def decode(path: pathlib.Path, rate: int, channels: int) -> np.ndarray:
    """Decodes with macOS afconvert: libsndfile stops early on Suno's VBR MP3s."""
    import soundfile as sf
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / "x.wav"
        subprocess.run(["afconvert", "-f", "WAVE", "-d", f"LEI16@{rate}", "-c", str(channels), str(path), str(wav)],
                       check=True, capture_output=True)
        audio, _ = sf.read(str(wav), dtype="float32", always_2d=True)
    return audio.T if channels > 1 else audio[:, 0]


# ---------------------------------------------------------------- the beat

def estimate_tempo(onset: np.ndarray) -> float:
    """The beat's tempo from the onset envelope's autocorrelation: the strongest periodicity
    between 60 and 200 BPM, gently pulled toward 120. librosa started from the old chart's
    tempo locked onto a syncopation alias (Torpedo Lock: 117.5 for a 174 BPM drum and bass)."""
    # A real beat repeats at one beat, two beats and the bar; a syncopation alias (117.5 in a
    # 172 BPM drum and bass) is strong at one lag only. So each candidate is scored on all three.
    fps = SR / HOP
    e = onset - onset.mean()
    ac = np.correlate(e, e, mode="full")[len(e) - 1:]
    ac = ac / (ac[0] + 1e-9)

    def at(seconds: float) -> float:
        i = int(round(seconds * fps))
        return float(ac[max(0, i - 1):i + 2].max()) if i + 2 < len(ac) else 0.0

    lo, hi = int(60.0 / 200.0 * fps), int(60.0 / 60.0 * fps)
    best, best_score = 120.0, -1e18
    for lag in range(lo + 1, hi):
        if ac[lag] >= ac[lag - 1] and ac[lag] >= ac[lag + 1]:
            period = lag / fps
            bpm = 60.0 / period
            score = (at(period) + at(2 * period) + at(4 * period)) * math.exp(-0.5 * (math.log2(bpm / 120.0) / 1.5) ** 2)
            if score > best_score:
                best, best_score = bpm, score
    return best


def beat_grid(drums: np.ndarray, harmony: np.ndarray, bpm_hint: float) -> tuple[float, np.ndarray, np.ndarray]:
    """(bpm, beat times, downbeat times) from the drums stem (or the whole mix when the song
    has no drums); the downbeat is the beat phase where the kick and the chord changes land most."""
    import librosa
    has_drums = float(np.mean(np.abs(drums) > 0.01)) > 0.15
    source = drums if has_drums else harmony
    onset = librosa.onset.onset_strength(y=source, sr=SR, hop_length=HOP, aggregate=np.median)
    start = estimate_tempo(onset)
    tempo, beats = librosa.beat.beat_track(onset_envelope=onset, sr=SR, hop_length=HOP, start_bpm=start,
                                           units="time", tightness=120)
    bpm = float(np.atleast_1d(tempo)[0])
    if len(beats) < 8:
        step = 60.0 / bpm
        beats = np.arange(0.0, len(drums) / SR, step)
    mel = librosa.feature.melspectrogram(y=drums, sr=SR, hop_length=HOP, n_mels=64, fmax=8000)
    kick = librosa.onset.onset_strength(S=librosa.power_to_db(mel[:6]), sr=SR, hop_length=HOP)
    chroma = librosa.feature.chroma_cqt(y=harmony, sr=SR, hop_length=HOP)
    change = np.concatenate([[0.0], np.linalg.norm(np.diff(chroma, axis=1), axis=0)])

    def at(env: np.ndarray, t: float) -> float:
        i = int(t * SR / HOP)
        return float(env[max(0, i - 2):i + 3].max()) if i < len(env) else 0.0

    kick_n = kick / (np.percentile(kick, 99) + 1e-9)
    change_n = change / (np.percentile(change, 99) + 1e-9)
    scores = [sum(at(kick_n, b) + 0.7 * at(change_n, b) for b in beats[p::4]) / max(len(beats[p::4]), 1) for p in range(4)]
    phase = int(np.argmax(scores))
    downbeats = np.asarray(beats[phase::4])
    beats = np.asarray(beats)
    if bpm < 95.0 and len(beats) > 1:
        # A half-time reading (drum and bass at 86 for 172): the beat the player feels is twice as
        # fast, so the grid the notes are scored and spaced against gets the in-between beats.
        mids = (beats[:-1] + beats[1:]) / 2.0
        beats = np.sort(np.concatenate([beats, mids]))
        bpm *= 2.0
    return bpm, beats, downbeats


def metric_weight(t: float, beats: np.ndarray, downbeats: np.ndarray) -> float:
    """1 on a downbeat, 0.7 on a beat, 0.4 on an eighth, 0.15 on a sixteenth, 0.1 off the grid."""
    if len(beats) < 2:
        return 0.5
    i = int(np.searchsorted(beats, t))
    if 0 < i < len(beats):
        a, b = beats[i - 1], beats[i]
    elif i == 0:
        a, b = beats[0] - (beats[1] - beats[0]), beats[0]
    else:
        a, b = beats[-1], beats[-1] + (beats[-1] - beats[-2])
    step = b - a
    phase = (t - a) / max(step, 1e-6)
    near = lambda x: abs(phase - x) * step < 0.035
    if near(0.0) or near(1.0):
        on = a if near(0.0) else b
        return 1.0 if np.min(np.abs(downbeats - on)) < 0.03 else 0.7
    if near(0.5):
        return 0.4
    if near(0.25) or near(0.75):
        return 0.15
    return 0.1


# ---------------------------------------------------------------- big hits

def big_hits(drums: np.ndarray, mix: np.ndarray, beats: np.ndarray, downbeats: np.ndarray) -> list[tuple[float, float]]:
    """[(time, strength 0-1)] for the song's biggest accents, at least 1.5 s apart: drum slams
    and crashes (high-band bursts) plus the energy jumps into drops, scored at beat times."""
    import librosa
    full = librosa.onset.onset_strength(y=drums, sr=SR, hop_length=HOP)
    mel = librosa.feature.melspectrogram(y=drums, sr=SR, hop_length=HOP, n_mels=64, fmax=11000)
    crash = librosa.onset.onset_strength(S=librosa.power_to_db(mel[44:]), sr=SR, hop_length=HOP)
    rms = librosa.feature.rms(y=mix, hop_length=HOP)[0]
    norm = lambda e: e / (np.percentile(e, 99.5) + 1e-9)
    full, crash = norm(full), norm(crash)
    frames_per_s = SR / HOP
    scored = []
    for b in beats:
        i = int(b * frames_per_s)
        if i >= len(full):
            break
        before = rms[max(0, i - int(2 * frames_per_s)):i].mean() if i > 4 else rms[:4].mean()
        after = rms[i:i + int(1 * frames_per_s)].mean()
        jump = min(max(after / (before + 1e-6) - 1.0, 0.0), 2.0) / 2.0
        down = 1.0 if np.min(np.abs(downbeats - b)) < 0.03 else 0.0
        value = 0.45 * full[max(0, i - 2):i + 3].max() + 0.3 * crash[max(0, i - 2):i + 3].max() + 0.5 * jump + 0.15 * down
        scored.append((float(b), float(value)))
    if not scored:
        return []
    values = np.array([v for _, v in scored])
    threshold = np.percentile(values, 93)
    chosen: list[tuple[float, float]] = []
    for t, v in sorted(scored, key=lambda x: -x[1]):
        if v < threshold:
            break
        if all(abs(t - c) >= 1.5 for c, _ in chosen):
            chosen.append((t, v))
    top = max(v for _, v in chosen)
    return sorted((t, v / top) for t, v in chosen)


# ---------------------------------------------------------------- the lead line

def transcribe_stem(audio: np.ndarray, sung: bool) -> list[dict]:
    """Basic Pitch on one clean stem (the importer's transcription, monophonic for a voice,
    the top line for an instrument)."""
    import soundfile as sf
    from import_song import transcribe, refine_with_pyin, merge_repeats
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / "stem.wav"
        sf.write(str(wav), audio, SR, subtype="PCM_16")
        notes = transcribe(wav, sung)
    if sung and notes:
        notes = refine_with_pyin(notes, audio, SR)
    return merge_repeats(notes)


def choose_leads(stems: dict[str, np.ndarray], notes: dict[str, list[dict]], downbeats: np.ndarray,
                 duration: float) -> list[tuple[float, float, str]]:
    """[(bar start, bar end, stem)]: the stem carrying the tune in each bar, by its loudness
    against the mix, how much it plays there and its preference; a new stem takes over only
    when clearly ahead for two bars running, so the lead does not flicker."""
    bars = list(downbeats) + [duration]
    if bars[0] > 0.5:
        bars = [0.0] + bars
    mix_rms = {}
    out = []
    current = None
    challenger, challenger_bars = None, 0
    for a, b in zip(bars, bars[1:]):
        i0, i1 = int(a * SR), int(b * SR)
        scores = {}
        for name, weight in MELODIC.items():
            if name not in stems:
                continue
            seg = stems[name][i0:i1]
            loud = float(np.sqrt(np.mean(seg ** 2))) if len(seg) else 0.0
            count = sum(1 for n in notes.get(name, []) if a <= n["t"] < b)
            if count == 0 or loud < 1e-3:
                continue
            scores[name] = weight * loud * min(count, 8) ** 0.5
        best = max(scores, key=scores.get) if scores else None
        if current is None or current not in scores:
            current = best
        elif best and best != current and scores[best] > 1.3 * scores[current]:
            if challenger == best:
                challenger_bars += 1
            else:
                challenger, challenger_bars = best, 1
            if challenger_bars >= 2:
                current, challenger, challenger_bars = best, None, 0
        else:
            challenger, challenger_bars = None, 0
        out.append((a, b, current or ""))
    return out


# ---------------------------------------------------------------- salience and tiers

def onset_env(audio: np.ndarray) -> np.ndarray:
    import librosa
    e = librosa.onset.onset_strength(y=audio, sr=SR, hop_length=HOP)
    return e / (np.percentile(e, 99) + 1e-9)


def score_notes(lead: list[dict], envs: dict[str, np.ndarray], beats: np.ndarray, downbeats: np.ndarray,
                hits: list[tuple[float, float]]) -> None:
    """Sets n["sal"] on every note: how much it matters to a listener."""
    hit_times = np.array([t for t, _ in hits]) if hits else np.array([1e9])
    for i, n in enumerate(lead):
        env = envs.get(n["src"])
        j = int(n["t"] * SR / HOP)
        strike = float(env[max(0, j - 2):j + 3].max()) if env is not None and j < len(env) else 0.5
        metric = metric_weight(n["t"], beats, downbeats)
        length = min(n["d"], 1.0)
        phrase = 1.0 if i == 0 or n["t"] - (lead[i - 1]["t"] + lead[i - 1]["d"]) > 0.6 else 0.0
        neighbours = [lead[k]["p"] for k in range(max(0, i - 2), min(len(lead), i + 3)) if k != i]
        contour = 1.0 if neighbours and (n["p"] >= max(neighbours) or n["p"] <= min(neighbours)) else 0.0
        accent = 1.0 if np.min(np.abs(hit_times - n["t"])) < 0.08 else 0.0
        n["sal"] = 0.3 * min(strike, 1.5) + 0.25 * metric + 0.15 * length + 0.12 * phrase + 0.08 * contour + 0.35 * accent


def thin(notes: list[dict], min_gap: float) -> list[dict]:
    """Of notes closer than `min_gap`, keeps the more salient (a chord's notes travel together)."""
    kept: list[dict] = []
    for n in sorted(notes, key=lambda n: -n["sal"]):
        if all(abs(n["t"] - k["t"]) >= min_gap or abs(n["t"] - k["t"]) < 0.005 for k in kept):
            kept.append(n)
    return sorted(kept, key=lambda n: n["t"])


def easy_pick(pool: list[dict], gap: float, beats: np.ndarray, downbeats: np.ndarray) -> list[dict]:
    """Easy: notes that sound on the beat (or the eighth between), most salient first, at least
    `gap` apart; big hits always; an off-grid note only where Easy would otherwise go quiet for
    more than two seconds. Playtest: Easy "felt almost random" when chosen by spacing alone."""
    def weight(n: dict) -> float:
        return metric_weight(n["t"], beats, downbeats)

    on_grid = [n for n in pool if n.get("keep") or weight(n) >= 0.4]
    ranked = sorted(on_grid, key=lambda n: -(n["sal"] + 0.6 * weight(n) + (1.0 if n.get("keep") else 0.0)))
    kept: list[dict] = []
    for n in ranked:
        if all(abs(n["t"] - k["t"]) >= gap for k in kept):
            kept.append(n)
    kept.sort(key=lambda n: n["t"])
    # Fill long silences from the off-grid notes, most salient first.
    times = [0.0] + [k["t"] for k in kept] + [1e9]
    extra = []
    for a, b in zip(times, times[1:]):
        if b - a > 2.0:
            inside = [n for n in pool if a + gap <= n["t"] <= b - gap and n not in kept]
            for n in sorted(inside, key=lambda n: -n["sal"]):
                if all(abs(n["t"] - k["t"]) >= gap for k in kept + extra):
                    extra.append(n)
    return sorted(kept + extra, key=lambda n: n["t"])


def level_of(notes: list[dict]) -> float:
    return difficulty.rate(notes)["level"] if len(notes) > 1 else 1.0


def thin_to(notes: list[dict], ceiling: float, floor_gap: float) -> list[dict]:
    """Removes the least salient note from the busiest stretch until the level is at or under
    `ceiling` (or nothing more can go without breaking the song)."""
    notes = thin(notes, floor_gap)
    guard = 0
    while level_of(notes) > ceiling and len(notes) > 16 and guard < 2000:
        guard += 1
        times = np.array([n["t"] for n in notes])
        # The densest 4 s window.
        counts = [np.sum((times >= t) & (times < t + 4.0)) for t in times]
        start = times[int(np.argmax(counts))]
        window = [n for n in notes if start <= n["t"] < start + 4.0 and not n.get("keep")]
        if not window:
            window = [n for n in notes if not n.get("keep")]
            if not window:
                break
        drop = min(window, key=lambda n: n["sal"])
        notes = [n for n in notes if n is not drop and not (n.get("chord_of") is drop)]
    return notes


def normal_tier(pool: list[dict], hits: list[tuple[float, float]], ceiling: float, gap: float) -> list[dict]:
    """Normal: the pool thinned, plus power chords on its biggest hits, at or under `ceiling` with
    the chords in. (Thinning to the ceiling and then adding chords put Kill Feed Aftermath's Normal
    at 6.5, which the menu shows as Lv 7.)"""
    target = ceiling
    for _ in range(8):
        normal = with_power_chords(thin_to(pool, target, gap), hits, 0.25)
        if level_of(normal) <= ceiling:
            break
        target -= 0.1
    return normal


LANE_CLEAR = 0.3  # seconds kept free around a chord note on its key (see with_power_chords)


def _hand_and_x(n: dict) -> tuple[int, float]:
    """Which hand plays a note and where its key sits across the board (Difficulty's layout)."""
    if n.get("s"):
        i = min(max(int(n["l"]), 0), len(difficulty.SHARP_HANDS) - 1)
        return difficulty.SHARP_HANDS[i], i + 0.5
    return (0 if n["l"] < 5 else 1), float(n["l"])


def with_power_chords(notes: list[dict], hits: list[tuple[float, float]], share: float) -> list[dict]:
    """Adds a second key to the notes on the strongest `share` of big hits: the mirror key on
    the other hand (or the nearest free home key on that hand), so a power chord is always one
    finger per hand. Works on copies: the tiers share note dicts, and marking a Hard chord's
    note in place left lone "pw" notes in Normal (2026-11-11). A key that already has a note
    within LANE_CLEAR of the chord is not used: the judge gives a press to the nearest note on
    its key, so a neighbour that close could take the chord's press."""
    out = [{k: v for k, v in n.items() if k not in ("pw", "chord_of")} for n in notes]
    strongest = sorted(hits, key=lambda h: -h[1])[:max(1, int(round(len(hits) * share)))] if hits else []
    for t, _ in strongest:
        near = [n for n in out if abs(n["t"] - t) < 0.08 and not n.get("pw") and not n.get("chord_of")]
        if not near:
            continue
        n = max(near, key=lambda n: n["sal"])
        hand, x = _hand_and_x(n)
        start, end = n["t"] - LANE_CLEAR, n["t"] + n["d"] + LANE_CLEAR
        for lane in sorted(range(5, 10) if hand == 0 else range(0, 5), key=lambda l: abs(l - (9.0 - x))):
            busy = any(m is not n and m["l"] == lane and not m.get("s") and m["t"] < end and m["t"] + m["d"] > start
                       for m in out)
            if not busy:
                n["pw"] = 1
                out.append({"t": n["t"], "d": n["d"], "p": n["p"], "l": lane, "pw": 1, "sal": n["sal"], "chord_of": n})
                break
    return sorted(out, key=lambda n: (n["t"], n["l"]))


def public(notes: list[dict]) -> list[dict]:
    keys = ("t", "d", "p", "l", "s", "pw")
    out = []
    for n in notes:
        d = {k: n[k] for k in keys if k in n and n[k] not in (None, 0) or k in ("t", "d", "p", "l")}
        d["t"], d["d"] = round(float(n["t"]), 4), round(float(n["d"]), 4)
        out.append(d)
    return out


# ---------------------------------------------------------------- the whole song

def chart_song(song_id: str, keep_audio: bool = False, source: str = "suno") -> dict:
    chart_path = ROOT / "game/data/songs" / f"{song_id}.json"
    old = json.loads(chart_path.read_text())
    files = stem_files(song_id, source)
    missing = [s for s in ("drums", "bass") if s not in files]
    if not files or missing:
        raise SystemExit(f"{song_id}: no stems (missing {missing or 'all'})")
    log("decoding", len(files), "stems")
    stems = {name: decode(path, SR, 1) for name, path in files.items()}
    length = max(len(a) for a in stems.values())
    for name in stems:
        stems[name] = np.pad(stems[name], (0, length - len(stems[name])))
    duration = length / SR
    mix = sum(stems.values())
    # Demucs has no keys / synth / strings / guitar stems, only "other": without it the harmony
    # (downbeats; the beats too in a song with no drums) was the bass alone.
    chordal = [s for s in ("keyboard", "synth", "strings", "guitar") if s in stems] or [s for s in ("other",) if s in stems]
    harmony = sum(stems[s] for s in ["bass", *chordal] if s in stems)

    bpm, beats, downbeats = beat_grid(stems["drums"], harmony, float(old.get("bpm", 120.0)))
    log(f"{bpm:.1f} BPM, {len(beats)} beats, {len(downbeats)} bars")
    hits = big_hits(stems["drums"], mix, beats, downbeats)
    log(len(hits), "big hits")

    notes: dict[str, list[dict]] = {}
    for name in MELODIC:
        if name not in stems:
            continue
        active = float(np.mean(np.abs(stems[name]) > 0.01))
        if active < 0.03:
            continue
        found = transcribe_stem(stems[name], sung=name.endswith("vocals"))
        for n in found:
            n["src"] = name
        notes[name] = found
        log(f"{name}: {len(found)} notes")
    leads = choose_leads(stems, notes, downbeats, duration)
    lead: list[dict] = []
    for a, b, name in leads:
        lead += [n for n in notes.get(name, []) if a <= n["t"] < b]
    # Fills: long rests in the lead take the next busiest line's notes.
    fills: list[dict] = []
    edges = [0.0] + [x for n in lead for x in (n["t"], n["t"] + n["d"])] + [duration]
    for i in range(0, len(edges) - 1, 2):
        start, end = edges[i] + 0.3, edges[i + 1] - 0.3
        if end - start < 1.2:
            continue
        for name in sorted(notes, key=lambda s: -len([n for n in notes[s] if start <= n["t"] <= end])):
            found = [dict(n, fill=True) for n in notes[name] if start <= n["t"] and n["t"] + n["d"] <= end]
            if found:
                fills += found
                break
    hard_pool = sorted(lead + fills, key=lambda n: n["t"])
    # Every big hit gets a note: if the line is silent there, one on the nearest pitch.
    for t, v in hits:
        if not any(abs(n["t"] - t) < 0.08 for n in hard_pool):
            near = min(hard_pool, key=lambda n: abs(n["t"] - t)) if hard_pool else {"p": 60}
            hard_pool.append({"t": t, "d": 0.2, "p": near["p"], "src": "drums", "hit": True})
    hard_pool.sort(key=lambda n: n["t"])
    # Onto the beat grid where a note is within 35 ms of a sixteenth.
    sixteenths = np.sort(np.concatenate([beats + (beats[1] - beats[0]) * k / 4.0 for k in range(4)])) if len(beats) > 1 else beats
    for n in hard_pool:
        if len(sixteenths):
            g = sixteenths[int(np.argmin(np.abs(sixteenths - n["t"])))]
            if abs(g - n["t"]) < 0.035:
                n["t"] = float(g)
    envs = {name: onset_env(stems[name]) for name in set(n["src"] for n in hard_pool) if name in stems}
    score_notes(hard_pool, envs, beats, downbeats, hits)
    for n in hard_pool:
        n["keep"] = bool(n.get("hit")) or any(abs(n["t"] - t) < 0.08 for t, _ in hits)
    hard_pool = thin(hard_pool, 0.09)

    # Lanes once, on the fullest set, so a note sits on the same key at every level.
    if any(out for _, out in songlib.scale_positions(hard_pool)):
        laned, _, _ = songlib.assign_lanes_with_sharps(hard_pool)
    else:
        resting, folded = songlib.assign_lanes(hard_pool, songlib.EASY_LANES)
        laned = resting if folded == 0 else songlib.assign_lanes(hard_pool, songlib.NORMAL_LANES)[0]
    for n, m in zip(hard_pool, laned):
        n["l"] = m["l"]
        if m.get("s"):
            n["s"] = 1
    for n in hard_pool:
        n["d"] = max(0.06, n["d"])
    for a, b in zip(hard_pool, hard_pool[1:]):
        if b["t"] - a["t"] > 0.005:
            a["d"] = max(0.06, min(a["d"], b["t"] - a["t"] - 0.03))

    hard = with_power_chords(hard_pool, hits, 0.6)
    normal_pool = [n for n in hard_pool if not n.get("fill") or n["keep"]]
    normal = normal_tier(normal_pool, hits, NORMAL_CEILING, 0.16)
    if level_of(hard) - level_of(normal) < 1.2:
        normal = normal_tier([n for n in normal if not n.get("chord_of")], hits, level_of(hard) - 1.5, 0.2)
    easy_pool = [dict(n) for n in normal if not n.get("chord_of")]
    for n in easy_pool:
        n.pop("pw", None)
        n.pop("s", None)
    beat = 60.0 / bpm
    gap = max(0.45, beat * 0.9)
    easy = easy_pick(easy_pool, gap, beats, downbeats)
    while level_of(songlib.assign_lanes(easy, songlib.EASY_LANES)[0]) > BANDS["easy"][1] and gap < 1.6:
        gap += 0.1
        easy = easy_pick(easy_pool, gap, beats, downbeats)
    easy = songlib.assign_lanes(easy, songlib.EASY_LANES)[0]
    for n in easy:
        n.pop("s", None)

    levels = {k: round(level_of(v), 2) for k, v in (("easy", easy), ("normal", normal), ("hard", hard))}
    log("notes", {"easy": len(easy), "normal": len(normal), "hard": len(hard)}, "levels", levels)
    lead_names = sorted(set(name for _, _, name in leads if name))
    meta = {k: v for k, v in old.items() if k not in ("difficulties", "notes", "lanes")}
    meta.update({"bpm": round(bpm, 2), "beat_offset": round(float(downbeats[0]) if len(downbeats) else 0.0, 4),
                 "duration": round(duration, 3), "lead_source": ("stems: " if source == "suno" else "demucs: ") + ", ".join(lead_names),
                 "stem_source": source, "chart_version": 2, "big_hits": len(hits)})
    chart = {**meta, "lanes": "home_row",
             "difficulties": {"easy": public(easy), "normal": public(normal), "hard": public(hard)},
             "notes": public(normal)}
    chart_path.write_text(json.dumps(chart, indent=1))
    if not keep_audio:
        write_audio(song_id, files, leads)
    return {"id": song_id, "levels": levels, "counts": {"easy": len(easy), "normal": len(normal), "hard": len(hard)},
            "bpm": round(bpm, 1), "hits": len(hits), "leads": lead_names}


def write_audio(song_id: str, files: dict[str, pathlib.Path], leads: list[tuple[float, float, str]]) -> None:
    """lead.ogg: each bar's lead stem (40 ms fades at the changes); backing.ogg: the rest."""
    from import_song import write_stem
    rate = 44100
    full = {name: decode(path, rate, 2) for name, path in files.items()}
    length = max(a.shape[1] for a in full.values())
    for name in full:
        full[name] = np.pad(full[name], ((0, 0), (0, length - full[name].shape[1])))
    lead = np.zeros((2, length), dtype=np.float32)
    backing = np.zeros((2, length), dtype=np.float32)
    for name, audio in full.items():
        gain = np.zeros(length, dtype=np.float32)
        for a, b, chosen in leads:
            if chosen == name:
                gain[int(a * rate):int(b * rate)] = 1.0
        fade = int(0.04 * rate)
        gain = np.convolve(gain, np.ones(fade) / fade, mode="same").astype(np.float32)
        lead += audio * gain
        backing += audio * (1.0 - gain)
    out = ROOT / "game/assets/songs" / song_id
    out.mkdir(parents=True, exist_ok=True)
    # The game's audio isn't in git: keep the first importer's pair once, so a chart can go back.
    keep = ROOT / "sources/audio_v1" / song_id
    if not keep.exists() and (out / "lead.ogg").exists():
        keep.mkdir(parents=True)
        for f in ("lead.ogg", "backing.ogg"):
            if (out / f).exists():
                shutil.copy2(out / f, keep / f)
    peak = max(float(np.max(np.abs(lead + backing))), 1e-6)
    scale = min(1.0, 0.98 / peak)
    write_stem(out / "lead.ogg", lead * scale, rate)
    write_stem(out / "backing.ogg", backing * scale, rate)
    log("audio written")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    result = chart_song(args[0], keep_audio="--keep-audio" in sys.argv,
                        source="demucs" if "--demucs" in sys.argv else "suno")
    print("RESULT", json.dumps(result))
