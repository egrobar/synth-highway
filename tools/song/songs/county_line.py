"""County Line: Backroads. An original country tune in C, 88 BPM.

Boom-chick bass and kick, fingerpicked guitar, brushes, a chorus organ, and a
pedal-steel lead that only plays while the player hits it. The melody sits on
the Q row's white keys (C4 to C5) because this is the first song a player meets.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from songlib import Song  # noqa: E402

VERSE_CHORDS = ["C", "C", "F", "C", "C", "Am", "G", "G"]
CHORUS_CHORDS = ["F", "C", "G", "C", "F", "C", "G", "C"]
VERSE_1 = [
    "E4:1 G4:1 G4:1.5 A4:0.5", "G4:3 E4:1", "F4:1 A4:1 A4:1.5 G4:0.5", "E4:3 r:1",
    "E4:1 G4:1 C5:1.5 B4:0.5", "A4:3 G4:1", "G4:1 F4:1 E4:1 D4:1", "D4:3 r:1",
]
VERSE_2 = [
    "E4:1 G4:0.5 G4:0.5 G4:1.5 A4:0.5", "G4:3 E4:1", "F4:1 A4:1 C5:1.5 A4:0.5", "G4:3 r:1",
    "E4:1 G4:1 C5:1.5 B4:0.5", "A4:3 G4:1", "G4:1 F4:1 E4:1 D4:1", "D4:3 r:1",
]
CHORUS = [
    "C5:2 A4:2", "G4:1 E4:1 G4:2", "B4:2 G4:1 D4:1", "C5:3 r:1",
    "C5:2 A4:1 C5:1", "G4:2 E4:1 C4:1", "G4:1 A4:1 B4:1.5 A4:0.5", "C5:3 r:1",
]
OUTRO = ["E4:2 G4:2", "C5:4"]
SECTIONS = [
    ("intro", ["C", "C"], None), ("verse", VERSE_CHORDS, VERSE_1), ("chorus", CHORUS_CHORDS, CHORUS),
    ("verse", VERSE_CHORDS, VERSE_2), ("chorus", CHORUS_CHORDS, CHORUS), ("outro", ["C", "C"], OUTRO),
]
VOICING = {"C": [48, 55, 60, 64, 67], "F": [53, 57, 60, 65, 69], "G": [43, 50, 55, 59, 62], "Am": [45, 52, 57, 60, 64]}
BASS = {"C": (36, 31), "F": (41, 36), "G": (43, 38), "Am": (45, 40)}
PICK_ORDER = [0, 2, 3, 2, 4, 3, 2, 3]

song = Song("county_line", "County Line", "backroads", bpm=88, lead_patch="steel")
bar = 0
for name, chords, melody in SECTIONS:
    song.section(name, bar)
    for i, chord in enumerate(chords):
        swing = lambda b: song.at(bar, b + (0.07 if (b * 2) % 2 == 1 else 0.0))  # noqa: E731
        final = name == "outro" and i == len(chords) - 1
        chorus = name == "chorus"
        root, fifth = BASS[chord]
        song.hit(song.at(bar, 0), "bass", root, song.beat * (3.5 if final else 0.9), 0.5)
        song.hit(song.at(bar, 0), "kick", amp=0.5 if name != "intro" else 0.3)
        if not final:
            song.hit(song.at(bar, 2), "bass", fifth, song.beat * 0.9, 0.42)
            song.hit(song.at(bar, 2), "kick", amp=0.42 if name != "intro" else 0.25)
            for k in range(8):
                song.hit(swing(k * 0.5), "pick", VOICING[chord][PICK_ORDER[k]], 1.6, 0.2 if chorus else 0.27,
                         pan=song.rng.uniform(-0.3, 0.3))
        else:
            for k, p in enumerate(VOICING[chord]):
                song.hit(song.at(bar, 0) + k * 0.018, "pick", p, 4.0, 0.3)
        if name != "intro" and not final:
            for b in (1, 3):
                for k, p in enumerate(VOICING[chord][1:]):
                    song.hit(song.at(bar, b) + k * 0.011, "pick", p, 0.35, 0.2 if chorus else 0.14)
                song.hit(song.at(bar, b), "brush", amp=0.32 if chorus else 0.22, pan=0.1)
        if chorus:
            for k in range(8):
                song.hit(swing(k * 0.5), "shaker", amp=0.11 if k % 2 else 0.07, pan=-0.25)
            for p in VOICING[chord][2:]:
                song.hit(song.at(bar, 0), "organ", p, song.beat * 3.9, 0.1, pan=0.2)
        if melody:
            song.melody(bar, [melody[i]])
        bar += 1
song.write(bars=bar)
