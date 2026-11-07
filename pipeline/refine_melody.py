"""Second opinion on the vocal melody: run pyin (a monophonic pitch tracker) on
the vocal stem and reconcile every transcribed note with it.

- note sits an octave off the tracker       -> shift it by 12
- note disagrees by more than ~2.5 semitones -> retune to the tracker's median
- tracker hears no voice under the note      -> drop it (breath, bleed, noise)
Then merge same-pitch notes separated by tiny gaps.

Usage: python refine_melody.py vocals.wav in.mid out.mid
"""
import sys

import librosa
import numpy as np
import pretty_midi

voc, midi_in, midi_out = sys.argv[1:4]
HOP = 512
y, sr = librosa.load(voc, sr=22050, mono=True)
f0, _, _ = librosa.pyin(y, fmin=librosa.note_to_hz("E2"), fmax=librosa.note_to_hz("C6"),
                        sr=sr, hop_length=HOP, frame_length=2048)
times = librosa.times_like(f0, sr=sr, hop_length=HOP)
midi_f0 = librosa.hz_to_midi(f0)

pm = pretty_midi.PrettyMIDI(midi_in)
mel = next(i for i in pm.instruments if i.name.lower().startswith("vocal"))
kept, shifted, retuned, dropped = [], 0, 0, 0
for n in sorted(mel.notes, key=lambda n: n.start):
    i0 = int(np.searchsorted(times, n.start))
    i1 = max(i0 + 1, int(np.searchsorted(times, n.end)))
    seg = midi_f0[i0:i1]
    voiced = seg[~np.isnan(seg)]
    if len(voiced) / max(1, len(seg)) < 0.35:
        dropped += 1
        continue
    med = float(np.median(voiced))
    diff = med - n.pitch
    if abs(abs(diff) - 12) <= 1.5:
        n.pitch += 12 if diff > 0 else -12
        shifted += 1
    elif abs(diff) > 2.5:
        n.pitch = int(round(med))
        retuned += 1
    kept.append(n)

merged = []
for n in kept:
    if merged and merged[-1].pitch == n.pitch and n.start - merged[-1].end < 0.06:
        merged[-1].end = max(merged[-1].end, n.end)
    else:
        merged.append(n)
mel.notes = merged
pm.write(midi_out)
ps = [n.pitch for n in merged]
print(f"melody: {len(mel.notes)} notes kept of {len(kept) + dropped}; octave-shifted {shifted}, retuned {retuned}, dropped {dropped}; "
      f"range {pretty_midi.note_number_to_name(min(ps))}..{pretty_midi.note_number_to_name(max(ps))}")

# melody-only companion (melody + bass) for Learn mode
solo = pretty_midi.PrettyMIDI(initial_tempo=pm.estimate_tempo() if False else 120)
for inst in pm.instruments:
    if not inst.name.lower().startswith("synth"):
        solo.instruments.append(inst)
solo_path = midi_out.replace(".mid", "_melody.mid")
solo.write(solo_path)
print("wrote", midi_out, "and", solo_path)
