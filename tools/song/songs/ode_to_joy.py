"""Ode to Joy (Beethoven): Aurora Pass. Public domain (Symphony No. 9, finale, 1824). C major, 112 BPM.

Ported from the web trainer's built-in version (index.html, BUILTIN): its lead and bass voices, read in
the same note notation by tools/themes/aurora/webseq.py. Two bars of piano and pad come first, then
the theme twice: the first time over the web's bass and a soft pad, the second over a broken-chord
(Alberti) left hand with the bass an octave down, then a held C major chord.
The melody's one G3 sits below the Q row, so the chart folds it up an octave; the audio stays put.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "themes" / "aurora"))
from webseq import Song, classical_room, write, fold_notes, lead, parse, pitch, voice  # noqa: E402

# Verbatim from index.html.
THEME = ("E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 E4:1.5 D4:0.5 D4:2 E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 "
         "D4:1.5 C4:0.5 C4:2 D4 D4 E4 C4 D4 E4:0.5 F4:0.5 E4 C4 D4 E4:0.5 F4:0.5 E4 D4 C4 D4 G3:2 E4 E4 F4 "
         "G4 G4 F4 E4 D4 C4 C4 D4 E4 D4:1.5 C4:0.5 C4:2")
BASS = ("C3:4 G3:4 C3:4 G3:4 C3:4 G3:4 C3:4 G3:2 C3:2 G3:4 C3:4 G3:4 C3:2 G3:2 C3:4 G3:4 C3:4 G3:2 "
        "C3:2")
# Chords over each bass root, for the pad and the Alberti figure (low, high, middle, high).
PAD = {"C3": "[C3 G3 C4 E4]", "G3": "[G2 D3 G3 B3]"}
ALBERTI = {"C3": ["C3", "G3", "E3", "G3"], "G3": ["B2", "G3", "D3", "G3"]}

song = Song("ode_to_joy", "Ode to Joy (Beethoven)", "aurora", bpm=112, lead_patch="piano")
classical_room(song)

song.section("intro", 0)
voice(song, 0, "C2:4 G2:4", amp=0.3)
voice(song, 0, "[C3 G3 C4 E4]:4 [G2 D3 G3 B3]:4", "pad", amp=0.05, ring=1.1)
voice(song, 0, "C3:1 G3:1 E3:1 G3:1 B2:1 G3:1 D3:1 G3:1", amp=0.13)

bass_events, _ = parse(BASS)
for start_bar, second in ((2, False), (18, True)):
    song.section("theme" if not second else "theme again", start_bar)
    lead(song, start_bar, THEME)
    voice(song, start_bar, BASS if not second else BASS.replace("3:", "2:"), amp=0.32)
    for start, length, (root,) in bass_events:
        t0 = float(start)
        voice(song, start_bar, f"{PAD[root]}:{float(length)}", "pad", amp=0.045 if not second else 0.06,
              beat=t0, ring=1.05)
        if second:
            figure = ALBERTI[root]
            steps = int(float(length) * 2)
            for k in range(steps):
                song.hit(song.at(start_bar, t0 + k * 0.5), "piano", pitch(figure[k % 4]), song.beat * 0.6,
                         0.12 if k % 2 else 0.15, pan=-0.15)

song.section("outro", 34)
voice(song, 34, "[C2 C3]:8", amp=0.32)
voice(song, 34, "[G3 C4 E4 G4]:8", amp=0.16, roll=0.03)
voice(song, 34, "[C3 G3 C4 E4]:8", "pad", amp=0.06, ring=0.9)

fold_notes(song)
write(song, bars=36)
