"""Chrome Overpass: Neon Sprawl. An original synthwave tune in A minor, 110 BPM.

Four-on-the-floor kick, snare on 2 and 4, eighth hats in the verses and sixteenths
in the choruses, a sixteenth-note arp, wide saw pads, pumping synth-bass eighths
(octave-bouncing in the choruses), and a detuned saw lead that only plays while
the player hits it. The melody stays on the Q row's white keys (E4 to G5), with
long held notes over the chord changes: region 2 asks for more notes than County
Line (about 1.5 a second on Normal) and a wider keyboard.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from songlib import Song  # noqa: E402

VERSE_CHORDS = ["Am", "F", "C", "G", "Am", "F", "C", "G"]
CHORUS_CHORDS = ["F", "G", "Am", "Am", "F", "G", "C", "E"]
VERSE_1 = [
    "E5:1.5 D5:0.5 C5:1 B4:1", "C5:1.5 A4:0.5 F4:2", "G4:0.5 C5:0.5 E5:1 D5:0.5 C5:0.5 D5:1", "B4:3 r:1",
    "E5:1.5 D5:0.5 C5:1 B4:1", "C5:1 A4:0.5 C5:0.5 F5:2", "E5:0.5 D5:0.5 C5:0.5 D5:0.5 E5:1 G5:1", "D5:2 B4:2",
]
CHORUS = [
    "A4:0.5 C5:0.5 F5:1.5 E5:0.5 C5:1", "D5:0.5 B4:0.5 G5:2 r:1", "E5:0.5 E5:0.5 E5:0.5 D5:0.5 E5:2", "C5:1 A4:3",
    "A4:0.5 C5:0.5 F5:1.5 E5:0.5 C5:1", "D5:0.5 B4:0.5 G5:1.5 F5:0.5 E5:1", "E5:0.5 G5:0.5 E5:0.5 C5:0.5 D5:2",
    "B4:3 E4:1",
]
BREAK = ["F5:2 E5:1 D5:1", "C5:2 A4:2", "A4:1 C5:1 D5:1 F5:1", "E5:3 r:1"]
VERSE_2 = [
    "A4:0.5 C5:0.5 E5:1.5 D5:0.5 C5:1", "A4:1 C5:1 F5:2", "E5:0.5 E5:0.5 G5:1 E5:0.5 D5:0.5 C5:1", "D5:1.5 B4:0.5 G4:2",
    "E5:1.5 D5:0.5 C5:1 E5:1", "F5:1.5 E5:0.5 D5:0.5 C5:0.5 A4:1", "E4:0.5 G4:0.5 C5:0.5 E5:0.5 G5:1 E5:1", "B4:2 D5:2",
]
OUTRO = ["C5:1.5 B4:0.5 A4:2", "A4:1 C5:1 F5:2", "D5:2 B4:2", "A4:4"]
SECTIONS = [
    ("intro", ["Am", "F", "C", "G"], None), ("verse", VERSE_CHORDS, VERSE_1), ("chorus", CHORUS_CHORDS, CHORUS),
    ("break", ["Dm", "Am", "F", "E"], BREAK), ("verse", VERSE_CHORDS, VERSE_2), ("chorus", CHORUS_CHORDS, CHORUS),
    ("outro", ["Am", "F", "G", "Am"], OUTRO),
]
PAD = {"Am": [57, 60, 64, 67], "F": [53, 57, 60, 64], "C": [55, 60, 64, 67], "G": [55, 59, 62, 67],
       "Dm": [53, 57, 62, 65], "E": [52, 56, 59, 64]}
BASS = {"Am": 45, "F": 41, "C": 48, "G": 43, "Dm": 38, "E": 40}
ARP_ORDER = [0, 2, 1, 3, 2, 1, 3, 2, 0, 2, 1, 3, 2, 3, 1, 2]

song = Song("neon_overpass", "Chrome Overpass", "neon", bpm=110, lead_patch="sawlead")
# A bigger room and a slapback than the default: the genre lives in its reverb.
song.room = {"backing": [0.27, 0.8, 0.14], "lead": [0.3, 0.82, 0.22]}
BAR = song.at(1)
# Levels: synth voices are quieter than plucked strings, so the backing gets a gain and the
# lead a higher amp than County Line's, to sit at about the same loudness as region 1.
GAIN = 1.75
LEAD_AMP = 0.85


def hit(t: float, inst: str, midi: int = 60, dur: float = 0.25, amp: float = 0.3, pan: float = 0.0) -> None:
    song.hit(t, inst, midi, dur, amp * GAIN, pan)


def drums(bar: int, name: str, i: int, last: bool, final: bool) -> None:
    def at(b: float) -> float:
        return song.at(bar, b)

    if i == 0 and name != "intro":
        hit(at(0), "crash", amp=0.12 if name == "break" else 0.2, pan=0.2)
    if final:
        hit(at(0), "kick", amp=0.6)
        return
    if name == "intro" and i < 2:
        return
    if name == "break":
        if last:
            # Build back in: kick on every beat under a crescendo snare roll.
            for b in range(4):
                hit(at(b), "kick", amp=0.5)
            for k in range(16):
                hit(at(k * 0.25), "snare", amp=0.06 + 0.3 * k / 15, pan=0.05)
        else:
            hit(at(2), "snare", amp=0.24, pan=0.05)
            for k in range(4):
                hit(at(k + 0.5), "hat", dur=0.04, amp=0.05, pan=-0.2)
        return
    for b in range(4):
        hit(at(b), "kick", amp=0.58 if b % 2 == 0 else 0.52)
    fill = name == "verse" and last
    if name != "intro":
        for b in (1, 3):
            if not (fill and b == 3):
                hit(at(b), "snare", amp=0.36 if name == "chorus" else 0.3, pan=0.05)
    if fill or (name == "intro" and last):
        for k, midi in enumerate((52, 48, 45, 41)):
            hit(at(3 + k * 0.25), "tom", midi, amp=0.3, pan=-0.3 + 0.2 * k)
    if name in ("chorus", "outro"):
        for k in range(16):
            hit(at(k * 0.25), "hat", dur=0.04, amp=0.07 if k % 2 else 0.045, pan=-0.2)
        for b in range(4):
            hit(at(b + 0.5), "hat", dur=0.16, amp=0.07, pan=-0.25)
    else:
        for k in range(8):
            hit(at(k * 0.5), "hat", dur=0.04, amp=0.085 if k % 2 else 0.06, pan=-0.2)


def harmony(bar: int, name: str, i: int, chord: str, final: bool) -> None:
    pad_amp = {"intro": 0.06, "verse": 0.055, "chorus": 0.065, "break": 0.07, "outro": 0.065}[name]
    for k, p in enumerate(PAD[chord]):
        hit(song.at(bar, 0) + k * 0.006, "pad", p, 3.6 if final else BAR - 0.3, pad_amp,
                 pan=(-0.4, 0.4, -0.15, 0.15)[k])
    root = BASS[chord]
    if final:
        hit(song.at(bar, 0), "synthbass", root, 3.0, 0.34)
        return
    if name == "break":
        hit(song.at(bar, 0), "synthbass", root, BAR * 0.9, 0.26)
    elif not (name == "intro" and i < 2):
        bounce = name in ("chorus", "outro")
        for k in range(8):
            midi = root + (12 if bounce and k % 2 else 0)
            hit(song.at(bar, k * 0.5), "synthbass", midi, song.beat * 0.42, 0.32 if k % 2 == 0 else 0.27)
    arp_amp = {"intro": 0.12, "verse": 0.085, "chorus": 0.075, "break": 0.12, "outro": 0.08}[name]
    notes = [p + 12 for p in PAD[chord]]
    for k, idx in enumerate(ARP_ORDER):
        hit(song.at(bar, k * 0.25), "arp", notes[idx], 0.1, arp_amp * (1.15 if k % 4 == 0 else 1.0),
                 pan=0.35 if k % 2 else -0.35)


bar = 0
for name, chords, melody in SECTIONS:
    song.section(name, bar)
    for i, chord in enumerate(chords):
        last = i == len(chords) - 1
        final = name == "outro" and last
        drums(bar, name, i, last, final)
        harmony(bar, name, i, chord, final)
        if melody:
            song.melody(bar, [melody[i]], amp=LEAD_AMP)
        bar += 1
song.write(bars=bar)
