"""Für Elise (Beethoven): Aurora Pass. Public domain (Bagatelle in A minor, WoO 59, 1810). 3/8, 112 BPM.

A beat here is the piece's eighth note, as in the web trainer's built-in version (index.html, BUILTIN),
whose right and left hands are read in the same notation by tools/themes/aurora/webseq.py. The web
plays the opening theme twice at 160; this plays the whole first section with its repeats (theme,
theme, the C major episode and its run of Es back, theme, episode, theme), at 112 so the sixteenths
stay playable.
The melody is played legato: a rest straight after a note is held by the sustain pedal, so the quaver
at the end of each little phrase (A, B, C) becomes a short hold. The one E6 is folded onto E5 on the
chart. Two bars of the left hand come first.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "themes" / "aurora"))
from webseq import Song, classical_room, write, fold_notes, lead, voice  # noqa: E402

# Verbatim from index.html: bars 1 to 7 of the theme, each hand.
RH_BODY = ("E5:0.5 D#5:0.5 E5:0.5 B4:0.5 D5:0.5 C5:0.5 A4:1 r:0.5 C4:0.5 E4:0.5 A4:0.5 B4:1 r:0.5 E4:0.5 "
           "G#4:0.5 B4:0.5 C5:1 r:0.5 E4:0.5 E5:0.5 D#5:0.5 E5:0.5 D#5:0.5 E5:0.5 B4:0.5 D5:0.5 C5:0.5 A4:1 "
           "r:0.5 C4:0.5 E4:0.5 A4:0.5 B4:1 r:0.5 E4:0.5 C5:0.5 B4:0.5")
LH_BODY = ("r:3 A2:0.5 E3:0.5 A3:0.5 r:1.5 E2:0.5 G#2:0.5 B2:0.5 r:1.5 A2:0.5 E3:0.5 A3:0.5 r:1.5 r:3 "
           "A2:0.5 E3:0.5 A3:0.5 r:1.5 E2:0.5 G#2:0.5 B2:0.5 r:1.5")
PICKUP = "E5:0.5 D#5:0.5"
LH_HOME = "A2:0.5 E3:0.5 A3:0.5 r:1.5"  # under the theme's last bar
# The theme's last bar: back to the start (with the pickup again), on into the episode, or the end.
TO_REPEAT = "A4:1 r:1 " + PICKUP
TO_EPISODE = "A4:1 r:0.5 B4:0.5 C5:0.5 D5:0.5"
TO_END = "A4:3"
# The C major episode and the run of Es back to the theme (bars 10 to 15), which the web leaves out.
EPISODE = ("E5:1.5 G4:0.5 F5:0.5 E5:0.5 D5:1.5 F4:0.5 E5:0.5 D5:0.5 C5:1.5 E4:0.5 D5:0.5 C5:0.5 "
           "B4:1 r:0.5 E4:0.5 E5:0.5 r:0.5 r:0.5 E5:0.5 E6:0.5 r:0.5 r:0.5 D#5:0.5 "
           "E5:0.5 r:0.5 r:0.5 D#5:0.5 E5:0.5 D#5:0.5")
LH_EPISODE = ("C3:0.5 G3:0.5 C4:0.5 r:1.5 G2:0.5 G3:0.5 B3:0.5 r:1.5 A2:0.5 E3:0.5 A3:0.5 r:1.5 "
              "E2:0.5 E3:0.5 r:2 r:3 r:3")
# Each theme pass is 8 bars; the episode is 6. The form of the first section with its repeats.
FORM = [("theme", TO_REPEAT), ("theme", TO_EPISODE), ("episode", None), ("theme", TO_EPISODE),
        ("episode", None), ("theme", TO_END)]

song = Song("fur_elise", "Für Elise (Beethoven)", "aurora", bpm=112, lead_patch="piano", beats_per_bar=3)
classical_room(song)

song.section("intro", 0)
voice(song, 0, LH_HOME + " " + LH_HOME, amp=0.26)
voice(song, 0, "[A2 E3 A3]:6", "pad", amp=0.03, ring=0.9)

# The first pickup is the last beat of bar 1; every theme pass then starts on a downbeat.
lead(song, 1, PICKUP, beat=2, legato=True)
bar = 2
for name, ending in FORM:
    song.section(name, bar)
    if name == "theme":
        lead(song, bar, RH_BODY + " " + ending, legato=True)
        voice(song, bar, LH_BODY + " " + (LH_HOME if ending != TO_END else "[A1 A2]:3"), amp=0.26)
        bar += 8
    else:
        lead(song, bar, EPISODE, legato=True)
        voice(song, bar, LH_EPISODE, amp=0.24)
        voice(song, bar, "[C3 G3 C4]:3 [G2 D3 G3 B3]:3 [A2 E3 A3]:3 [E2 B2 E3 G#3]:3", "pad", amp=0.03,
              ring=0.95)
        bar += 6
voice(song, bar - 1, "[A2 E3 A3 C4]:6", "pad", amp=0.035, ring=0.9)
voice(song, bar - 1, "r:0.05 [E3 A3 C4]:6", amp=0.1, roll=0.04)

fold_notes(song)
write(song, bars=bar + 1)
