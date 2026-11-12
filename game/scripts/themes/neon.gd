extends ThemeWorld
## Neon Sprawl (cyberpunk, synthwave, EDM): an elevated freeway at night through a
## rain-soaked megacity. The ground drops away below the deck to misty streets full of
## tiny lights; megatowers rise out of the haze either side, holographic billboards
## flicker, sign gantries pass overhead, and rain streams down beyond the barriers.
##
## The road is glossy where its puddle map says so (textures/asphalt_rough.png, the
## road's roughness texture) and screen-space reflections are on, so the neon smears
## across the wet asphalt. Nothing stands on the road: decks, barriers and lamps start
## at its edge, and the gantry's signs hang above the camera so they only cross the sky.
##
## High detail (2026-11-10): the props are engineered up close (curtain walls with mullions and
## roof plant, fire escapes, bolted barrier joints, finned lamp heads, a box-truss gantry with a
## catwalk) and their material names pick the shared surface maps: concrete for the deck and
## barriers, brushed metal for steel, riveted plating for tower cladding, grating for catwalks.
## Weathering is city soot run down in rain streaks; the tower glass stays clean and mapless so
## its reflections read.
##
## The city answers the player (2026-11-11, ThemeWorld's on_* events). On a combo milestone the
## billboards flip over to a celebration, cycling colour, and fireworks go up over the towers either
## side; from the second milestone a drone light show rises out of the streets on the right and
## draws a shape in the sky (a ring, a star, then a heart), and from the third searchlights sweep up
## from the streets; each milestone sends up more. A fast streak floods the neon brighter; a long
## combo keeps it up and two searchlights sweeping. Faltering glitches every sign at once, showers
## sparks from a lamp ahead and blacks out a sector of the towers' windows (all of them when it is
## bad); getting going again brings the windows back on and steadies the signs.

const LAMP_SPACING := 20.0  # must match LAMP_SPACING in tools/themes/neon/props.py
const BARRIER_LENGTH := 10.0  # two precast segments; must match BARRIER_LENGTH in tools/themes/neon/props.py
const DECK_LENGTH := 30.0  # must match DECK_LENGTH in tools/themes/neon/props.py
const GANTRY_ROAD_HALF := 8.4  # the gantry model is built for this road half-width; it is stretched to fit
const STREET_LEVEL := -26.0  # the city floor, far below the freeway deck
const LOOP := 420.0  # landmark loop length, the same as ThemeWorld.landmarks()' default

var _signs: Array[Dictionary] = []
var _glitch := RandomNumberGenerator.new()
var _clock: float = 0.0
# The player's events.
const SHELLS := 10
const DRONES := 72
## The drone show: well out to the right, past the towers, in the gap of sky they leave there.
const SHOW_CENTRE := Vector3(150.0, 34.0, -240.0)
const FIREWORK_COLOURS: Array[Color] = [Color(1.0, 0.2, 0.7), Color(0.2, 0.9, 1.0), Color(1.0, 0.75, 0.3),
	Color(0.7, 0.35, 1.0), Color(0.6, 1.0, 0.75)]
var _shells: Array[Dictionary] = []
var _shell_queue: Array[float] = []
var _drones: MultiMeshInstance3D
var _drone_from: Array[Vector3] = []
var _show_age: float = -1.0
var _show_shape: int = 0
var _searchlights: Array[Dictionary] = []
var _search_until: float = 0.0
var _party_until: float = 0.0
var _flood: float = 0.0
var _neon: Array[Dictionary] = []
var _pools: Array[Dictionary] = []
var _windows_warm: Array[Dictionary] = []
var _windows_cool: Array[Dictionary] = []
var _warm_power: float = 1.0
var _cool_power: float = 1.0
var _warm_target: float = 1.0
var _cool_target: float = 1.0
var _glitch_until: float = 0.0
var _spark_anchor: Node3D
var _sparks: CPUParticles3D
var _fx := RandomNumberGenerator.new()
var _lamp_row: Node3D


