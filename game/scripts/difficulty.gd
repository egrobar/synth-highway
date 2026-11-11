class_name Difficulty
extends RefCounted
## How hard a chart is to play, as a level from 1 to 10 and the reasons why.
##
## Playtest (2026-11-10): "some songs are MUCH harder". Notes per second alone misjudges this
## layout, so the model scores what the hands actually do:
##
##   effort   each note costs by the move from the note before it: switching hands is cheap; a
##            different finger on the same hand costs a little more the further it spreads; the
##            same finger on a different key (the index finger jumping F, G, R, T) costs most, as
##            does hammering one key fast; changing between the home row and the top row (sharps),
##            the G and H reach keys, and tapping with the hand that is holding a note all add.
##            Notes closer together than a quarter second cost extra on top.
##   strain   effort piles up and drains away over STRAIN_SECONDS, so a dense passage counts for
##            far more than one hard note on its own.
##   score    a blend of the chart's peak strain (95th percentile) and its sustained hard
##            sections (the mean of its hardest 40%), raised by how irregular the rhythm is
##            (gaps that are not simple multiples of the gap before are hard to read).
##   level    the score on a log scale, calibrated so the built-in library spans 1 to 10
##            (tests/rate_all.gd prints every chart's score: rerun it after changing the model).
##
## Charts come in as raw note dictionaries (t, d, l lane, s sharp flag, p pitch), so menus can
## rate songs without building playable charts.

const STRAIN_SECONDS := 2.0
## Scores at level 1 and level 10, from tests/rate_all.gd over the built-in library
## (2026-11-10: 188 charts scored 1.58 to 16.0; easy charts 1.6 to 3.7, normal 3.1 to 16).
const SCORE_AT_1 := 1.6
const SCORE_AT_10 := 16.5
const FAST_GAP := 0.25

## Sharps by key (W E R T Y U I O P): which hand plays each, touch-typing style.
const SHARP_HANDS: Array[int] = [0, 0, 0, 0, 1, 1, 1, 1, 1]


## {"level": 1-10 (float), "score": raw score, "reasons": [short phrases, hardest first],
##  "peak_nps": busiest 2-second stretch in notes per second}
static func rate(raw_notes: Array) -> Dictionary:
	var notes: Array = _normalised(raw_notes)
	if notes.size() < 2:
		return {"level": 1.0, "score": 0.0, "reasons": [], "peak_nps": 0.0}
	var strains: Array[float] = []
	var strain: float = 0.0
	var counts := {"finger": 0, "row": 0, "hold": 0, "jack": 0, "fast": 0}
	var irregular: int = 0
	var timed: int = 0
	for i: int in range(1, notes.size()):
		var a: Dictionary = notes[i - 1]
		var b: Dictionary = notes[i]
		var gap: float = maxf(float(b["t"]) - float(a["t"]), 0.06)
		var effort: float = _move_cost(a, b, gap, counts)
		if gap < FAST_GAP:
			effort *= 1.0 + 0.5 * clampf((FAST_GAP - gap) / 0.15, 0.0, 1.0)
			counts["fast"] += 1
		strain = strain * exp(-gap / STRAIN_SECONDS) + effort
		strains.append(strain)
		if i >= 2:
			var before: float = float(a["t"]) - float(notes[i - 2]["t"])
			if gap < 1.0 and before < 1.0 and before > 0.02:
				timed += 1
				if not _simple_ratio(gap / before):
					irregular += 1
	var sorted: Array[float] = strains.duplicate()
	sorted.sort()
	var peak: float = sorted[int(floor(0.95 * float(sorted.size() - 1)))]
	var top: Array[float] = sorted.slice(int(floor(0.6 * float(sorted.size()))))
	var body: float = 0.0
	for s: float in top:
		body += s
	body /= maxf(float(top.size()), 1.0)
	var irregular_share: float = float(irregular) / maxf(float(timed), 1.0)
	var score: float = (0.6 * peak + 0.4 * body) * (1.0 + 0.3 * irregular_share)
	var level: float = 1.0 + 9.0 * clampf(log(maxf(score, 0.001) / SCORE_AT_1) / log(SCORE_AT_10 / SCORE_AT_1), 0.0, 1.0)
	var peak_nps: float = _peak_density(notes)
	return {"level": level, "score": score, "peak_nps": peak_nps,
		"reasons": _reasons(counts, notes.size(), irregular_share, peak_nps)}


## A whole-number level for menus.
static func level_of(rating: Dictionary) -> int:
	return clampi(int(round(float(rating.get("level", 1.0)))), 1, 10)


