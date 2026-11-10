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

## Which finger plays a lane, mirrored across the hands: 0 pinky, 1 ring, 2 middle, 3 index.
## Notes, lanes and keys are coloured by finger, so the colour of an approaching note says
## which finger moves before the eye has worked out which of ten lanes it is in.
const HOME_FINGERS: Array[int] = [0, 1, 2, 3, 3, 3, 3, 2, 1, 0]
## The top-row keys W E R T Y U I O P, by standard touch-typing fingering.
const SHARP_FINGERS: Array[int] = [1, 2, 3, 3, 3, 3, 2, 1, 0]
const FINGER_NAMES: Array[String] = ["pinky", "ring", "middle", "index"]
## Chosen to stay apart from each other, from the orange of sharps and the red of a miss.
const FINGER_COLORS: Array[Color] = [
	Color(0.74, 0.52, 1.0),   # pinky: violet
	Color(1.0, 0.88, 0.3),    # ring: yellow
	Color(0.42, 1.0, 0.55),   # middle: green
	Color(0.247, 0.847, 1.0), # index: cyan
]


## The lane a physical key plays, or -1 if it is not one of the instrument's keys.
static func lane_for(code: Key) -> int:
	var home: int = LANES.find(code)
	if home >= 0:
		return home
	var sharp: int = SHARPS.find(code)
	return SHARP_BASE + sharp if sharp >= 0 else -1


static func is_sharp(lane: int) -> bool:
	return lane >= SHARP_BASE


static func finger_for(lane: int) -> int:
	if is_sharp(lane):
		return SHARP_FINGERS[clampi(lane - SHARP_BASE, 0, SHARP_FINGERS.size() - 1)]
	return HOME_FINGERS[clampi(lane, 0, COUNT - 1)]


static func color_for(lane: int) -> Color:
	return FINGER_COLORS[finger_for(lane)]


static func key_for(lane: int) -> Key:
	if is_sharp(lane):
		var i: int = lane - SHARP_BASE
		return SHARPS[i] if i < SHARPS.size() else KEY_NONE
	return LANES[lane] if lane >= 0 and lane < COUNT else KEY_NONE


static func label_for(lane: int) -> String:
	if lane == 9:
		return ";"
	return OS.get_keycode_string(key_for(lane))
