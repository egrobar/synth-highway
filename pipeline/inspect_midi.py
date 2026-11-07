"""Print per-track stats for a MIDI file: note count, pitch range, density, first notes."""
import sys

import pretty_midi

NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def name(p):
    return f"{NAMES[p % 12]}{p // 12 - 1}"


pm = pretty_midi.PrettyMIDI(sys.argv[1])
print(f"{sys.argv[1]}  length {pm.get_end_time():.1f}s  tempo {pm.estimate_tempo():.0f} (est)")
for inst in pm.instruments:
    ns = sorted(inst.notes, key=lambda n: n.start)
    if not ns:
        print(f"  {inst.name}: empty")
        continue
    ps = [n.pitch for n in ns]
    durs = [n.end - n.start for n in ns]
    span = ns[-1].end - ns[0].start
    print(f"  {inst.name}: {len(ns)} notes, {name(min(ps))}..{name(max(ps))}, "
          f"median dur {sorted(durs)[len(durs)//2]:.2f}s, {len(ns)/max(1,span):.1f} notes/s, "
          f"first at {ns[0].start:.1f}s")
    print("    " + " ".join(f"{name(n.pitch)}@{n.start:.1f}" for n in ns[:24]))
