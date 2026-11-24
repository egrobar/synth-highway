class_name ItemEffects
extends Node
## What battle items do to your own run (BattleItems), and the feed of who sent what.
##
## Attacks a rival sends you, each for its seconds (BattleItems.ITEMS):
##   Paint Bomb  your notes wear the wrong fingers' colours (Highway.paint); the keys keep theirs.
##   Earthquake  the camera bumps and shakes (Stage.quake).
##   Disco Ball  a mirror ball hangs over the road, coloured spots sweeping across it.
##   Fog Bank    a fog wall comes down the road: notes appear out of it late (Highway.fog_depth).
##   Turbo       notes travel twice as fast: the same timing, half the warning (Highway.speed_scale).
##   Blackout    the lights go out: everything dims to a faint glow (an overlay under the HUD).
##   Wobble      the road sways and rolls like a ship (Stage.wobble).
##   Gas Leak    a quarter of your gas, at once; never below 10%, so it can't end your run by itself.
## Boosts you use: Nitro (points x2: Judge.boost) and Shield (blocks the next attack, 20 s).
## Speed and fog ease in and out, so notes never jump. Every material is warmed at setup, so the first
## disco ball or fog wall of a web race doesn't stall a frame (ShaderWarmup).
##
## The feed, top right under your place: "JO → EARTHQUAKE" for what you're hit with, what you send
## and what goes between the others, each for a few seconds.

## Notes show this far up the road in a Fog Bank (Highway.LENGTH is 46: about a second's warning).
const FOG_DEPTH := 15.0
const EASE := 0.6
const FEED_SECONDS := 3.2
const FEED_MAX := 3

var _stage: Stage
var _highway: Highway
var _judge: Judge
var _hud: CanvasLayer
## id -> seconds left, for what is running on this road.
var _left: Dictionary = {}
var shielded: bool = false
var _effects_root: Node3D
var _disco: Node3D
var _disco_ball: MeshInstance3D
## Coloured pools of light the mirror ball throws, sweeping the road: additive discs lying on it
## (cheaper than spot lights, and they read on the web renderer, where spots barely showed).
var _disco_pools: Array[MeshInstance3D] = []
## The fog: three soft layers a few metres apart, so it has depth rather than reading as one wall.
var _fog_layers: Array[MeshInstance3D] = []
var _fog_wall: MeshInstance3D
var _barrier: MeshInstance3D
var _blackout: ColorRect
var _overlay_layer: CanvasLayer
var _env: Environment
var _fog_density: float = 0.0
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _feed: Array[Control] = []
## Seconds left of the Shield's flash as it takes a hit (then it is gone).
var _barrier_flash: float = 0.0


func setup(stage: Stage, highway: Highway, judge: Judge, hud: CanvasLayer) -> void:
	_stage = stage
	_highway = highway
	_judge = judge
	_hud = hud
	_rng.randomize()
	if stage.world:
		_env = stage.world.get("_world_env") as Environment
		if _env:
			_fog_density = _env.fog_density
	_effects_root = Node3D.new()
	stage.add_child(_effects_root)
	_build_disco()
	_build_fog_wall()
	_build_barrier()
	_overlay_layer = CanvasLayer.new()
	# Over the 3D world, under the HUD (layer 1): the Blackout dims the road, not your score.
	_overlay_layer.layer = 0
	add_child(_overlay_layer)
	_blackout = ColorRect.new()
	_blackout.color = Color(0.0, 0.0, 0.02, 0.0)
	_blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_blackout)
	if ThemeWorld.compatibility_renderer():
		var warm := ShaderWarmup.new()
		stage.add_child(warm)
		warm.prewarm(_effects_root)


func _exit_tree() -> void:
	if _effects_root and is_instance_valid(_effects_root):
		_effects_root.queue_free()
	if _stage and is_instance_valid(_stage):
		_stage.calm()
	if _env:
		_env.fog_density = _fog_density


## An attack arrived. False when your Shield took it instead (it is used up).
func receive(id: String) -> bool:
	if BattleItems.is_attack(id) and shielded:
		shielded = false
		_left.erase("shield")
		# The barrier flashes white as it takes the hit, then goes.
		_barrier_flash = 0.45
		return false
	apply(id)
	return true


