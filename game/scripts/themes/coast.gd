extends ThemeWorld
## Tidewater (pop, sea shanties; region id `coast`): the shore of an ocean moon at night. Ice and
## rock on the left, a sea wall with coral reflectors and cool light masts on the right, and past
## them a dark alien sea: ice floes heaving gently, icebergs, marker buoys, floating habitat
## platforms with warm windows (one moored to the shore by a catwalk) and beacon towers whose
## beams sweep the water. On the land side ice cliffs and terraced ice shelves, antenna masts
## with blinking tips, frosted markers along the shoulder, and cryo-geysers that erupt now and
## then. Ice crystals drift in the air, and the surf at the foot of the shelf glows faintly.
##
## A giant banded gas giant rises out of the sea PLANET_YAW degrees right of straight ahead
## (painted into sky.png by tools/themes/coast/textures.py). Its light is the scene's key light,
## and the sea shader reflects a disc of the same size and place, so its broken path of cream
## and coral light falls on open water, not on the road.
##
## High-detail pass (2026-11-10): the props are rebuilt in detail (tools/themes/coast/props.py): a W-beam
## guard rail on a concrete kerb, lattice light masts, a lighthouse with gallery, lamp room and stairs,
## habitats on braced legs with cranes, gangways and a helipad, ice in strata. Everything that stands in
## the sea is modelled from the WATERLINE up and lifted to SEA_LEVEL here (_afloat, the bank row, the floe
## groups), so a scaled landmark keeps its waterline and the prop shader's grime, measured up from the
## model's origin, is a band of wet grime and algae just above the water. `surfaces` sets the shader's
## relief and grain per material: the ice map at full strength crinkled big facets like foil.

const RAIL_LENGTH := 6.0  # must match RAIL_LENGTH in tools/themes/coast/props.py
const BANK_LENGTH := 12.0  # must match BANK_LENGTH in tools/themes/coast/props.py
const LAMP_SPACING := 30.0  # must match LAMP_SPACING in tools/themes/coast/props.py
const MARKER_SPACING := 15.0  # must match MARKER_SPACING in tools/themes/coast/props.py
const SEA_LEVEL := -5.0  # the waterline; must match SEA_LEVEL in tools/themes/coast/props.py
const BEAM_HEIGHT := 26.0  # the beacon's lens above the waterline; must match BEAM_HEIGHT in props.py
const VENT_HEIGHT := 2.4  # the geyser's throat; must match VENT_HEIGHT in props.py
const PLANET_YAW := 20.0  # degrees right of the road; must match tools/themes/coast/textures.py
const PLANET_ELEVATION := 1.5  # degrees, the disc's centre; must match textures.py
const PLANET_RADIUS := 7.5  # degrees; must match textures.py
const LAND_EDGE := 3.4  # the land ends this far past the road edge, under the sea wall
const BEAM_LENGTH := 90.0
const SURF_PERIOD := 9.0  # matches the main swell in tools/themes/coast/ambience.scd
const FLOE_TILE := 60.0
const BLINK_PERIOD := 2.4
const GEYSER_PERIOD := 11.0
const GEYSER_BURST := 2.6

