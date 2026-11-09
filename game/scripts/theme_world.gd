class_name ThemeWorld
extends Node3D
## Base for every region's scenery. A region subclass (scripts/themes/<id>.gd)
## overrides build() and assembles its world with the helpers below.
##
## Scenery is driven by one number, distance travelled, and never touches timing
## or scoring. Repeating things are grouped and wrapped by their tile length, so
## the road scrolls forever at a fixed, small cost. A region's assets live in
## res://assets/themes/<id>/ (models/, textures/, audio/ambience.wav).

const WORLD_SPEED := 15.33  # matches the note speed: Highway.LENGTH / Highway.LOOKAHEAD
const ROAD_TILE := 10.0

var id: String = ""
var road_half: float = 8.4

var _distance: float = 0.0
var _speed: float = 0.6
var _target_speed: float = 0.6
var _headlight_level: float = 1.0
var _headlight_energy: Array[float] = []
var _headlights: Array[Light3D] = []
var _wrapped: Array[Dictionary] = []
var _looped: Array[Dictionary] = []
var _scrolling_materials: Array[StandardMaterial3D] = []
var _flicker := RandomNumberGenerator.new()


func setup(theme_id: String, half_width: float) -> void:
	id = theme_id
	road_half = half_width
	_flicker.seed = 1987
	build()


## Override: build the region.
func build() -> void:
	pass


## Override for per-frame effects of your own; call super first.
func _process(delta: float) -> void:
	_speed = move_toward(_speed, _target_speed, delta * 0.9)
	_distance += delta * WORLD_SPEED * _speed
	for mat: StandardMaterial3D in _scrolling_materials:
		mat.uv1_offset.y = -_distance / ROAD_TILE
	for entry: Dictionary in _wrapped:
		(entry["node"] as Node3D).position.z = fposmod(_distance, float(entry["tile"]))
	for entry: Dictionary in _looped:
		(entry["node"] as Node3D).position.z = float(entry["near"]) - fposmod(float(entry["along"]) - _distance, float(entry["loop"]))
	var flicker: float = 1.0
	if _headlight_level < 0.3:
		flicker = 0.55 + 0.45 * _flicker.randf()
	for i: int in _headlights.size():
		_headlights[i].light_energy = _headlight_energy[i] * (0.3 + 0.7 * _headlight_level) * flicker


## 1.0 is cruising speed. Scenery only: the song never changes tempo.
func set_target_speed(value: float) -> void:
	_target_speed = value


## Low fuel dims the lights and makes them stutter, a warning you read without looking away.
func set_headlight_level(level: float) -> void:
	_headlight_level = clampf(level, 0.0, 1.0)


func distance() -> float:
	return _distance


# ---------------------------------------------------------------- helpers for regions

func asset(relative: String) -> String:
	return "res://assets/themes/%s/%s" % [id, relative]


func ambience_path() -> String:
	return asset("audio/ambience.wav")


## Sky panorama, ambient light, fog, glow and a key light. Keys (all optional):
## sky, sky_rotation, ambient, ambient_energy, fog, fog_density, glow, glow_threshold,
## light_color, light_energy, light_rotation (degrees), background (when there is no sky).
func make_environment(p: Dictionary) -> WorldEnvironment:
	var env := Environment.new()
	if p.has("sky"):
		var sky_material := PanoramaSkyMaterial.new()
		sky_material.panorama = load(p["sky"])
		var sky := Sky.new()
		sky.sky_material = sky_material
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		# A panorama's centre column faces +Z in Godot; turn it to face down the road.
		env.sky_rotation = Vector3(0.0, PI + deg_to_rad(float(p.get("sky_rotation", 0.0))), 0.0)
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = p.get("background", Color(0.02, 0.02, 0.05))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = p.get("ambient", Color(0.3, 0.38, 0.62))
	env.ambient_light_energy = p.get("ambient_energy", 0.35)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = p.get("glow", 0.85)
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = p.get("glow_threshold", 1.0)
	env.fog_enabled = true
	env.fog_light_color = p.get("fog", Color(0.05, 0.075, 0.17))
	env.fog_density = p.get("fog_density", 0.011)
	env.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.light_color = p.get("light_color", Color(0.68, 0.76, 1.0))
	light.light_energy = p.get("light_energy", 0.6)
	light.rotation_degrees = p.get("light_rotation", Vector3(-24, 18, 0))
	add_child(light)
	return world


