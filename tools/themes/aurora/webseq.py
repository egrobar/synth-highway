"""Aurora Pass song kit: reads the web trainer's note notation and puts public-domain pieces on the chart.

The original web trainer (index.html, BUILTIN) writes its pieces as "E4 F4:0.5 r:1 [C3 E3 G3]:2": a
pitch or a rest `r`, then `:` and a length in beats (a decimal or a fraction such as 1/3; no length
means one beat), with chords in square brackets and `|` allowed as a bar line. Accidentals are read
by songlib.pitch, so Bb3 is A#3 and B#3 is C4.

Used by the Aurora Pass songs in tools/song/songs/ (ode_to_joy, greensleeves, fur_elise, minuet_in_g,
canon_in_d, moonlight_sonata, prelude_in_c). It lives in the region's own folder so the region stays
self-contained: build_assets.sh only runs props.py, textures.py and ambience.scd from here, so this
file is never run as a build step itself.
"""
from __future__ import annotations

import pathlib
import sys
from fractions import Fraction

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "song"))
from songlib import LANE_HIGH, LANE_LOW, Song, fold_to_lanes, pitch  # noqa: E402,F401

Event = tuple[Fraction, Fraction, list[str]]  # start beat, length in beats, note names (a chord has several)


def beats_of(text: str) -> Fraction:
    """'0.5' -> 1/2, '1/3' -> 1/3, '' -> 1, as the web's parseDur reads them."""
    if not text:
        return Fraction(1)
    if "/" in text:
        top, bottom = text.split("/")
        return Fraction(int(top), int(bottom))
    return Fraction(text)


def parse(seq: str, legato: bool = False) -> tuple[list[Event], Fraction]:
    """Notes and chords of one voice, with the voice's total length in beats. Rests are left out.
    With legato, a rest straight after a note is added to that note: the sustain pedal holds it,
    and on the chart it turns the note into a hold."""
    tokens = seq.replace("|", " ").split()
    events: list[Event] = []
    t = Fraction(0)
    i = 0
    last_was_note = False
    while i < len(tokens):
        token = tokens[i]
        i += 1
        if token.startswith("["):
            chord = token
            while "]" not in chord:
                chord += " " + tokens[i]
                i += 1
            inner, _, length = chord[1:].partition("]")
            d = beats_of(length.lstrip(":"))
            events.append((t, d, inner.split()))
            t += d
            last_was_note = True
            continue
        name, _, length = token.partition(":")
        d = beats_of(length)
        if name == "r":
            if legato and last_was_note and events:
                # Rests in a row all go to the note before them.
                start, held, names = events[-1]
                events[-1] = (start, held + d, names)
            else:
                last_was_note = False
        else:
            pitch(name)  # fails early on a bad note name
            events.append((t, d, [name]))
            last_was_note = True
        t += d
    return events, t


def rep(seq: str, n: int) -> str:
    """The web's rep(): a passage n times over."""
    return " ".join([seq] * n)


def lead(song: Song, bar: int, seq: str, beat: float = 0.0, amp: float = 0.5, legato: bool = False,
         chord_amp: float = 0.22) -> float:
    """Puts a melody voice on the chart through song.melody, starting `beat` beats into `bar`.
    A chord's top note is the chart note; its other notes go to the backing on piano, since the
    chart takes one note at a time. Returns the voice's length in beats."""
    events, total = parse(seq, legato)
    parts: list[str] = []
    pos = -Fraction(beat).limit_denominator(48)
    for start, d, names in events:
        if start > pos:
            parts.append(f"r:{float(start - pos)!r}")
        top = max(names, key=pitch)
        parts.append(f"{top}:{float(d)!r}")
        for name in names:
            if name != top:
                song.hit(song.at(bar, beat + float(start)), "piano", pitch(name), float(d) * song.beat, chord_amp)
        pos = start + d
    song.melody(bar, [" ".join(parts)], amp)
    return float(total)


def voice(song: Song, bar: int, seq: str, inst: str = "piano", amp: float = 0.22, pan: float = 0.0,
          beat: float = 0.0, ring: float = 1.0, roll: float = 0.0) -> float:
    """A backing voice in the web's notation. `ring` scales each note's length (a pad can swell past
    its written length), `roll` spreads a chord's notes upward by that many seconds."""
    events, total = parse(seq)
    for start, d, names in events:
        t = song.at(bar, beat + float(start))
        for k, name in enumerate(sorted(names, key=pitch)):
            song.hit(t + k * roll, inst, pitch(name), float(d) * song.beat * ring, amp, pan)
    return float(total)


def fold_notes(song: Song, shift: int | None = 0) -> None:
    """Moves the chart by `shift` semitones and folds any note still off the Q row in by octaves.
    The default keeps the melody at its real pitches; shift=None lets songlib.fold_to_lanes pick the
    octave that fits most notes (it would rather move a whole tune than fold one stray note).
    Only the chart changes: the lead stem still plays what was written."""
    if shift is None:
        song.notes = fold_to_lanes(song.notes)
        return
    for n in song.notes:
        p = n["p"] + shift
        while p < LANE_LOW:
            p += 12
        while p > LANE_HIGH:
            p -= 12
        n["p"] = p


def fold_bars(song: Song) -> None:
    """Like fold_notes, but bar by bar: each bar of the chart moves by whole octaves as one, so a
    figure keeps its shape on the keys. A bar prefers its real pitches, then the previous bar's shift;
    anything still off the Q row is folded note by note."""
    bar_seconds = song.beat * song.beats_per_bar
    groups: dict[int, list[dict]] = {}
    for n in song.notes:
        groups.setdefault(int((n["t"] + 1e-6) // bar_seconds), []).append(n)
    previous = 0
    for key in sorted(groups):
        notes = groups[key]

        def rank(shift: int, notes: list[dict] = notes, previous: int = previous) -> tuple[int, bool, int]:
            fit = sum(1 for n in notes if LANE_LOW <= n["p"] + shift <= LANE_HIGH)
            return (-fit, shift != previous, abs(shift))

        best = min((0, 12, -12, 24, -24), key=rank)
        for n in notes:
            p = n["p"] + best
            while p < LANE_LOW:
                p += 12
            while p > LANE_HIGH:
                p -= 12
            n["p"] = p
        previous = best


def classical_room(song: Song) -> None:
    """A larger, darker hall than the default: the pieces are solo piano with a pad, no slap delay."""
    song.room = {"backing": [0.3, 0.82, 0.0], "lead": [0.28, 0.82, 0.0]}


def write(song: Song, bars: int, backing_gain: float = 2.0) -> None:
    """song.write, with the whole backing raised by one gain. The arrangements are written at the
    balance a pianist would play (left hand under the melody), which left the backing stem ~10 dB
    quieter than the other regions' songs; one gain fixes the level without touching the balance."""
    for event in song.backing:
        event[4] = round(event[4] * backing_gain, 4)
    song.write(bars=bars)
