class_name Settings
extends RefCounted
## The player's options: what they are, their defaults, and how each is applied.
##
## Values live in SaveData.settings (save.json). apply() pushes them into the
## places that read them: the two audio buses, Highway's note speed and letters,
## the window mode, and the `motion` flag the world and camera check.
##
## Audio buses, made at startup by ensure_buses():
##   Music    the song stems and the region's ambience
##   Stems    the two song stems only, feeding Music; it carries the pitch
##            correction a slowed-down practice run needs (see set_practice_speed)
##   Effects  clicks, hits and other sound effects

const DEFAULTS := {"music": 0.8, "effects": 0.8, "note_speed": 1, "letters": true, "motion": true, "fullscreen": false}
## Name, and the seconds a note is in view before it lands.
const NOTE_SPEEDS: Array = [["Relaxed", 3.8], ["Normal", 3.0], ["Fast", 2.4], ["Faster", 1.9]]
const BUS_MUSIC := "Music"
const BUS_STEMS := "Stems"
const BUS_EFFECTS := "Effects"

## Beat flashes, the combo's rush of speed and the camera's movement. Off for anyone
## who finds a moving, pulsing screen hard to read notes on.
static var motion: bool = true


static func ensure_buses() -> void:
	for bus: String in [BUS_MUSIC, BUS_STEMS, BUS_EFFECTS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, BUS_MUSIC if bus == BUS_STEMS else "Master")
	if AudioServer.get_bus_effect_count(AudioServer.get_bus_index(BUS_STEMS)) == 0:
		var shift := AudioEffectPitchShift.new()
		AudioServer.add_bus_effect(AudioServer.get_bus_index(BUS_STEMS), shift)
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(BUS_STEMS), 0, false)


static func value(settings: Dictionary, key: String) -> Variant:
	return settings.get(key, DEFAULTS[key])


static func apply(settings: Dictionary) -> void:
	ensure_buses()
	_set_volume(BUS_MUSIC, float(value(settings, "music")))
	_set_volume(BUS_EFFECTS, float(value(settings, "effects")))
	var speed: int = clampi(int(value(settings, "note_speed")), 0, NOTE_SPEEDS.size() - 1)
	Highway.lookahead = float(NOTE_SPEEDS[speed][1])
	Highway.show_letters = bool(value(settings, "letters"))
	motion = bool(value(settings, "motion"))
	# Headless runs and embedded windows have no window mode to change.
	if DisplayServer.get_name() != "headless":
		var want: int = DisplayServer.WINDOW_MODE_FULLSCREEN if bool(value(settings, "fullscreen")) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and (want == DisplayServer.WINDOW_MODE_FULLSCREEN
				or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(want)


## A practice run plays the stems slower by lowering their pitch scale, which also
## drops the pitch; this shifts it back up by the same ratio so the song stays in key.
static func set_practice_speed(speed: float) -> void:
	ensure_buses()
	var bus: int = AudioServer.get_bus_index(BUS_STEMS)
	var slowed: bool = speed < 0.999
	AudioServer.set_bus_effect_enabled(bus, 0, slowed)
	if slowed:
		(AudioServer.get_bus_effect(bus, 0) as AudioEffectPitchShift).pitch_scale = 1.0 / speed


static func _set_volume(bus: String, level: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, level <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(level, 0.001, 1.0)))