func build() -> void:
	# City soot, run down vertical faces in rain streaks; nothing settles in the rain, so the "dust"
	# is a thin wet film of soot on the tops. The surface maps (concrete tie holes and pour lines,
	# steel brushing, cladding plates) carry the detail at a moderate tone, so the props stay dark
	# and the neon leads. Grain and relief are kept low: this region's metal and glass are glossy
	# and lit by hundreds of neon points, and at 0.3 grain / 0.9 relief the gantry truss, the sign
	# faces and the tower glass glittered like crumpled foil.
	weathering = {"grime_color": Color(0.085, 0.075, 0.11), "grime": 0.6, "grime_height": 1.2,
		"dust_color": Color(0.2, 0.18, 0.24), "dust": 0.06, "grain": 0.12, "mottle": 0.16,
		"detail_tone": 0.55, "detail_bump": 0.6}
	# Tower glass stays mapless (it would otherwise get brushed metal for its metalness): its
	# mullions are modelled, and clean glass keeps the reflected neon crisp. Sign faces are smooth
	# sheeting, so they get no map either.
	surfaces = {"glass": "", "sign_face": ""}
	_glitch.seed = 2077
	var world := make_environment({
		"sky": asset("textures/sky.png"),
		"ambient": Color(0.42, 0.3, 0.7), "ambient_energy": 0.32,
		# Rain haze: the headlights and the signs bloom through it.
		"haze": 0.004, "haze_color": Color(0.3, 0.1, 0.34), "haze_glow": 0.06,
		"fog": Color(0.2, 0.06, 0.24), "fog_density": 0.012,
		"glow": 0.9, "glow_threshold": 1.0,
		"light_color": Color(0.62, 0.5, 1.0), "light_energy": 0.3,
		"light_rotation": Vector3(-30, -15, 0),
	})
	var env: Environment = world.environment
	env.ssr_enabled = true
	env.ssr_max_steps = 72
	env.ssr_fade_in = 0.12
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.4
	# Mist pooled over the streets below, so the towers' feet dissolve into a pink glow.
	env.fog_height = STREET_LEVEL + 14.0
	env.fog_height_density = 0.06
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12

	var ground := make_ground(asset("textures/ground.png"), Color(0.8, 0.75, 0.9))
	ground.position.y = STREET_LEVEL
	# Rain-wet asphalt: glossy, with standing water that mirrors the city.
	make_road(asset("textures/asphalt.png"), Color(0.72, 0.72, 0.84), Color(1.0, 0.18, 0.72), 2.2,
		{"roughness": 1.0, "roughness_texture": asset("textures/asphalt_rough.png"), "specular": 0.75,
		"wetness": 0.4, "puddle_tint": Color(0.7, 0.66, 0.8)})
	make_vehicle(asset("models/hood.glb"), Color(0.86, 0.92, 1.0), 24.0)
	# Underglow: magenta spilling from under the car's nose onto the shoulders, beside the keys.
	for side: float in [-1.0, 1.0]:
		var underglow := OmniLight3D.new()
		underglow.light_color = Color(1.0, 0.15, 0.7)
		underglow.omni_range = 6.0
		underglow.omni_attenuation = 1.6
		underglow.position = Vector3(side * (road_half + 0.6), 0.25, 2.6)
		add_light(underglow, 2.4)

	for side: float in [-1.0, 1.0]:
		# Left-side pieces are turned round so their road face (-X in Blender) faces the road.
		var yaw: float = 0.0 if side > 0.0 else 180.0
		row(asset("models/deck.glb"), side * road_half, DECK_LENGTH, 13, yaw)
		row(asset("models/barrier.glb"), side * (road_half + 1.4), BARRIER_LENGTH, 32, yaw)
		var lamps := row(asset("models/lamp.glb"), side * (road_half + 2.6), LAMP_SPACING, 16, yaw)
		if side > 0.0:
			_lamp_row = lamps
		for lamp: Node in lamps.get_children():
			var pool := OmniLight3D.new()
			pool.light_color = Color(1.0, 0.72, 0.95)
			pool.omni_range = 15.0
			pool.omni_attenuation = 1.4
			pool.light_energy = 1.4
			pool.position = Vector3(-2.45, 10.0, 0.0)
			(lamp as Node3D).add_child(pool)
			_pools.append({"light": pool, "base": pool.light_energy})
	var streets := scatter(asset("models/citylight.glb"), 110, 8.0, 90.0, 48.0, 0.8, 1.4, 77)
	streets.position.y = STREET_LEVEL + 0.05

	landmarks([
		["tower_a", 1.0, 16.0, 20.0, 1.0], ["block", -1.0, 66.0, 40.0, 1.0], ["tower_c", -1.0, 14.0, 48.0, 1.0],
		["tower_a", 1.0, 36.0, 74.0, 1.1], ["tower_b", -1.0, 22.0, 94.0, 1.0], ["block", 1.0, 72.0, 128.0, 1.0],
		["tower_a", -1.0, 18.0, 142.0, 1.0], ["tower_c", 1.0, 15.0, 152.0, 0.9], ["block", -1.0, 80.0, 196.0, 1.2],
		["tower_b", 1.0, 20.0, 218.0, 1.0], ["tower_c", -1.0, 30.0, 236.0, 1.2], ["tower_a", -1.0, 16.0, 290.0, 0.9],
		["tower_c", 1.0, 26.0, 302.0, 1.0], ["block", 1.0, 76.0, 330.0, 1.0], ["tower_b", -1.0, 20.0, 352.0, 1.1],
		["tower_a", 1.0, 18.0, 382.0, 1.0], ["tower_c", -1.0, 40.0, 398.0, 1.0],
	])
	for entry: Array in [["billboard", 1.0, 11.0, 62.0], ["pylon", -1.0, 7.0, 118.0], ["billboard", -1.0, 12.0, 178.0],
			["pylon", 1.0, 7.0, 254.0], ["billboard", 1.0, 12.0, 272.0], ["billboard", -1.0, 11.0, 334.0]]:
		_sign(entry[0], entry[1], entry[2], entry[3])
	for along: float in [126.0, 316.0]:
		var gantry := _place("gantry", 0.0, along, 0.0)
		gantry.scale.x = road_half / GANTRY_ROAD_HALF

	# Rain: drifters falling fast, re-dressed as thin streaks aligned to their fall.
	var first: int = get_child_count()
	drifters(Color(0.62, 0.75, 1.0), 520, 7.0, 14.0, Vector3(0.0, -24.0, 7.0), 0.02)
	var streak := BoxMesh.new()
	streak.size = Vector3(0.018, 0.75, 0.018)
	var rain := StandardMaterial3D.new()
	rain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain.vertex_color_use_as_albedo = true
	rain.albedo_color = Color(1.0, 1.0, 1.0, 0.5)
	streak.material = rain
	for i: int in range(first, get_child_count()):
		var drops := get_child(i) as CPUParticles3D
		if drops == null:
			continue
		drops.mesh = streak
		drops.lifetime = 0.8
		drops.preprocess = 1.0
		drops.spread = 3.0
		drops.particle_flag_align_y = true

	event_tint = Color(1.0, 0.45, 0.9)
	# The hood's own cyan stays out of the flood: it sits right under the keys.
	_neon = emissive_materials(["neon_pink", "neon_violet", "band"])
	_windows_warm = emissive_materials(["window_warm"])
	_windows_cool = emissive_materials(["window_cool"])
	_build_events()


