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
##
## The shore answers the player (2026-11-11, ThemeWorld's on_* events). On a combo milestone a line
## of cryo-geysers erupts one after another across the ice on the left and the beacon towers' beams
## flare and whirl; from the second milestone an ice cliff out in the sea ahead calves, a spire of
## ice toppling into the water with a burst of spray and a ring of foam; each milestone sets off more
## geysers. A long combo lights an aurora in the sky, curtains of green and violet over the sea (a
## milestone flares it). A fast streak spins the beams and pops a geyser. Faltering cracks the ice
## beside the road, a glowing fracture splitting outward with shards flying, and fog rolls in over
## the sea and the ice (thicker the worse it is); getting going again lifts the fog and the crack
## fades.

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
# The player's events.
const EVENT_VENTS := 6
var _beam_mats: Array[ShaderMaterial] = []
var _beam_spin: float = 0.0
var _beam_flare: float = 0.0
var _vent_field: Node3D
var _vents: Array[Dictionary] = []  # {"node", "plume", "glow", "at": float (clock time to erupt), "until": float}
var _calve: Dictionary = {}
var _aurora: ShaderMaterial
var _aurora_boost: float = 0.0
var _fog: float = 0.0
var _target_fog: float = 0.0
var _base_fog: float = 0.0
var _base_haze: float = 0.0
var _mist: Array[CPUParticles3D] = []
var _crack: MeshInstance3D
var _crack_mat: ShaderMaterial
var _crack_age: float = -1.0
var _shards: CPUParticles3D
var _fx := RandomNumberGenerator.new()


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
	event_tint = Color(0.75, 0.92, 1.0)
	_build_events()


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	if _ocean:
		_ocean.set_shader_parameter("travel", distance())
	# The beams sweep; a milestone or a streak flares them and whirls them round.
	_beam_flare = maxf(_beam_flare - delta * 0.3, 0.0)
	_beam_spin += delta * (0.6 + (1.2 if calm() else 3.4) * _beam_flare)
	for i: int in _beam_pivots.size():
		_beam_pivots[i].rotation.y = _beam_spin + float(i) * 2.3
	for mat: ShaderMaterial in _beam_mats:
		mat.set_shader_parameter("strength", 0.13 * (1.0 + 3.0 * _beam_flare))
	_update_events(delta)
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


# ---------------------------------------------------------------- answering the player