## Starts an item's effect on this road (an attack that got through, or a boost you used).
func apply(id: String) -> void:
	var seconds: float = BattleItems.seconds(id)
	match id:
		"paint":
			_highway.paint = _scrambled()
		"quake":
			_stage.quake(seconds)
		"wobble":
			_stage.wobble(seconds)
		"disco":
			_disco.visible = true
		"leak":
			if _judge.fuel > 0.1:
				_judge.fuel = maxf(0.1, _judge.fuel - 0.25)
		"nitro":
			_judge.boost = 2.0
		"shield":
			shielded = true
			_barrier_flash = 0.0
			_barrier.visible = true
	if seconds > 0.0:
		_left[id] = maxf(float(_left.get(id, 0.0)), seconds)


func is_running(id: String) -> bool:
	return _left.has(id)


## The line under the item slot for a boost you have running.
func status() -> Array:
	if _left.has("nitro"):
		return ["NITRO x2  %d" % ceili(float(_left["nitro"])), Color(0.45, 0.8, 1.0)]
	if shielded:
		return ["SHIELD UP", Color(0.45, 1.0, 0.95)]
	return ["", Ui.WARM]


## Every lane's notes in a finger colour that isn't their own (5 is the sharps' orange).
func _scrambled() -> Dictionary:
	var map: Dictionary = {}
	for lane: int in KeyMap.COUNT + KeyMap.SHARPS.size():
		var own: int = KeyMap.FINGER_COLORS.size() if KeyMap.is_sharp(lane) else KeyMap.finger_for(lane)
		var pick: int = _rng.randi_range(0, KeyMap.FINGER_COLORS.size() - 1)
		if pick == own:
			pick = (pick + 1 + _rng.randi_range(0, KeyMap.FINGER_COLORS.size() - 1)) % (KeyMap.FINGER_COLORS.size() + 1)
		map[lane] = pick
	return map


func _process(delta: float) -> void:
	if not is_instance_valid(_highway) or not is_instance_valid(_stage):
		return
	_time += delta
	for id: String in _left.keys():
		_left[id] = float(_left[id]) - delta
		if float(_left[id]) <= 0.0:
			_left.erase(id)
			_end(id)
	# Turbo and Fog ease in and out: the notes speed up and the fog rolls in, never jump.
	var turbo: float = _strength("turbo")
	_highway.speed_scale = 1.0 + turbo
	var fog: float = _strength("fog")
	_highway.fog_depth = lerpf(Highway.LENGTH + 2.0, FOG_DEPTH, fog) if fog > 0.0 else 0.0
	for k: int in _fog_layers.size():
		var layer: MeshInstance3D = _fog_layers[k]
		layer.visible = fog > 0.0
		if fog > 0.0:
			layer.position.z = -_highway.fog_depth - 1.0 - k * 7.0
			(layer.material_override as ShaderMaterial).set_shader_parameter("strength", fog * (1.0 - k * 0.15))
	if _env:
		# A little haze over the whole road too; not much, or the notes you can see would grey out.
		_env.fog_density = lerpf(_fog_density, maxf(_fog_density, 0.02), fog)
	_blackout.color.a = 0.8 * _strength("blackout")
	if _disco.visible:
		_disco_ball.rotation.y += delta * 1.1
		for i: int in _disco_pools.size():
			var pool: MeshInstance3D = _disco_pools[i]
			var phase: float = _time * (0.55 + i * 0.13) + i * 1.7
			# Across the road and up and down it, in loops that never line up.
			pool.position = Vector3(sin(phase) * 7.5, 0.06, -5.0 - 11.0 * (0.5 + 0.5 * sin(phase * 0.71 + i)))
			pool.scale = Vector3.ONE * (1.0 + 0.25 * sin(_time * 3.0 + i))
	if _barrier.visible:
		var mat: StandardMaterial3D = _barrier.material_override
		if _barrier_flash > 0.0:
			_barrier_flash -= delta
			var k: float = clampf(_barrier_flash / 0.45, 0.0, 1.0)
			mat.albedo_color = Color(Color(1, 1, 1).lerp(Color(0.45, 1.0, 0.95), 1.0 - k), 0.85 * k)
			mat.emission_energy_multiplier = 1.5 + 4.0 * k
			_barrier.scale = Vector3(1.0, 1.0 + (1.0 - k) * 0.6, 1.0)
			if _barrier_flash <= 0.0:
				_barrier.visible = false
				_barrier.scale = Vector3.ONE
				mat.albedo_color = Color(0.45, 1.0, 0.95, 0.4)
				mat.emission_energy_multiplier = 1.5
		else:
			mat.albedo_color.a = 0.35 + 0.15 * sin(_time * 5.0)
	_age_feed(delta)


