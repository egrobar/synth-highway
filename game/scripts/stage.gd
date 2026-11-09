class_name Stage
extends Node3D
## Owns the 3D scene: the region's world, the keyboard highway and the camera.
##
## The road is as wide as the ten-lane home-row keyboard, the same for every song, so a
## world is rebuilt only when the region changes. Region worlds are scripts at
## res://scripts/themes/<id>.gd extending ThemeWorld.

const CAMERA_POSITION := Vector3(0.0, 8.8, 13.6)  # high enough that the hood frames the bottom edge
const CAMERA_TARGET := Vector3(0.0, 1.0, -12.0)
## Menus and drives share one road width (the ten-lane keyboard), so the world is never rebuilt between them.
const MENU_HALF_WIDTH := 8.0 + 1.7

var highway: Highway
var world: ThemeWorld
var theme_id: String = ""
var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 56.0
	add_child(camera)
	camera.look_at_from_position(CAMERA_POSITION, CAMERA_TARGET)


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