# Unshaded water: the shader does its own sky reflection, planet path, surf and haze, so the
# far sea melts into the panorama's horizon colour instead of the fog's.
const OCEAN_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec3 deep : source_color = vec3(0.012, 0.035, 0.05);
uniform vec3 sky_low : source_color = vec3(0.10, 0.26, 0.30);
uniform vec3 sky_high : source_color = vec3(0.03, 0.07, 0.13);
uniform vec3 haze : source_color = vec3(0.10, 0.19, 0.22);
uniform vec3 glint : source_color = vec3(1.0, 0.88, 0.72);
uniform vec3 glint_warm : source_color = vec3(1.0, 0.52, 0.40);
uniform vec3 foam : source_color = vec3(0.22, 0.62, 0.55);
uniform vec3 planet_dir = vec3(0.34, 0.044, -0.94);
uniform float planet_radius = 0.13;
uniform float travel = 0.0;
uniform float shore_x = 27.0;
uniform float surf_period = 9.0;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Slope of a sum of travelling sines: long swell down to short chop.
vec2 slope(vec2 p, float t) {
	vec2 s = vec2(0.0);
	vec4 waves[6] = vec4[6](
		vec4(0.28, 0.96, 0.3, 0.2), vec4(-0.6, 0.8, 0.7, 0.07), vec4(0.9, 0.44, 1.6, 0.035),
		vec4(-0.2, -0.98, 3.1, 0.02), vec4(0.7, -0.7, 5.3, 0.011), vec4(-0.95, 0.3, 8.7, 0.0065));
	for (int i = 0; i < 6; i++) {
		vec2 d = normalize(waves[i].xy);
		float k = waves[i].z;
		float phase = dot(d, p) * k + t * (0.7 + float(i) * 0.6);
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
	vec3 rd = normalize(r);
	float fres = 0.02 + 0.98 * pow(1.0 - clamp(dot(-eye, n), 0.0, 1.0), 5.0);
	vec3 sky = mix(sky_low, sky_high, smoothstep(0.0, 0.3, rd.y));
	vec3 col = mix(deep, sky, clamp(fres, 0.0, 1.0) * 0.6);
	// The planet's disc in the reflected ray: the swell breaks it into a broad glittering path.
	// Its colour follows the band the ray lands on; the sea hides the disc below the horizon.
	float ang = acos(clamp(dot(rd, planet_dir), -1.0, 1.0));
	vec3 up_p = normalize(vec3(0.0, 1.0, 0.0) - planet_dir * planet_dir.y);
	float lat = dot(rd - planet_dir, up_p) / planet_radius;
	vec3 band = mix(glint, glint_warm, smoothstep(0.2, 0.9, sin(lat * 7.0 + 1.3)));
	float disc = (1.0 - smoothstep(planet_radius * 0.8, planet_radius * 1.05, ang)) * smoothstep(0.0, 0.012, rd.y);
	float sheen = exp(-ang * ang / (planet_radius * planet_radius * 5.0));
	col += band * sheen * 0.05;
	col += band * disc * (0.10 + 0.55 * fres);
	col += glint * pow(max(dot(rd, planet_dir), 0.0), 900.0) * 1.2;
	// Surf at the foot of the ice shelf: a faintly glowing lacy band, washing with the ambience.
	float wash = 0.5 + 0.5 * sin(TIME * 6.2831 / surf_period);
	float lace = 0.55 + 0.45 * sin(p.y * 0.9 + sl.x * 30.0) * sin(p.y * 0.37 - TIME * 0.7);
	float band_w = 1.0 - smoothstep(0.0, 1.5 + 3.0 * wash, world_pos.x - shore_x);
	col = mix(col, foam * (0.8 + 0.4 * wash), clamp(band_w * lace, 0.0, 1.0) * step(shore_x - 1.0, world_pos.x));
	float dist = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);
	col = mix(col, haze, 1.0 - exp(-dist * 0.0042));
	ALBEDO = col;
}
"""

# A beacon beam: an open cone added over the night, fading along its length and at its edges.
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.72, 0.95, 1.0);
uniform float strength = 0.13;
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
var _beam_pivots: Array[Node3D] = []
var _blinkers: Array[Dictionary] = []  # {"mat": StandardMaterial3D, "phase": float}
var _floe_groups: Array[Node3D] = []
var _bobbers: Array[Dictionary] = []  # {"node": Node3D, "phase": float, "heave": float, "roll": float}
var _geysers: Array[Dictionary] = []  # {"plume": CPUParticles3D, "offset": float}


func build() -> void:
	# Salt frost on top, dark algae and wet grime low down by the water: sea props are modelled from the
	# waterline, so grime_height is a band of algae above the water (and the foot of things on land).
	weathering = {"grime_color": Color(0.06, 0.13, 0.11), "grime": 0.45, "grime_height": 1.2,
		"dust_color": Color(0.82, 0.88, 0.92), "dust": 0.34, "grain": 0.25, "mottle": 0.14}
	# Surface maps per material name (props.py names them), each with its own shader settings: ice keeps
	# a soft relief and little grain (at full strength its map crinkled big facets like foil, and grain
	# made it glitter) and stays cleaner than the rest; hull plating, grating and rock push their relief
	# so seams, bars and strata read; glossy steel gets little grain. Coral paint is painted hull plating.
	surfaces = {
		"ice": ["ice", 0.15, {"detail_bump": 0.4, "detail_tone": 0.45, "grain": 0.08, "grime": 0.3}],
		"frost": ["ice", 0.15, {"detail_bump": 0.3, "detail_tone": 0.35, "grain": 0.06, "grime": 0.15}],
		"rock": ["rock", 0.2, {"detail_bump": 1.2, "detail_tone": 0.7}],
		"hull": ["panel", 0.33, {"detail_bump": 1.3, "detail_tone": 0.55}],
		"coral": ["panel", 0.33, {"detail_bump": 1.1, "detail_tone": 0.45}],
		"steel": ["brushed", 0.5, {"detail_bump": 0.6, "detail_tone": 0.35, "grain": 0.08}],
		"walkway": ["grate", 0.8, {"detail_bump": 1.4, "detail_tone": 0.8}],
		"concrete": ["concrete", 0.25, {"detail_bump": 1.0, "detail_tone": 0.65}],
	}
	make_environment({
		"sky": asset("textures/sky.png"),
		"ambient": Color(0.34, 0.46, 0.6), "ambient_energy": 0.3,
		# Sea mist off the ice.
		"haze": 0.005, "haze_color": Color(0.16, 0.26, 0.32), "haze_glow": 0.05,
		"fog": Color(0.025, 0.06, 0.078), "fog_density": 0.008,
		"glow": 0.9,
		# Planet-shine: warm cream from ahead and to the right, low over the sea, against the
		# cold blue ambient, so ice faces turned to the planet catch a warm edge.
		"light_color": Color(0.95, 0.86, 0.76), "light_energy": 0.5,
		"light_rotation": Vector3(-10.0, 180.0 - PLANET_YAW, 0.0),
	})
	var ground := make_ground(asset("textures/ground.png"), Color(0.88, 0.94, 1.0))
	# Land only on the left: the ground stops under the sea wall, and past it is the sea.
	ground.position.x = -400.0 + road_half + LAND_EDGE
	# Gentle relief: this asphalt tile is busy, and at full bump it crinkled under the notes.
	make_road(asset("textures/asphalt.png"), Color(0.86, 0.9, 0.96), Color(1.0, 0.56, 0.46), 0.35, {"bump": 0.6, "grain": 0.15})
	make_vehicle(asset("models/hood.glb"), Color(0.82, 0.94, 1.0), 24.0)
	_make_sea()

	# The sea side: the ice shelf's edge, the sea wall, light masts with cool pools of light.
	# The bank is modelled from the waterline up (props.py), so its row hangs from the sea, not the road.
	var bank := row(asset("models/bank.glb"), road_half + LAND_EDGE, BANK_LENGTH, 30)
	bank.position.y = SEA_LEVEL
	row(asset("models/barrier.glb"), road_half + 2.6, RAIL_LENGTH, 58)
	var masts := row(asset("models/lightmast.glb"), road_half + 1.5, LAMP_SPACING, 11)
	for post: Node in masts.get_children():
		var pool := OmniLight3D.new()
		pool.light_color = Color(0.72, 0.9, 1.0)
		pool.light_energy = 1.5
		pool.omni_range = 10.0
		pool.omni_attenuation = 1.3
		pool.position = Vector3(-1.2, 6.9, 0.0)
		post.add_child(pool)

	# The land side: frosted markers on the shoulder, ice shards and boulders, ice rising behind.
	row(asset("models/marker.glb"), -(road_half + 1.6), MARKER_SPACING, 22, 180.0)
	# Sparse on purpose: 300 a tile made a bright field of spikes that pulled the eye off the notes.
	_scatter_land(asset("models/shard.glb"), 120, 3.0, 40.0, 48.0, 0.6, 1.2, 2024)
	_scatter_land(asset("models/boulder.glb"), 40, 2.0, 34.0, 48.0, 0.7, 1.8, 77)

	# Ice floes out on the water, in three groups that heave out of step.
	_scatter_sea(asset("models/floe_a.glb"), 18, 20.0, 150.0, FLOE_TILE, 0.6, 1.5, 515)
	_scatter_sea(asset("models/floe_b.glb"), 8, 24.0, 160.0, FLOE_TILE, 0.7, 1.4, 616)
	drifters(Color(0.72, 0.9, 1.0), 30, 3.0, 14.0, Vector3(-1.2, -0.2, 2.5), 0.035, Vector3(0.0, -0.05, 0.0), 1.6)

	landmarks([
		["cliff_a", -1.0, 16.0, 20.0, 1.3], ["shelf", -1.0, 11.0, 95.0, 1.0],
		["cliff_c", -1.0, 14.0, 135.0, 1.4], ["cliff_b", -1.0, 18.0, 175.0, 1.5],
		["cliff_a", -1.0, 26.0, 245.0, 1.8], ["shelf", -1.0, 14.0, 320.0, 1.2], ["cliff_c", -1.0, 15.0, 385.0, 1.1],
		["cliff_b", -1.0, 13.0, 410.0, 1.0],
	])
	# Icebergs keep their waterline now at any scale, so the big one is scaled down to its old visible size.
	for entry: Array in [["iceberg_a", 34.0, 40.0, 1.0], ["iceberg_b", 30.0, 176.0, 0.9], ["platform", LAND_EDGE, 252.0, 1.0],
			["iceberg_a", 46.0, 310.0, 1.3], ["iceberg_b", 36.0, 402.0, 1.1]]:
		_afloat(entry[0], entry[1], entry[2], entry[3])
	_blink(_find_landmark("platform"), 0.9)
	for entry: Array in [["mast", 8.0, 60.0, 1.0, 0.0], ["mast", 10.0, 285.0, 0.9, 1.3]]:
		_blink(_landmark(entry[0], -1.0, entry[1], entry[2], entry[3]), entry[4])
	for entry: Array in [[48.0, 140.0, 1.0, 0.0], [150.0, 300.0, 1.3, 1.9]]:
		var tower := _afloat("beacon", entry[0], entry[1], entry[2])
		_make_beam(tower, entry[3])
		_blink(tower, 0.4)
	for entry: Array in [[70.0, 200.0, 1.0], [120.0, 360.0, 1.4]]:
		var habitat := _afloat("habitat", entry[0], entry[1], entry[2])
		_blink(habitat, entry[1] * 0.01)
		_bobbers.append({"node": habitat, "phase": entry[1], "heave": 0.12, "roll": deg_to_rad(0.5)})
	for entry: Array in [[30.0, 110.0], [55.0, 330.0]]:
		var buoy := _afloat("buoy", entry[0], entry[1], 1.0)
		_blink(buoy, entry[1] * 0.013)
		_bobbers.append({"node": buoy, "phase": entry[1] * 0.1, "heave": 0.22, "roll": deg_to_rad(1.6)})
	for entry: Array in [[12.0, 210.0, 1.1, 0.0], [22.0, 362.0, 0.8, 5.5]]:
		var vent := _landmark("geyser", -1.0, entry[0], entry[1], entry[2])
		_geysers.append({"plume": _make_plume(vent), "offset": entry[3]})


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	if _ocean:
		_ocean.set_shader_parameter("travel", distance())
	for i: int in _beam_pivots.size():
		_beam_pivots[i].rotation.y = _clock * 0.6 + float(i) * 2.3
	for blinker: Dictionary in _blinkers:
		var on: bool = fposmod(_clock + float(blinker["phase"]), BLINK_PERIOD) < 0.45
		(blinker["mat"] as StandardMaterial3D).emission_energy_multiplier = 9.0 if on else 0.4
	# Kept small on purpose: the floes and platforms ride the swell, they don't toss on it.
	for i: int in _floe_groups.size():
		_floe_groups[i].position.y = SEA_LEVEL + sin(_clock * 0.55 + float(i) * 2.1) * 0.06
	for bob: Dictionary in _bobbers:
		var node: Node3D = bob["node"]
		var phase: float = bob["phase"]
		node.position.y = SEA_LEVEL + sin(_clock * 0.5 + phase) * float(bob["heave"])
		node.rotation.z = sin(_clock * 0.37 + phase * 1.7) * float(bob["roll"])
	for geyser: Dictionary in _geysers:
		var plume: CPUParticles3D = geyser["plume"]
		var erupting: bool = fposmod(_clock + float(geyser["offset"]), GEYSER_PERIOD) < GEYSER_BURST
		if plume.emitting != erupting:
			plume.emitting = erupting


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
	# haze is the sea band just under the horizon, rgb(0.010,0.030,0.040), so the far water
	# melts into the sky texture; sky_low is the teal band just above it.
	_ocean.set_shader_parameter("deep", Color(0.02, 0.05, 0.07))
	_ocean.set_shader_parameter("sky_low", Color(0.17, 0.31, 0.35))
	_ocean.set_shader_parameter("sky_high", Color(0.07, 0.15, 0.22))
	_ocean.set_shader_parameter("haze", Color(0.10, 0.19, 0.221))
	var yaw: float = deg_to_rad(PLANET_YAW)
	var pitch: float = deg_to_rad(PLANET_ELEVATION)
	_ocean.set_shader_parameter("planet_dir", Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)))
	_ocean.set_shader_parameter("planet_radius", deg_to_rad(PLANET_RADIUS))
	# The bank prop meets the water about 11 units out from the land's edge.
	_ocean.set_shader_parameter("shore_x", road_half + LAND_EDGE + 10.6)
	_ocean.set_shader_parameter("surf_period", SURF_PERIOD)
	sea.material_override = _ocean
	sea.position = Vector3(road_half + LAND_EDGE - 0.5 + 700.0, SEA_LEVEL, -750.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


func _make_beam(tower: Node3D, phase: float) -> void:
	if tower == null:
		return
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, BEAM_HEIGHT, 0.0)
	pivot.rotation.y = phase
	tower.add_child(pivot)
	_beam_pivots.append(pivot)
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
		pivot.add_child(beam)


## A cryo-geyser's plume: soft pale puffs shot up from the vent, rising, spreading and fading.
## It moves with the vent (local coordinates), and _process switches it on for a burst now and then.
func _make_plume(vent: Node3D) -> CPUParticles3D:
	var dot := GradientTexture2D.new()
	dot.width = 64
	dot.height = 64
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	falloff.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	dot.gradient = falloff
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = dot
	var puff := QuadMesh.new()
	puff.size = Vector2(2.6, 2.6)
	puff.material = mat
	var grow := Curve.new()
	grow.max_value = 4.0
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 3.6))
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.8, 0.93, 1.0, 0.0))
	ramp.set_color(1, Color(0.8, 0.93, 1.0, 0.0))
	# Faint and many: fewer, more opaque puffs read as a stack of cotton balls.
	ramp.add_point(0.1, Color(0.82, 0.93, 1.0, 0.24))
	ramp.add_point(0.5, Color(0.72, 0.86, 0.95, 0.13))
	var plume := CPUParticles3D.new()
	plume.mesh = puff
	plume.amount = 120
	plume.lifetime = 3.6
	plume.local_coords = true
	plume.emitting = false
	plume.position = Vector3(0.0, VENT_HEIGHT, 0.0)
	plume.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	plume.emission_sphere_radius = 0.4
	plume.direction = Vector3.UP
	plume.spread = 14.0
	plume.initial_velocity_min = 5.5
	plume.initial_velocity_max = 10.5
	plume.gravity = Vector3(0.0, -3.0, 0.0)
	plume.damping_min = 1.0
	plume.damping_max = 2.0
	plume.scale_amount_min = 1.0
	plume.scale_amount_max = 1.8
	plume.scale_amount_curve = grow
	plume.color_ramp = ramp
	vent.add_child(plume)
	return plume


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
	_wrapped.append({"node": _stamp(model_path, base, tile, 300.0), "tile": tile})


## Floes scattered on the sea side, split into groups whose nodes _process heaves out of step.
## Scaled across only: a floe's geometry sits at SEA_LEVEL below its origin, so a vertical
## scale would lift it off the water.
func _scatter_sea(model_path: String, per_tile: int, x_from: float, x_to: float, tile: float,
		scale_from: float, scale_to: float, seed: int, groups: int = 3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bases: Array = []
	for g: int in groups:
		var list: Array[Transform3D] = []
		bases.append(list)
	for i: int in per_tile:
		var x: float = road_half + rng.randf_range(x_from, x_to)
		var size: float = rng.randf_range(scale_from, scale_to)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(size, 1.0, size))
		bases[i % groups].append(Transform3D(basis, Vector3(x, 0.0, -rng.randf_range(0.0, tile))))
	for g: int in groups:
		var node := _stamp(model_path, bases[g], tile, 420.0)
		_wrapped.append({"node": node, "tile": tile})
		_floe_groups.append(node)


## One tile of transforms stamped down the road as a single MultiMesh.
func _stamp(model_path: String, base: Array[Transform3D], tile: float, reach: float) -> MultiMeshInstance3D:
	var all: Array[Transform3D] = []
	for stamp: int in range(-1, int(ceil(reach / tile))):
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
	return instance


## A landmark in the sea: props.py models these from the waterline up, so the node sits at SEA_LEVEL.
func _afloat(model: String, from_edge: float, along: float, scale_by: float) -> Node3D:
	var node := _landmark(model, 1.0, from_edge, along, scale_by)
	node.position.y = SEA_LEVEL
	return node


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


## Swaps the glb's "blink" material on a node for a copy this script blinks, `phase` seconds
## out of step with the others so the shore's lights don't flash in unison.
func _blink(node: Node3D, phase: float) -> void:
	if node == null:
		return
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := found as MeshInstance3D
		for s: int in mesh_node.mesh.get_surface_count():
			var mat: Material = mesh_node.mesh.surface_get_material(s)
			if mat and mat.resource_name == "blink" and mat is StandardMaterial3D:
				var own := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				mesh_node.set_surface_override_material(s, own)
				_blinkers.append({"mat": own, "phase": phase})

