"""The chart difficulty model, in Python, for tuning generated charts to a level band.

A port of game/scripts/difficulty.gd (the game shows its result on the route): per-note effort
from the hand movement on the home-row layout, strain that piles up and drains over
STRAIN_SECONDS, a score from peak and sustained strain raised by rhythmic irregularity, and a
1-10 level on a log scale. Keep the two in step: tools/song/test_difficulty_parity.py compares
them on every built-in chart. Chords (notes within CHORD_GAP of each other, the "power notes" on
big hits) count as one onset: the extra notes cost a fixed effort (CHORD_OTHER_HAND /
CHORD_SAME_HAND) and add no speed, and the next move is from the chord's note on the same hand.
"""
import math

STRAIN_SECONDS = 2.0
SCORE_AT_1 = 1.6
SCORE_AT_10 = 16.5
FAST_GAP = 0.25
CHORD_GAP = 0.03  # Chart.CHORD_SECONDS
CHORD_OTHER_HAND = 0.35
CHORD_SAME_HAND = 0.6
CHORD_DENSITY = 0.5  # a chord's extra notes in the peak-density count
HOLD_MIN = 0.75
SHARP_BASE = 10
COUNT = 10
REACH = (4, 5)
HOME_FINGERS = [0, 1, 2, 3, 4, 4, 3, 2, 1, 0]
SHARP_FINGERS = [1, 2, 3, 3, 3, 3, 2, 1, 0]
SHARP_HANDS = [0, 0, 0, 0, 1, 1, 1, 1, 1]


def _normalised(raw: list[dict]) -> list[dict]:
    out = []
    for n in raw:
        lane = int(n.get("l", 0))
        sharp = int(n.get("s", 0)) == 1 or lane >= SHARP_BASE
        if sharp and lane < SHARP_BASE:
            lane += SHARP_BASE
        if sharp:
            i = max(0, min(lane - SHARP_BASE, len(SHARP_FINGERS) - 1))
            e = {"hand": SHARP_HANDS[i], "finger": SHARP_FINGERS[i], "row": 1, "x": i + 0.5}
        else:
            h = max(0, min(lane, COUNT - 1))
            e = {"hand": 0 if h < COUNT // 2 else 1, "finger": min(HOME_FINGERS[h], 3), "row": 0, "x": float(h)}
        e.update({"t": float(n["t"]), "d": float(n.get("d", 0.0)), "lane": lane})
        out.append(e)
    return sorted(out, key=lambda e: (e["t"], e["lane"]))


def _move_cost(a: dict, b: dict, gap: float, counts: dict) -> float:
    if a["hand"] != b["hand"]:
        cost = 0.8
    elif a["finger"] != b["finger"]:
        cost = 1.0 + 0.08 * max(abs(a["finger"] - b["finger"]) - 1.0, 0.0)
    elif a["lane"] == b["lane"]:
        cost = 1.0 + 0.5 * min(max((0.3 - gap) / 0.2, 0.0), 1.0)
        if gap < 0.3:
            counts["jack"] += 1
    else:
        cost = 1.4 + 0.2 * abs(a["x"] - b["x"])
        if gap < 0.5:
            counts["finger"] += 1
    if a["row"] != b["row"]:
        cost += 0.25
        counts["row"] += 1
    if b["lane"] in REACH:
        cost += 0.1
    if a["d"] >= HOLD_MIN and a["t"] + a["d"] > b["t"] + 0.05:
        cost += 0.35 if a["hand"] == b["hand"] else 0.15
        counts["hold"] += 1
    return cost


def _simple_ratio(ratio: float) -> bool:
    return any(abs(ratio / s - 1.0) < 0.12 for s in (1.0, 2.0, 0.5, 3.0, 1 / 3, 1.5, 2 / 3, 4.0, 0.25))


def _chord_joins(notes: list[dict]) -> list[bool]:
    """For each note, whether it joins the chord begun by an earlier note (within CHORD_GAP of
    that chord's first note) -- Difficulty._chord_joins."""
    joins, start = [], -math.inf
    for n in notes:
        joined = n["t"] - start <= CHORD_GAP
        joins.append(joined)
        if not joined:
            start = n["t"]
    return joins


def rate(raw: list[dict]) -> dict:
    """{"level", "score", "peak_nps"} for a chart's notes (dicts with t, d, l, s)."""
    notes = _normalised(raw)
    if len(notes) < 2:
        return {"level": 1.0, "score": 0.0, "peak_nps": 0.0}
    counts = {"finger": 0, "row": 0, "hold": 0, "jack": 0}
    scratch = {"finger": 0, "row": 0, "hold": 0, "jack": 0}
    strains: list[float] = []
    strain = 0.0
    joins = _chord_joins(notes)
    onsets = [notes[0]["t"]]
    group_start = 0
    for i in range(1, len(notes)):
        b = notes[i]
        if joins[i]:
            # Part of a chord: a fixed effort, no speed, and the chord stays one onset.
            same_hand = any(notes[k]["hand"] == b["hand"] for k in range(group_start, i))
            strain += CHORD_SAME_HAND if same_hand else CHORD_OTHER_HAND
            strains.append(strain)
            continue
        gap = max(b["t"] - notes[i - 1]["t"], 0.06)
        origin = i - 1
        if i - 1 > group_start:
            # After a chord the move is from the chord's note on this note's hand.
            cheapest, on_hand = math.inf, False
            for k in range(group_start, i):
                same = notes[k]["hand"] == b["hand"]
                if on_hand and not same:
                    continue
                cost = _move_cost(notes[k], b, gap, scratch)
                if (same and not on_hand) or cost < cheapest:
                    cheapest, origin = cost, k
                    on_hand = on_hand or same
        effort = _move_cost(notes[origin], b, gap, counts)
        if gap < FAST_GAP:
            effort *= 1.0 + 0.5 * min(max((FAST_GAP - gap) / 0.15, 0.0), 1.0)
        strain = strain * math.exp(-gap / STRAIN_SECONDS) + effort
        strains.append(strain)
        onsets.append(b["t"])
        group_start = i
    irregular = timed = 0
    for i in range(2, len(onsets)):
        gap = max(onsets[i] - onsets[i - 1], 0.06)
        before = onsets[i - 1] - onsets[i - 2]
        if gap < 1.0 and 0.02 < before < 1.0:
            timed += 1
            if not _simple_ratio(gap / before):
                irregular += 1
    ordered = sorted(strains)
    peak = ordered[int(math.floor(0.95 * (len(ordered) - 1)))]
    top = ordered[int(math.floor(0.6 * len(ordered))):]
    body = sum(top) / max(len(top), 1)
    score = (0.6 * peak + 0.4 * body) * (1.0 + 0.3 * irregular / max(timed, 1))
    level = 1.0 + 9.0 * min(max(math.log(max(score, 0.001) / SCORE_AT_1) / math.log(SCORE_AT_10 / SCORE_AT_1), 0.0), 1.0)
    best = inside = 0.0
    start = 0
    for i, n in enumerate(notes):
        inside += CHORD_DENSITY if joins[i] else 1.0
        while n["t"] - notes[start]["t"] > 2.0:
            inside -= CHORD_DENSITY if joins[start] else 1.0
            start += 1
        best = max(best, inside)
    return {"level": level, "score": score, "peak_nps": best / 2.0}
