extends SceneTree
## Rules for Difficulty.rate: the things that make a chart harder must raise its level.
##   tools/godot.sh --headless -s res://tests/test_difficulty.gd

var _checks: int = 0
var _failures: int = 0


func _init() -> void:
	var slow := _stream(0.8, [0, 9], 60)  # slow, alternating hands
	var fast := _stream(0.2, [0, 9], 60)  # the same, four times as fast
	_check(_level(fast) > _level(slow) + 2.0, "four times the speed is much harder")

	var hands := _stream(0.25, [3, 6], 80)  # F J F J: alternate hands
	var finger := _stream(0.25, [3, 4], 80)  # F G F G: one index finger jumping
	_check(_score(finger) > _score(hands) * 1.3, "one finger jumping is harder than alternating hands")

	var home := _stream(0.3, [1, 2], 80)
	var sharps := _stream(0.3, [1, 12], 80)  # S then a top-row key
	_check(_score(sharps) > _score(home), "moving to the top row is harder than staying home")

	var gaps_mean: float = (0.31 + 0.47 + 0.23 + 0.53 + 0.37) / 5.0
	var even := _stream(gaps_mean, [0, 9], 80)  # the same average pace, evenly spaced
	var ragged: Array = []
	var t: float = 0.0
	var gaps: Array[float] = [0.31, 0.47, 0.23, 0.53, 0.37]
	for i: int in 80:
		ragged.append({"t": t, "d": 0.1, "l": [0, 9][i % 2]})
		t += gaps[i % gaps.size()]
	_check(_score(ragged) > _score(even), "an irregular rhythm is harder than an even one at a similar pace")

	var burst: Array = _stream(1.0, [0, 9], 40) + _stream(0.12, [2, 7], 30, 41.0)
	_check(_level(burst) > _level(_stream(1.0, [0, 9], 70)) + 1.0, "one dense passage raises the level")

	_check(_level([]) == 1.0, "an empty chart is level 1")
	_check(_level(_stream(0.05, [3, 4, 5, 6], 400)) <= 10.0, "levels never pass 10")
	_check(Difficulty.level_of({"level": 6.4}) == 6 and Difficulty.level_of({"level": 6.6}) == 7, "levels round to whole numbers")

	var r: Dictionary = Difficulty.rate(finger)
	_check((r["reasons"] as Array).has("finger jumps"), "a jumping index finger is named as the reason")

	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _stream(gap: float, lanes: Array, count: int, start: float = 0.0) -> Array:
	var out: Array = []
	for i: int in count:
		out.append({"t": start + i * gap, "d": 0.1, "l": lanes[i % lanes.size()]})
	return out


func _level(notes: Array) -> float:
	return float(Difficulty.rate(notes)["level"])


func _score(notes: Array) -> float:
	return float(Difficulty.rate(notes)["score"])


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: " + what)
