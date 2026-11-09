"""Moonglass: Coast Road. An original R&B / soul tune in C major (verses lean on A minor), 90 BPM.

Laid-back swung drums (kick, snare, brushed ghosts, hats), e-piano comping in
rootless 7th and 9th voicings, a smooth bass with octave pops and chromatic
approach notes, a light pad, and a breathy flute lead that only plays while the
player hits it. Region 3 pacing: about 1.7 notes a second on Normal, a quarter
of them holds. The melody stays on the Q row's white keys (C4 to G5).
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from songlib import Song  # noqa: E402

# Off-beat 8ths and 16ths land a little late, the whole band and the melody alike:
# that shared lag is the laid-back swing. Kept small enough that a 16th after an
# off-beat is still over 0.12 s from the next downbeat.
SWING = {0.25: 0.05, 0.5: 0.07, 0.75: 0.05}

VERSE_CHORDS = ["Am9", "Dm9", "Am9", "Dm9", "Fmaj9", "Em7", "Dm9", "G13sus"]
CHORUS_CHORDS = ["Fmaj9", "G13", "Em7", "Am9", "Dm9", "G13", "Cmaj9", "Cmaj9"]
VERSE_1 = [
    "r:0.5 E4:0.5 G4:0.5 A4:1.5 G4:0.5 E4:0.5", "F4:1.5 E4:0.5 D4:1.5 C4:0.25 D4:0.25",
    "E4:0.5 G4:0.5 A4:0.5 C5:1.5 B4:0.5 A4:0.5", "A4:1.5 G4:0.5 F4:1.5 r:0.5",
    "C4:0.5 F4:0.5 A4:0.5 C5:1.5 B4:0.5 C5:0.5", "D5:1.5 B4:0.5 G4:1.5 E4:0.25 G4:0.25",
    "A4:0.5 G4:0.5 F4:0.5 E4:0.5 D4:0.5 F4:0.5 E4:1", "D4:3 r:0.5 E4:0.5",
]
VERSE_2 = [
    "r:0.5 E4:0.5 G4:0.5 A4:0.5 C5:1.5 A4:0.5", "G4:1.5 F4:0.5 E4:0.5 D4:0.5 F4:0.5 E4:0.5",
    "C4:0.5 E4:0.5 A4:1.5 G4:0.5 E4:1", "D4:1.5 F4:0.5 A4:1.5 r:0.5",
    "A4:0.5 C5:0.5 E5:0.5 G5:1.5 E5:0.5 C5:0.5", "B4:1.5 D5:0.5 B4:1.5 G4:0.25 A4:0.25",
    "B4:0.5 A4:0.5 G4:0.5 F4:0.5 E4:0.5 D4:0.5 F4:1", "G4:3 r:0.5 B4:0.5",
]
CHORUS_1 = [
    "C5:0.5 E5:0.5 G5:1.5 E5:0.5 D5:0.5 C5:0.5", "D5:1.5 B4:0.5 G4:1.5 A4:0.25 B4:0.25",
    "E5:0.5 D5:0.5 B4:0.5 D5:1.5 E5:0.5 G5:0.5", "E5:1.5 C5:0.5 A4:1.5 r:0.5",
    "F5:1.5 E5:0.5 D5:0.5 C5:0.5 A4:0.5 C5:0.5", "D5:1.5 B4:0.5 G5:1.5 F5:0.25 E5:0.25",
    "E5:0.5 D5:0.5 C5:0.5 D5:0.5 E5:0.5 G5:0.5 E5:1", "C5:3 r:1",
]
CHORUS_2 = [
    "C5:0.5 E5:0.5 G5:1.5 E5:0.5 D5:0.5 C5:0.5", "D5:1.5 B4:0.5 G4:1.5 A4:0.25 B4:0.25",
    "E5:0.5 G5:0.5 E5:0.5 D5:1.5 B4:0.5 D5:0.5", "E5:1.5 C5:0.5 A4:1.5 r:0.5",
    "F5:1.5 E5:0.5 D5:0.5 E5:0.5 F5:0.5 A4:0.5", "G5:1.5 F5:0.5 D5:1.5 B4:0.25 D5:0.25",
    "E5:0.5 D5:0.5 C5:0.5 B4:0.5 C5:0.5 D5:0.5 E5:1", "E5:1.5 D5:0.5 C5:2",
]
OUTRO = ["A4:1.5 G4:0.5 E4:1.5 D4:0.5", "C4:4"]
SECTIONS = [
    ("intro", ["Am9", "Dm9"], None), ("verse", VERSE_CHORDS, VERSE_1), ("chorus", CHORUS_CHORDS, CHORUS_1),
    ("verse", VERSE_CHORDS, VERSE_2), ("chorus", CHORUS_CHORDS, CHORUS_2), ("outro", ["Fmaj9", "Cmaj9"], OUTRO),
]
# Rootless voicings (the bass has the root), kept under the flute's range where they can.
VOICING = {
    "Am9": [55, 59, 60, 64], "Dm9": [53, 57, 60, 64], "Fmaj9": [52, 55, 57, 60], "Em7": [50, 55, 59, 62],
    "G13": [53, 57, 59, 64], "G13sus": [53, 57, 60, 62], "Cmaj9": [52, 55, 59, 62],
}
ROOT = {"Am9": 45, "Dm9": 38, "Fmaj9": 41, "Em7": 40, "G13": 43, "G13sus": 43, "Cmaj9": 36}


def swing(beat: float) -> float:
    frac = round(beat % 1.0, 4)
    return beat + SWING.get(frac, 0.0)


def swung(bar_text: str) -> str:
    """Rewrites one bar of melody tokens so off-beat notes land with the band's swing.
    Every start and end is moved by the same rule, so the bar still adds up to 4."""
    tokens, pos = [], 0.0
    for token in bar_text.split():
        name, beats = token.split(":")
        tokens.append((name, pos, pos + float(beats)))
        pos += float(beats)
    out = []
    for name, start, end in tokens:
        out.append(f"{name}:{round(swing(end) - swing(start), 4)}")
    return " ".join(out)


song = Song("coast_moonglass", "Moonglass", "coast", bpm=90, lead_patch="flute")
song.room = {"backing": [0.26, 0.7, 0.0], "lead": [0.34, 0.78, 0.12]}
ALL_CHORDS = [c for _, chords, _ in SECTIONS for c in chords]  # for the bass's approach notes
bar = 0
for name, chords, melody in SECTIONS:
    song.section(name, bar)
    chorus = name == "chorus"
    for i, chord in enumerate(chords):
        at = lambda b: song.at(bar, swing(b))  # noqa: E731
        final = name == "outro" and i == len(chords) - 1
        voicing = VOICING[chord]
        root = ROOT[chord]
        next_root = ROOT[ALL_CHORDS[bar + 1]] if bar + 1 < len(ALL_CHORDS) else root

        # ---------------------------------------------------------------- e-piano and pad
        if final:
            for k, p in enumerate([48] + voicing + [67]):
                song.hit(at(0) + k * 0.03, "epiano", p, song.beat * 5.5, 0.15, pan=-0.15 + k * 0.06)
            for p in voicing:
                song.hit(at(0), "pad", p + 12, song.beat * 5.0, 0.05, pan=0.25)
        else:
            amp = 0.15 if chorus else 0.13
            for k, p in enumerate(voicing):
                song.hit(at(0) + k * 0.012, "epiano", p, song.beat * 1.3, amp, pan=-0.2 + k * 0.1)
            for k, p in enumerate(voicing[1:]):
                song.hit(at(1.5) + k * 0.01, "epiano", p, song.beat * 0.35, amp * 0.6, pan=-0.1 + k * 0.1)
            for k, p in enumerate(voicing):
                song.hit(at(2.5) + k * 0.012, "epiano", p, song.beat * 1.2, amp * 0.8, pan=-0.2 + k * 0.1)
            if name != "intro":
                for k, p in enumerate(voicing[1:]):
                    song.hit(at(3.75), "epiano", p, song.beat * 0.18, amp * 0.35, pan=0.15)
            pad_amp = 0.05 if chorus else 0.035
            for k, p in enumerate(voicing):
                song.hit(at(0), "pad", p + 12 if k >= 2 else p, song.beat * 3.8, pad_amp, pan=0.3 if k % 2 else -0.3)

        # ---------------------------------------------------------------- bass
        if name == "intro" and i == 0:
            pass  # the bass walks in on the second intro bar
        elif final:
            song.hit(at(0), "bass", root, song.beat * 5.0, 0.48)
        else:
            approach = next_root - 1 if next_root > root else next_root + 1
            if next_root == root:
                approach = root + 7
            song.hit(at(0), "bass", root, song.beat * 1.3, 0.5)
            song.hit(at(1.5), "bass", root + 12, song.beat * 0.28, 0.3)
            song.hit(at(2.0), "bass", root + 7, song.beat * 0.8, 0.4)
            song.hit(at(2.75), "bass", root, song.beat * 0.5, 0.36)
            song.hit(at(3.5), "bass", approach, song.beat * 0.42, 0.34)

        # ---------------------------------------------------------------- drums
        if name == "intro":
            for k in range(8):
                song.hit(at(k * 0.5), "hat", dur=0.04, amp=0.08 if k % 2 == 0 else 0.05, pan=0.2)
            if i == 1:
                song.hit(at(3.0), "brush", amp=0.18, pan=0.05)
                song.hit(at(3.5), "brush", amp=0.12, pan=0.05)
        elif final:
            song.hit(at(0), "kick", amp=0.5)
            song.hit(at(0), "crash", amp=0.12, pan=-0.3)
        else:
            if i == 0 and bar > 2:
                song.hit(at(0), "crash", amp=0.13 if chorus else 0.09, pan=-0.3)
            song.hit(at(0), "kick", amp=0.55)
            song.hit(at(1.75), "kick", amp=0.32)
            song.hit(at(2.5), "kick", amp=0.44)
            # Snare sits a hair behind the beat; brushed ghosts fill the gaps.
            for b in (1, 3):
                song.hit(at(b) + 0.022, "snare", amp=0.36 if chorus else 0.3, pan=0.05)
                song.hit(at(b) + 0.022, "brush", amp=0.12, pan=0.05)
            for b in (0.75, 2.25, 3.75):
                song.hit(at(b), "brush", amp=0.07, pan=-0.05)
            steps = 16 if chorus else 8
            for k in range(steps):
                b = k * 4 / steps
                accent = 0.1 if b % 1 == 0 else (0.065 if b % 0.5 == 0 else 0.04)
                song.hit(at(b), "hat", dur=0.12 if b == 3.5 else 0.04, amp=accent, pan=0.22)
            if chorus:
                for k in range(8):
                    song.hit(at(k * 0.5 + 0.25), "shaker", amp=0.045, pan=-0.3)

        if melody:
            song.melody(bar, [swung(melody[i])])
        bar += 1
song.write(bars=bar)