## 0 to 1: how strongly an easing effect is on, rising over EASE at its start and falling over its end.
func _strength(id: String) -> float:
	if not _left.has(id):
		return 0.0
	var left: float = float(_left[id])
	var ran: float = BattleItems.seconds(id) - left
	return clampf(minf(ran, left) / EASE, 0.0, 1.0)


func _end(id: String) -> void:
	match id:
		"paint":
			_highway.paint = {}
		"disco":
			_disco.visible = false
		"nitro":
			_judge.boost = 1.0
		"shield":
			shielded = false
			if _barrier_flash <= 0.0:
				_barrier.visible = false


# ---------------------------------------------------------------- the feed

## A line in the feed: `who` and the item's icon and name, warm when it's aimed at you.
func feed(text: String, id: String, at_you: bool) -> void:
	var row := Panel.new()
	var box: StyleBoxFlat = Ui.card_style(at_you, Ui.WARM)
	box.bg_color = Color(box.bg_color, 0.9)
	row.add_theme_stylebox_override("panel", box)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = BattleItems.icon(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	Ui.anchor(icon, 0.0, 0.0, 0.0, 1.0, 6, 5, 46, -5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Ui.label(text, 20, Ui.WARM if at_you else Ui.TEXT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.anchor(label, 0.0, 0.0, 1.0, 1.0, 54, 0, -10, 0)
	Ui.shrink_to_fit(label, 214.0, 14)
	row.add_child(label)
	row.set_meta("left", FEED_SECONDS)
	_hud.add_child(row)
	_feed.push_front(row)
	while _feed.size() > FEED_MAX:
		(_feed.pop_back() as Control).queue_free()
	_layout_feed()


func _layout_feed() -> void:
	for i: int in _feed.size():
		var y: float = 178.0 + i * 54.0
		Ui.anchor(_feed[i], 1.0, 0.0, 1.0, 0.0, -300, y, -22, y + 48)


func _age_feed(delta: float) -> void:
	var gone := false
	for row: Control in _feed.duplicate():
		var left: float = float(row.get_meta("left")) - delta
		row.set_meta("left", left)
		row.modulate.a = clampf(left / 0.4, 0.0, 1.0)
		if left <= 0.0:
			_feed.erase(row)
			row.queue_free()
			gone = true
	if gone:
		_layout_feed()


# ---------------------------------------------------------------- the 3D pieces

## A mirror ball over the left of the road (clear of the notes and the rivals' panels): mirror tiles
## glinting in shifting colours, a soft halo behind it, and coloured pools of light sweeping the road.
func _build_disco() -> void:
	_disco = Node3D.new()
	_disco.position = Vector3(-8.0, 8.0, -9.5)
	_disco.visible = false
	_effects_root.add_child(_disco)
	var cord := MeshInstance3D.new()
	var cord_mesh := CylinderMesh.new()
	cord_mesh.top_radius = 0.035
	cord_mesh.bottom_radius = 0.035
	cord_mesh.height = 6.0
	cord.mesh = cord_mesh
	cord.position = Vector3(0, 4.9, 0)
	var cord_mat := StandardMaterial3D.new()
	cord_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cord_mat.albedo_color = Color(0.5, 0.5, 0.56)
	cord.material_override = cord_mat
	_disco.add_child(cord)
	var halo := MeshInstance3D.new()
	var halo_quad := QuadMesh.new()
	halo_quad.size = Vector2(7.5, 7.5)
	halo.mesh = halo_quad
	var halo_shader := Shader.new()
	halo_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
void vertex() { MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]); }
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	vec3 tint = 0.6 + 0.4 * cos(6.2831 * (TIME * 0.15 + vec3(0.0, 0.33, 0.67)));
	ALBEDO = tint * pow(max(1.0 - d, 0.0), 2.2) * 0.9;
}
"""
	var halo_mat := ShaderMaterial.new()
	halo_mat.shader = halo_shader
	halo.material_override = halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disco.add_child(halo)
	_disco_ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.9
	sphere.height = 3.8
	_disco_ball.mesh = sphere
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 grid = UV * vec2(40.0, 20.0);
	vec2 cell = floor(grid);
	vec2 f = fract(grid);
	float r = hash(cell);
	float seam = step(0.12, f.x) * step(0.12, f.y);
	// Each tile catches the light in turn: most are cool silver, a few flash white or a colour.
	float glint = smoothstep(0.86, 1.0, fract(r * 7.0 + TIME * (0.5 + r)));
	float facing = clamp(dot(NORMAL, normalize(vec3(-0.3, 0.6, 1.0))), 0.0, 1.0);
	vec3 tile = mix(vec3(0.55, 0.6, 0.72), vec3(0.95, 0.97, 1.0), r * 0.6 + facing * 0.4);
	vec3 tint = 0.55 + 0.45 * cos(6.2831 * (r + TIME * 0.25 + vec3(0.0, 0.33, 0.67)));
	ALBEDO = (tile * (0.55 + 0.45 * facing) + tint * glint * 2.6) * seam + vec3(0.05) * (1.0 - seam);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_disco_ball.material_override = mat
	_disco_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disco.add_child(_disco_ball)
	# The pools hang off the effects root, not the ball: they lie on the road.
	var pool_shader := Shader.new()
	pool_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 tint = vec3(1.0);
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = tint * smoothstep(1.0, 0.35, d) * 0.55;
}
"""
	var colors: Array[Color] = [Color(1.0, 0.25, 0.7), Color(0.25, 0.9, 1.0), Color(1.0, 0.85, 0.2), Color(0.4, 1.0, 0.45),
		Color(0.7, 0.4, 1.0)]
	var pools := Node3D.new()
	pools.visible = false
	_disco.visibility_changed.connect(func() -> void: pools.visible = _disco.visible)
	_effects_root.add_child(pools)
	for color: Color in colors:
		var pool := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(4.2, 4.2)
		quad.orientation = PlaneMesh.FACE_Y
		pool.mesh = quad
		var pool_mat := ShaderMaterial.new()
		pool_mat.shader = pool_shader
		pool_mat.set_shader_parameter("tint", Vector3(color.r, color.g, color.b))
		pool.material_override = pool_mat
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pools.add_child(pool)
		_disco_pools.append(pool)


