"""Suno song -> MIDI for the Synth Highway trainer.

Pipeline: Demucs splits the mix into vocals / bass / other / drums, Basic Pitch
transcribes each pitched stem, the vocal line is reduced to a single melody,
and everything is written as one multi-track MIDI (one track per stem) so the
trainer's "Your part" menu can pick the melody, the synths or the bass.

Usage:
  python transcribe.py input.wav --out out/song.mid [--no-stems] [--device cpu|cuda]
"""
import argparse
import pathlib
import subprocess
import sys


def run_demucs(wav: pathlib.Path, workdir: pathlib.Path, model: str, device: str) -> pathlib.Path:
    stems = workdir / model / wav.stem
    if all((stems / f"{s}.wav").exists() for s in ("vocals", "bass", "other", "drums")):
        print(f"[demucs] reusing stems in {stems}")
        return stems
    cmd = [sys.executable, "-m", "demucs", "-n", model, "-d", device, "-o", str(workdir), str(wav)]
    print("[demucs]", " ".join(cmd))
    subprocess.run(cmd, check=True)
    return stems


def transcribe(path: pathlib.Path, **kw):
    from basic_pitch import ICASSP_2022_MODEL_PATH
    from basic_pitch.inference import predict

    print(f"[basic-pitch] {path.name} {kw}")
    _, _, events = predict(str(path), ICASSP_2022_MODEL_PATH, **kw)
    # events: (start_s, end_s, midi_pitch, amplitude, pitch_bends)
    return [(float(s), float(e), int(p), float(a)) for s, e, p, a, *_ in events]


def monophonic(notes, min_len=0.09, chord_window=0.06):
    """Keep one note at a time: near-simultaneous onsets keep the louder note,
    a later onset cuts the previous note short."""
    notes = sorted((n for n in notes if n[1] - n[0] >= min_len), key=lambda n: (n[0], -n[3]))
    out = []
    for s, e, p, a in notes:
        if out:
            ps, pe, pp, pa = out[-1]
            if s < pe:
                if s - ps < chord_window:
                    if a > pa:
                        out[-1] = (s, e, p, a)
                    continue
                out[-1] = (ps, s, pp, pa)
        out.append((s, e, p, a))
    return [n for n in out if n[1] - n[0] >= 0.04]


def smooth_octaves(notes, max_jump=9):
    """Vocal transcriptions love spurious octave jumps: when a note leaps more
    than max_jump semitones away from its neighbours and an octave shift lands
    it back inside the line, shift it."""
    out = list(notes)
    for i in range(1, len(out) - 1):
        s, e, p, a = out[i]
        prev_p, next_p = out[i - 1][2], out[i + 1][2]
        ref = (prev_p + next_p) / 2
        if abs(p - ref) > max_jump:
            for shift in (-12, 12, -24, 24):
                if abs(p + shift - ref) <= max_jump:
                    out[i] = (s, e, p + shift, a)
                    break
    return out


def write_midi(tracks, out: pathlib.Path, tempo: float):
    import pretty_midi

    pm = pretty_midi.PrettyMIDI(initial_tempo=tempo)
    for name, program, notes in tracks:
        if not notes:
            continue
        inst = pretty_midi.Instrument(program=program, name=name)
        for s, e, p, a in notes:
            vel = int(max(30, min(127, 40 + 87 * min(1.0, a))))
            inst.notes.append(pretty_midi.Note(velocity=vel, pitch=int(max(0, min(127, p))), start=s, end=e))
        pm.instruments.append(inst)
    pm.write(str(out))
    print(f"[midi] wrote {out}  tracks: " + ", ".join(f"{n} ({len(ns)})" for n, _, ns in tracks if ns))


def estimate_tempo(wav: pathlib.Path) -> float:
    try:
        import librosa

        y, sr = librosa.load(str(wav), sr=22050, mono=True, duration=90)
        tempo, _ = librosa.beat.beat_track(y=y, sr=sr)
        tempo = float(tempo if not hasattr(tempo, "__len__") else tempo[0])
        return tempo if 40 < tempo < 240 else 120.0
    except Exception as exc:  # tempo is cosmetic for the trainer
        print("[tempo] estimate failed:", exc)
        return 120.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("--out", required=True)
    ap.add_argument("--workdir", default=None, help="where Demucs writes stems (default: next to --out)")
    ap.add_argument("--model", default="htdemucs")
    ap.add_argument("--device", default="cpu")
    ap.add_argument("--no-stems", action="store_true", help="transcribe the full mix instead of separating")
    args = ap.parse_args()

    wav = pathlib.Path(args.input)
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    workdir = pathlib.Path(args.workdir) if args.workdir else out.parent / "stems"
    tempo = estimate_tempo(wav)
    print(f"[tempo] ~{tempo:.1f} bpm")

    if args.no_stems:
        notes = transcribe(wav, onset_threshold=0.5, frame_threshold=0.3, minimum_note_length=90)
        write_midi([("Full mix", 80, notes)], out, tempo)
        return

    stems = run_demucs(wav, workdir, args.model, args.device)

    vocals = transcribe(stems / "vocals.wav", onset_threshold=0.45, frame_threshold=0.3,
                        minimum_note_length=110, minimum_frequency=70, maximum_frequency=1100, melodia_trick=True)
    melody = smooth_octaves(monophonic(vocals))
    other = transcribe(stems / "other.wav", onset_threshold=0.55, frame_threshold=0.35, minimum_note_length=90)
    bass = transcribe(stems / "bass.wav", onset_threshold=0.5, frame_threshold=0.3,
                      minimum_note_length=100, minimum_frequency=28, maximum_frequency=400)
    bass = monophonic(bass, min_len=0.1)

    write_midi([
        ("Vocal melody", 80, melody),      # 80 = square lead
        ("Synths / keys", 81, other),      # 81 = saw lead
        ("Bass", 38, bass),                # 38 = synth bass
    ], out, tempo)

    # also a melody-only file, handy for Learn mode
    solo = out.with_name(out.stem + "_melody.mid")
    write_midi([("Vocal melody", 80, melody), ("Bass", 38, bass)], solo, tempo)


if __name__ == "__main__":
    main()
