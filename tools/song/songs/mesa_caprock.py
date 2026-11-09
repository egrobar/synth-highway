"""Caprock Overdrive: Red Mesa. An original hard-rock tune in A minor, 132 BPM.

Straight-eighths rock drums (crash on every section, tom fills into the next), palm-muted power-chord
chugs in the verses, ringing open chords and an organ bed in the choruses, an eighth-note bass, and an
overdriven `drive` lead that only plays while the player hits it. The lead is all eighth notes and
two-beat (or longer) sustains, so about a quarter of its notes are holds: the bent, singing notes.
The melody stays on white keys (A minor) between G4 and G5.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from songlib import Song  # noqa: E402

INTRO_CHORDS = ["Am", "Am", "F", "G"]
VERSE_CHORDS = ["Am", "Am", "F", "G", "Am", "Am", "F", "E"]
CHORUS_CHORDS = ["F", "G", "Am", "Am", "F", "G", "C", "E"]
LAST_CHORUS_CHORDS = ["F", "G", "Am", "Am", "F", "G", "E", "Am"]
SOLO_CHORDS = ["Dm", "Am", "Dm", "Am", "F", "G", "E", "E"]
OUTRO_CHORDS = ["Am", "Am"]

VERSE_1 = [
    "A4:0.5 C5:0.5 D5:0.5 C5:0.5 E5:2", "G5:2 E5:0.5 D5:0.5 C5:0.5 D5:0.5",
    "C5:0.5 A4:0.5 C5:0.5 D5:0.5 F5:2", "D5:2 B4:0.5 D5:0.5 G5:1",
    "A4:0.5 C5:0.5 D5:0.5 C5:0.5 E5:2", "G5:0.5 E5:0.5 D5:0.5 C5:0.5 D5:2",
    "F5:2 E5:0.5 D5:0.5 C5:0.5 A4:0.5", "B4:2 E5:2",
]
VERSE_2 = [
    "E5:0.5 E5:0.5 D5:0.5 C5:0.5 A4:2", "C5:1 D5:0.5 E5:0.5 G5:2",
    "A4:0.5 C5:0.5 F5:0.5 E5:0.5 D5:1 C5:1", "D5:2 B4:0.5 C5:0.5 D5:1",
    "E5:2 G5:0.5 E5:0.5 D5:0.5 E5:0.5", "A4:2 C5:2",
    "C5:0.5 D5:0.5 F5:0.5 E5:0.5 D5:2", "E5:2 B4:2",
]
CHORUS = [
    "A4:0.5 C5:0.5 F5:0.5 E5:0.5 F5:2", "G5:2 F5:0.5 E5:0.5 D5:0.5 B4:0.5",
    "C5:0.5 E5:0.5 A4:0.5 C5:0.5 E5:2", "G5:2 E5:2",
    "A4:0.5 C5:0.5 F5:0.5 E5:0.5 F5:2", "G5:2 F5:0.5 G5:0.5 F5:0.5 D5:0.5",
    "E5:0.5 D5:0.5 C5:0.5 D5:0.5 E5:2", "D5:2 B4:2",
]
LAST_CHORUS = CHORUS[:6] + ["E5:0.5 D5:0.5 B4:0.5 D5:0.5 E5:2", "E5:2 C5:2"]
SOLO = [
    "D5:0.5 F5:0.5 A4:0.5 D5:0.5 F5:2", "E5:0.5 D5:0.5 C5:0.5 A4:0.5 C5:0.5 D5:0.5 E5:1",
    "G5:2 F5:0.5 E5:0.5 D5:0.5 F5:0.5", "E5:2 C5:0.5 D5:0.5 E5:0.5 G5:0.5",
    "A4:0.5 C5:0.5 F5:0.5 A4:0.5 C5:0.5 F5:0.5 E5:1", "G5:2 D5:2",
    "E5:0.5 D5:0.5 B4:0.5 G4:0.5 B4:0.5 D5:0.5 B4:1", "E5:4",
]
OUTRO = ["A4:4"]

# (name, chords, melody, guitar style)
SECTIONS = [
    ("intro", INTRO_CHORDS, None, "riff"), ("verse", VERSE_CHORDS, VERSE_1, "chug"),
    ("chorus", CHORUS_CHORDS, CHORUS, "ring"), ("verse", VERSE_CHORDS, VERSE_2, "chug"),
    ("chorus", CHORUS_CHORDS, CHORUS, "ring"), ("solo", SOLO_CHORDS, SOLO, "gallop"),
    ("chorus", LAST_CHORUS_CHORDS, LAST_CHORUS, "ring"), ("outro", OUTRO_CHORDS, OUTRO, "end"),
]
GUITAR = {"Am": 45, "F": 41, "G": 43, "C": 48, "E": 40, "Dm": 38}  # power-chord roots
BASS = {"Am": 33, "F": 29, "G": 31, "C": 36, "E": 28, "Dm": 38}
ORGAN = {"Am": [57, 60, 64], "F": [53, 57, 60], "G": [55, 59, 62], "C": [55, 60, 64],
         "E": [52, 56, 59], "Dm": [50, 53, 57]}
RIFF = [(0.0, 0, 0.3, 0.3), (0.5, 0, 0.08, 0.18), (1.0, 0, 0.08, 0.18), (1.5, 3, 0.28, 0.28),
        (2.0, 0, 0.08, 0.18), (2.5, 5, 0.28, 0.28), (3.0, 0, 0.08, 0.18), (3.5, 3, 0.2, 0.26)]
FILL = [(2.0, 50), (2.5, 47), (3.0, 43), (3.5, 40)]
GUITAR_LEVEL = 0.78
LEAD_LEVEL = 0.66  # the drive patch is darker than the steel; this keeps it as loud as County Line's lead

song = Song("mesa_caprock", "Caprock Overdrive", "mesa", bpm=132, lead_patch="drive", seed=4040)
song.room = {"backing": [0.16, 0.55, 0.0], "lead": [0.24, 0.7, 0.22]}
beat = song.beat


def drums(bar: int, name: str, i: int, count: int) -> None:
    at = lambda b: song.at(bar, b)  # noqa: E731
    first, last = i == 0, i == count - 1
    quiet_intro = name == "intro" and i < 2
    if (first and not quiet_intro) or (name == "chorus" and i == 4) or (name == "intro" and i == 2):
        song.hit(at(0), "crash", amp=0.24, pan=-0.3)
    if name == "outro":
        song.hit(at(0), "kick", amp=0.6)
        song.hit(at(0), "crash", amp=0.26, pan=0.3)
        if not last:
            for b in (1, 2, 3):
                song.hit(at(b), "tom", 50 - b * 3, amp=0.36, pan=0.2 * b - 0.2)
        return
    for k in range(8):
        b = k * 0.5
        if name == "chorus":
            song.hit(at(b), "hat", 60, 0.14 if k % 2 else 0.05, 0.13 if k % 2 else 0.09, pan=0.3)
        else:
            song.hit(at(b), "hat", 60, 0.04, 0.12 if k % 2 == 0 else 0.07, pan=0.3)
    if quiet_intro:
        return
    fill = last
    kicks = {"verse": (0, 1.75, 2.5), "chorus": (0, 1.5, 2, 2.5), "solo": (0, 0.5, 2, 2.5),
             "intro": (0, 2.5)}[name]
    for b in kicks:
        if not (fill and b >= 2):
            song.hit(at(b), "kick", amp=0.5)
    song.hit(at(1), "snare", amp=0.4)
    if fill:
        for b, tom in FILL:
            song.hit(at(b), "tom", tom, amp=0.42, pan=(tom - 45) / 20)
        song.hit(at(3.5), "snare", amp=0.3)
    else:
        song.hit(at(3), "snare", amp=0.42)


def power(t: float, midi: int, sus: float, amp: float, pan: float) -> None:
    # Rhythm guitars sit a little under the lead, so the player's notes cut through the wall.
    song.hit(t, "power", midi, sus, amp * GUITAR_LEVEL, pan)


def guitar(bar: int, style: str, chord: str, i: int, count: int) -> None:
    at = lambda b: song.at(bar, b)  # noqa: E731
    root = GUITAR[chord]
    if style == "riff" and chord == "Am":
        for b, step, sus, amp in RIFF:
            power(at(b), root + step, sus, amp, -0.25)
            power(at(b), root + step, sus, amp * 0.7, 0.25)
    elif style in ("chug", "riff", "gallop"):
        for k in range(8):
            b = k * 0.5
            accent = b == 0 or (b == 1.5 and style != "gallop") or (b == 2 and style == "gallop")
            sus, amp = (0.3, 0.26) if accent else (0.09, 0.16)
            power(at(b), root, sus, amp, -0.3)
            power(at(b), root, sus, amp * 0.75, 0.3)
    elif style == "ring":
        power(at(0), root, beat * 2.4, 0.3, -0.3)
        power(at(0), root + 12, beat * 2.4, 0.14, 0.35)
        power(at(2.5), root, beat * 1.4, 0.26, -0.3)
        power(at(2.5), root + 12, beat * 1.4, 0.12, 0.35)
        for p in ORGAN[chord]:
            song.hit(at(0), "organ", p, beat * 3.8, 0.06, pan=0.15)
    elif style == "end":
        power(at(0), root, beat * (3.8 if i < count - 1 else 6.0), 0.32, -0.3)
        power(at(0), root + 12, beat * (3.8 if i < count - 1 else 6.0), 0.16, 0.35)


def bass(bar: int, name: str, chord: str, i: int, count: int) -> None:
    at = lambda b: song.at(bar, b)  # noqa: E731
    root = BASS[chord]
    if name == "intro" and i < 2:
        return
    if name == "outro":
        song.hit(at(0), "bass", root, beat * (3.6 if i < count - 1 else 6.0), 0.5)
        return
    for k in range(8):
        b = k * 0.5
        note = root + 12 if name == "solo" and k in (3, 7) else root
        song.hit(at(b), "bass", note, 0.24 if name == "chorus" else 0.19, 0.38 if k % 2 == 0 else 0.31)


bar = 0
for name, chords, melody, style in SECTIONS:
    song.section(name, bar)
    for i, chord in enumerate(chords):
        drums(bar, name, i, len(chords))
        guitar(bar, style, chord, i, len(chords))
        bass(bar, name, chord, i, len(chords))
        if melody and i < len(melody):
            song.melody(bar, [melody[i]], amp=LEAD_LEVEL)
        bar += 1
song.write(bars=bar)