## Glitching signs: now and then a billboard stutters and its light drops out with it.
func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	for sign: Dictionary in _signs:
		if _clock >= float(sign["next"]):
			sign["until"] = _clock + _glitch.randf_range(0.12, 0.5)
			sign["next"] = _clock + _glitch.randf_range(2.5, 8.0)
		var level: float = 1.0
		if _clock < float(sign["until"]):
			level = 0.12 if _glitch.randf() < 0.55 else 1.0
		elif _clock < _glitch_until:
			level = 0.06 if _glitch.randf() < 0.7 else 1.2  # faltering: every sign at once, and worse
		# A milestone's celebration: every sign cycles through the colours, brighter.
		var partying: bool = _clock < _party_until
		var mats: Array = sign["mats"]
		for i: int in mats.size():
			var entry: Dictionary = mats[i]
			var mat: StandardMaterial3D = entry["mat"]
			mat.emission = Color.from_hsv(fposmod(_clock * 0.5 + float(i) * 0.19, 1.0), 0.7, 1.0) if partying else entry["colour"]
			mat.emission_energy_multiplier = float(entry["base"]) * level * (1.6 if partying else 1.0)
		(sign["light"] as OmniLight3D).light_energy = float(sign["energy"]) * level * (1.5 if partying else 1.0)
	_update_events(delta)


