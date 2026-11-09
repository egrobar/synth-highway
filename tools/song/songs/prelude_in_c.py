"""Prelude in C (Bach, BWV 846): Aurora Pass. Public domain (The Well-Tempered Clavier, Book I, 1722). 76 BPM.

Ported from the web trainer's built-in version (index.html, preludeVoices): the 32 five-note chords,
each bar's broken-chord figure in the right hand (the lead), the two held left-hand notes under it,
the two closing runs and the final chord, all read in the same notation by
tools/themes/aurora/webseq.py. Two bars of a low C and a pad come first, since the piece starts at once.
The figures run from D3 up to A5, wider than the Q row, so the chart is folded bar by bar: a bar
that sits low moves up an octave as a whole and keeps its shape. The audio plays what was written.
The final chord's top note, C5, is the chart's last note; its other notes go to the backing.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "themes" / "aurora"))
from webseq import Song, classical_room, write, fold_bars, lead, voice  # noqa: E402

# Verbatim from index.html (preludeVoices): one five-note chord a bar, lowest first.
BARS = [["C4", "E4", "G4", "C5", "E5"], ["C4", "D4", "A4", "D5", "F5"], ["B3", "D4", "G4", "D5", "F5"],
        ["C4", "E4", "G4", "C5", "E5"], ["C4", "E4", "A4", "E5", "A5"], ["C4", "D4", "F#4", "A4", "D5"],
        ["B3", "D4", "G4", "D5", "G5"], ["B3", "C4", "E4", "G4", "C5"], ["A3", "C4", "E4", "G4", "C5"],
        ["D3", "A3", "D4", "F#4", "C5"], ["G3", "B3", "D4", "G4", "B4"], ["G3", "Bb3", "E4", "G4", "C#5"],
        ["F3", "A3", "D4", "A4", "D5"], ["F3", "Ab3", "D4", "F4", "B4"], ["E3", "G3", "C4", "G4", "C5"],
        ["E3", "F3", "A3", "C4", "F4"], ["D3", "F3", "A3", "C4", "F4"], ["G2", "D3", "G3", "B3", "F4"],
        ["C3", "E3", "G3", "C4", "E4"], ["C3", "G3", "Bb3", "C4", "E4"], ["F2", "F3", "A3", "C4", "E4"],
        ["F#2", "C3", "A3", "C4", "Eb4"], ["Ab2", "F3", "B3", "C4", "D4"], ["G2", "F3", "G3", "B3", "D4"],
        ["G2", "E3", "G3", "C4", "E4"], ["G2", "D3", "G3", "C4", "F4"], ["G2", "D3", "G3", "B3", "F4"],
        ["G2", "Eb3", "A3", "C4", "F#4"], ["G2", "E3", "G3", "C4", "G4"], ["G2", "D3", "G3", "C4", "F4"],
        ["G2", "D3", "G3", "B3", "F4"], ["C2", "C3", "G3", "Bb3", "E4"]]
CLOSE_RH = ("r:0.5 F3:0.25 A3:0.25 C4:0.25 F4:0.25 C4:0.25 A3:0.25 C4:0.25 A3:0.25 F3:0.25 A3:0.25 F3:0.25 "
            "D3:0.25 F3:0.25 D3:0.25 r:0.5 G4:0.25 B4:0.25 D5:0.25 F5:0.25 D5:0.25 B4:0.25 D5:0.25 B4:0.25 "
            "G4:0.25 B4:0.25 D4:0.25 F4:0.25 E4:0.25 D4:0.25 [E4 G4 C5]:4")
CLOSE_LH1 = "C2:4 C2:4 C2:4"
CLOSE_LH2 = "r:0.25 C3:3.75 r:0.25 B2:3.75 C3:4"


def voices() -> tuple[str, str, str]:
    """The web's preludeVoices(): right-hand figures, and the two left-hand notes held under them."""
    rh, lh1, lh2 = [], [], []
    for a, b, c, d, e in BARS:
        figure = f"{c}:0.25 {d}:0.25 {e}:0.25 {c}:0.25 {d}:0.25 {e}:0.25"
        rh.append(f"r:0.5 {figure} r:0.5 {figure}")
        lh1.append(f"{a}:2 {a}:2")
        lh2.append(f"r:0.25 {b}:1.75 r:0.25 {b}:1.75")
    return (" ".join(rh) + " " + CLOSE_RH, " ".join(lh1) + " " + CLOSE_LH1, " ".join(lh2) + " " + CLOSE_LH2)


RH, LH1, LH2 = voices()

song = Song("prelude_in_c", "Prelude in C (Bach, BWV 846)", "aurora", bpm=76, lead_patch="piano")
classical_room(song)

song.section("intro", 0)
voice(song, 0, "[C2 C3]:8", amp=0.28)
voice(song, 0, "[C3 G3 C4 E4]:8", "pad", amp=0.04, ring=0.95)

song.section("prelude", 2)
lead(song, 2, RH, amp=0.46, chord_amp=0.2)
voice(song, 2, LH1, amp=0.27)
voice(song, 2, LH2, amp=0.22)
song.section("dominant pedal", 2 + 23)
song.section("close", 2 + 32)
voice(song, 2 + 32, "[C3 G3 C4 E4]:12", "pad", amp=0.035, ring=0.95)

fold_bars(song)
write(song, bars=2 + 35)
