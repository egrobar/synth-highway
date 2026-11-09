extends ThemeWorld
## Coast Road (pop, R&B, soul): a cliffside highway at night. Land and rock on the
## left, a stone guardrail and seaside lamps on the right, and beyond them the sea:
## a dark plane well below the road with a moon-glitter path drawn by its own shader,
## sea stacks, a pier, a bell buoy and a lighthouse whose beam sweeps the bay.
##
## The moon sits MOON_YAW degrees right of straight ahead (painted into sky.png by
## tools/themes/coast/textures.py) so its glitter falls on open water, not the road.

const RAIL_LENGTH := 6.0  # must match RAIL_LENGTH in tools/themes/coast/props.py
const BANK_LENGTH := 12.0  # must match BANK_LENGTH in tools/themes/coast/props.py
const LAMP_SPACING := 30.0  # must match LAMP_SPACING in tools/themes/coast/props.py
const SEA_LEVEL := -5.0  # must match SEA_LEVEL in tools/themes/coast/props.py
const MOON_YAW := 20.0  # degrees right of the road; must match tools/themes/coast/textures.py
const MOON_ELEVATION := 4.8  # degrees; must match tools/themes/coast/textures.py
const PALM_SPACING := 34.0
const LAND_EDGE := 3.4  # the land ends this far past the road edge, under the guardrail
const BEAM_HEIGHT := 18.8  # the lighthouse lamp room, in the lighthouse model
const BEAM_LENGTH := 90.0
const SURF_PERIOD := 6.6  # matches the main wave in tools/themes/coast/ambience.scd

# Unshaded water: the shader does its own sky reflection, moon glitter, surf and haze,
# so the far sea melts into the panorama's horizon colour instead of the fog's.
const OCEAN_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec3 deep : source_color = vec3(0.006, 0.016, 0.028);
uniform vec3 sky_low : source_color = vec3(0.075, 0.215, 0.25);
uniform vec3 sky_high : source_color = vec3(0.10, 0.055, 0.19);
uniform vec3 haze : source_color = vec3(0.04, 0.105, 0.125);
uniform vec3 glint : source_color = vec3(1.0, 0.95, 0.82);
uniform vec3 foam : source_color = vec3(0.42, 0.52, 0.55);
uniform vec3 moon_dir = vec3(0.34, 0.098, -0.935);
uniform float travel = 0.0;
uniform float shore_x = 27.0;
uniform float surf_period = 6.6;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Slope of a sum of travelling sines: long swell down to short chop.
vec2 slope(vec2 p, float t) {
	vec2 s = vec2(0.0);
	vec4 waves[6] = vec4[6](
		vec4(0.28, 0.96, 0.35, 0.18), vec4(-0.6, 0.8, 0.8, 0.07), vec4(0.9, 0.44, 1.7, 0.035),
		vec4(-0.2, -0.98, 3.1, 0.02), vec4(0.7, -0.7, 5.3, 0.011), vec4(-0.95, 0.3, 8.7, 0.0065));
	for (int i = 0; i < 6; i++) {
		vec2 d = normalize(waves[i].xy);
		float k = waves[i].z;
		float phase = dot(d, p) * k + t * (0.9 + float(i) * 0.75);
		s += d * (waves[i].w * k * cos(phase));
	}
	return s;
}

void fragment() {
	vec2 p = vec2(world_pos.x, world_pos.z - travel);
	vec2 sl = slope(p, TIME);
	vec3 n = normalize(vec3(-sl.x, 1.0, -sl.y));
	vec3 eye = normalize(world_pos - CAMERA_POSITION_WORLD);
	vec3 r = reflect(eye, n);
	r.y = abs(r.y);
	float fres = 0.02 + 0.98 * pow(1.0 - clamp(dot(-eye, n), 0.0, 1.0), 5.0);
	vec3 sky = mix(sky_low, sky_high, smoothstep(0.0, 0.3, r.y));
	vec3 col = mix(deep, sky, clamp(fres, 0.0, 1.0) * 0.6);
	float m = max(dot(normalize(r), moon_dir), 0.0);
	col += glint * pow(m, 40.0) * 0.18;
	col += glint * pow(m, 260.0) * 0.5;
	col += glint * smoothstep(0.9975, 0.9993, m) * 7.0;
	// Surf at the foot of the bank: a lacy band that washes in and out with the ambience.
	float wash = 0.5 + 0.5 * sin(TIME * 6.2831 / surf_period);
	float lace = 0.55 + 0.45 * sin(p.y * 0.9 + sl.x * 30.0) * sin(p.y * 0.37 - TIME * 0.7);
	float band = 1.0 - smoothstep(0.0, 1.5 + 3.0 * wash, world_pos.x - shore_x);
	col = mix(col, foam, clamp(band * lace, 0.0, 1.0) * step(shore_x - 1.0, world_pos.x));
	float dist = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);
	col = mix(col, haze, 1.0 - exp(-dist * 0.0042));
	ALBEDO = col;
}
"""

# The lighthouse beam: an open cone added over the night, fading along its length and at its edges.
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.9, 0.68);
uniform float strength = 0.14;
uniform float half_length = 45.0;
varying float along;

void vertex() {
	along = clamp((half_length - VERTEX.y) / (2.0 * half_length), 0.0, 1.0);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	// max(): at the open far rim 1.0 - along can dip below zero, and pow() of a negative
	// is NaN, which drew a ring of dead pixels where the beam pointed away from the camera.
	ALBEDO = tint * strength * pow(max(1.0 - along, 0.0), 1.4) * smoothstep(0.05, 0.7, facing);
}
"""

