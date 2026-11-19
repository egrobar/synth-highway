class_name RouteLoop
extends RefCounted
## Which regions are open: the route is a loop, and a player can start anywhere on it.
##
## The five regions sit on one loop in their "order" (Red Frontier, Neon Sprawl, Tidewater,
## Io Burn, Ring Road, then back to Red Frontier). A new player picks a start on the loop map
## (scripts/ui/loop_map.gd); clearing CLEARS_TO_ADVANCE songs in an open region opens the next
## one clockwise, so a full lap opens everything. This replaced a fixed chain that opened
## Red Frontier (country) first for everyone (playtest, 2026-11-12). The regions are equally
## hard (each one's easiest songs are Easy 1-3, Normal 3.5-5.3, Hard 6-7), so no start is a
## harder one, and each region's list is sorted easiest first, so its top two songs are the
## gentlest way on.
##
## Saves from before the loop keep every region the old chain had opened (`kept`), with the
## start at the first region.
##
## Pure functions over region indexes (0 .. count - 1, in loop order), so the rule can be
## tested on its own (tests/test_route_loop.gd).

const CLEARS_TO_ADVANCE := 2


## open[i] is true when region i is open. `start` is -1 until a start is picked: nothing is open.
## `clears` holds the songs cleared in each region; `kept` the regions an old save had open.
static func open_regions(count: int, start: int, clears: Array[int], kept: Array[int] = []) -> Array[bool]:
	var open: Array[bool] = []
	open.resize(count)
	open.fill(false)
	if start < 0 or start >= count:
		return open
	open[start] = true
	for i: int in kept:
		if i >= 0 and i < count:
			open[i] = true
	# A region opens when the one before it is open and has its clears. Open regions can be
	# scattered (kept ones), so this walks the loop until nothing more opens.
	var changed: bool = true
	while changed:
		changed = false
		for i: int in count:
			var next: int = (i + 1) % count
			if open[i] and not open[next] and clears[i] >= CLEARS_TO_ADVANCE:
				open[next] = true
				changed = true
	return open


## How many more songs region i - 1 (the one before it on the loop) needs cleared to open
## region i: 0 when it is open or the region before it is not open yet.
static func clears_needed(index: int, count: int, start: int, clears: Array[int], kept: Array[int] = []) -> int:
	var open: Array[bool] = open_regions(count, start, clears, kept)
	var previous: int = (index - 1 + count) % count
	if open[index] or not open[previous]:
		return 0
	return maxi(0, CLEARS_TO_ADVANCE - clears[previous])


## The region after `index` on the loop.
static func next(index: int, count: int) -> int:
	return (index + 1) % count


## The regions the chain before the loop had open, for a save from then: the first region, and
## every region whose predecessor had any song cleared.
static func old_chain_open(count: int, clears: Array[int]) -> Array[int]:
	var kept: Array[int] = [0]
	for i: int in range(1, count):
		if clears[i - 1] > 0:
			kept.append(i)
	return kept