## A colour from calm green (1) through yellow to red (10).
static func colour_of(level: int) -> Color:
	var x: float = clampf(float(level - 1) / 9.0, 0.0, 1.0)
	if x < 0.5:
		return Color(0.45, 0.95, 0.55).lerp(Color(1.0, 0.86, 0.3), x * 2.0)
	return Color(1.0, 0.86, 0.3).lerp(Color(1.0, 0.38, 0.38), (x - 0.5) * 2.0)


# ---------------------------------------------------------------- the model

## Each note as {t, d, lane, hand, finger, row, x}, sorted by time.
static func _normalised(raw_notes: Array) -> Array:
	var out: Array = []
	for raw: Variant in raw_notes:
		var n: Dictionary = raw
		var lane: int = int(n.get("l", -1))
		if lane < 0:
			lane = Chart.fallback_lane(int(n.get("p", 60)))
		var sharp: bool = int(n.get("s", 0)) == 1 or lane >= KeyMap.SHARP_BASE
		if sharp and lane < KeyMap.SHARP_BASE:
			lane += KeyMap.SHARP_BASE
		var entry := {"t": float(n["t"]), "d": float(n.get("d", 0.0)), "lane": lane}
		if sharp:
			var index: int = clampi(lane - KeyMap.SHARP_BASE, 0, KeyMap.SHARP_FINGERS.size() - 1)
			entry["hand"] = SHARP_HANDS[index]
			entry["finger"] = KeyMap.SHARP_FINGERS[index]
			entry["row"] = 1
			entry["x"] = float(index) + 0.5
		else:
			var home: int = clampi(lane, 0, KeyMap.COUNT - 1)
			entry["hand"] = 0 if home < KeyMap.COUNT / 2 else 1
			entry["finger"] = mini(KeyMap.HOME_FINGERS[home], 3)  # the reach keys are the index finger
			entry["row"] = 0
			entry["x"] = float(home)
		out.append(entry)
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["t"]) < float(q["t"]))
	return out


static func _move_cost(a: Dictionary, b: Dictionary, gap: float, counts: Dictionary) -> float:
	var cost: float
	if a["hand"] != b["hand"]:
		cost = 0.8
	elif a["finger"] != b["finger"]:
		cost = 1.0 + 0.08 * maxf(float(absi(int(a["finger"]) - int(b["finger"]))) - 1.0, 0.0)
	elif a["lane"] == b["lane"]:
		cost = 1.0 + 0.5 * clampf((0.3 - gap) / 0.2, 0.0, 1.0)
		if gap < 0.3:
			counts["jack"] += 1
	else:
		cost = 1.4 + 0.2 * absf(float(a["x"]) - float(b["x"]))
		if gap < 0.5:
			counts["finger"] += 1
	if a["row"] != b["row"]:
		cost += 0.25
		counts["row"] += 1
	if int(b["lane"]) in KeyMap.REACH:
		cost += 0.1
	# Tapping while a held note is still sounding.
	if float(a["d"]) >= Chart.HOLD_MIN_SECONDS and float(a["t"]) + float(a["d"]) > float(b["t"]) + 0.05:
		cost += 0.35 if a["hand"] == b["hand"] else 0.15
		counts["hold"] += 1
	return cost


## True when one gap is a simple multiple of the one before (1, 2, 3, 1.5 and their inverses),
## within 12%: rhythms built from those are easy to read.
static func _simple_ratio(ratio: float) -> bool:
	for simple: float in [1.0, 2.0, 0.5, 3.0, 1.0 / 3.0, 1.5, 2.0 / 3.0, 4.0, 0.25]:
		if absf(ratio / simple - 1.0) < 0.12:
			return true
	return false


static func _peak_density(notes: Array) -> float:
	var best: int = 0
	var start: int = 0
	for i: int in notes.size():
		while float(notes[i]["t"]) - float(notes[start]["t"]) > 2.0:
			start += 1
		best = maxi(best, i - start + 1)
	return float(best) / 2.0


## The two things that stand out most about the chart, in a few words each.
static func _reasons(counts: Dictionary, total: int, irregular_share: float, peak_nps: float) -> Array[String]:
	var found: Array = []
	var n: float = maxf(float(total), 1.0)
	found.append([peak_nps / 6.0, "fast runs"])
	found.append([float(counts["finger"]) / n * 5.0, "finger jumps"])
	found.append([float(counts["row"]) / n * 4.0, "sharps"])
	found.append([irregular_share * 1.6, "tricky rhythm"])
	found.append([float(counts["hold"]) / n * 6.0, "holds while tapping"])
	found.append([float(counts["jack"]) / n * 6.0, "repeated keys"])
	found.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) > float(q[0]))
	var out: Array[String] = []
	for entry: Array in found:
		if float(entry[0]) >= 0.35 and out.size() < 2:
			out.append(str(entry[1]))
	return out