## Fog across the road where the notes come out of it: three soft layers a few metres apart, each
## drifting, with a ragged top and soft sides, so it reads as fog and not as a wall.
func _build_fog_wall() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 1.0;
uniform float seed = 0.0;
uniform vec3 tint = vec3(0.55, 0.6, 0.7);
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void fragment() {
	vec2 p = UV * vec2(6.0, 2.0) + vec2(TIME * 0.1 + seed, seed * 0.7);
	float n = noise(p) * 0.6 + noise(p * 2.3 - vec2(TIME * 0.07, 0.0)) * 0.4;
	// A ragged top: billows of fog rather than a ruled line.
	float top = 0.12 + 0.32 * noise(vec2(UV.x * 9.0 + seed * 3.0 + TIME * 0.05, seed));
	float body = smoothstep(top, top + 0.42, UV.y);
	float sides = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	ALBEDO = tint * (0.75 + 0.45 * n) * mix(1.15, 0.8, UV.y);
	ALPHA = clamp(body * sides * (0.62 + 0.4 * n), 0.0, 0.94) * strength;
}
"""
	var tint := Color(0.55, 0.6, 0.7)
	if _env:
		# Lifted toward the region's own fog colour, so a Fog Bank belongs to the road it rolls over.
		tint = tint.lerp(_env.fog_light_color * 4.0, 0.35).clamp(Color(0.25, 0.25, 0.3), Color(0.85, 0.85, 0.9))
	for k: int in 3:
		var layer := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(140.0, 20.0)
		layer.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("seed", float(k) * 3.7)
		mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		layer.material_override = mat
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.position = Vector3(0.0, 6.5 + k * 0.6, -FOG_DEPTH - k * 7.0)
		layer.visible = false
		_effects_root.add_child(layer)
		_fog_layers.append(layer)
	_fog_wall = _fog_layers[0]


## Your Shield: a glowing bar across the keys, pulsing while it holds.
func _build_barrier() -> void:
	_barrier = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(Highway.half_width() * 2.0 + 1.2, 1.4, 0.12)
	_barrier.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.45, 1.0, 0.95, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.45, 1.0, 0.95)
	mat.emission_energy_multiplier = 1.5
	_barrier.material_override = mat
	_barrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_barrier.position = Vector3(0.0, 0.7, -0.6)
	_barrier.visible = false
	_effects_root.add_child(_barrier)
