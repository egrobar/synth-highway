class_name KeyMap
extends RefCounted
## The QWERTY piano layout, carried over unchanged from the web build.
##
## Two rows of physical keys: the Z row starts at C3 and the Q row at C4, with
## sharps on the row above each. C4 to E4 can be played from either row.

const BASE_PITCH := 48
const UPPER_START := 60

const LOWER: Array[Key] = [
	KEY_Z, KEY_S, KEY_X, KEY_D, KEY_C, KEY_V, KEY_G, KEY_B, KEY_H, KEY_N, KEY_J, KEY_M,
	KEY_COMMA, KEY_L, KEY_PERIOD, KEY_SEMICOLON, KEY_SLASH,
]
const UPPER: Array[Key] = [
	KEY_Q, KEY_2, KEY_W, KEY_3, KEY_E, KEY_R, KEY_5, KEY_T, KEY_6, KEY_Y, KEY_7, KEY_U,
	KEY_I, KEY_9, KEY_O, KEY_0, KEY_P, KEY_BRACKETLEFT, KEY_EQUAL, KEY_BRACKETRIGHT,
]
const SYMBOLS: Dictionary = {
	KEY_COMMA: ",", KEY_PERIOD: ".", KEY_SEMICOLON: ";", KEY_SLASH: "/",
	KEY_BRACKETLEFT: "[", KEY_EQUAL: "=", KEY_BRACKETRIGHT: "]",
}


## The MIDI pitch a physical key plays, or -1 if it is not part of the piano.
static func pitch_for(code: Key) -> int:
	var upper_index: int = UPPER.find(code)
	if upper_index >= 0:
		return UPPER_START + upper_index
	var lower_index: int = LOWER.find(code)
	if lower_index >= 0:
		return BASE_PITCH + lower_index
	return -1


## The key caption for a pitch. Pitches on both rows show the Q row's key.
static func label_for(pitch: int) -> String:
	var code: Key = key_for(pitch)
	if code == KEY_NONE:
		return ""
	if SYMBOLS.has(code):
		return SYMBOLS[code]
	return OS.get_keycode_string(code)


## The physical key that plays a pitch, used by the bot and the captions.
static func key_for(pitch: int) -> Key:
	if pitch >= UPPER_START and pitch - UPPER_START < UPPER.size():
		return UPPER[pitch - UPPER_START]
	if pitch >= BASE_PITCH and pitch - BASE_PITCH < LOWER.size():
		return LOWER[pitch - BASE_PITCH]
	return KEY_NONE