## A tiling textured material, optionally scrolling with the road.
func surface(texture_path: String, tint: Color = Color.WHITE, roughness: float = 0.85, scroll: bool = true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(texture_path)
	mat.albedo_color = tint
	mat.roughness = roughness
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if scroll:
		_scrolling_materials.append(mat)
	return mat


func make_ground(texture_path: String, tint: Color = Color.WHITE, tiles_per_side: float = 80.0) -> MeshInstance3D:
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(800.0, 800.0)
	ground.mesh = mesh
	var mat := surface(texture_path, tint, 1.0)
	mat.uv1_scale = Vector3(tiles_per_side, tiles_per_side, 1.0)
	ground.material_override = mat
	ground.position = Vector3(0.0, -0.08, -300.0)
	add_child(ground)
	return ground


## The road the notes ride on, with two edge stripes. Pass an emission energy to make the stripes glow.
func make_road(texture_path: String, tint: Color = Color(0.9, 0.9, 0.95), edge: Color = Color(0.95, 0.92, 0.8), edge_glow: float = 0.0) -> MeshInstance3D:
	var road := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(road_half * 2.0, 400.0)
	road.mesh = mesh
	var mat := surface(texture_path, tint, 0.72)
	mat.uv1_scale = Vector3(road_half * 2.0 / ROAD_TILE, 400.0 / ROAD_TILE, 1.0)
	road.material_override = mat
	road.position = Vector3(0.0, -0.03, -180.0)
	add_child(road)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = edge
	paint.roughness = 0.6
	if edge_glow > 0.0:
		paint.emission_enabled = true
		paint.emission = edge
		paint.emission_energy_multiplier = edge_glow
	for side: float in [-1.0, 1.0]:
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.22, 0.01, 400.0)
		stripe.mesh = stripe_mesh
		stripe.material_override = paint
		stripe.position = Vector3(side * (road_half - 0.45), -0.02, -180.0)
		add_child(stripe)
	return road


## The player's vehicle (a hood model, origin at the keyboard's back edge) and its lights.
func make_vehicle(model_path: String, beam: Color = Color(1.0, 0.88, 0.66), energy: float = 26.0) -> Node3D:
	var hood: Node3D = (load(model_path) as PackedScene).instantiate()
	# Sits a little below the keys so its front edge never covers their captions.
	hood.position = Vector3(0.0, -0.2, 2.45)
	hood.scale.x = road_half / 8.4
	add_child(hood)
	for side: float in [-1.0, 1.0]:
		var light := SpotLight3D.new()
		light.light_color = beam
		light.spot_range = 90.0
		light.spot_angle = 40.0
		light.spot_attenuation = 0.9
		light.position = Vector3(side * road_half * 0.72, 2.2, 1.6)
		# Toed in slightly so the two beams overlap down the middle of the road.
		light.rotation_degrees = Vector3(-8.0, side * 7.0, 0.0)
		add_light(light, energy)
	# A low beam from the middle fills the dark wedge between the cones, right where notes arrive.
	var low_beam := SpotLight3D.new()
	low_beam.light_color = beam
	low_beam.spot_range = 40.0
	low_beam.spot_angle = 38.0
	low_beam.spot_attenuation = 1.2
	low_beam.position = Vector3(0.0, 3.2, 3.0)
	low_beam.rotation_degrees = Vector3(-17.0, 0.0, 0.0)
	add_light(low_beam, energy)
	return hood


## Registers a light that dims and flickers with the fuel gauge.
func add_light(light: Light3D, energy: float) -> void:
	light.light_energy = energy
	add_child(light)
	_headlights.append(light)
	_headlight_energy.append(energy)