# ---------------------------------------------------------------- answering the player

func on_milestone(level: int) -> void:
	_party_until = _clock + 4.5 + 0.5 * float(mini(level, 5))
	if not calm():
		for sign: Dictionary in _signs:
			_flip(sign)
		# Fireworks over the towers, more each time.
		var shells: int = [3, 5, 8, 10][mini(level, 4) - 1] + maxi(level - 4, 0) * 2
		for i: int in mini(shells, SHELLS * 2):
			_shell_queue.append(_clock + 0.15 + float(i) * 0.38 + _fx.randf_range(0.0, 0.2))
		event_sound("fireworks", -10.0)
	if level >= 2:
		_show_age = 0.0
		_show_shape = mini(level - 2, 2)
		_scatter_drones()
	if level >= 3:
		_search_until = _clock + 7.0 + float(mini(level, 6))
	super(level)


func on_streak(strength: float) -> void:
	_flood = maxf(_flood, 0.6 + 0.6 * strength)
	super(strength * 0.5)


func on_burst(strength: float, kind: String) -> void:
	_flood = maxf(_flood, 0.45 * strength)
	_party_until = maxf(_party_until, _clock + 1.0)
	super(strength, kind)


func on_falter(severity: float) -> void:
	# A sector of the city's windows goes dark; when it is bad, all of them.
	_cool_target = 0.05
	if severity >= 0.7:
		_warm_target = 0.08
	if calm():
		return
	_glitch_until = maxf(_glitch_until, _clock + 1.2 + 2.6 * severity)
	event_sound("glitch", -14.0)
	# Sparks from the top of a lamp post a little way ahead on the right, flying out, away from the road.
	var z: float = _lamp_row.position.z + 2.0 * LAMP_SPACING
	while z > -38.0:
		z -= LAMP_SPACING
	_spark_anchor.position = Vector3(road_half + 2.6, 9.6, z)
	_sparks.restart()


func on_recover() -> void:
	_cool_target = 1.0
	_warm_target = 1.0
	_glitch_until = 0.0
	super()


func on_settle() -> void:
	_cool_target = 1.0
	_warm_target = 1.0
	_cool_power = 1.0
	_warm_power = 1.0
	_glitch_until = 0.0
	_party_until = 0.0
	_flood = 0.0
	_search_until = 0.0
	_show_age = -1.0
	_drones.visible = false
	_shell_queue.clear()
	for shell: Dictionary in _shells:
		shell["age"] = -1.0
		(shell["trail"] as CPUParticles3D).emitting = false
		(shell["burst"] as CPUParticles3D).restart()
		(shell["burst"] as CPUParticles3D).emitting = false
	_sparks.restart()
	_sparks.emitting = false
	for sign: Dictionary in _signs:
		(sign["node"] as Node3D).rotation.y = float(sign["yaw"])


## A billboard flips right over (a full turn about its pole) and lands facing the road again.
func _flip(sign: Dictionary) -> void:
	var node: Node3D = sign["node"]
	var yaw: float = sign["yaw"]
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "rotation:y", yaw + TAU, 1.1).from(yaw).set_delay(_fx.randf_range(0.0, 0.3))
	tween.tween_callback(func() -> void: node.rotation.y = yaw)