var _clock: float = 0.0
var _ocean: ShaderMaterial
var _beam_pivot: Node3D
var _blinkers: Array[StandardMaterial3D] = []


func build() -> void:
	make_environment({
		"sky": asset("textures/sky.png"),
		"ambient": Color(0.30, 0.38, 0.56), "ambient_energy": 0.32,
		"fog": Color(0.03, 0.065, 0.085), "fog_density": 0.0085,
		"glow": 0.9,
		# Moonlight from ahead and to the right, low over the sea.
		"light_color": Color(0.74, 0.82, 0.95), "light_energy": 0.55,
		"light_rotation": Vector3(-12.0, 180.0 - MOON_YAW, 0.0),
	})
	var ground := make_ground(asset("textures/ground.png"))
	# Land only on the left: the ground stops under the guardrail, and past it is the sea.
	ground.position.x = -400.0 + road_half + LAND_EDGE
	make_road(asset("textures/asphalt.png"), Color(0.88, 0.9, 0.95), Color(0.95, 0.9, 0.78))
	make_vehicle(asset("models/hood.glb"), Color(1.0, 0.9, 0.72), 26.0)
	_make_sea()

	# The sea side: rocky bank, stone rail, lamps with warm pools of light.
	row(asset("models/bank.glb"), road_half + LAND_EDGE, BANK_LENGTH, 30)
	row(asset("models/guardrail.glb"), road_half + 2.6, RAIL_LENGTH, 58)
	var lamps := row(asset("models/lamp.glb"), road_half + 1.5, LAMP_SPACING, 11)
	for post: Node in lamps.get_children():
		var pool := OmniLight3D.new()
		pool.light_color = Color(1.0, 0.78, 0.5)
		pool.light_energy = 1.6
		pool.omni_range = 10.0
		pool.omni_attenuation = 1.3
		pool.position = Vector3(-1.1, 5.6, 0.0)
		post.add_child(pool)

	# The land side: palms along the shoulder, scrub and boulders, rock rising behind.
	var palms: Array[Vector3] = []
	var tall: Array[Vector3] = []
	for i: int in 7:
		palms.append(Vector3(-(road_half + 3.0), 0.0, -float(i) * PALM_SPACING * 2.0 + PALM_SPACING * 4.0))
		tall.append(Vector3(-(road_half + 5.5), 0.0, -float(i) * PALM_SPACING * 2.0 + PALM_SPACING * 3.0))
	repeat(asset("models/palm.glb"), palms, PALM_SPACING * 2.0, 180.0)
	repeat(asset("models/palm_tall.glb"), tall, PALM_SPACING * 2.0, 180.0)
	_scatter_land(asset("models/scrub.glb"), 420, 0.8, 36.0, 48.0, 0.8, 1.4, 2024)
	_scatter_land(asset("models/boulder.glb"), 46, 1.5, 30.0, 48.0, 0.7, 1.8, 77)

	landmarks([
		["cliff_a", -1.0, 16.0, 20.0, 1.3], ["sea_stack", 1.0, 34.0, 40.0, 1.2], ["diner", -1.0, 7.0, 70.0, 1.0],
		["cliff_c", -1.0, 24.0, 96.0, 1.4], ["buoy", 1.0, 30.0, 110.0, 1.0], ["cliff_b", -1.0, 14.0, 150.0, 1.5],
		["sea_stack", 1.0, 22.0, 176.0, 0.9], ["shack", -1.0, 9.0, 200.0, 1.0], ["cliff_a", -1.0, 26.0, 226.0, 1.8],
		["pier", 1.0, LAND_EDGE, 252.0, 1.0], ["cliff_c", -1.0, 15.0, 286.0, 1.1], ["sea_stack", 1.0, 46.0, 310.0, 1.6],
		["cliff_b", -1.0, 20.0, 340.0, 1.2], ["cliff_a", -1.0, 13.0, 380.0, 1.0], ["sea_stack", 1.0, 28.0, 402.0, 1.1],
	])
	var lighthouse := _landmark("lighthouse", 1.0, 48.0, 140.0, 1.0)
	_make_beam(lighthouse)
	_blink(_landmark("buoy", 1.0, 55.0, 330.0, 1.0), "red_light")
	_blink(_find_landmark("pier"), "red_light")
	var diner := _find_landmark("diner")
	if diner:
		var neon := OmniLight3D.new()
		neon.light_color = Color(1.0, 0.45, 0.36)
		neon.light_energy = 2.2
		neon.omni_range = 14.0
		neon.position = Vector3(-6.0, 6.0, 0.0)
		diner.add_child(neon)


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	if _ocean:
		_ocean.set_shader_parameter("travel", distance())
	if _beam_pivot:
		_beam_pivot.rotation.y = _clock * 0.7
	var on: bool = fposmod(_clock, 2.4) < 0.45
	for mat: StandardMaterial3D in _blinkers:
		mat.emission_energy_multiplier = 9.0 if on else 0.4


