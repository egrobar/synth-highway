class_name ThemeWorld
extends Node3D
## Base for every region's scenery. A region subclass (scripts/themes/<id>.gd)
## overrides build() and assembles its world with the helpers below.
##
## Scenery is driven by one number, distance travelled, and never touches timing
## or scoring. It also answers the music and the player: beat() makes the glow, the
## road's edge lines and the headlights flare on each beat, and set_heat() (the
## combo, 0 to 1) speeds the road up and brightens the whole scene. A region gets
## both for free; override on_beat() to add its own. Repeating things are grouped and wrapped by their tile length, so
## the road scrolls forever at a fixed, small cost. A region's assets live in
## res://assets/themes/<id>/ (models/, textures/, audio/ambience.wav).
##
## The world also reacts to how the player is doing (Evan's playtest, 2026-11-11: "environmental
## responses"). PlaySession reads the run and calls milestone() (combo 25, 50, 100, then every 100),
## streak() (a run of quick hits), burst() (a long hold carried home, a power chord struck whole),
## falter() (a big combo broken, misses in a row, the tank running low), recover() (going again after
## faltering) and set_flow() (a long combo held past full heat). Each lands in an on_* override; the
## defaults throw a swell of light over the scene (flash()), and each region adds its own spectacle,
## placed ahead or to the sides, never over the note lanes or the keys. With Settings.motion off
## (calm()) a region plays calm versions: things still happen, but nothing flashes, strobes or shakes.
## The fx_* helpers below build those effects cheaply: billboard particles, beams and sprites with
## their own small shaders, no shadows, kept out of the weathering pass; ride() carries a placed
## effect down the road with the scenery.

## How much faster the scenery runs at full heat. Scenery only: the notes never speed up.
const HEAT_SPEED := 0.3
const ROAD_TILE := 10.0
const SURFACE_SHADER := preload("res://shaders/surface.gdshader")
const PROP_SHADER := preload("res://shaders/prop_detail.gdshader")
## The shared surface maps (tools/gimp/surfaces.py, in res://assets/surfaces/) and which one a prop
## material gets: the first keyword that starts a word of its material name ("_" separated, so
## "hull_dark" and "steel_frame" match, "brushed" does not match "shed") wins. A region adds its own
## keywords, or overrides these, in `surfaces`.
const SURFACE_KEYWORDS: Array = [
	["grate", "grate"], ["mesh", "grate"], ["walkway", "grate"],
	["corrug", "corrugated"], ["shed", "corrugated"], ["container", "corrugated"],
	["concrete", "concrete"], ["plinth", "concrete"], ["footing", "concrete"], ["slab", "concrete"],
	["rock", "rock"], ["stone", "rock"], ["crag", "rock"], ["cliff", "rock"], ["basalt", "rock"],
	["boulder", "rock"], ["regolith", "rock"],
	["ice", "ice"], ["frost", "ice"], ["snow", "ice"],
	["membrane", "membrane"], ["fabric", "membrane"], ["canvas", "membrane"], ["skin", "membrane"],
	["brushed", "brushed"], ["chrome", "brushed"], ["steel", "brushed"], ["pipe", "brushed"],
	["hull", "panel"], ["panel", "panel"], ["plate", "panel"], ["metal", "panel"], ["body", "panel"],
]
## Map tiles per metre: one tile of `panel` is four plates across, so 0.33 gives 75 cm plates.
const SURFACE_SCALE := {"panel": 0.33, "concrete": 0.25, "rock": 0.2, "brushed": 0.5, "grate": 0.8,
	"corrugated": 0.5, "ice": 0.15, "membrane": 0.6}

var id: String = ""
var road_half: float = 8.4
## How the props weather (prop_detail.gdshader): set in build() to the region's dirt and dust.
## Keys: grime_color, grime, grime_height, dust_color, dust, grain, mottle. Missing keys keep the
## shader's defaults.
var weathering: Dictionary = {}
## A region's own material-name keywords for surface maps, checked before SURFACE_KEYWORDS:
## keyword -> map name ("panel"), or [map name, tiles per metre], or "" for no map, or
## [map name or "", tiles per metre, {shader parameter: value}] to also tune that material alone
## (say less grain on glossy metal and glass, which glitter at the region-wide value).
var surfaces: Dictionary = {}

