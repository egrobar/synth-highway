class_name KeyMap
extends RefCounted
## The home row is the instrument: ten lanes, A S D F G H J K L ;.
##
## Fingers rest on A S D F and J K L ;, and the index fingers reach for G and H,
## so every song is played from the same hand position. Charts give each note a
## lane that follows the melody's shape; see tools/song/songlib.py.
##
## On Normal, notes outside the song's key are sharps, played like a piano's black
## keys on the top-row key that sits between two home keys: W between A and S,
## E between S and D, ... P between L and ;. Lane ids: 0-9 are the home keys,
## 10-18 the sharps (10 = W, the sharp just above lane 0).

const LANES: Array[Key] = [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON]
const SHARPS: Array[Key] = [KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P]
const COUNT := 10
const SHARP_BASE := 10
## G and H: reached by the index fingers, not rested on.
const REACH: Array[int] = [4, 5]
## F and J: the keys with the homing bumps.
const HOMING: Array[int] = [3, 6]


## The lane a physical key plays, or -1 if it is not one of the instrument's keys.
static func lane_for(code: Key) -> int:
	var home: int = LANES.find(code)
	if home >= 0:
		return home
	var sharp: int = SHARPS.find(code)
	return SHARP_BASE + sharp if sharp >= 0 else -1


static func is_sharp(lane: int) -> bool:
	return lane >= SHARP_BASE


static func key_for(lane: int) -> Key:
	if is_sharp(lane):
		var i: int = lane - SHARP_BASE
		return SHARPS[i] if i < SHARPS.size() else KEY_NONE
	return LANES[lane] if lane >= 0 and lane < COUNT else KEY_NONE


static func label_for(lane: int) -> String:
	if lane == 9:
		return ";"
	return OS.get_keycode_string(key_for(lane))