func _make_sea() -> void:
	var sea := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1400.0, 1700.0)
	sea.mesh = mesh
	_ocean = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = OCEAN_SHADER
	_ocean.shader = shader
	# sRGB versions of the panorama's linear GEGL colours (tools/themes/coast/textures.py):
	# haze is the sea just under the horizon, so the far water melts into the sky texture.
	_ocean.set_shader_parameter("deep", Color(0.05, 0.10, 0.14))
	_ocean.set_shader_parameter("sky_low", Color(0.22, 0.40, 0.44))
	_ocean.set_shader_parameter("sky_high", Color(0.27, 0.19, 0.39))
	_ocean.set_shader_parameter("haze", Color(0.112, 0.196, 0.235))
	var yaw: float = deg_to_rad(MOON_YAW)
	var pitch: float = deg_to_rad(MOON_ELEVATION)
	_ocean.set_shader_parameter("moon_dir", Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)))
	# The bank prop meets the water about 11 units out from the land's edge.
	_ocean.set_shader_parameter("shore_x", road_half + LAND_EDGE + 10.6)
	_ocean.set_shader_parameter("surf_period", SURF_PERIOD)
	sea.material_override = _ocean
	sea.position = Vector3(road_half + LAND_EDGE - 0.5 + 700.0, SEA_LEVEL, -750.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


func _make_beam(lighthouse: Node3D) -> void:
	if lighthouse == null:
		return
	_beam_pivot = Node3D.new()
	_beam_pivot.position = Vector3(0.0, BEAM_HEIGHT, 0.0)
	lighthouse.add_child(_beam_pivot)
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = BEAM_SHADER
	mat.shader = shader
	mat.set_shader_parameter("half_length", BEAM_LENGTH * 0.5)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.4  # +Y end, at the lamp
	cone.bottom_radius = 7.0
	cone.height = BEAM_LENGTH
	cone.radial_segments = 16
	cone.cap_top = false
	cone.cap_bottom = false
	cone.material = mat
	for side: float in [1.0, -1.0]:
		var beam := MeshInstance3D.new()
		beam.mesh = cone
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Lay the cone on its side, narrow end at the lamp, pointing out along +X (or -X).
		beam.rotation_degrees = Vector3(0.0, 0.0, 90.0 if side > 0.0 else -90.0)
		beam.position = Vector3(side * BEAM_LENGTH * 0.5, 0.0, 0.0)
		_beam_pivot.add_child(beam)


## One-sided scatter (the helper scatters both sides, but the right side here is sea).
func _scatter_land(model_path: String, per_tile: int, x_from: float, x_to: float, tile: float,
		scale_from: float, scale_to: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var base: Array[Transform3D] = []
	for i: int in per_tile:
		var x: float = -(road_half + rng.randf_range(x_from, x_to))
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


## Places one landmark through the shared helper and hands back its node.
func _landmark(model: String, side: float, from_edge: float, along: float, scale_by: float) -> Node3D:
	landmarks([[model, side, from_edge, along, scale_by]])
	return _looped[_looped.size() - 1]["node"]


## The first landmark node built from `model`, matched by the glb's root name.
func _find_landmark(model: String) -> Node3D:
	for entry: Dictionary in _looped:
		var node: Node3D = entry["node"]
		if node.name.begins_with(model) or node.find_child(model + "*", true, false):
			return node
	return null


## Swaps the named glb material for a copy this script can blink.
func _blink(node: Node3D, material_name: String) -> void:
	if node == null:
		return
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := found as MeshInstance3D
		for s: int in mesh_node.mesh.get_surface_count():
			var mat: Material = mesh_node.mesh.surface_get_material(s)
			if mat and mat.resource_name == material_name and mat is StandardMaterial3D:
				var own := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				mesh_node.set_surface_override_material(s, own)
				_blinkers.append(own)
