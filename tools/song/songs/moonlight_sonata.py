"""Moonlight Sonata, opening (Beethoven): Aurora Pass. Public domain (Piano Sonata No. 14, first movement,
1801). C-sharp minor, 54 BPM, triplets.

Ported from the web trainer's built-in version (index.html, BUILTIN): its three voices, read in the
same notation by tools/themes/aurora/webseq.py. As in the web, the player plays the rippling triplets
(the lead); the octave bass and the dotted G-sharp melody are backing. The web's six bars play twice,
the second time with the G-sharp figure returning over the C-sharp minor bars and a soft pad, then a
short close on the dominant and a held C-sharp. Two bars of bass and pad come first.
The triplets sit between G#3 and F#4, partly below the Q row, so the whole chart moves up an octave
(G#4 to F#5); the audio plays what was written.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "themes" / "aurora"))
from webseq import Song, classical_room, write, fold_notes, lead, voice  # noqa: E402


def arp(a: str, b: str, c: str, n: int) -> str:
    """The web's MOON_ARP: n triplet groups of a, b, c."""
    return " ".join([f"{a}:1/3 {b}:1/3 {c}:1/3"] * n)


# Verbatim from index.html: the triplets, the melody and the octave bass, six bars.
TRIPLETS = (arp("G#3", "C#4", "E4", 8) + " " + arp("A3", "C#4", "E4", 2) + " " + arp("A3", "D4", "F#4", 2) + " "
            + arp("G#3", "B#3", "F#4", 2) + " " + arp("G#3", "C#4", "E4", 2) + " " + arp("G#3", "C#4", "E4", 8))
MELODY = "r:19 G#4:0.75 G#4:0.25 G#4:4"
OCTAVES = ("[C#2 C#3]:4 [B1 B2]:4 [A1 A2]:2 [F#1 F#2]:2 [G#1 G#2]:2 [G#1 G#2]:2 [C#2 C#3]:4 "
           "[C#2 C#3]:4")
# The second time round the G-sharp figure also sings into the second bar and over the dominant.
MELODY_AGAIN = "r:3 G#4:0.75 G#4:0.25 G#4:4 r:7 G#4:0.75 G#4:0.25 G#4:3 G#4:0.75 G#4:0.25 G#4:4"
PAD = "[C#3 G#3 E4]:4 [B2 G#3 E4]:4 [A2 C#4 E4]:2 [F#2 A3 D4]:2 [G#2 B#3 F#4]:2 [G#2 C#4 E4]:2 [C#3 G#3 E4]:8"
# The close: one bar of the dominant, then C-sharp minor held.
CLOSE = arp("G#3", "B#3", "F#4", 2) + " " + arp("G#3", "B#3", "D#4", 2) + " C#4:4"

song = Song("moonlight_sonata", "Moonlight Sonata, opening (Beethoven)", "aurora", bpm=54, lead_patch="piano")
classical_room(song)

song.section("intro", 0)
voice(song, 0, "[C#2 C#3]:8", amp=0.3)
voice(song, 0, "[C#3 G#3 E4]:8", "pad", amp=0.04, ring=0.95)

for i, bar in enumerate((2, 8)):
    song.section("triplets" if i == 0 else "triplets again", bar)
    lead(song, bar, TRIPLETS, amp=0.44)
    voice(song, bar, OCTAVES, amp=0.3)
    voice(song, bar, MELODY if i == 0 else MELODY_AGAIN, amp=0.2, pan=0.1)
    if i == 1:
        voice(song, bar, PAD, "pad", amp=0.035, ring=1.03)

song.section("close", 14)
lead(song, 14, CLOSE, amp=0.44)
voice(song, 14, "[G#1 G#2]:4 [C#2 C#3]:8", amp=0.3)
voice(song, 14, "[G#2 B#3 D#4]:4 [C#3 G#3 E4]:8", "pad", amp=0.04, ring=0.95)
voice(song, 15, "[G#3 C#4 E4]:4", amp=0.12, roll=0.05)

fold_notes(song, shift=12)
write(song, bars=17)