var _distance: float = 0.0
var _speed: float = 0.6
var _target_speed: float = 0.6
var _headlight_level: float = 1.0
var _headlight_energy: Array[float] = []
var _headlights: Array[Light3D] = []
var _wrapped: Array[Dictionary] = []
var _looped: Array[Dictionary] = []
var _scrolling_materials: Array[StandardMaterial3D] = []
var _scrolling_shaders: Array[ShaderMaterial] = []
var _flicker := RandomNumberGenerator.new()
var _key_light: DirectionalLight3D
var _world_env: Environment
var _glow_base: float = 0.85
var _edge_paint: StandardMaterial3D
var _edge_base: float = 0.0
var _beat: float = 0.0
var _heat: float = 0.0
var _target_heat: float = 0.0

## The colour of the default swell of light the player's events throw over the scene (set in build()).
var event_tint: Color = Color(1.0, 0.86, 0.62)
var _swell: float = 0.0
var _swell_peak: float = 0.0
var _swell_decay: float = 1.5
var _event_light: DirectionalLight3D
var _flow: float = 0.0
var _target_flow: float = 0.0
var _faltering: bool = false
var _riders: Array[Node3D] = []
var _event_players: Array[AudioStreamPlayer] = []
var _event_sounds: Dictionary = {}


func setup(theme_id: String, half_width: float) -> void:
	id = theme_id
	road_half = half_width
	_flicker.seed = 1987
	build()
	_weather_props()
	# The default events' light: off (and skipped by the renderer) until something happens. No shadows.
	_event_light = DirectionalLight3D.new()
	_event_light.light_energy = 0.0
	_event_light.visible = false
	add_child(_event_light)


## Override: build the region.
func build() -> void:
	pass


## Override for per-frame effects of your own; call super first.
func _process(delta: float) -> void:
	_speed = move_toward(_speed, _target_speed, delta * 0.9)
	# Heat builds over a few seconds and falls away faster, so a broken combo is felt at once.
	_heat = move_toward(_heat, _target_heat, delta * (0.35 if _target_heat > _heat else 1.6))
	_beat = maxf(_beat - delta * 3.6, 0.0)
	_update_swell(delta)
	# Flow builds slowly (it is a reward for holding on) and drains a little faster.
	_flow = move_toward(_flow, _target_flow, delta * (0.12 if _target_flow > _flow else 0.4))
	# The scenery keeps pace with the notes at whatever note speed the player chose.
	var travelled: float = delta * (Highway.LENGTH / Highway.lookahead) * _speed * (1.0 + HEAT_SPEED * _heat)
	_distance += travelled
	for i: int in range(_riders.size() - 1, -1, -1):
		if is_instance_valid(_riders[i]):
			_riders[i].position.z += travelled
		else:
			_riders.remove_at(i)
	if _world_env:
		_world_env.glow_intensity = _glow_base * (1.0 + 0.2 * _beat + 0.3 * _heat + 0.35 * _swell + 0.12 * _flow)
	if _edge_paint:
		_edge_paint.emission_energy_multiplier = (_edge_base * (1.0 + 0.9 * _beat) + (0.5 * _beat + 0.5 * _heat)
			+ 0.8 * _swell)
	for mat: StandardMaterial3D in _scrolling_materials:
		mat.uv1_offset.y = -_distance / ROAD_TILE
	for mat: ShaderMaterial in _scrolling_shaders:
		mat.set_shader_parameter("scroll", -_distance / ROAD_TILE)
	for entry: Dictionary in _wrapped:
		(entry["node"] as Node3D).position.z = fposmod(_distance, float(entry["tile"]))
	for entry: Dictionary in _looped:
		(entry["node"] as Node3D).position.z = float(entry["near"]) - fposmod(float(entry["along"]) - _distance, float(entry["loop"]))
	var flicker: float = 1.0
	if _headlight_level < 0.3:
		flicker = 0.55 + 0.45 * _flicker.randf()
	for i: int in _headlights.size():
		_headlights[i].light_energy = _headlight_energy[i] * (0.3 + 0.7 * _headlight_level) * flicker * (1.0 + 0.1 * _beat)


