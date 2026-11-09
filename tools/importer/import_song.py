"""Turns a player's own song into a playable chart with stems. Run by the game.

  python import_song.py <input> <out_dir> --theme <region id> [--title "..."]

Audio (MP3, WAV, FLAC, OGG, AIFF):
  1. Demucs splits the mix into vocals / drums / bass / other.
  2. The lead is the vocal stem; if there is barely any voice, the "other" stem.
  3. Basic Pitch transcribes the lead, reduced to one note at a time with octave
     slips fixed, then checked against a pitch tracker (pyin) for a sung lead.
  4. librosa finds the tempo, first downbeat and key. Onsets close to the beat
     grid are snapped to it, and the key is moved to C major / A minor so the
     lanes sit on the Q row's white keys (lanes only: the audio is untouched).
  5. Writes backing.wav (everything but the lead), lead.wav and chart.json.
MIDI (.mid, .midi):
  The melody track (named vocal / melody / lead, else the busiest high track) is
  the lead; every track is rendered offline by SuperCollider with the region's
  instruments, and the chart comes from the melody's notes.

Progress goes to stdout, one line each, for the game to show:
  PROGRESS <0..1> <message>  /  DONE <chart path>  /  ERROR <message>
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import traceback

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "tools/song"))
sys.path.insert(0, str(ROOT / "pipeline"))
import songlib  # noqa: E402

LEADS = {"backroads": "steel", "neon": "sawlead", "coast": "flute", "mesa": "drive", "aurora": "piano"}
KEY_PROFILE_MAJOR = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
KEY_PROFILE_MINOR = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]


def progress(fraction: float, message: str) -> None:
    print(f"PROGRESS {fraction:.3f} {message}", flush=True)


def fail(message: str) -> None:
    print(f"ERROR {message}", flush=True)
    sys.exit(1)


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")[:40] or "song"


# ---------------------------------------------------------------- audio

def separate(mix, sr: int):
    """Demucs htdemucs. Reports progress through its own chunk loop."""
    import numpy as np
    import torch
    from demucs import apply as demucs_apply
    from demucs.pretrained import get_model

    model = get_model("htdemucs")
    model.eval()

    class _Ticker:  # demucs drives a tqdm over its chunks; this turns that into progress lines
        def __init__(self, iterable, **_):
            self.items = list(iterable)

        def __iter__(self):
            for i, item in enumerate(self.items):
                progress(0.08 + 0.55 * i / max(1, len(self.items)), "Separating the vocals from the band")
                yield item

    demucs_apply.tqdm = type("tqdm_shim", (), {"tqdm": _Ticker})
    wav = torch.tensor(mix, dtype=torch.float32)
    ref = wav.mean(0)
    wav = (wav - ref.mean()) / (ref.std() + 1e-8)
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    try:
        with torch.no_grad():
            out = demucs_apply.apply_model(model, wav[None], device=device, split=True, overlap=0.25, progress=True)[0]
    except Exception:  # some operations are missing on Apple's GPU; the CPU always works
        with torch.no_grad():
            out = demucs_apply.apply_model(model, wav[None], device="cpu", split=True, overlap=0.25, progress=True)[0]
    out = out * ref.std() + ref.mean()
    return {name: out[i].cpu().numpy().astype(np.float32) for i, name in enumerate(model.sources)}


def transcribe(path: pathlib.Path, sung: bool) -> list[dict]:
    from basic_pitch import ICASSP_2022_MODEL_PATH
    from basic_pitch.inference import predict
    from transcribe import monophonic, smooth_octaves  # the repo's own pipeline helpers

    if sung:
        kwargs = dict(onset_threshold=0.45, frame_threshold=0.3, minimum_note_length=110,
                      minimum_frequency=70, maximum_frequency=1100, melodia_trick=True)
    else:
        kwargs = dict(onset_threshold=0.55, frame_threshold=0.35, minimum_note_length=100, melodia_trick=True)
    _, _, events = predict(str(path), ICASSP_2022_MODEL_PATH, **kwargs)
    notes = [(float(s), float(e), int(p), float(a)) for s, e, p, a, *_ in events]
    # A voice is one note at a time already; an instrumental stem is chords and
    # accompaniment, where the melody is usually the highest line.
    melody = smooth_octaves(monophonic(notes) if sung else top_line(notes))
    return [{"t": s, "d": e - s, "p": p} for s, e, p, _ in melody]


def top_line(notes: list[tuple], min_len: float = 0.09) -> list[tuple]:
    """The highest voice: of notes starting together keep the top one, ignore notes that
    start underneath a melody note still sounding, and let a higher note cut the last one off."""
    notes = sorted((n for n in notes if n[1] - n[0] >= min_len), key=lambda n: (n[0], -n[2]))
    out: list[tuple] = []
    for s, e, p, a in notes:
        if out:
            ps, pe, pp, pa = out[-1]
            if s - ps < 0.05:
                continue
            if s < pe:
                if p < pp:
                    continue
                out[-1] = (ps, s, pp, pa)
        out.append((s, e, p, a))
    return out


def refine_with_pyin(notes: list[dict], lead_mono, sr: int) -> list[dict]:
    """Second opinion for a sung lead: fix octave slips, retune strays, drop breaths."""
    import librosa
    import numpy as np

    y = librosa.resample(lead_mono, orig_sr=sr, target_sr=22050)
    hop = 512
    f0, _, _ = librosa.pyin(y, fmin=librosa.note_to_hz("E2"), fmax=librosa.note_to_hz("C6"), sr=22050,
                            hop_length=hop, frame_length=2048)
    times = librosa.times_like(f0, sr=22050, hop_length=hop)
    midi = librosa.hz_to_midi(f0)
    kept = []
    for n in notes:
        i0 = int(np.searchsorted(times, n["t"]))
        i1 = max(i0 + 1, int(np.searchsorted(times, n["t"] + n["d"])))
        seg = midi[i0:i1]
        voiced = seg[~np.isnan(seg)]
        if len(voiced) < max(1, 0.3 * len(seg)):
            continue
        heard = float(np.median(voiced))
        p = n["p"]
        if abs(heard - (p + 12)) < 1.5 or abs(heard - (p - 12)) < 1.5:
            p = p + 12 if heard > p else p - 12
        elif abs(heard - p) > 2.5:
            p = int(round(heard))
        kept.append({**n, "p": p})
    return kept


def merge_repeats(notes: list[dict], gap: float = 0.07) -> list[dict]:
    """A held sung note often comes back from transcription as several pieces (vibrato,
    a breath in the middle). Same pitch with only a sliver between them is one note, and
    so becomes a hold instead of a run of taps."""
    out: list[dict] = []
    for n in sorted(notes, key=lambda n: n["t"]):
        if out and n["p"] == out[-1]["p"] and n["t"] - (out[-1]["t"] + out[-1]["d"]) <= gap:
            out[-1]["d"] = n["t"] + n["d"] - out[-1]["t"]
        else:
            out.append(dict(n))
    return out


def tempo_and_key(mono, sr: int) -> tuple[float, float, int]:
    """(bpm, first beat in seconds, semitone shift that moves the key to C major / A minor)."""
    import librosa
    import numpy as np

    y = librosa.resample(mono, orig_sr=sr, target_sr=22050)
    tempo, beats = librosa.beat.beat_track(y=y, sr=22050, units="time")
    bpm = float(np.atleast_1d(tempo)[0])
    if not 60 <= bpm <= 200:
        bpm = 120.0
    offset = float(beats[0]) % (60.0 / bpm) if len(beats) else 0.0
    chroma = librosa.feature.chroma_cqt(y=y, sr=22050).mean(axis=1)
    best, shift = -2.0, 0
    for tonic in range(12):
        for profile, target in ((KEY_PROFILE_MAJOR, 0), (KEY_PROFILE_MINOR, 9)):
            score = float(np.corrcoef(np.roll(profile, tonic), chroma)[0, 1])
            if score > best:
                best, shift = score, ((target - tonic + 6) % 12) - 6
    return bpm, offset, shift


def snap_to_grid(notes: list[dict], bpm: float, offset: float, tolerance: float = 0.04) -> list[dict]:
    """Nudges onsets within 40 ms of a sixteenth-note gridline onto it. Further out, the
    singer meant it, and it stays."""
    step = 60.0 / bpm / 4.0
    out = []
    for n in notes:
        k = round((n["t"] - offset) / step)
        grid = offset + k * step
        t = grid if abs(grid - n["t"]) <= tolerance else n["t"]
        out.append({**n, "t": max(0.0, t)})
    return out


def import_audio(src: pathlib.Path, out: pathlib.Path, theme: str, title: str) -> dict:
    import librosa
    import numpy as np
    import soundfile as sf

    progress(0.02, "Reading the audio")
    sr = 44100
    mix, _ = librosa.load(str(src), sr=sr, mono=False)
    if mix.ndim == 1:
        mix = np.stack([mix, mix])
    duration = mix.shape[1] / sr
    if duration < 20:
        fail("That song is under 20 seconds; pick a full track.")
    if duration > 600:
        fail("That song is over 10 minutes; pick something shorter.")
    progress(0.06, "Loading the separation model")
    stems = separate(mix, sr)
    vocal_rms = float(np.sqrt(np.mean(stems["vocals"] ** 2)))
    mix_rms = float(np.sqrt(np.mean(mix ** 2))) + 1e-9
    sung = vocal_rms > 0.12 * mix_rms
    lead_name = "vocals" if sung else "other"
    lead = stems[lead_name]
    backing = sum(v for k, v in stems.items() if k != lead_name)
    out.mkdir(parents=True, exist_ok=True)
    sf.write(out / "lead.wav", np.clip(lead.T, -1, 1), sr, subtype="PCM_16")
    sf.write(out / "backing.wav", np.clip(backing.T, -1, 1), sr, subtype="PCM_16")

    progress(0.66, "Finding the melody" if sung else "No vocal found: finding the lead instrument")
    notes = transcribe(out / "lead.wav", sung)
    if sung:
        progress(0.78, "Checking every note against the voice")
        notes = refine_with_pyin(notes, lead.mean(axis=0), sr)
    progress(0.88, "Finding the tempo and key")
    bpm, offset, shift = tempo_and_key(mix.mean(axis=0), sr)
    notes = snap_to_grid(merge_repeats(notes), bpm, offset)
    if len(notes) < 12:
        fail("Could not find a clear melody in that song.")
    normal = songlib.clean_notes(songlib.fold_to_lanes(notes, shift))
    meta = {"lead_source": lead_name, "key_shift": shift, "vocal_ratio": round(vocal_rms / mix_rms, 3)}
    return finish(out, src, theme, title, bpm, offset, duration, normal, meta)


# ---------------------------------------------------------------- MIDI

GM_DRUMS = {35: "kick", 36: "kick", 37: "snare", 38: "snare", 39: "snare", 40: "snare", 42: "hat", 44: "hat",
            46: "hat", 49: "crash", 57: "crash", 41: "tom", 43: "tom", 45: "tom", 47: "tom", 48: "tom", 50: "tom"}


def gm_instrument(program: int) -> str:
    if program < 8:
        return "piano"
    if program < 16:
        return "bell"
    if program < 24:
        return "organ"
    if program < 32:
        return "pick"
    if program < 40:
        return "synthbass" if program >= 38 else "bass"
    if program < 64:
        return "pad"
    if program < 80:
        return "flute"
    if program < 88:
        return "sawlead"
    if program < 104:
        return "pad"
    return "pick" if program < 112 else "bell"


def pick_melody(pm):
    candidates = [i for i in pm.instruments if not i.is_drum and len(i.notes) >= 8]
    if not candidates:
        fail("That MIDI file has no melody to play.")
    named = [i for i in candidates if re.search(r"vocal|melody|lead|voice|sing", i.name or "", re.I)]
    if named:
        return named[0]
    return max(candidates, key=lambda i: (sum(n.pitch for n in i.notes) / len(i.notes)) * (len(i.notes) ** 0.5))


def import_midi(src: pathlib.Path, out: pathlib.Path, theme: str, title: str) -> dict:
    import pretty_midi

    progress(0.05, "Reading the MIDI file")
    pm = pretty_midi.PrettyMIDI(str(src))
    melody_inst = pick_melody(pm)
    # The melody track, one note at a time: the highest of any notes that start together.
    raw = sorted(melody_inst.notes, key=lambda n: (round(n.start, 3), -n.pitch))
    line: list[dict] = []
    for n in raw:
        if line and abs(n.start - line[-1]["t"]) < 0.03:
            continue
        line.append({"t": n.start, "d": n.end - n.start, "p": n.pitch})
    backing, lead = [], []
    for inst in pm.instruments:
        for n in inst.notes:
            amp = round(0.12 + 0.35 * n.velocity / 127, 3)
            if inst.is_drum:
                name = GM_DRUMS.get(n.pitch, "shaker")
                backing.append([n.start, name, 60, 0.1, amp, 0.0])
            elif inst is melody_inst:
                continue
            else:
                backing.append([n.start, gm_instrument(inst.program), n.pitch, n.end - n.start, amp * 0.8, 0.0])
    for n in line:
        lead.append([n["t"], LEADS.get(theme, "steel"), n["p"], n["d"], 0.42, 0.0])
    duration = pm.get_end_time() + 2.5
    progress(0.2, "Recording the band (SuperCollider)")
    out.mkdir(parents=True, exist_ok=True)
    score = out / "score.scd"
    songlib.write_score(score, duration, backing, lead, {"backing": [0.2, 0.6, 0.0], "lead": [0.3, 0.72, 0.16]})
    sclang = shutil.which("sclang", path=os.environ.get("PATH", "") + ":/opt/homebrew/bin:/usr/local/bin")
    if not sclang:
        fail("MIDI songs need SuperCollider (sclang) to record the band.")
    result = subprocess.run([sclang, str(ROOT / "tools/song/render_score.scd"), str(score), str(out),
                             str(ROOT / "tools/song/synths")], capture_output=True, text=True, timeout=900)
    if not (out / "backing.wav").exists() or not (out / "lead.wav").exists():
        fail("SuperCollider could not record the song: " + result.stdout[-300:])
    score.unlink(missing_ok=True)
    tempos = pm.get_tempo_changes()[1]
    bpm = float(tempos[0]) if len(tempos) else 120.0
    downbeats = pm.get_downbeats()
    offset = float(downbeats[0]) if len(downbeats) else 0.0
    progress(0.9, "Writing the chart")
    normal = songlib.clean_notes(songlib.fold_to_lanes(line, 0))
    return finish(out, src, theme, title, bpm, offset, duration, normal, {"lead_source": melody_inst.name or "melody"})


# ---------------------------------------------------------------- shared

def finish(out: pathlib.Path, src: pathlib.Path, theme: str, title: str, bpm: float, offset: float,
           duration: float, normal: list[dict], extra: dict) -> dict:
    meta = {
        "id": out.name, "title": title, "theme": theme, "bpm": round(bpm, 3), "beats_per_bar": 4,
        "beat_offset": round(offset % (60.0 / bpm), 4), "duration": round(duration, 3),
        "backing": "backing.wav", "lead": "lead.wav", "sections": [], "source": "imported",
        "original_file": src.name, **extra,
    }
    chart = songlib.write_chart(out / "chart.json", meta, normal)
    holds = sum(1 for n in normal if n["d"] >= songlib.HOLD_MIN)
    progress(1.0, f"{len(normal)} notes, {holds} holds")
    return chart


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("out_dir")
    ap.add_argument("--theme", default="backroads")
    ap.add_argument("--title", default=None)
    args = ap.parse_args()
    src = pathlib.Path(args.input).expanduser()
    if not src.exists():
        fail(f"Cannot find {src}")
    out = pathlib.Path(args.out_dir).expanduser()
    title = args.title or re.sub(r"[_-]+", " ", src.stem).strip().title()
    try:
        if src.suffix.lower() in (".mid", ".midi"):
            import_midi(src, out, args.theme, title)
        else:
            import_audio(src, out, args.theme, title)
    except SystemExit:
        raise
    except Exception as exc:  # the game shows this line; the traceback goes to stderr
        traceback.print_exc()
        fail(f"{type(exc).__name__}: {exc}")
    print(f"DONE {out / 'chart.json'}", flush=True)


if __name__ == "__main__":
    main()
