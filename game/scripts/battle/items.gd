class_name BattleItems
extends RefCounted
## The battle's items (Evan, 2026-11-24: "if you hit big streak or hard note combo you get spinning
## block above like a mario kart item ... press 1 2 or 3 to send to respective opponent").
##
## A racer earns an item box every COMBO_STEP in a streak (50, 100, 150...) and for each power chord
## struck whole (Hard). One item is held at a time: the box spins for ROLL_SECONDS (ItemSlot) and lands
## on one of ITEMS. An attack goes to a rival with 1, 2 or 3 (their panel, left to right: RivalBar); a
## boost is used on yourself with any of the three. Effects play on the receiving racer's own road
## (ItemEffects); a Shield blocks the next attack.
##
## Catch-up (Evan's choice): the further behind you are, the stronger the box. Items come in three
## tiers, mild to strong; the leader mostly rolls mild ones, last place mostly strong ones (roll()).
## Icons: res://assets/textures/items/<id>.png (tools/items/slice_icons.gd, from a Nano Banana sheet).

const COMBO_STEP := 50
const ROLL_SECONDS := 1.6

## id -> name (as shown), kind ("attack" or "boost"), seconds it lasts (0: at once), tier (0 mild,
## 1 middling, 2 strong) and what it does, in a line.
const ITEMS := {
	"paint": {"name": "PAINT BOMB", "kind": "attack", "seconds": 8.0, "tier": 0, "line": "Their notes take random colours"},
	"quake": {"name": "EARTHQUAKE", "kind": "attack", "seconds": 6.0, "tier": 1, "line": "Their road shakes and bumps"},
	"disco": {"name": "DISCO BALL", "kind": "attack", "seconds": 8.0, "tier": 0, "line": "A disco ball lights up their road"},
	"fog": {"name": "FOG BANK", "kind": "attack", "seconds": 8.0, "tier": 1, "line": "Their notes come out of the fog late"},
	"turbo": {"name": "TURBO", "kind": "attack", "seconds": 8.0, "tier": 2, "line": "Their notes come twice as fast"},
	"blackout": {"name": "BLACKOUT", "kind": "attack", "seconds": 6.0, "tier": 2, "line": "Their lights go out"},
	"wobble": {"name": "WOBBLE", "kind": "attack", "seconds": 8.0, "tier": 0, "line": "Their road sways like a ship"},
	"leak": {"name": "GAS LEAK", "kind": "attack", "seconds": 0.0, "tier": 2, "line": "Drains a quarter of their gas"},
	"nitro": {"name": "NITRO", "kind": "boost", "seconds": 8.0, "tier": 1, "line": "Double points"},
	"shield": {"name": "SHIELD", "kind": "boost", "seconds": 20.0, "tier": 0, "line": "Blocks the next attack"},
}

static var _icons: Dictionary = {}


static func is_attack(id: String) -> bool:
	return str((ITEMS.get(id, {}) as Dictionary).get("kind", "")) == "attack"


static func item_name(id: String) -> String:
	return str((ITEMS.get(id, {}) as Dictionary).get("name", id.to_upper()))


static func seconds(id: String) -> float:
	return float((ITEMS.get(id, {}) as Dictionary).get("seconds", 0.0))


## The item's icon, or the mystery "?" or the empty slot ("mystery", "empty").
static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path: String = "res://assets/textures/items/%s.png" % id
		_icons[id] = load(path) if ResourceLoader.exists(path) else null
	return _icons[id]


## The item a box lands on for a racer in `place` (0 = leading) of `racers`: mild items weigh most
## for the leader, strong ones for last place, middling ones the same for all.
static func roll(place: int, racers: int, rng: RandomNumberGenerator) -> String:
	var behind: float = clampf(float(place) / maxf(float(racers - 1), 1.0), 0.0, 1.0)
	var tier_weight: Array[float] = [3.0 - 2.0 * behind, 2.0, 0.5 + 2.5 * behind]
	var total: float = 0.0
	for id: String in ITEMS:
		total += tier_weight[int(ITEMS[id]["tier"])]
	var pick: float = rng.randf() * total
	for id: String in ITEMS:
		pick -= tier_weight[int(ITEMS[id]["tier"])]
		if pick <= 0.0:
			return id
	return ITEMS.keys()[0]