## 1.0 is cruising speed. Scenery only: the song never changes tempo.
func set_target_speed(value: float) -> void:
	_target_speed = value


## Low fuel dims the lights and makes them stutter, a warning you read without looking away.
func set_headlight_level(level: float) -> void:
	_headlight_level = clampf(level, 0.0, 1.0)


## A beat of the song landed (1.0 for a bar line, less for the beats between).
func beat(strength: float) -> void:
	if not Settings.motion:
		return
	_beat = maxf(_beat, strength)
	on_beat(strength)


## Override for a region's own answer to the beat.
func on_beat(_strength: float) -> void:
	pass


## How well the drive is going, 0 to 1, from the player's combo.
func set_heat(level: float) -> void:
	_target_heat = clampf(level, 0.0, 1.0) if Settings.motion else 0.0


func heat() -> float:
	return _heat


func distance() -> float:
	return _distance


# ---------------------------------------------------------------- answering the player

## A combo milestone: level 1 at 25, 2 at 50, 3 at 100, 4 at 200, one more for every 100 after.
## Each level is bigger than the last.
func milestone(level: int) -> void:
	on_milestone(maxi(level, 1))


## A run of quick hits, 0 to 1: longer runs are stronger.
func streak(strength: float) -> void:
	on_streak(clampf(strength, 0.0, 1.0))


## A punctuation of the run, 0 to 1: a long hold carried to its end (kind "hold") or a power chord
## struck whole (kind "power").
func burst(strength: float, kind: String = "") -> void:
	on_burst(clampf(strength, 0.0, 1.0), kind)


## The player is faltering, 0 to 1: a big combo broken, misses in a row, the tank running low.
## Things go wrong in the world until recover().
func falter(severity: float) -> void:
	_faltering = true
	on_falter(clampf(severity, 0.0, 1.0))


## The player got going again after faltering: the world rights itself (or replaces what broke),
## so a long run never looks wrecked for good.
func recover() -> void:
	if not _faltering:
		return
	_faltering = false
	on_recover()


## A long combo held past full heat, 0 to 1. Builds slowly; read it with flow().
func set_flow(level: float) -> void:
	_target_flow = clampf(level, 0.0, 1.0)


func flow() -> float:
	return _flow


func faltering() -> bool:
	return _faltering


## Motion is off: play calm versions (no flashes, strobes or shakes; slow swells are fine).
func calm() -> bool:
	return not Settings.motion


## A run starts (or ends): every event effect back to rest at once.
func settle() -> void:
	_faltering = false
	_target_flow = 0.0
	_flow = 0.0
	_swell = 0.0
	_swell_peak = 0.0
	on_settle()


## Overrides: a region's own answers. The defaults swell the light; call super() to keep it.
func on_milestone(level: int) -> void:
	flash(event_tint, 0.5 + 0.18 * float(mini(level, 6)))


func on_streak(strength: float) -> void:
	flash(event_tint, 0.3 * strength)


func on_burst(strength: float, _kind: String) -> void:
	flash(event_tint, 0.28 * strength)


func on_falter(_severity: float) -> void:
	pass


func on_recover() -> void:
	flash(event_tint, 0.22)


## Put every event effect back to rest at once (a new run, or leaving one).
func on_settle() -> void:
	pass


## A swell of light over the scene from `yaw` degrees (0 straight ahead, positive to the right),
## with extra bloom and brighter edge lines. Sharp with motion on; with it off, a slow, soft swell.
func flash(colour: Color, amount: float, yaw: float = 0.0) -> void:
	if _event_light == null:
		return
	if calm():
		amount *= 0.35
	if amount >= maxf(_swell, _swell_peak):
		_event_light.light_color = colour
		_event_light.rotation_degrees = Vector3(-24.0, 180.0 - yaw, 0.0)
	_swell_peak = maxf(_swell_peak, amount)


func _update_swell(delta: float) -> void:
	if _swell_peak > _swell:
		# Rises at once (a flash), or over a second or two when calm.
		_swell = move_toward(_swell, _swell_peak, delta * (0.6 if calm() else 30.0))
		if _swell >= _swell_peak:
			_swell_peak = 0.0
	else:
		_swell_peak = 0.0
		_swell = move_toward(_swell, 0.0, delta * (0.3 if calm() else 1.3))
	if _event_light:
		_event_light.light_energy = _swell * 0.6
		_event_light.visible = _swell > 0.004


