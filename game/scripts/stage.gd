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


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = BASE_FOV
	add_child(camera)
	camera.look_at_from_position(CAMERA_POSITION, CAMERA_TARGET)


func _process(delta: float) -> void:
	var heat: float = world.heat() if world else 0.0
	camera.fov = BASE_FOV + HEAT_FOV * heat
	_jolt = maxf(_jolt - delta * 5.0, 0.0)
	var offset := Vector3.ZERO
	if _jolt > 0.0:
		offset = Vector3(_jolt_rng.randf_range(-1.0, 1.0), _jolt_rng.randf_range(-1.0, 1.0), 0.0) * 0.07 * _jolt
	camera.look_at_from_position(CAMERA_POSITION + offset, CAMERA_TARGET)


## A short camera shake, 0 to 1. Used for a missed note.
func jolt(amount: float) -> void:
	if Settings.motion:
		_jolt = maxf(_jolt, amount)


## Shows a region with no keyboard, for menus.
func show_region(id: String) -> void:
	if highway:
		highway.queue_free()
		highway = null
	_ensure_world(id, MENU_HALF_WIDTH)


## Shows a region set up for one chart: keyboard sized to the song, road to match.
func show_chart(id: String, chart: Chart) -> Highway:
	if highway:
		highway.queue_free()
	highway = Highway.new()
	add_child(highway)
	highway.setup(chart)
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
