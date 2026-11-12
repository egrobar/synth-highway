"""Separates a built-in song's original mix into four stems with Demucs (htdemucs), for stem_chart.py.

The station songs chart best from Suno's own stems (sources/suno_stems/), but the account's stem
downloads ran out on 2026-11-11 (21 a month, next on 2026-12-09) with 50 songs still to go. This
gives those songs the same charter from Demucs's four stems instead: the drums for the beat grid
and the big hits, the bass, the vocals and "other" (everything melodic that isn't sung) for the
lead. Fewer, muddier stems than Suno's eleven, but the beats, downbeats and hits come from a real
drum track instead of the whole mix.

Reads the song's original file from space-mmo's radio folder (the chart's "original_file"), runs
the same Demucs setup as import_song.separate, and writes FLAC (Core Audio's afconvert reads it,
and it is half the size of WAV) to sources/demucs_stems/<id>/ under Suno's stem names:
"0 Lead Vocals", "2 Drums", "3 Bass", "8 Other".

Usage: .venv-pipeline/bin/python tools/importer/demucs_stems.py <song id> [...]
Env:   RADIO=/path/to/space-mmo/assets/radio
"""
from __future__ import annotations

import json
import os
import pathlib
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/importer"))
RADIO = pathlib.Path(os.environ.get("RADIO", str(pathlib.Path.home() / "Desktop/space-mmo/assets/radio")))
RATE = 44100  # htdemucs's rate
NAMES = {"vocals": "0 Lead Vocals", "drums": "2 Drums", "bass": "3 Bass", "other": "8 Other"}


def original_file(song_id: str) -> pathlib.Path:
    chart = json.loads((ROOT / "game/data/songs" / f"{song_id}.json").read_text())
    name = chart.get("original_file")
    if not name:
        raise SystemExit(f"{song_id}: the chart names no original_file")
    found = sorted(RADIO.glob(f"*/{name}"))
    if not found:
        raise SystemExit(f"{song_id}: {name} not found under {RADIO}")
    return found[0]


def separate_song(song_id: str) -> pathlib.Path:
    import librosa
    import soundfile as sf
    from import_song import separate

    out = ROOT / "sources/demucs_stems" / song_id
    if all((out / f"{n}.flac").exists() for n in NAMES.values()):
        print(f"{song_id}: already separated", flush=True)
        return out
    source = original_file(song_id)
    audio, rate = sf.read(str(source), dtype="float32", always_2d=True)
    audio = audio.T  # (channels, samples)
    if audio.shape[0] == 1:
        audio = np.repeat(audio, 2, axis=0)
    if rate != RATE:
        audio = librosa.resample(audio, orig_sr=rate, target_sr=RATE)
    print(f"{song_id}: separating {source.name} ({audio.shape[1] / RATE:.1f} s)", flush=True)
    stems = separate(audio[:2], RATE)
    out.mkdir(parents=True, exist_ok=True)
    for name, label in NAMES.items():
        sf.write(str(out / f"{label}.flac"), np.clip(stems[name].T, -1.0, 1.0), RATE, subtype="PCM_16")
    print(f"{song_id}: stems written to {out.relative_to(ROOT)}", flush=True)
    return out


if __name__ == "__main__":
    for song in sys.argv[1:]:
        separate_song(song)