func _build_events() -> void:
	_fx.seed = 1985
	# Firework shells: a rocket that climbs on a short trail, and its burst.
	for i: int in SHELLS:
		var rocket := Node3D.new()
		add_child(rocket)
		var trail := fx_particles(fx_material("glow", 3.0, false), 24, 0.55, 0.7, fx_ramp([
			[0.0, Color(1.0, 0.85, 0.55, 1.0)], [1.0, Color(1.0, 0.5, 0.2, 0.0)]]))
		trail.spread = 6.0
		trail.direction = Vector3.DOWN
		trail.initial_velocity_min = 1.0
		trail.initial_velocity_max = 2.0
		rocket.add_child(trail)
		# Kept under white-hot, so each shell keeps its colour against the pink sky.
		var burst := fx_particles(fx_material("glow", 2.4, false), 130, 2.4, 1.8, fx_ramp([[0.0, Color.WHITE], [1.0, Color.WHITE]]))
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.spread = 180.0
		burst.initial_velocity_min = 15.0
		burst.initial_velocity_max = 19.0
		burst.damping_min = 4.5
		burst.damping_max = 6.0
		burst.gravity = Vector3(0.0, -4.0, 0.0)
		add_child(burst)
		_shells.append({"rocket": rocket, "trail": trail, "burst": burst, "age": -1.0, "from": Vector3.ZERO,
			"to": Vector3.ZERO, "rise": 1.2, "burst_done": false})
	# The drone show: one MultiMesh of glowing points, hidden until a show.
	var dot := QuadMesh.new()
	dot.size = Vector2(2.4, 2.4)
	dot.material = fx_material("glow", 4.0, false)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = dot
	multi.instance_count = DRONES
	_drones = MultiMeshInstance3D.new()
	_drones.multimesh = multi
	_drones.visible = false
	_drones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drones)
	for i: int in DRONES:
		_drone_from.append(Vector3.ZERO)
	# Searchlights from the streets, two each side, leaning away from the road.
	for entry: Array in [[-1.0, 42.0, -150.0, 0.0], [1.0, 46.0, -170.0, 1.7], [-1.0, 80.0, -240.0, 3.1], [1.0, 76.0, -230.0, 4.4]]:
		var pivot := fx_beam(180.0, 1.0, 11.0, Color(0.85, 0.78, 1.0), 0.0)
		pivot.position = Vector3(float(entry[0]) * float(entry[1]), STREET_LEVEL, float(entry[2]))
		add_child(pivot)
		_searchlights.append({"pivot": pivot, "mat": pivot.get_meta("beam_material"), "side": entry[0], "phase": entry[3]})
	# Sparks from a lamp post (the anchor rides with the ground, as the lamp does).
	_spark_anchor = Node3D.new()
	add_child(_spark_anchor)
	ride(_spark_anchor)
	_sparks = fx_particles(fx_material("glow", 5.0), 90, 1.3, 0.2, fx_ramp([
		[0.0, Color(1.0, 0.97, 0.9, 1.0)], [0.4, Color(1.0, 0.6, 0.85, 1.0)], [1.0, Color(1.0, 0.3, 0.6, 0.0)]]))
	_sparks.local_coords = true
	_sparks.one_shot = true
	_sparks.explosiveness = 0.6
	_sparks.direction = Vector3(1.0, 0.4, 0.0)
	_sparks.spread = 50.0
	_sparks.initial_velocity_min = 3.0
	_sparks.initial_velocity_max = 8.0
	_sparks.gravity = Vector3(0.0, -11.0, 0.0)
	_spark_anchor.add_child(_sparks)


## Where drone i of a show starts: scattered over the streets below the show, so they rise into it.
func _scatter_drones() -> void:
	for i: int in DRONES:
		_drone_from[i] = SHOW_CENTRE + Vector3(_fx.randf_range(-45.0, 45.0), STREET_LEVEL - SHOW_CENTRE.y,
			_fx.randf_range(-40.0, 40.0))