## Curtains of aurora: a long vertical ribbon far out over the sea and the ice, its rays drifting and
## its hem waving. Brightest at its lower edge, green turning violet above; the sky straight over the
## road's far end is left clear.
const AURORA_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float strength = 0.0;
void vertex() {
	float t = TIME * 0.12;
	VERTEX.z += sin(UV.x * 17.0 + t * 3.0) * 28.0 + sin(UV.x * 6.0 - t * 2.0) * 45.0;
	VERTEX.y += sin(UV.x * 11.0 + t * 1.7) * 9.0;
}
void fragment() {
	float x = UV.x;
	float h = 1.0 - UV.y;
	float rays = 0.45 + 0.55 * sin(x * 150.0 + TIME * 0.7 + sin(x * 33.0 + TIME * 0.25) * 3.0);
	float hem = smoothstep(0.0, 0.08, h) * (1.0 - smoothstep(0.25, 1.0, h));
	float drift = 0.55 + 0.45 * sin(x * 8.0 - TIME * 0.35);
	float clear = smoothstep(0.05, 0.17, abs(x - 0.5));
	vec3 col = mix(vec3(0.2, 1.0, 0.55), vec3(0.6, 0.3, 1.0), smoothstep(0.3, 0.85, h));
	ALBEDO = col * rays * hem * drift * clear * strength;
}
"""
## The ice crack: a glowing fracture that runs out along its length (reveal) and fades.
const CRACK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float reveal = 0.0;
uniform float glow = 0.0;
void fragment() {
	float edge = 1.0 - abs(UV.y - 0.5) * 2.0;
	ALBEDO = vec3(0.55, 0.9, 1.0) * glow * step(UV.x, reveal) * (0.4 + 0.6 * edge);
}
"""
## The foam ring a calving spire throws up: a ring spreading over the water and fading.
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float ring = 0.1;
uniform float fade = 0.0;
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float band = smoothstep(ring - 0.12, ring, r) * (1.0 - smoothstep(ring, ring + 0.05, r));
	ALBEDO = vec3(0.6, 0.85, 0.9) * band * fade;
}
"""


func on_milestone(level: int) -> void:
	_beam_flare = maxf(_beam_flare, 1.0)
	_aurora_boost = maxf(_aurora_boost, 0.5 + 0.1 * float(mini(level, 5)))
	_erupt_vents(mini(2 + level, EVENT_VENTS), 0.35)
	event_sound("geysers", -11.0)
	if level >= 2:
		_start_calving(level)
		event_sound("calve", -9.0)
	super(level)


func on_streak(strength: float) -> void:
	_beam_flare = maxf(_beam_flare, 0.5 + 0.5 * strength)
	_erupt_vents(1, 0.0)
	super(strength * 0.5)


func on_burst(strength: float, kind: String) -> void:
	_beam_flare = maxf(_beam_flare, 0.4 * strength)
	_erupt_vents(1, 0.0)
	super(strength, kind)


func on_falter(severity: float) -> void:
	_target_fog = maxf(_target_fog, severity)
	_crack_age = 0.0
	event_sound("crack", -11.0)
	# A new crack each time: another jag pattern, just ahead on the ice.
	_crack.mesh = _crack_mesh(_fx.randi())
	_crack.position = Vector3(-(road_half + 4.0), 0.06, -38.0)
	if not calm():
		_shards.restart()


func on_recover() -> void:
	_target_fog = 0.0
	super()


func on_settle() -> void:
	_target_fog = 0.0
	_fog = 0.0
	_beam_flare = 0.0
	_aurora_boost = 0.0
	_crack_age = -1.0
	_crack.visible = false
	for vent: Dictionary in _vents:
		vent["at"] = -1.0
		(vent["plume"] as CPUParticles3D).restart()
		(vent["plume"] as CPUParticles3D).emitting = false
	for bank: CPUParticles3D in _mist:
		bank.restart()
		bank.emitting = false
	(_calve["spray"] as CPUParticles3D).restart()
	(_calve["spray"] as CPUParticles3D).emitting = false
	_end_calving()


func _build_events() -> void:
	_fx.seed = 3303
	_base_fog = _world_env.fog_density
	_base_haze = _world_env.volumetric_fog_density
	# Event geysers: a line of vents across the ice on the left, carried down the road from where a
	# milestone puts them. Pale steam, kept clear of the fog so it reads against the night.
	_vent_field = Node3D.new()
	add_child(_vent_field)
	var grow := Curve.new()
	grow.max_value = 5.0
	grow.add_point(Vector2(0.0, 0.6))
	grow.add_point(Vector2(1.0, 4.2))
	for i: int in EVENT_VENTS:
		var node := Node3D.new()
		node.position = Vector3(-(road_half + 16.0 + 7.0 * float(i % 3)), 0.0, -32.0 * float(i))
		_vent_field.add_child(node)
		# Faint and many, as the shore's own geysers: fewer, denser puffs read as cotton balls.
		var plume := fx_particles(fx_material("smoke", 1.0, false), 170, 3.4, 3.6, fx_ramp([
			[0.0, Color(0.9, 0.97, 1.0, 0.0)], [0.08, Color(0.86, 0.95, 1.0, 0.3)], [0.5, Color(0.7, 0.85, 0.95, 0.16)],
			[1.0, Color(0.6, 0.78, 0.9, 0.0)]]))
		plume.local_coords = true  # rides with its vent
		plume.direction = Vector3.UP
		plume.spread = 9.0
		plume.initial_velocity_min = 14.0
		plume.initial_velocity_max = 24.0
		plume.gravity = Vector3(0.0, -5.0, 0.0)
		plume.damping_min = 1.5
		plume.damping_max = 2.5
		plume.scale_amount_curve = grow
		plume.position.y = 0.5
		node.add_child(plume)
		var glow := fx_sprite(Color(0.55, 0.85, 1.0, 0.0), 4.0, 1.6, false)
		glow.position.y = 1.0
		node.add_child(glow)
		_vents.append({"node": node, "plume": plume, "glow": glow, "at": -1.0, "until": 0.0})
	# The aurora, far out ahead.
	var curtain := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.orientation = PlaneMesh.FACE_Z
	plane.size = Vector2(1300.0, 135.0)
	plane.subdivide_width = 96
	plane.subdivide_depth = 2
	curtain.mesh = plane
	_aurora = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = AURORA_SHADER
	_aurora.shader = shader
	curtain.material_override = _aurora
	curtain.position = Vector3(0.0, 100.0, -720.0)
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	curtain.visible = false
	curtain.set_meta("no_weathering", true)
	add_child(curtain)
	_aurora.set_meta("node", curtain)
	# Fog banks rolling in low over the sea and the ice (never over the road), and the ice crack.
	for side: float in [-1.0, 1.0]:
		var bank := fx_particles(fx_material("smoke", 1.0), 80, 8.0, 21.0, fx_ramp([
			[0.0, Color(0.5, 0.6, 0.66, 0.0)], [0.25, Color(0.5, 0.6, 0.66, 0.45)], [0.75, Color(0.45, 0.55, 0.62, 0.4)],
			[1.0, Color(0.42, 0.52, 0.6, 0.0)]]))
		bank.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		bank.emission_box_extents = Vector3(11.0, 1.5, 70.0)
		bank.position = Vector3(side * (road_half + 17.0), 2.0 if side < 0.0 else SEA_LEVEL + 2.5, -95.0)
		bank.spread = 4.0
		add_child(bank)
		_mist.append(bank)
	_crack = MeshInstance3D.new()
	_crack_mat = ShaderMaterial.new()
	var crack_shader := Shader.new()
	crack_shader.code = CRACK_SHADER
	_crack_mat.shader = crack_shader
	_crack.material_override = _crack_mat
	_crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crack.visible = false
	_crack.set_meta("no_weathering", true)
	add_child(_crack)
	ride(_crack)
	_shards = fx_particles(fx_material("glow", 3.0), 70, 1.6, 0.3, fx_ramp([
		[0.0, Color(0.85, 0.97, 1.0, 1.0)], [1.0, Color(0.5, 0.8, 1.0, 0.0)]]))
	_shards.local_coords = true
	_shards.one_shot = true
	_shards.explosiveness = 0.7
	_shards.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_shards.emission_box_extents = Vector3(12.0, 0.2, 6.0)
	_shards.position = Vector3(-14.0, 0.2, -6.0)
	_shards.direction = Vector3.UP
	_shards.spread = 40.0
	_shards.initial_velocity_min = 3.0
	_shards.initial_velocity_max = 8.0
	_shards.gravity = Vector3(0.0, -12.0, 0.0)
	_crack.add_child(_shards)
	_build_calving()


## A jagged fracture about 30 long on the ice, running out from the road's edge, as a flat strip
## whose UV.x runs along it (so the shader can reveal it from the road outward).
func _crack_mesh(pattern: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	var points: Array[Vector3] = [Vector3.ZERO]
	var heading: float = rng.randf_range(-0.5, -0.2)  # out from the road and a little ahead
	for i: int in 12:
		heading += rng.randf_range(-0.5, 0.5)
		heading = clampf(heading, -1.1, 0.3)
		points.append(points[points.size() - 1] + Vector3(-cos(heading), 0.0, sin(heading)) * rng.randf_range(2.0, 3.2))
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i: int in points.size():
		var along: Vector3 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		# Wide where it starts by the road and tapering out: seen at a glancing angle, a thin line vanishes.
		var across := Vector3(-along.z, 0.0, along.x) * (0.75 * (1.0 - float(i) / float(points.size())) + 0.12)
		verts.append(points[i] + across)
		verts.append(points[i] - across)
		uvs.append(Vector2(float(i) / float(points.size() - 1), 0.0))
		uvs.append(Vector2(float(i) / float(points.size() - 1), 1.0))
	var indices := PackedInt32Array()
	for i: int in points.size() - 1:
		indices.append_array([i * 2, i * 2 + 1, i * 2 + 2, i * 2 + 1, i * 2 + 3, i * 2 + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Sets `count` of the event geysers off one after another, `gap` seconds apart, from a line placed
## ahead on the ice (it rides past from there).
func _erupt_vents(count: int, gap: float) -> void:
	var busy: bool = false
	for vent: Dictionary in _vents:
		if _clock < float(vent["until"]):
			busy = true
	if not busy:
		_vent_field.position.z = -70.0
		ride(_vent_field)
	var started: int = 0
	for i: int in _vents.size():
		var vent: Dictionary = _vents[i]
		if started >= count:
			break
		if _clock < float(vent["until"]):
			continue
		vent["at"] = _clock + gap * float(started)
		vent["until"] = float(vent["at"]) + 1.8
		started += 1


## Out in the sea ahead and to the right: a tabular berg with an ice spire beside it that topples
## into the water (from 0.8 s), sinks, and throws up spray and a ring of foam (from about 2 s).
func _build_calving() -> void:
	var root := Node3D.new()
	root.visible = false
	add_child(root)
	var berg: Node3D = (load(asset("models/iceberg_b.glb")) as PackedScene).instantiate()
	berg.scale = Vector3(1.5, 1.9, 1.5)
	berg.position.x = 9.0
	root.add_child(berg)
	var pivot := Node3D.new()
	pivot.position = Vector3(-4.0, 0.0, 0.0)
	root.add_child(pivot)
	var spire: Node3D = (load(asset("models/iceberg_a.glb")) as PackedScene).instantiate()
	spire.scale = Vector3.ONE * 1.05
	spire.position.x = 5.0
	pivot.add_child(spire)
	var spray := fx_particles(fx_material("smoke", 1.0, false), 200, 2.8, 5.0, fx_ramp([
		[0.0, Color(0.95, 1.0, 1.0, 0.0)], [0.06, Color(0.92, 0.98, 1.0, 0.38)], [1.0, Color(0.7, 0.85, 0.95, 0.0)]]))
	spray.local_coords = true
	spray.one_shot = true
	spray.explosiveness = 0.75
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spray.emission_box_extents = Vector3(9.0, 0.5, 5.0)
	spray.position = Vector3(-14.0, 0.5, 0.0)
	spray.direction = Vector3.UP
	spray.spread = 35.0
	spray.initial_velocity_min = 10.0
	spray.initial_velocity_max = 21.0
	spray.gravity = Vector3(0.0, -13.0, 0.0)
	var grow := Curve.new()
	grow.max_value = 4.0
	grow.add_point(Vector2(0.0, 0.7))
	grow.add_point(Vector2(1.0, 3.0))
	spray.scale_amount_curve = grow
	root.add_child(spray)
	var ring := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(70.0, 70.0)
	ring.mesh = plane
	var ring_mat := ShaderMaterial.new()
	var ring_shader := Shader.new()
	ring_shader.code = RING_SHADER
	ring_mat.shader = ring_shader
	ring.material_override = ring_mat
	ring.position = Vector3(-14.0, 0.15, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	# A cold light on the ice as it goes, so the falling spire reads against the dark bergs behind it.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.75, 0.92, 1.0)
	lamp.omni_range = 45.0
	lamp.light_energy = 0.0
	lamp.position = Vector3(-14.0, 14.0, 10.0)
	root.add_child(lamp)
	_calve = {"root": root, "pivot": pivot, "spray": spray, "ring": ring_mat, "lamp": lamp, "age": -1.0, "splashed": false}


## Puts the calving berg out in the sea ahead (built once, in build(), so the ice is weathered like
## the rest) and starts it; one at a time.
func _start_calving(_level: int) -> void:
	if float(_calve["age"]) >= 0.0:
		return
	var root: Node3D = _calve["root"]
	root.position = Vector3(road_half + 30.0, SEA_LEVEL, -125.0)
	root.visible = true
	var pivot: Node3D = _calve["pivot"]
	pivot.rotation = Vector3.ZERO
	pivot.position.y = 0.0
	ride(root)
	_calve["age"] = 0.0
	_calve["splashed"] = false


func _end_calving() -> void:
	var root: Node3D = _calve["root"]
	unride(root)
	root.visible = false
	(_calve["ring"] as ShaderMaterial).set_shader_parameter("fade", 0.0)
	_calve["age"] = -1.0


## The geysers, the calving, the aurora, the fog and the crack.
func _update_events(delta: float) -> void:
	var any_vent: bool = false
	for vent: Dictionary in _vents:
		var at: float = vent["at"]
		var on: bool = at >= 0.0 and _clock >= at and _clock < at + 1.6
		var plume: CPUParticles3D = vent["plume"]
		if plume.emitting != on:
			plume.emitting = on
		var glow: float = clampf(1.0 - absf(_clock - at - 0.6) / 1.2, 0.0, 1.0) if at >= 0.0 else 0.0
		((vent["glow"] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(
			"tint", Color(0.55, 0.85, 1.0, glow))
		any_vent = any_vent or _clock < float(vent["until"]) + 3.5
	if not any_vent:
		unride(_vent_field)
	if float(_calve["age"]) >= 0.0:
		_calve["age"] = float(_calve["age"]) + delta
		var a: float = _calve["age"]
		var pivot: Node3D = _calve["pivot"]
		# It leans, then falls faster and faster, and once down it sinks out of sight.
		var fall: float = clampf((a - 0.8) / 1.3, 0.0, 1.0)
		pivot.rotation.z = deg_to_rad(98.0) * fall * fall
		pivot.position.y = -16.0 * clampf((a - 2.2) / 3.0, 0.0, 1.0)
		if a >= 2.0 and not bool(_calve["splashed"]):
			_calve["splashed"] = true
			(_calve["spray"] as CPUParticles3D).restart()
			flash(Color(0.8, 0.95, 1.0), 0.35, 15.0)
		(_calve["lamp"] as OmniLight3D).light_energy = 4.0 * clampf(a / 0.6, 0.0, 1.0) * clampf((7.0 - a) / 3.0, 0.0, 1.0)
		var ring_mat: ShaderMaterial = _calve["ring"]
		var r: float = clampf((a - 2.0) / 3.5, 0.0, 1.0)
		ring_mat.set_shader_parameter("ring", 0.1 + 0.85 * r)
		ring_mat.set_shader_parameter("fade", (1.0 - r) * 2.0 if a >= 2.0 else 0.0)
		if (_calve["root"] as Node3D).position.z > 80.0 or a > 16.0:
			_end_calving()
	# The aurora comes up with a long combo (and a milestone flares it for a while).
	_aurora_boost = maxf(_aurora_boost - delta * 0.06, 0.0)
	var aurora: float = clampf(1.1 * flow() + _aurora_boost, 0.0, 1.4)
	(_aurora.get_meta("node") as Node3D).visible = aurora > 0.01
	_aurora.set_shader_parameter("strength", aurora)
	# Fog rolls in slowly and lifts slowly; the notes are kept readable (the depth fog only thickens
	# by half), and the banks of mist stay off the road.
	_fog = move_toward(_fog, _target_fog, delta * (0.25 if _target_fog > _fog else 0.2))
	_world_env.fog_density = _base_fog * (1.0 + 0.5 * _fog)
	if Settings.high_graphics:
		_world_env.volumetric_fog_density = _base_haze + 0.006 * _fog
	var along: float = (Highway.LENGTH / Highway.lookahead) * _speed * (1.0 + HEAT_SPEED * _heat)
	for bank: CPUParticles3D in _mist:
		bank.emitting = _fog > 0.15
		# Mist hangs in the air: it comes past with the ground.
		bank.direction = Vector3(0.0, 0.0, 1.0)
		bank.initial_velocity_min = along
		bank.initial_velocity_max = along
	if _crack_age >= 0.0:
		_crack_age += delta
		_crack.visible = true
		_crack_mat.set_shader_parameter("reveal", clampf(_crack_age / (1.6 if calm() else 0.5), 0.0, 1.0))
		var hold: float = 6.0 if faltering() else 2.0
		_crack_mat.set_shader_parameter("glow", 2.4 * clampf(1.0 - (_crack_age - hold) / 3.0, 0.0, 1.0))
		if _crack_age > hold + 3.0 or _crack.position.z > 30.0:
			_crack_age = -1.0
			_crack.visible = false


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
	_beam_mats.append(mat)
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

