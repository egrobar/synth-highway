class_name Stage
extends Node3D
## Owns the 3D scene: the region's world, the keyboard highway and the camera.
##
## The road is as wide as the ten-lane home-row keyboard, the same for every song, so a
## world is rebuilt only when the region changes. Region worlds are scripts at
## res://scripts/themes/<id>.gd extending ThemeWorld.
##
## The camera leans into a good run: the view opens a little as the combo's heat
## rises, and a miss gives it a short jolt. Both are small on purpose, because the
## player is reading notes through this camera.
##
## On the Compatibility renderer (the web build) the first world of a session is built two
## frames after the menus first show, and that frame is drawn with the 3D view off: the
## engine's start-up, the world's build (~350 ms in a browser) and the first compile of the
## sky, glow and tone-mapping shaders (~0.5 s on a cold browser cache) then each get a frame
## of their own, where together they froze the start for 1-5 s (WASD Engine web check,
## 2026-11-19). The world's own shaders compile a few a frame after that (ShaderWarmup).

const CAMERA_POSITION := Vector3(0.0, 8.8, 13.6)  # high enough that the hood frames the bottom edge
const CAMERA_TARGET := Vector3(0.0, 1.0, -12.0)
## Menus and drives share one road width (the ten-lane keyboard), so the world is never rebuilt between them.
const MENU_HALF_WIDTH := 8.0 + 1.7
const BASE_FOV := 56.0
const HEAT_FOV := 1.5

var highway: Highway
var world: ThemeWorld
var theme_id: String = ""
var camera: Camera3D
var _jolt: float = 0.0
var _jolt_rng := RandomNumberGenerator.new()
## Web renderer: the first region, [id, half width], waiting to be built, and the frames left to wait.
var _first_region: Array = []
var _first_region_wait: int = 2
## Web renderer: the 3D view is off for the frame the first world was built in.
var _view_off: bool = false
## Battle items (ItemEffects): an Earthquake shakes and bumps the camera, a Wobble sways and rolls it,
## each for its seconds left. Gentler with Settings.motion off (they are still attacks, just smaller).
var _quake_left: float = 0.0
var _quake_time: float = 0.0
var _wobble_left: float = 0.0
var _wobble_time: float = 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = BASE_FOV
	add_child(camera)
	camera.look_at_from_position(CAMERA_POSITION, CAMERA_TARGET)
	if ThemeWorld.compatibility_renderer():
		# What shows behind the menus until the first world is built: night, not the default grey.
		RenderingServer.set_default_clear_color(Color(0.02, 0.02, 0.05))


func _process(delta: float) -> void:
	if _view_off:
		_view_off = false
		camera.make_current()
	if not _first_region.is_empty():
		# Not on the first frame: a browser runs Godot's first frame in the same task as its start-up,
		# so only from the second on does a frame reach the screen before the next one starts.
		_first_region_wait -= 1
		if _first_region_wait <= 0:
			var region: Array = _first_region
			_first_region = []
			_ensure_world(region[0], region[1])
			camera.current = false
			_view_off = true
	var heat: float = world.heat() if world else 0.0
	camera.fov = BASE_FOV + HEAT_FOV * heat
	_jolt = maxf(_jolt - delta * 5.0, 0.0)
	var offset := Vector3.ZERO
	if _jolt > 0.0:
		offset = Vector3(_jolt_rng.randf_range(-1.0, 1.0), _jolt_rng.randf_range(-1.0, 1.0), 0.0) * 0.07 * _jolt
	var roll: float = 0.0
	var size: float = 1.0 if Settings.motion else 0.35
	if _quake_left > 0.0:
		_quake_left -= delta
		_quake_time += delta
		var fade: float = clampf(_quake_left / 0.5, 0.0, 1.0) * size
		offset += Vector3(_jolt_rng.randf_range(-1.0, 1.0) * 0.16, absf(sin(_quake_time * 10.5)) * 0.5
			+ _jolt_rng.randf_range(-1.0, 1.0) * 0.06, 0.0) * fade
		roll += sin(_quake_time * 21.0) * 0.03 * fade
	if _wobble_left > 0.0:
		_wobble_left -= delta
		_wobble_time += delta
		var sway: float = clampf(_wobble_left / 0.5, 0.0, 1.0) * clampf(_wobble_time / 0.5, 0.0, 1.0) * size
		offset.x += sin(_wobble_time * 1.4) * 1.7 * sway
		roll += sin(_wobble_time * 1.9) * deg_to_rad(9.0) * sway
	camera.look_at_from_position(CAMERA_POSITION + offset, CAMERA_TARGET + Vector3(offset.x * 0.5, 0.0, 0.0))
	if roll != 0.0:
		camera.rotate_object_local(Vector3(0.0, 0.0, 1.0), roll)


## An Earthquake on this road (a battle item) for `seconds`.
func quake(seconds: float) -> void:
	_quake_left = maxf(_quake_left, seconds)
	_quake_time = 0.0


## A Wobble on this road (a battle item) for `seconds`.
func wobble(seconds: float) -> void:
	_wobble_left = maxf(_wobble_left, seconds)
	_wobble_time = 0.0


## Ends both at once (the run ended).
func calm() -> void:
	_quake_left = 0.0
	_wobble_left = 0.0


## A short camera shake, 0 to 1. Used for a missed note.
func jolt(amount: float) -> void:
	if Settings.motion:
		_jolt = maxf(_jolt, amount)


## Shows a region with no keyboard, for menus.
func show_region(id: String) -> void:
	if highway:
		highway.queue_free()
		highway = null
	# Web renderer, nothing built yet: build it shortly (see the header). Nothing reads `world`
	# outside a drive, and show_chart() builds at once.
	if world == null and ThemeWorld.compatibility_renderer():
		_first_region = [id, MENU_HALF_WIDTH]
		return
	_ensure_world(id, MENU_HALF_WIDTH)


## Shows a region set up for one chart: keyboard sized to the song, road to match.
func show_chart(id: String, chart: Chart) -> Highway:
	_first_region = []
	if highway:
		highway.queue_free()
	highway = Highway.new()
	add_child(highway)
	highway.setup(chart)
	if ThemeWorld.compatibility_renderer():
		# The keys show at once; the notes' and hit effects' materials compile over the next frames,
		# before the first notes arrive, instead of mid-song (ShaderWarmup.prewarm()).
		var warm := ShaderWarmup.new()
		# Ahead of a world warming up at the same time (one warm-up works a frame): notes come first.
		warm.process_priority = -1
		add_child(warm)
		warm.prewarm(highway)
	_ensure_world(id, highway.half_width() + 1.7)
	return highway


## Rebuilds the region in view, after the graphics setting changes.
func rebuild_world() -> void:
	if world == null:
		return
	var current: String = theme_id
	var half: float = world.road_half
	theme_id = ""
	_ensure_world(current, half)


func _ensure_world(id: String, half_width: float) -> void:
	if world and theme_id == id and is_equal_approx(world.road_half, half_width):
		return
	var speed: float = 0.6
	if world:
		world.queue_free()
	theme_id = id
	var script: Script = load("res://scripts/themes/%s.gd" % id)
	world = script.new()
	add_child(world)
	world.setup(id, half_width)
	world.set_target_speed(speed)


static func region_ids() -> Array[String]:
	var ids: Array[String] = []
	for file: String in DirAccess.get_files_at("res://data/themes"):
		if file.ends_with(".json"):
			ids.append(file.get_basename())
	return ids


static func region_info(id: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/themes/%s.json" % id))
	return parsed if parsed is Dictionary else {"id": id, "name": id.capitalize(), "order": 99}