## Drone i's place in a shape round the show's centre, facing the road: a ring, a star, a heart.
func _shape_point(shape: int, i: int) -> Vector3:
	var u: float = float(i) / float(DRONES)
	match shape:
		1:
			var corners: int = 10
			var at: float = u * float(corners)
			var k: int = int(at)
			var a0: float = TAU * float(k) / float(corners) + PI * 0.5
			var a1: float = TAU * float(k + 1) / float(corners) + PI * 0.5
			var r0: float = 30.0 if k % 2 == 0 else 12.0
			var r1: float = 12.0 if k % 2 == 0 else 30.0
			var p0 := Vector3(cos(a0) * r0, sin(a0) * r0, 0.0)
			var p1 := Vector3(cos(a1) * r1, sin(a1) * r1, 0.0)
			return p0.lerp(p1, at - float(k))
		2:
			var t: float = u * TAU
			return Vector3(16.0 * pow(sin(t), 3.0), 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t),
				0.0) * 1.8
	return Vector3(cos(u * TAU), sin(u * TAU), 0.0) * 26.0


## Fireworks, the drone show, the searchlights, the neon's flood and the windows' power.
func _update_events(delta: float) -> void:
	_flood = maxf(_flood - delta * 0.35, 0.0)
	set_emission(_neon, 1.0 + 1.0 * _flood + 0.35 * flow())
	for entry: Dictionary in _pools:
		(entry["light"] as OmniLight3D).light_energy = float(entry["base"]) * (1.0 + 0.6 * _flood)
	_warm_power = move_toward(_warm_power, _warm_target, delta * (1.5 if _warm_target < _warm_power else 0.6))
	_cool_power = move_toward(_cool_power, _cool_target, delta * (1.5 if _cool_target < _cool_power else 0.6))
	var stutter: float = 1.0
	if not calm() and (absf(_warm_power - _warm_target) > 0.02 or absf(_cool_power - _cool_target) > 0.02):
		stutter = 0.3 if _fx.randf() < 0.25 else 1.0  # power going or coming back stutters
	set_emission(_windows_warm, _warm_power * stutter)
	set_emission(_windows_cool, _cool_power * stutter)
	_update_fireworks(delta)
	_update_show(delta)
	var search: float = 1.0 if _clock < _search_until else 0.0
	for i: int in _searchlights.size():
		var light: Dictionary = _searchlights[i]
		var on: float = maxf(search, clampf((flow() - 0.3) / 0.3, 0.0, 1.0) if i < 2 else 0.0)
		var pivot: Node3D = light["pivot"]
		pivot.visible = on > 0.01
		if not pivot.visible:
			continue
		var side: float = light["side"]
		var sway: float = 0.5 + 0.5 * sin(_clock * (0.25 if calm() else 0.6) + float(light["phase"]))
		pivot.rotation = Vector3(-0.32, 0.0, -side * (0.12 + 0.38 * sway))
		(light["mat"] as ShaderMaterial).set_shader_parameter("strength", 0.2 * on)


func _update_fireworks(delta: float) -> void:
	while not _shell_queue.is_empty() and _clock >= _shell_queue[0]:
		_shell_queue.pop_front()
		for shell: Dictionary in _shells:
			if float(shell["age"]) < 0.0:
				_fire_shell(shell)
				break
	for shell: Dictionary in _shells:
		if float(shell["age"]) < 0.0:
			continue
		shell["age"] = float(shell["age"]) + delta
		var age: float = shell["age"]
		var rise: float = shell["rise"]
		if age < rise:
			var t: float = age / rise
			(shell["rocket"] as Node3D).position = (shell["from"] as Vector3).lerp(shell["to"], 1.0 - (1.0 - t) * (1.0 - t))
		elif not bool(shell["burst_done"]):
			shell["burst_done"] = true
			(shell["trail"] as CPUParticles3D).emitting = false
			var burst: CPUParticles3D = shell["burst"]
			burst.position = shell["to"]
			burst.restart()
		elif age > rise + 3.0:
			shell["age"] = -1.0


