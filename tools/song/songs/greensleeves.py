"""Greensleeves: Aurora Pass. Traditional English tune (16th century, public domain). A minor, 3/4, 150 BPM.

Ported from the web trainer's built-in version (index.html, BUILTIN): its verse and bass, read in the
same note notation by tools/themes/aurora/webseq.py. The web plays the verse twice at 180 BPM; here the
traditional refrain ("Greensleeves was all my joy") follows each verse, which brings the song to
length, and the tempo is 150 so the half notes are long enough to be holds.
Two and two-thirds bars of piano and pad come first; the melody enters on its pickup. The first
time round the piano plays the web's bass under a pad, the second time a waltz left hand.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "themes" / "aurora"))
from webseq import Song, classical_room, write, fold_notes, lead, pitch, voice  # noqa: E402

# Verbatim from index.html (GREEN_VERSE, GREEN_BASS): the verse starts on a one-beat pickup.
VERSE = ("A4:1 C5:2 D5:1 E5:1.5 F5:0.5 E5:1 D5:2 B4:1 G4:1.5 A4:0.5 B4:1 C5:2 A4:1 A4:1.5 G#4:0.5 A4:1 "
         "B4:2 G#4:1 E4:2 A4:1 C5:2 D5:1 E5:1.5 F5:0.5 E5:1 D5:2 B4:1 G4:1.5 A4:0.5 B4:1 C5:1.5 B4:0.5 "
         "A4:1 G#4:1.5 F#4:0.5 G#4:1 A4:3 r:2")
VERSE_BASS = "r:1 A3:3 A3:3 G3:3 G3:3 A3:3 E3:3 E3:3 E3:3 A3:3 A3:3 G3:3 G3:3 A3:3 E3:3 A3:5"
# The traditional refrain, which the web leaves out: 15 bars from the downbeat, ending on a long A.
REFRAIN = ("G5:3 G5:1.5 F#5:0.5 E5:1 D5:2 B4:1 G4:1.5 A4:0.5 B4:1 C5:2 A4:1 A4:1.5 G#4:0.5 A4:1 B4:2 "
           "G#4:1 E4:3 G5:3 G5:1.5 F#5:0.5 E5:1 D5:2 B4:1 G4:1.5 A4:0.5 B4:1 C5:1.5 B4:0.5 A4:1 G#4:1.5 "
           "F#4:0.5 G#4:1")
VERSE_CHORDS = ["Am", "Am", "G", "G", "Am", "E", "E", "E", "Am", "Am", "G", "G", "Am", "E", "Am", "Am"]
REFRAIN_CHORDS = ["C", "C", "G", "G", "Am", "E", "E", "E", "C", "C", "G", "G", "Am", "E", "Am", "Am"]
WEB_ROOT = {"Am": "A3", "G": "G3", "E": "E3", "C": "C3"}  # the register of the web's bass voice
LOW_ROOT = {"Am": "A2", "G": "G2", "E": "E2", "C": "C3"}
TRIAD = {"Am": "A3 C4 E4", "G": "G3 B3 D4", "E": "G#3 B3 E4", "C": "G3 C4 E4"}

song = Song("greensleeves", "Greensleeves", "aurora", bpm=150, lead_patch="piano", beats_per_bar=3)
classical_room(song)

song.section("intro", 0)
voice(song, 0, "A2:3 E2:3 A2:2", amp=0.3)
voice(song, 0, "[A3 C4 E4]:3 [G#3 B3 E4]:3 [A3 C4 E4]:2", "pad", amp=0.05, ring=1.05)
voice(song, 0, "r:1 [A3 C4 E4]:1 [A3 C4 E4]:1 r:1 [G#3 B3 E4]:1 [G#3 B3 E4]:1", amp=0.09)

# The pickup is the last beat of the bar before each verse; verse and refrain are 16 bars each.
bar = 3
for second in (False, True):
    song.section("verse" if not second else "verse again", bar - 1)
    melody = VERSE + " r:1 " + REFRAIN + (" A4:3 r:2" if not second else " A4:6")
    lead(song, bar - 1, melody, beat=2)
    if not second:
        voice(song, bar - 1, VERSE_BASS, amp=0.3, beat=2)
    for part, chords in ((0, VERSE_CHORDS), (1, REFRAIN_CHORDS)):
        if part == 1:
            song.section("refrain" if not second else "refrain again", bar)
        for i, chord in enumerate(chords):
            b = bar + i
            if not second:
                if part == 1:
                    voice(song, b, f"{WEB_ROOT[chord]}:3", amp=0.3)
            else:
                song.hit(song.at(b, 0), "piano", pitch(LOW_ROOT[chord]), song.beat * 2.8, 0.34)
                if i < len(chords) - 1:
                    for k in (1, 2):
                        voice(song, b, f"[{TRIAD[chord]}]:1", amp=0.1, beat=k, pan=0.15)
            voice(song, b, f"[{TRIAD[chord]}]:3", "pad", amp=0.04 if not second else 0.055, ring=1.05)
        bar += 16

song.section("outro", bar)
voice(song, bar, "[A1 A2]:6", amp=0.32)
voice(song, bar, "[E3 A3 C4 E4]:6", amp=0.14, roll=0.035)
voice(song, bar, "[A2 E3 A3 C4]:6", "pad", amp=0.055, ring=0.9)

fold_notes(song)
write(song, bars=bar + 2)