## Plays this region's audio/event_<name>.wav if it has one, on the effects bus, under the music.
func event_sound(sound: String, volume_db: float = -8.0) -> void:
	# Headless runs (the bot tests) have no audio device; a sound left playing as they quit leaks.
	if AudioServer.get_driver_name() == "Dummy":
		return
	var path: String = asset("audio/event_%s.wav" % sound)
	if not _event_sounds.has(path):
		_event_sounds[path] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _event_sounds[path]
	if stream == null:
		return
	if _event_players.is_empty():
		for i: int in 2:
			var player := AudioStreamPlayer.new()
			player.bus = Settings.BUS_EFFECTS
			add_child(player)
			_event_players.append(player)
	# Two voices, so a falter does not cut a launch short.
	var voice: AudioStreamPlayer = _event_players[0] if not _event_players[0].playing else _event_players[1]
	voice.stream = stream
	voice.volume_db = volume_db
	voice.play()


## From now on `node` moves with the ground, as the road's own scenery does: an effect placed ahead
## is carried past the player. Returns the node.
func ride(node: Node3D) -> Node3D:
	if not _riders.has(node):
		_riders.append(node)
	return node


func unride(node: Node3D) -> void:
	_riders.erase(node)


# ---------------------------------------------------------------- effect helpers

