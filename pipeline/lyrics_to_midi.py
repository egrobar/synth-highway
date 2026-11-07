"""Transcribe sung lyrics from a vocal stem with word timestamps and write them
into a MIDI file as lyric meta events (one per word; a leading "/" marks the
start of a new line, the usual karaoke convention). Also writes a JSON sidecar.

Usage: python lyrics_to_midi.py vocals.wav in.mid out.mid [--model medium.en] [--lyrics lyrics.txt]

If --lyrics is given (the real words, one line per lyric line), Whisper's
timing is kept but its words are replaced by the real text, line by line, so
typos in the recognition do not end up on screen.
"""
import argparse
import json
import pathlib
import re

import pretty_midi

ap = argparse.ArgumentParser()
ap.add_argument("vocals")
ap.add_argument("midi_in")
ap.add_argument("midi_out")
ap.add_argument("--model", default="medium.en")
ap.add_argument("--lyrics", default=None)
ap.add_argument("--language", default="en")
args = ap.parse_args()

from faster_whisper import WhisperModel  # noqa: E402  (import after argparse so --help is fast)

model = WhisperModel(args.model, device="cpu", compute_type="int8", cpu_threads=8)
segments, info = model.transcribe(args.vocals, language=args.language, word_timestamps=True,
                                  vad_filter=True, vad_parameters={"min_silence_duration_ms": 400},
                                  beam_size=5, condition_on_previous_text=False)
lines = []
for seg in segments:
    words = [(w.start, w.end, w.word.strip()) for w in (seg.words or []) if w.word.strip()]
    if words:
        lines.append(words)
print(f"[whisper] {len(lines)} lines, {sum(len(l) for l in lines)} words, language {info.language} p={info.language_probability:.2f}")

if args.lyrics:
    # swap recognised words for the real ones, line by line, keeping Whisper's timing
    real = [l.strip() for l in pathlib.Path(args.lyrics).read_text(encoding="utf-8").splitlines() if l.strip() and not re.match(r"^\[.*\]$", l.strip())]
    swapped = []
    for i, words in enumerate(lines):
        if i < len(real):
            rw = real[i].split()
            n = min(len(rw), len(words))
            # distribute real words over whisper's word slots
            slots = [words[int(j * len(words) / len(rw))] for j in range(len(rw))] if rw else words
            swapped.append([(s, e, rw[j]) for j, (s, e, _) in enumerate(slots)])
        else:
            swapped.append(words)
    lines = swapped

pm = pretty_midi.PrettyMIDI(args.midi_in)
pm.lyrics = []
for words in lines:
    for k, (s, e, text) in enumerate(words):
        # trailing space = whole word (karaoke files use it to end a syllable run)
        pm.lyrics.append(pretty_midi.Lyric(("/" if k == 0 else "") + text + " ", float(s)))
pm.write(args.midi_out)

side = pathlib.Path(args.midi_out).with_suffix(".lyrics.json")
side.write_text(json.dumps([[{"start": round(s, 2), "end": round(e, 2), "word": t} for s, e, t in words] for words in lines], indent=1), encoding="utf-8")
print(f"[midi] wrote {args.midi_out} with {len(pm.lyrics)} lyric events; sidecar {side.name}")
for words in lines[:12]:
    print(f"  {words[0][0]:6.1f}s  " + " ".join(w for _, _, w in words))