## Instances of one model in a group that wraps every `tile` units: exactly
## seamless when the positions themselves repeat every `tile`.
func repeat(model_path: String, positions: Array[Vector3], tile: float, yaw_degrees: float = 0.0) -> Node3D:
	var group := Node3D.new()
	add_child(group)
	var scene: PackedScene = load(model_path)
	for p: Vector3 in positions:
		var node: Node3D = scene.instantiate()
		node.position = p
		node.rotation_degrees.y = yaw_degrees
		group.add_child(node)
	_wrapped.append({"node": group, "tile": tile})
	return group


## A row of a repeating model along one side of the road, `count` copies `spacing` apart.
func row(model_path: String, x: float, spacing: float, count: int, yaw_degrees: float = 0.0) -> Node3D:
	var positions: Array[Vector3] = []
	for i: int in count:
		positions.append(Vector3(x, 0.0, -float(i) * spacing + spacing * 2.0))
	return repeat(model_path, positions, spacing, yaw_degrees)


## Thousands of copies of a small model (grass, rocks, cacti, debris) scattered
## either side of the road, as one MultiMesh tile stamped down the road.
func scatter(model_path: String, per_tile: int, x_from: float, x_to: float, tile: float = 48.0,
		scale_from: float = 0.85, scale_to: float = 1.3, seed: int = 2024) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var base: Array[Transform3D] = []
	for i: int in per_tile:
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var x: float = side * (road_half + rng.randf_range(x_from, x_to))
		var size: float = rng.randf_range(scale_from, scale_to)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(size, size, size))
		base.append(Transform3D(basis, Vector3(x, 0.0, -rng.randf_range(0.0, tile))))
	var all: Array[Transform3D] = []
	for stamp: int in range(-1, int(ceil(300.0 / tile))):
		for t: Transform3D in base:
			all.append(t.translated(Vector3(0.0, 0.0, -float(stamp) * tile)))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = first_mesh(model_path)
	multi.instance_count = all.size()
	for i: int in all.size():
		multi.set_instance_transform(i, all[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	add_child(instance)
	_wrapped.append({"node": instance, "tile": tile})
	return instance


## Landmarks that come round on a long loop. Each entry:
## [model name in this region's models/, side (-1 left, 1 right), distance from the road edge,
##  position along the loop, scale]. Left-side props are turned to face the road.
func landmarks(layout: Array, loop: float = 420.0, near: float = 18.0) -> void:
	for entry: Array in layout:
		var node: Node3D = (load(asset("models/%s.glb" % entry[0])) as PackedScene).instantiate()
		var side: float = entry[1]
		node.position.x = side * (road_half + float(entry[2]))
		node.scale = Vector3.ONE * float(entry[4])
		node.rotation_degrees.y = 0.0 if side > 0.0 else 180.0
		add_child(node)
		_looped.append({"node": node, "along": float(entry[3]), "loop": loop, "near": near})


## Small glowing motes drifting past both sides: fireflies, embers, snow, spray.
func drifters(color: Color, amount: int, height: float, spread_x: float, velocity: Vector3, size: float = 0.05,
		gravity: Vector3 = Vector3.ZERO, glow_energy: float = 5.0) -> void:
	var bead := SphereMesh.new()
	bead.radius = size
	bead.height = size * 2.0
	bead.radial_segments = 6
	bead.rings = 3
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = glow_energy  # snow wants far less than fireflies
	bead.material = glow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.0))
	ramp.set_color(1, Color(color, 0.0))
	ramp.add_point(0.5, Color(color, 1.0))
	for side: float in [-1.0, 1.0]:
		var motes := CPUParticles3D.new()
		motes.mesh = bead
		motes.amount = amount
		motes.lifetime = 5.0
		motes.preprocess = 5.0
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		motes.emission_box_extents = Vector3(spread_x, height * 0.6, 30.0)
		motes.position = Vector3(side * (road_half + spread_x + 2.0), height, -24.0)
		motes.direction = velocity.normalized()
		motes.spread = 28.0
		motes.initial_velocity_min = velocity.length() * 0.6
		motes.initial_velocity_max = velocity.length()
		motes.gravity = gravity
		motes.color_ramp = ramp
		add_child(motes)


func first_mesh(model_path: String) -> Mesh:
	var scene: Node = (load(model_path) as PackedScene).instantiate()
	var found: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh
	scene.free()
	return mesh
