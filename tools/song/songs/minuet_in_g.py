"""Minuet in G (Petzold): Aurora Pass. Public domain (Christian Petzold, c. 1725, once credited to Bach as
BWV Anh. 114). G major, 3/4, 120 BPM.

Ported from the web trainer's built-in version (index.html, BUILTIN): its sixteen-bar first part and
bass, read in the same notation by tools/themes/aurora/webseq.py. The web stops there; this goes on
into the minuet's second part (the turn to D major and back) and then plays the first part again, as
a minuet's da capo does. Two bars of piano come first, and a soft pad holds each bar's chord.
The second part climbs to B5, above the Q row, so the chart is folded bar by bar: those bars move
down an octave as a whole and keep their shape. The audio plays what was written.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "themes" / "aurora"))
from webseq import Song, classical_room, write, fold_bars, lead, voice  # noqa: E402

# Verbatim from index.html: the first part (two eight-bar phrases) and its bass.
PART_A = ("D5 G4:0.5 A4:0.5 B4:0.5 C5:0.5 D5 G4 G4 E5 C5:0.5 D5:0.5 E5:0.5 F#5:0.5 G5 G4 G4 C5 D5:0.5 "
          "C5:0.5 B4:0.5 A4:0.5 B4 C5:0.5 B4:0.5 A4:0.5 G4:0.5 F#4 G4:0.5 A4:0.5 B4:0.5 G4:0.5 B4 A4:2 D5 "
          "G4:0.5 A4:0.5 B4:0.5 C5:0.5 D5 G4 G4 E5 C5:0.5 D5:0.5 E5:0.5 F#5:0.5 G5 G4 G4 C5 D5:0.5 C5:0.5 "
          "B4:0.5 A4:0.5 B4 C5:0.5 B4:0.5 A4:0.5 G4:0.5 A4 B4:0.5 A4:0.5 G4:0.5 F#4:0.5 G4:3")
BASS_A = ("G3:2 A3:1 B3:2 G3:1 C4:2 B3:1 B3:2 A3:1 A3:2 F#3:1 G3:2 B3:1 D3:3 D3:3 G3:2 A3:1 B3:2 G3:1 "
          "C4:2 B3:1 B3:2 A3:1 A3:2 F#3:1 G3:2 B3:1 D3:3 G3:3")
# The second part, which the web leaves out: to D major and home again.
PART_B = ("B5 G5:0.5 A5:0.5 B5:0.5 G5:0.5 A5 D5:0.5 E5:0.5 F#5:0.5 D5:0.5 G5 E5:0.5 F#5:0.5 G5:0.5 D5:0.5 "
          "C#5 B4:0.5 C#5:0.5 A4 A4:0.5 B4:0.5 C#5:0.5 D5:0.5 E5:0.5 F#5:0.5 G5 F#5 E5 F#5 A4 C#5 D5:3 "
          "D5 G4:0.5 F#4:0.5 G4 E5 G4:0.5 F#4:0.5 G4 D5 C5 B4 A4:0.5 G4:0.5 F#4:0.5 G4:0.5 A4 "
          "D4:0.5 E4:0.5 F#4:0.5 G4:0.5 A4:0.5 B4:0.5 C5 B4 A4 B4:0.5 D5:0.5 G4 F#4 G4:3")
BASS_B = ("G3:3 F#3:3 E3:2 G3:1 A3:2 A2:1 D3:3 G3:3 A3:2 A2:1 D3:2 D2:1 B2:3 C3:3 B2:3 D3:3 D3:3 C3:3 "
          "D3:2 D2:1 G2:3")
# One chord a bar for the pad.
CHORD = {"G": "G3 B3 D4", "C": "E3 G3 C4", "D": "F#3 A3 D4", "D7": "F#3 A3 C4", "Em": "E3 G3 B3",
         "A": "E3 A3 C#4", "A7": "E3 G3 C#4"}
CHORDS_A = ["G", "G", "C", "G", "C", "G", "D", "D", "G", "G", "C", "G", "C", "G", "D7", "G"]
CHORDS_B = ["G", "D", "Em", "A", "D", "G", "A7", "D", "G", "C", "G", "D7", "G", "C", "D7", "G"]

song = Song("minuet_in_g", "Minuet in G (Petzold)", "aurora", bpm=120, lead_patch="piano", beats_per_bar=3)
classical_room(song)

song.section("intro", 0)
voice(song, 0, "[G2 D3 G3]:3 [D3 F#3 A3 C4]:3", amp=0.22, roll=0.03)
voice(song, 0, "[G3 B3 D4]:3 [F#3 A3 C4]:3", "pad", amp=0.035)

bar = 2
for name, part, bass, chords, pad_amp in (("first part", PART_A, BASS_A, CHORDS_A, 0.03),
                                          ("second part", PART_B, BASS_B, CHORDS_B, 0.04),
                                          ("da capo", PART_A, BASS_A, CHORDS_A, 0.045)):
    song.section(name, bar)
    lead(song, bar, part)
    voice(song, bar, bass, amp=0.3)
    voice(song, bar, " ".join(f"[{CHORD[c]}]:3" for c in chords), "pad", amp=pad_amp, ring=1.02)
    bar += 16
voice(song, bar - 1, "r:0.05 [G1 G2]:3", amp=0.3)

fold_bars(song)
write(song, bars=bar + 1)