func _fire_shell(shell: Dictionary) -> void:
	# Out past the towers, mostly on the right where they leave the most sky (the left's are nearer).
	var side: float = -1.0 if _fx.randf() < 0.3 else 1.0
	var from := Vector3(side * _fx.randf_range(105.0, 215.0), STREET_LEVEL + 4.0, _fx.randf_range(-190.0, -300.0))
	shell["from"] = from
	shell["to"] = Vector3(from.x + _fx.randf_range(-8.0, 8.0), _fx.randf_range(26.0, 46.0), from.z)
	shell["rise"] = _fx.randf_range(1.0, 1.4)
	shell["age"] = 0.0
	shell["burst_done"] = false
	var colour: Color = FIREWORK_COLOURS[_fx.randi() % FIREWORK_COLOURS.size()]
	(shell["burst"] as CPUParticles3D).color_ramp = fx_ramp([[0.0, Color(1.0, 1.0, 1.0, 1.0)], [0.06, colour],
		[0.7, Color(colour.r * 0.8, colour.g * 0.8, colour.b * 0.8, 0.8)], [1.0, Color(colour, 0.0)]])
	(shell["rocket"] as Node3D).position = from
	(shell["trail"] as CPUParticles3D).emitting = true


## The drone show: rise out of the streets into the shape (0-2.2 s), hold it turning slowly with the
## colours running round it (to 7 s), then spread out and fade (to 8.5 s).
func _update_show(delta: float) -> void:
	if _show_age < 0.0:
		return
	_show_age += delta
	var a: float = _show_age
	if a > 8.5:
		_show_age = -1.0
		_drones.visible = false
		return
	_drones.visible = true
	var multi: MultiMesh = _drones.multimesh
	var gather: float = smoothstep(0.0, 2.2, a)
	var spin: float = 0.22 * maxf(a - 2.2, 0.0)
	var spread: float = 1.0 + 0.9 * smoothstep(7.0, 8.5, a)
	var fade: float = 1.0 - smoothstep(7.3, 8.5, a)
	for i: int in DRONES:
		var p: Vector3 = _shape_point(_show_shape, i).rotated(Vector3.BACK, spin) * spread
		var at: Vector3 = (_drone_from[i] as Vector3).lerp(SHOW_CENTRE + p, gather)
		multi.set_instance_transform(i, Transform3D(Basis(), at))
		var hue: float = fposmod(float(i) / float(DRONES) + a * 0.15, 1.0)
		var twinkle: float = 0.75 + 0.25 * sin(a * 6.0 + float(i) * 1.7)
		multi.set_instance_color(i, Color.from_hsv(hue, 0.55, 1.0, fade * twinkle))


## Like landmarks(), but with a free yaw and no road-edge offset: billboards must face the
## oncoming driver on both sides (landmarks() turns every left-side prop a fixed 180 degrees),
## and the gantry straddles the road centre.
func _place(model: String, x: float, along: float, yaw: float) -> Node3D:
	var node: Node3D = (load(asset("models/%s.glb" % model)) as PackedScene).instantiate()
	node.position.x = x
	node.rotation_degrees.y = yaw
	add_child(node)
	_looped.append({"node": node, "along": along, "loop": LOOP, "near": 18.0})
	return node


## A billboard or holo pylon angled toward the road and the driver, with its own glow on the
## road and its own copy of the holo_* materials so it can glitch on its own.
func _sign(model: String, side: float, from_edge: float, along: float) -> void:
	var turn: float = 50.0 if model == "billboard" else 35.0
	var node := _place(model, side * (road_half + from_edge), along, turn if side > 0.0 else 180.0 - turn)
	var light := OmniLight3D.new()
	light.light_color = Color(0.95, 0.3, 0.85)
	light.omni_range = 24.0
	light.omni_attenuation = 1.2
	light.position = Vector3(-2.5, 13.5 if model == "billboard" else 15.0, 0.0)
	node.add_child(light)
	var mats: Array[Dictionary] = []
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		for s: int in mesh_instance.mesh.get_surface_count():
			var mat := mesh_instance.mesh.surface_get_material(s) as StandardMaterial3D
			if mat != null and mat.resource_name.begins_with("holo"):
				var own := mat.duplicate() as StandardMaterial3D
				mesh_instance.set_surface_override_material(s, own)
				mats.append({"mat": own, "base": own.emission_energy_multiplier, "colour": own.emission})
	var energy: float = 3.0
	light.light_energy = energy
	_signs.append({"mats": mats, "light": light, "energy": energy, "until": 0.0,
		"next": _glitch.randf_range(1.0, 6.0), "node": node, "yaw": node.rotation.y})
