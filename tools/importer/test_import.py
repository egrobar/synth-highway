"""End-to-end check of the song importer against songs whose notes are known.

Builds two inputs from County Line's score, imports each through import_song.py
exactly as the game does, and scores the chart against the true melody:
  1. an MP3 of the band plus a synthetic singer (formant "voice"): the audio path;
  2. a multi-track MIDI file with a "Vocal melody" track: the MIDI path.
Note matching: onset within 80 ms, pitch class equal after the importer's key shift.

The MIDI result is a real accuracy measure (it should be exact). The MP3 result is only a
smoke test of the audio path: no synthetic singer tried so far (formant "ah", macOS speech
re-pitched) sounds enough like a person for Demucs and Basic Pitch to treat it as one, so
its score says little about real vocals. Judge the audio path on a real song.

Usage: .venv-pipeline/bin/python tools/importer/test_import.py <work_dir>
"""
import json
import pathlib
import re
import subprocess
import sys

import numpy as np
import soundfile as sf

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/song"))
import songlib  # noqa: E402

ROW = re.compile(r"\[([\d.]+),(\w+),(-?\d+),([\d.]+),([\d.]+),(-?[\d.]+)\]")


def read_score(path: pathlib.Path) -> tuple[float, list, list]:
    text = path.read_text()
    duration = float(re.search(r"~duration = ([\d.]+)", text).group(1))
    backing_text, lead_text = text.split("~lead =")
    parse = lambda block: [[float(a), b, int(c), float(d), float(e), float(f)] for a, b, c, d, e, f in ROW.findall(block)]  # noqa: E731
    return duration, parse(backing_text), parse(lead_text)


def score_chart(chart_path: pathlib.Path, truth: list[dict], key_shift: int) -> dict:
    chart = json.loads(chart_path.read_text())
    got = chart["difficulties"]["normal"]
    used, matched, errors = set(), 0, []
    for n in truth:
        for i, g in enumerate(got):
            if i in used or abs(g["t"] - n["t"]) > 0.08:
                continue
            if (g["p"] - key_shift - n["p"]) % 12 == 0:
                used.add(i)
                matched += 1
                errors.append(abs(g["t"] - n["t"]))
                break
    precision = matched / max(1, len(got))
    recall = matched / max(1, len(truth))
    f1 = 2 * precision * recall / max(1e-9, precision + recall)
    return {"notes": len(got), "truth": len(truth), "precision": round(precision, 3), "recall": round(recall, 3),
            "f1": round(f1, 3), "mean_onset_error_ms": round(1000 * float(np.mean(errors)), 1) if errors else None,
            "bpm": chart["bpm"], "key_shift": chart.get("key_shift"), "lead_source": chart.get("lead_source"),
            "vocal_ratio": chart.get("vocal_ratio"),
            "holds": sum(1 for g in got if g["d"] >= songlib.HOLD_MIN), "true_holds": sum(1 for n in truth if n.get("d", 0) >= songlib.HOLD_MIN)}


