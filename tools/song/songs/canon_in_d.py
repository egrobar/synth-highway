"""Canon in D (Pachelbel): Aurora Pass. Public domain (Johann Pachelbel, c. 1680-1706). D major, 72 BPM.

Ported from the web trainer's built-in version (index.html, BUILTIN): its ground bass, its four bars
of bass alone, and its two violin lines (A in quarter notes, B in eighths), read in the same notation
by tools/themes/aurora/webseq.py. The web plays A, B, A once; this plays A, B, A, B, A, and, as in a
canon, a second voice in the backing follows the player one variation behind, quieter and to the
side. A soft pad holds the ground's chords. It ends on a held D major chord.
The lines dip to B3 and climb to A5 once each, outside the Q row; the chart folds those two notes in
by an octave. The audio plays what was written.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "themes" / "aurora"))
from webseq import Song, classical_room, write, fold_notes, lead, rep, voice  # noqa: E402

# Verbatim from index.html (CANON_A, CANON_B, CANON_BASS); each is four bars, one turn of the ground.
LINE_A = "F#5 E5 D5 C#5 B4 A4 B4 C#5 D5 C#5 B4 A4 G4 F#4 G4 E4"
LINE_B = ("D4:0.5 F#4:0.5 A4:0.5 G4:0.5 F#4:0.5 D4:0.5 F#4:0.5 E4:0.5 D4:0.5 B3:0.5 D4:0.5 A4:0.5 G4:0.5 "
          "B4:0.5 A4:0.5 G4:0.5 F#4:0.5 D4:0.5 E4:0.5 C#5:0.5 D5:0.5 F#5:0.5 A5:0.5 A4:0.5 B4:0.5 G4:0.5 "
          "A4:0.5 F#4:0.5 D4:0.5 D5:0.5 D5:0.5 C#5:0.5")
GROUND = "D3:2 A3:2 B3:2 F#3:2 G3:2 D3:2 G3:2 A3:2"
# The ground's chords, two beats each, for the pad.
GROUND_PAD = ("[F#3 A3 D4]:2 [E3 A3 C#4]:2 [F#3 B3 D4]:2 [F#3 A3 C#4]:2 [G3 B3 D4]:2 [F#3 A3 D4]:2 "
              "[G3 B3 D4]:2 [E3 A3 C#4]:2")
LINES = [LINE_A, LINE_B, LINE_A, LINE_B, LINE_A]

song = Song("canon_in_d", "Canon in D (Pachelbel)", "aurora", bpm=72, lead_patch="piano")
classical_room(song)

# The ground runs from the first bar to the end of the last variation.
turns = 1 + len(LINES)
voice(song, 0, rep(GROUND, turns), amp=0.3)
voice(song, 0, rep(GROUND.replace("3:", "2:"), turns), amp=0.16)
voice(song, 0, rep(GROUND_PAD, turns), "pad", amp=0.04, ring=1.08)

song.section("ground", 0)
for i, line in enumerate(LINES):
    bar = 4 + i * 4
    song.section(f"variation {i + 1}", bar)
    lead(song, bar, line)
    # The second voice: the line the player played last, one turn of the ground later.
    if i > 0:
        voice(song, bar, LINES[i - 1], amp=0.11, pan=-0.35)
end = 4 + len(LINES) * 4
song.section("coda", end)
voice(song, end, "[D2 D3]:8", amp=0.32)
voice(song, end, "[A3 D4 F#4 A4 D5]:8", amp=0.15, roll=0.04)
voice(song, end, "[D3 A3 D4 F#4]:8", "pad", amp=0.05, ring=0.9)

fold_notes(song)
write(song, bars=end + 2)
