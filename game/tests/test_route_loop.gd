extends SceneTree
## Rules for RouteLoop: start anywhere on the loop, two clears open the next region clockwise.
##   tools/godot.sh --headless -s res://tests/test_route_loop.gd

var _checks: int = 0
var _failures: int = 0


func _init() -> void:
	var none: Array[int] = [0, 0, 0, 0, 0]
	_check(_open(-1, none) == [false, false, false, false, false], "nothing is open before a start is picked")
	_check(_open(2, none) == [false, false, true, false, false], "the start is open on its own")

	var one: Array[int] = [0, 0, 1, 0, 0]
	_check(_open(2, one) == [false, false, true, false, false], "one clear is not enough")
	var two: Array[int] = [0, 0, 2, 0, 0]
	_check(_open(2, two) == [false, false, true, true, false], "two clears open the next region clockwise")
	_check(_open(2, [0, 0, 5, 0, 0]) == [false, false, true, true, false], "more clears still open only the next one")

	var round_the_end: Array[int] = [0, 0, 0, 0, 2]
	_check(_open(4, round_the_end) == [true, false, false, false, true], "the last region opens the first: it is a loop")
	_check(_open(3, [2, 2, 2, 2, 2]) == [true, true, true, true, true], "a full lap opens everything")
	_check(_open(1, [0, 2, 2, 0, 0]) == [false, true, true, true, false], "a chain of cleared regions opens in turn")
	_check(_open(1, [2, 0, 0, 0, 0]) == [false, true, false, false, false],
		"clears in a region that is not open open nothing")

	_check(RouteLoop.clears_needed(3, 5, 2, one) == 1, "one more clear needed in the region before")
	_check(RouteLoop.clears_needed(3, 5, 2, two) == 0, "nothing needed once it is open")
	_check(RouteLoop.clears_needed(4, 5, 2, none) == 0, "nothing to count while the region before is locked too")
	_check(RouteLoop.next(4, 5) == 0, "after the last region comes the first")

	var old_clears: Array[int] = [3, 1, 0, 0, 0]
	var kept: Array[int] = RouteLoop.old_chain_open(5, old_clears)
	_check(kept == [0, 1, 2], "an old save keeps the regions the old chain opened")
	_check(RouteLoop.open_regions(5, 0, old_clears, kept) == [true, true, true, false, false],
		"kept regions stay open even with fewer than two clears before them")
	var kept_and_more: Array[int] = [3, 1, 2, 0, 0]
	_check(RouteLoop.open_regions(5, 0, kept_and_more, RouteLoop.old_chain_open(5, kept_and_more))
		== [true, true, true, true, false], "a kept region with two clears opens the next")

	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _open(start: int, clears: Array[int]) -> Array[bool]:
	return RouteLoop.open_regions(5, start, clears)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", what)