def say_singer(lead: list, sr: int, frames: int, work: pathlib.Path):
    """A stand-in human voice. macOS speech says one "lah"; its pitch is measured, and the
    syllable is time-stretched and pitch-shifted onto every note. (This macOS's voices read
    embedded [[pbas]] pitch commands aloud instead of obeying them.) A synthetic "ah"
    through formant filters is not voice-like enough for Demucs to call it vocals."""
    import librosa

    work.mkdir(parents=True, exist_ok=True)
    aiff = work / "lah.aiff"
    subprocess.run(["say", "-v", "Samantha", "-o", str(aiff), "aah"], check=True)
    base, _ = librosa.load(str(aiff), sr=sr, mono=True)
    base, _ = librosa.effects.trim(base, top_db=30)
    # Speech glides over most of an octave, which is nothing like a sung note. Like a
    # sampler: keep the "l", find the steadiest 120 ms of the vowel, loop it with crossfades.
    hop = 256
    f0, _, _ = librosa.pyin(base, fmin=60, fmax=600, sr=sr, frame_length=4096, hop_length=hop)
    midi_track = librosa.hz_to_midi(f0)
    win = int(0.12 * sr / hop)
    best, start_frame = 99.0, len(midi_track) // 2
    for i in range(len(midi_track) // 3, len(midi_track) - win):
        seg = midi_track[i:i + win]
        if not np.isnan(seg).any() and float(np.std(seg)) < best:
            best, start_frame = float(np.std(seg)), i
    a, b = start_frame * hop, start_frame * hop + win * hop
    grain = base[a:b]
    grain_midi = float(np.nanmedian(midi_track[start_frame:start_frame + win]))
    onset = base[:0]  # no consonant: it made every detected onset about 110 ms late
    fade = np.hanning(len(grain))
    track = np.zeros(frames, dtype=np.float32)
    for t, _, midi, dur, _, _ in lead:
        target = max(0.12, dur * 0.94)
        body_len = max(len(grain), int(target * sr) - len(onset))
        body = np.zeros(body_len + len(grain), dtype=np.float32)
        for k in range(0, body_len, len(grain) // 2):
            body[k:k + len(grain)] += grain * fade
        y = np.concatenate([onset, body[:body_len]])
        y = librosa.effects.pitch_shift(y, sr=sr, n_steps=midi - grain_midi)
        y = y[: int(target * sr)]
        fade = min(len(y), int(0.02 * sr))
        y[-fade:] *= np.linspace(1, 0, fade)
        start = int(t * sr)
        end = min(frames, start + len(y))
        track[start:end] += y[: end - start] / (np.abs(y).max() + 1e-9) * 0.5
    return track


def run_import(src: pathlib.Path, out: pathlib.Path) -> pathlib.Path:
    proc = subprocess.run([sys.executable, str(ROOT / "tools/importer/import_song.py"), str(src), str(out),
                           "--theme", "backroads"], capture_output=True, text=True)
    lines = proc.stdout.strip().splitlines()
    print("   last lines:", lines[-2:] if lines else proc.stderr[-400:])
    done = [line for line in lines if line.startswith("DONE ")]
    if not done:
        raise SystemExit("import failed:\n" + proc.stdout[-800:] + proc.stderr[-1500:])
    return pathlib.Path(done[0][5:])


def main() -> None:
    work = pathlib.Path(sys.argv[1]).resolve()
    work.mkdir(parents=True, exist_ok=True)
    duration, backing, lead = read_score(ROOT / "tools/song/build/county_line.scd")
    truth = [{"t": e[0], "p": e[2], "d": e[3]} for e in lead]

    print("== rendering a sung version of County Line")
    songlib.write_score(work / "band.scd", duration, backing, [], {"backing": [0.2, 0.6, 0.0], "lead": [0.2, 0.6, 0.0]})
    subprocess.run(["sclang", str(ROOT / "tools/song/render_score.scd"), str(work / "band.scd"), str(work / "band"),
                    str(ROOT / "tools/song/synths")], capture_output=True, check=True)
    band, sr = sf.read(work / "band/backing.wav")
    voice = say_singer(lead, sr, band.shape[0], work / "say")
    mix = np.clip(band + voice[:, None] * 0.9, -1, 1)
    import lameenc
    encoder = lameenc.Encoder()
    encoder.set_bit_rate(192)
    encoder.set_in_sample_rate(sr)
    encoder.set_channels(2)
    encoder.set_quality(2)
    pcm = (mix * 32767).astype(np.int16).tobytes()
    (work / "county_line_sung.mp3").write_bytes(encoder.encode(pcm) + encoder.flush())

    print("== writing a MIDI version")
    import pretty_midi
    pm = pretty_midi.PrettyMIDI(initial_tempo=88)
    tracks = {"Vocal melody": pretty_midi.Instrument(80, name="Vocal melody"),
              "Guitar": pretty_midi.Instrument(25, name="Guitar"), "Bass": pretty_midi.Instrument(33, name="Bass"),
              "Drums": pretty_midi.Instrument(0, is_drum=True, name="Drums"),
              "Organ": pretty_midi.Instrument(17, name="Organ")}
    for e in lead:
        tracks["Vocal melody"].notes.append(pretty_midi.Note(100, e[2], e[0], e[0] + e[3]))
    drum_note = {"kick": 36, "brush": 38, "shaker": 42}
    for t, inst, midi, dur, amp, _ in backing:
        if inst in drum_note:
            tracks["Drums"].notes.append(pretty_midi.Note(int(40 + 80 * min(1, amp)), drum_note[inst], t, t + 0.1))
        elif inst in ("pick", "bass", "organ"):
            name = {"pick": "Guitar", "bass": "Bass", "organ": "Organ"}[inst]
            tracks[name].notes.append(pretty_midi.Note(int(40 + 80 * min(1, amp)), midi, t, t + min(dur, 2.0)))
    pm.instruments.extend(tracks.values())
    pm.write(str(work / "county_line.mid"))

    results = {}
    for name, src in (("mp3 (sung)", work / "county_line_sung.mp3"), ("midi", work / "county_line.mid")):
        print(f"== importing {name}")
        chart_path = run_import(src, work / f"imported_{src.suffix[1:]}")
        chart = json.loads(chart_path.read_text())
        results[name] = score_chart(chart_path, truth, int(chart.get("key_shift", 0)))
        print("  ", results[name])
    (work / "results.json").write_text(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