const FX_BILLBOARD := """
	mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]),
		normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
"""
## Light that adds to the scene (sparks, lava, fireworks, engine flames): HDR, so it blooms.
const FX_GLOW := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled%s;
uniform sampler2D dot_tex : source_color, filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 3.0;
void vertex() {%s}
void fragment() {
	float a = texture(dot_tex, UV).a;
	ALBEDO = COLOR.rgb * tint.rgb * energy * a * COLOR.a * tint.a;
}
"""
## Soft see-through puffs (ash, steam, mist, exhaust smoke): their colour is their light.
const FX_SMOKE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled%s;
uniform sampler2D dot_tex : source_color, filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
void vertex() {%s}
void fragment() {
	ALBEDO = COLOR.rgb * tint.rgb;
	ALPHA = COLOR.a * tint.a * texture(dot_tex, UV).a;
}
"""
## A shaft of light: an open cone added over the scene, fading along its length and at its edges.
const FX_BEAM := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(1.0);
uniform float strength = 0.15;
uniform float half_length = 50.0;
varying float along;
void vertex() {
	along = clamp((VERTEX.y + half_length) / (2.0 * half_length), 0.0, 1.0);
}
void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = tint * strength * pow(max(1.0 - along, 0.0), 1.3) * smoothstep(0.05, 0.7, facing);
}
"""

static var _fx_shaders: Dictionary = {}
static var _fx_dot: GradientTexture2D


## A material for effects. kind "glow" adds light, "smoke" is soft see-through puffs; both take their
## colour from the particles' colour ramp (times `tint`, and `energy` for glow). billboard: each quad
## turns to face the camera. fogged false keeps a far-off effect clear of the distance fog, as the
## sky is (a volcano's fountain 400 m away would otherwise vanish into it).
func fx_material(kind: String, energy: float = 3.0, fogged: bool = true, billboard: bool = true,
		tint: Color = Color.WHITE) -> ShaderMaterial:
	var key: String = "%s-%s-%s" % [kind, fogged, billboard]
	if not _fx_shaders.has(key):
		var shader := Shader.new()
		var code: String = FX_GLOW if kind == "glow" else FX_SMOKE
		shader.code = code % ["" if fogged else ", fog_disabled", FX_BILLBOARD if billboard else ""]
		_fx_shaders[key] = shader
	var mat := ShaderMaterial.new()
	mat.shader = _fx_shaders[key]
	mat.set_shader_parameter("dot_tex", fx_dot())
	mat.set_shader_parameter("tint", tint)
	if kind == "glow":
		mat.set_shader_parameter("energy", energy)
	return mat


## A soft round dot, white with its alpha falling off to the edge: every particle's shape.
static func fx_dot() -> GradientTexture2D:
	if _fx_dot == null:
		_fx_dot = GradientTexture2D.new()
		_fx_dot.width = 64
		_fx_dot.height = 64
		_fx_dot.fill = GradientTexture2D.FILL_RADIAL
		_fx_dot.fill_from = Vector2(0.5, 0.5)
		_fx_dot.fill_to = Vector2(1.0, 0.5)
		var falloff := Gradient.new()
		falloff.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		falloff.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		falloff.add_point(0.35, Color(1.0, 1.0, 1.0, 0.55))
		_fx_dot.gradient = falloff
	return _fx_dot


## A colour ramp from [[offset 0-1, Color], ...] (alpha included: fade in and out with it).
static func fx_ramp(stops: Array) -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array(stops.map(func(s: Array) -> float: return float(s[0])))
	ramp.colors = PackedColorArray(stops.map(func(s: Array) -> Color: return s[1] as Color))
	return ramp


## An effect emitter, off until fired (emitting = true; restart() for a one-shot burst): `amount`
## camera-facing dots `size` metres across, coloured by `ramp` over their life. Particles live in
## world space by default, so a moving emitter leaves a trail. Never drawn into shadows.
func fx_particles(material: Material, amount: int, lifetime: float, size: float, ramp: Gradient) -> CPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material
	var p := CPUParticles3D.new()
	p.mesh = quad
	p.amount = amount
	p.lifetime = lifetime
	p.emitting = false
	p.local_coords = false
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.set_meta("no_weathering", true)
	return p


## A shaft of light `length` long from a lamp at the returned pivot, pointing up its +Y (turn the
## pivot to aim it). Its strength is the "strength" parameter of the mesh's material.
func fx_beam(length: float, near_radius: float, far_radius: float, colour: Color, strength: float) -> Node3D:
	var pivot := Node3D.new()
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FX_BEAM
	mat.shader = shader
	mat.set_shader_parameter("tint", colour)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("half_length", length * 0.5)
	var cone := CylinderMesh.new()
	cone.bottom_radius = near_radius
	cone.top_radius = far_radius
	cone.height = length
	cone.radial_segments = 14
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	cone.material = mat
	var beam := MeshInstance3D.new()
	beam.mesh = cone
	beam.position.y = length * 0.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(beam)
	pivot.set_meta("no_weathering", true)
	pivot.set_meta("beam_material", mat)
	return pivot


## A glowing, camera-facing sprite (a glint, a beacon flare, an engine's glow), `size` metres across.
func fx_sprite(colour: Color, size: float, energy: float, fogged: bool = true) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var sprite := MeshInstance3D.new()
	sprite.mesh = quad
	sprite.material_override = fx_material("glow", energy, fogged, true, colour)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.set_meta("no_weathering", true)
	return sprite


## Every StandardMaterial3D under `root` (default: the whole world) whose name starts with one of
## `prefixes`, once each (imported materials are shared by every copy of a model), with its emission
## as built: [{"mat": StandardMaterial3D, "base": float}]. Turn them up and down with set_emission().
func emissive_materials(prefixes: Array, root: Node = null) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen: Dictionary = {}
	for node: Node in (root if root else self).find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s: int in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as StandardMaterial3D
			if mat == null or seen.has(mat.get_instance_id()):
				continue
			for prefix: String in prefixes:
				if mat.resource_name.begins_with(prefix):
					seen[mat.get_instance_id()] = true
					found.append({"mat": mat, "base": mat.emission_energy_multiplier})
					break
	return found


func set_emission(entries: Array[Dictionary], level: float) -> void:
	for entry: Dictionary in entries:
		(entry["mat"] as StandardMaterial3D).emission_energy_multiplier = float(entry["base"]) * level


## Where a point of the world would sit on screen, roughly: true when it is ahead of the camera, past
## the near scenery and within `half_angle` degrees of straight ahead (the Stage's camera looks down
## the road from z = 13.6).
static func ahead_in_view(at: Vector3, near_z: float = -25.0, far_z: float = -260.0, half_angle: float = 38.0) -> bool:
	if at.z > near_z or at.z < far_z:
		return false
	return absf(rad_to_deg(atan2(at.x, 13.6 - at.z))) < half_angle


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
	_world_env = env
	_glow_base = env.glow_intensity
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
	_key_light = light
	if Settings.high_graphics:
		_heavy_rendering(env, light, p)
	return world


## The high-detail stack (Settings.high_graphics): shadows from the key light, ambient occlusion,
## bounce light, reflections on glossy and wet surfaces, and a thin volumetric haze that the
## headlights cut beams through. Each is tuned to stay out of the way of the notes: the haze is
## thin over the road, and the notes are unshaded, so none of this can darken them.
## Optional keys in make_environment()'s dictionary: haze (volumetric density), haze_color,
## haze_glow (how much of its own colour the haze gives off), ao (ambient occlusion strength).
func _heavy_rendering(env: Environment, light: DirectionalLight3D, p: Dictionary) -> void:
	# Two splits to 110 m: four splits and headlight shadows quintupled the draw calls (200 to
	# 1,065) for shadows nobody reads at speed. Timing rides on the frame rate, so it stays lean.
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_max_distance = 110.0
	light.directional_shadow_blend_splits = true
	light.shadow_blur = 1.6
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 1.2
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = float(p.get("ao", 2.2))
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.ssil_enabled = true
	env.ssil_radius = 5.0
	env.ssil_intensity = 0.7
	env.ssr_enabled = true
	env.ssr_max_steps = 72
	env.ssr_fade_in = 0.12
	env.ssr_fade_out = 2.2
	env.ssr_depth_tolerance = 0.35
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = float(p.get("haze", 0.006))
	var haze: Color = p.get("haze_color", env.fog_light_color)
	env.volumetric_fog_albedo = haze.lightened(0.4)
	env.volumetric_fog_emission = haze
	# Kept low: haze that gives off much light of its own washes the whole frame out (Neon Sprawl
	# went milky purple at 0.3); the beams and lit haze come from the lights scattering in it.
	env.volumetric_fog_emission_energy = float(p.get("haze_glow", 0.06))
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_detail_spread = 2.2
	env.volumetric_fog_ambient_inject = 0.35
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	# Wider, softer bloom: a tight core from the middle levels and a broad halo from the upper ones.
	# Blend mode and intensity stay as each region tuned them.
	var levels: Array[float] = [0.0, 0.6, 1.0, 0.8, 0.6]
	for level: int in levels.size():
		env.set_glow_level(level + 1, levels[level])


## A tiling textured material, optionally scrolling with the road. Plain and cheap: for things
## that are not the road or the ground (a region's own decks, walls and quays).
func surface(texture_path: String, tint: Color = Color.WHITE, roughness: float = 0.85, scroll: bool = true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(texture_path)
	mat.albedo_color = tint
	mat.roughness = roughness
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if scroll:
		_scrolling_materials.append(mat)
	return mat


## The physically based surface for the road and the ground (shaders/surface.gdshader): relief
## from the painted tile, fine grain, slow colour variation and, with `wetness`, damp patches and
## puddles. Keys of `look` (all optional): roughness, specular, metallic, roughness_texture,
## bump, grain, grain_frequency, macro, wetness, puddle_frequency, puddle_tint, anti_tile.
func pbr_surface(texture_path: String, tint: Color, uv_scale: Vector2, look: Dictionary = {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE_SHADER
	mat.set_shader_parameter("albedo_tex", load(texture_path))
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("uv_scale", uv_scale)
	mat.set_shader_parameter("tile_metres", ROAD_TILE)
	mat.set_shader_parameter("roughness", float(look.get("roughness", 0.8)))
	mat.set_shader_parameter("specular", float(look.get("specular", 0.5)))
	mat.set_shader_parameter("metallic", float(look.get("metallic", 0.0)))
	mat.set_shader_parameter("bump_strength", float(look.get("bump", 1.6)))
	mat.set_shader_parameter("grain_strength", float(look.get("grain", 0.35)))
	mat.set_shader_parameter("grain_frequency", float(look.get("grain_frequency", 9.0)))
	mat.set_shader_parameter("macro_strength", float(look.get("macro", 0.16)))
	mat.set_shader_parameter("wetness", float(look.get("wetness", 0.0)))
	mat.set_shader_parameter("puddle_frequency", float(look.get("puddle_frequency", 0.11)))
	mat.set_shader_parameter("puddle_tint", look.get("puddle_tint", Color(0.55, 0.55, 0.6)))
	mat.set_shader_parameter("anti_tile", bool(look.get("anti_tile", false)))
	if look.has("roughness_texture"):
		mat.set_shader_parameter("roughness_tex", load(str(look["roughness_texture"])))
		mat.set_shader_parameter("use_roughness_tex", true)
	_scrolling_shaders.append(mat)
	return mat


## The ground either side of the road. `look` as for pbr_surface(); the tile is broken up by
## default (anti_tile), as the ground is seen across hundreds of metres.
func make_ground(texture_path: String, tint: Color = Color.WHITE, tiles_per_side: float = 80.0, look: Dictionary = {}) -> MeshInstance3D:
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(800.0, 800.0)
	ground.mesh = mesh
	var settings: Dictionary = {"roughness": 1.0, "anti_tile": true, "bump": 2.0, "grain": 0.45, "macro": 0.22}
	settings.merge(look, true)
	ground.material_override = pbr_surface(texture_path, tint, Vector2(tiles_per_side, tiles_per_side), settings)
	ground.position = Vector3(0.0, -0.08, -300.0)
	add_child(ground)
	return ground


## The road the notes ride on, with two edge stripes. Pass an emission energy to make the stripes
## glow, and `look` (as for pbr_surface()) for the surface: a region's road roughness, wetness...
func make_road(texture_path: String, tint: Color = Color(0.9, 0.9, 0.95), edge: Color = Color(0.95, 0.92, 0.8),
		edge_glow: float = 0.0, look: Dictionary = {}) -> MeshInstance3D:
	var road := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(road_half * 2.0, 400.0)
	road.mesh = mesh
	var settings: Dictionary = {"roughness": 0.72}
	settings.merge(look, true)
	road.material_override = pbr_surface(texture_path, tint, Vector2(road_half * 2.0 / ROAD_TILE, 400.0 / ROAD_TILE), settings)
	road.position = Vector3(0.0, -0.03, -180.0)
	add_child(road)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = edge
	paint.roughness = 0.6
	# Always emissive, even at zero, so every region's edge lines can flare with the beat.
	paint.emission_enabled = true
	paint.emission = edge
	paint.emission_energy_multiplier = edge_glow
	_edge_paint = paint
	_edge_base = edge_glow
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
	# Kept clean: it is always in view, right under the keys, where weathering grain is just noise.
	hood.set_meta("no_weathering", true)
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
	# The beams show in the volumetric haze (high graphics only; with it off there is no haze).
	light.light_volumetric_fog_energy = 0.35 if light is SpotLight3D else 0.0
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


# ---------------------------------------------------------------- weathering

## Swaps every plain prop material (opaque, lit, not glowing) for the weathered detail shader
## (shaders/prop_detail.gdshader), keeping its colour, roughness, metalness and texture. Runs after
## build(), so a region's own material work (glass, beacons, blinking windows) is done; those are
## emissive, see-through or unshaded and are left alone. Each source material becomes one shared
## weathered material, so copies of a prop still batch as before. Only the world is touched: the
## highway (keys and notes) is the Stage's, not the world's.
func _weather_props() -> void:
	if not Settings.high_graphics:
		return
	var converted: Dictionary = {}
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		if _unweathered(node):
			continue
		if node is MeshInstance3D:
			var instance := node as MeshInstance3D
			if instance.mesh == null or instance.material_override != null:
				continue
			for s: int in instance.mesh.get_surface_count():
				if instance.get_surface_override_material(s) != null:
					continue
				var weathered := _weathered(instance.mesh.surface_get_material(s), converted)
				if weathered:
					instance.set_surface_override_material(s, weathered)
		elif node is MultiMeshInstance3D:
			var multi := node as MultiMeshInstance3D
			if multi.multimesh == null or multi.multimesh.mesh == null or multi.material_override != null:
				continue
			# A MultiMesh has no per-surface override, so it gets its own copy of the mesh.
			var mesh: Mesh = multi.multimesh.mesh
			var copy: Mesh = null
			for s: int in mesh.get_surface_count():
				var weathered := _weathered(mesh.surface_get_material(s), converted)
				if weathered:
					if copy == null:
						copy = mesh.duplicate()
					copy.surface_set_material(s, weathered)
			if copy:
				multi.multimesh.mesh = copy


func _unweathered(node: Node) -> bool:
	while node != null and node != self:
		if node.has_meta("no_weathering"):
			return true
		node = node.get_parent()
	return false


func _weathered(source: Material, converted: Dictionary) -> ShaderMaterial:
	var mat := source as StandardMaterial3D
	if mat == null:
		return null
	var key: int = mat.get_instance_id()
	if converted.has(key):
		return converted[key]
	var glowing: bool = mat.emission_enabled and mat.emission_energy_multiplier > 0.0 and mat.emission.get_luminance() > 0.0
	# A material a region set up specially keeps its own look: Ring Road turns fog off on its distant
	# station, and weathered (fogged) it faded to a dashed outline of windows.
	var special: bool = (mat.disable_fog or mat.disable_receive_shadows or mat.no_depth_test
			or mat.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED)
	var plain: bool = (mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
			and mat.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and not glowing and not special)
	var out: ShaderMaterial = null
	if plain:
		out = ShaderMaterial.new()
		# Double-sided glTF materials (panels, signs, fins) must stay visible from behind.
		out.shader = PROP_SHADER if mat.cull_mode == BaseMaterial3D.CULL_BACK else _double_sided_prop_shader()
		out.set_shader_parameter("albedo", mat.albedo_color)
		out.set_shader_parameter("roughness", mat.roughness)
		out.set_shader_parameter("metallic", mat.metallic)
		out.set_shader_parameter("specular", mat.metallic_specular)
		out.set_shader_parameter("use_vertex_color", mat.vertex_color_use_as_albedo)
		if mat.albedo_texture:
			out.set_shader_parameter("albedo_tex", mat.albedo_texture)
			out.set_shader_parameter("use_albedo_tex", true)
		for param: String in weathering:
			out.set_shader_parameter(param, weathering[param])
		var surface: Array = _surface_for(mat.resource_name.to_lower(), mat.metallic)
		if not surface.is_empty() and str(surface[0]) != "":
			out.set_shader_parameter("detail_tex", load("res://assets/surfaces/%s.png" % surface[0]))
			out.set_shader_parameter("detail_scale", float(surface[1]))
			out.set_shader_parameter("use_detail", true)
		if surface.size() > 2:
			var tuning: Dictionary = surface[2]
			for param: String in tuning:
				out.set_shader_parameter(param, tuning[param])
	converted[key] = out
	return out


## [map name, tiles per metre] for a material name, or [] for none. Bare metal with no keyword
## gets brushed metal; anything else unnamed keeps only the procedural weathering.
func _surface_for(material_name: String, metallic: float) -> Array:
	# Keywords match at the start of a word ("_" separated), never inside one: as plain substrings
	# "shed" caught "brushed", "ice" caught "lattice" and "service", "plate" caught "template".
	var words: String = "_" + material_name.to_lower().replace(" ", "_").replace("-", "_").replace(".", "_")
	var chosen: Variant = null
	for keyword: String in surfaces:
		if words.contains("_" + keyword.to_lower()):
			chosen = surfaces[keyword]
			break
	if chosen == null:
		for entry: Array in SURFACE_KEYWORDS:
			if words.contains("_" + str(entry[0])):
				chosen = entry[1]
				break
	if chosen == null and metallic > 0.5:
		chosen = "brushed"
	if chosen == null or (chosen is String and chosen == ""):
		return []
	if chosen is Array:
		var entry: Array = chosen
		if entry.size() == 1:
			return [entry[0], SURFACE_SCALE.get(entry[0], 0.33)]
		return entry
	return [chosen, SURFACE_SCALE.get(chosen, 0.33)]


static var _double_sided: Shader


static func _double_sided_prop_shader() -> Shader:
	if _double_sided == null:
		_double_sided = Shader.new()
		_double_sided.code = PROP_SHADER.code.replace("cull_back", "cull_disabled")
	return _double_sided
