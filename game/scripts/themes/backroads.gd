extends ThemeWorld
## Red Frontier (region id `backroads`; country, folk, driving): a Mars homestead at dusk.
##
## A sintered-regolith road across rust-red plains, heading straight into the blue Martian
## sunset. Lattice power pylons march down the left with their insulators and cables; rows of glowing crop tubes fill
## the fields on the right where the wheat used to be; marker posts with amber reflectors line
## both shoulders. Round the loop come greenhouse domes, pressurised habitats with warm windows,
## a habitat hub, water-ice silos, landing pads with a parked cargo shuttle, dust turbines
## turning, boulders and dunes. Greenhouse pods and rocks are scattered over the plain, and dim
## dust motes drift past.
##
## The sun sits just ahead, so the key light comes from ahead (and to the left) and the scenery is
## mostly backlit: dark shapes against the butterscotch sky, lit by their own windows. Beacon lights
## (materials named beacon_* in the models) blink: the red aviation lights with a slow flash,
## the landing pads' amber edge lights with the beat. Nothing stands on the road: the nearest
## props are the marker posts, 2.4 beyond its edge.
##
## The colony answers the player (2026-11-11, ThemeWorld's on_* events). From the second combo
## milestone on, a cargo shuttle lifts off a launch pad out on the plain ahead and to the right:
## the pads' lights strobe, its jets kick up a ring of dust, light washes the plain, and it climbs
## away down the road on a plume of fire and smoke; bigger milestones throw a bigger plume and,
## from the fourth, a second shuttle goes up on the left. The first milestone strobes the pads and
## spins the turbines. A fast streak spins the turbines up and sets the crop tubes throbbing on the
## beat; a long combo keeps them bright. Faltering browns the colony out: sparks fly from a pylon's
## insulators, windows and crop tubes dim and stutter, and on the tank running low it nearly blacks
## out; getting going again brings the power back, flickering on.

const PYLON_SPACING := 30.0  # must match PYLON_SPACING in tools/themes/backroads/props.py
const CROP_TILE := 18.0  # must match CROP_TILE in tools/themes/backroads/props.py
const MARKER_SPACING := 12.0  # must match MARKER_SPACING in tools/themes/backroads/props.py
const ROTOR_HUB := Vector3(0.0, 17.0, 1.4)  # TURBINE_HUB in props.py: (0, -1.4, 17) in Blender
const LOOP := 420.0  # landmark loop length, the same as ThemeWorld.landmarks()' default
## Crop fields on the right: each row's distance from the road edge, and what fills the four
## CROP_TILE slots of its repeating pattern: a green tube (g), a wheat-gold one (o) or a gap (.).
const CROP_ROWS := [[16.0, "gg.o"], [20.5, "og.g"], [25.0, ".ggo"], [29.5, "g.og"]]

var _rotors: Array[Dictionary] = []
var _red: Array[Dictionary] = []
var _amber: Array[Dictionary] = []
var _seen_materials: Dictionary = {}
var _clock: float = 0.0
var _pulse: float = 0.0
var _spin := RandomNumberGenerator.new()
# The player's events: launch sites (one each side), the colony's power, the turbines' boost.
const PYLON_TOP := 13.2  # the pylon's cross-arm, where the insulators hang (props.py arm_z)
const LAUNCH_SCALE := 1.35
var _sites: Array[Dictionary] = []
var _windows: Array[Dictionary] = []
var _grow: Array[Dictionary] = []
var _house_lights: Array[Dictionary] = []
var _power: float = 1.0
var _target_power: float = 1.0
var _boost: float = 0.0
var _strobe_until: float = 0.0
var _crop_surge: float = 0.0
var _sparks: CPUParticles3D
var _spark_anchor: Node3D
var _pylons: Node3D
var _fx_rng := RandomNumberGenerator.new()


func build() -> void:
	# Red dust settles on everything: a heavy layer on every upward face, rust-brown grime collecting
	# low down and streaking the walls. The surface maps (hull plating, brushed steel, sintered
	# concrete, rock, frosted ice) read clearly up close; detail_bump stays near the default so the
	# rivets and seams do not sparkle at speed.
	weathering = {
		"grime_color": Color(0.36, 0.2, 0.14), "grime": 0.5, "grime_height": 1.4,
		"dust_color": Color(0.62, 0.36, 0.26), "dust": 0.6, "grain": 0.3, "mottle": 0.14,
		"detail_tone": 0.7, "detail_bump": 1.1,
	}
	# This region's own material names (tools/themes/backroads/props.py): solar panels show the cell
	# grid (the grate map, about 14 cm cells), dunes wind ripples (the corrugated map stretched to
	# about half a metre per ripple). Bare steel ("steel", "trim_steel": the pylon lattice, frames,
	# ladders, rails) keeps its brushed map but almost no grain: at the region's grain the thin
	# glossy members glittered like foil in the low sun. Cables and glass insulators get none.
	surfaces = {
		"steel": ["brushed", 0.5, {"grain": 0.05, "detail_bump": 0.35}],
		"solar": ["grate", 0.3, {"grain": 0.05}],
		"dune": ["corrugated", 0.1],
		# Frosted ice silos stay pale blue: under the region's grime the streaks ran their full
		# 13 m height and turned them rust-brown.
		"ice": ["ice", 0.15, {"grime": 0.12, "dust": 0.3, "mottle": 0.08}],
		"cable": ["", 0, {"grain": 0.0}],
		"insulator": ["", 0, {"grain": 0.0}],
	}
	_spin.seed = 1976
	var world := make_environment({
		"sky": asset("textures/sky.png"),
		"ambient": Color(0.78, 0.55, 0.5), "ambient_energy": 0.32,
		# Dust hangs in the thin air: the low sun and the headlights show in it.
		"haze": 0.005, "haze_color": Color(0.5, 0.3, 0.24), "haze_glow": 0.06,
		"fog": Color(0.22, 0.11, 0.095), "fog_density": 0.0095,
		"glow": 0.85, "glow_threshold": 1.0,
		# The sun is down the road but the key light comes from ahead-left and a little higher:
		# straight ahead and low, it laid a sunset glint down the middle lanes, where notes arrive.
		"light_color": Color(0.7, 0.8, 1.0), "light_energy": 0.75,
		"light_rotation": Vector3(-18.0, 215.0, 0.0),
	})
	var env: Environment = world.environment
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06

	make_ground(asset("textures/ground.png"), Color(0.92, 0.84, 0.8))
	# Matt regolith: at the default sheen the headlights laid a white glare down the middle lanes.
	make_road(asset("textures/road.png"), Color(0.95, 0.9, 0.88), Color(1.0, 0.6, 0.28), 0.7,
		{"roughness": 0.95, "specular": 0.2, "bump": 2.0, "grain": 0.45})
	make_vehicle(asset("models/hood.glb"), Color(1.0, 0.93, 0.82), 26.0)

	_pylons = row(asset("models/pylon.glb"), -(road_half + 7.0), PYLON_SPACING, 11)
	row(asset("models/marker.glb"), road_half + 2.4, MARKER_SPACING, 28)
	row(asset("models/marker.glb"), -(road_half + 2.4), MARKER_SPACING, 28, 180.0)
	_crop_fields()
	scatter(asset("models/rock.glb"), 200, 3.0, 60.0, 48.0, 0.6, 1.6, 2024)
	scatter(asset("models/pod.glb"), 9, 33.0, 72.0, 48.0, 0.8, 1.3, 77)

	# Left: closer, past the pylons. Right: beyond the crop fields.
	for entry: Array in [
		["habitat", -1.0, 19.0, 20.0, 1.0], ["dome", -1.0, 22.0, 62.0, 1.0], ["pad", -1.0, 24.0, 128.0, 1.0],
		["shuttle", -1.0, 24.0, 128.0, 1.0], ["hab_hub", -1.0, 22.0, 215.0, 1.0], ["silo", -1.0, 18.0, 250.0, 1.0],
		["dome_pair", -1.0, 20.0, 290.0, 1.0], ["boulder", -1.0, 26.0, 325.0, 1.0], ["habitat", -1.0, 21.0, 360.0, 0.9],
		["dune", -1.0, 55.0, 100.0, 1.0], ["dune", -1.0, 70.0, 240.0, 1.2], ["dune", -1.0, 50.0, 395.0, 0.9],
		["silo", 1.0, 38.0, 40.0, 1.1], ["dome", 1.0, 46.0, 140.0, 1.15], ["hab_hub", 1.0, 38.0, 185.0, 1.0],
		["pad", 1.0, 42.0, 225.0, 1.0], ["shuttle", 1.0, 42.0, 225.0, 1.0], ["dome_pair", 1.0, 42.0, 265.0, 1.0],
		["boulder", 1.0, 42.0, 300.0, 1.2], ["habitat", 1.0, 36.0, 335.0, 1.0],
		["dune", 1.0, 75.0, 60.0, 1.3], ["dune", 1.0, 68.0, 200.0, 1.0], ["dune", 1.0, 80.0, 330.0, 1.2],
	]:
		var node := _place(entry[0], entry[1], entry[2], entry[3], entry[4])
		if entry[0] == "habitat":
			_glow(node, Vector3(-3.9, 3.0, 0.0), Color(1.0, 0.66, 0.34), 9.0, 1.6)
		elif entry[0] == "shuttle":
			# In front of the lit cargo hold, which sits ahead of the wing root (Blender (-2.9, 3.0, 2.6)).
			_glow(node, Vector3(-2.9, 2.6, -3.0), Color(1.0, 0.7, 0.4), 11.0, 2.0)
	for entry: Array in [[-1.0, 20.0, 170.0], [-1.0, 33.0, 182.0], [1.0, 40.0, 80.0], [1.0, 52.0, 96.0],
			[1.0, 64.0, 112.0], [1.0, 42.0, 375.0], [1.0, 54.0, 392.0]]:
		_turbine(entry[0], entry[1], entry[2])

	# Dust motes: dim (their colour is their brightness, as the bead is unshaded) and drifting past.
	drifters(Color(0.62, 0.42, 0.28), 90, 2.6, 12.0, Vector3(0.0, 0.25, 8.0), 0.035, Vector3.ZERO, 0.7)

	for found: Node in find_children("*", "MeshInstance3D", true, false):
		_collect_beacons(found as MeshInstance3D)
	_windows = emissive_materials(["window", "cockpit", "status"])
	_grow = emissive_materials(["grow"])
	for entry: Dictionary in _grow:
		entry["albedo"] = (entry["mat"] as StandardMaterial3D).albedo_color
	event_tint = Color(1.0, 0.72, 0.48)
	_build_events()


## Red aviation lights flash slowly; the pads' amber edge lights breathe and jump on the beat;
## the turbines turn.
func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	_pulse = maxf(_pulse - delta * 2.5, 0.0)
	_update_power(delta)
	var red_level: float = (0.06 + 0.94 * pow(maxf(sin(_clock * PI * 0.8), 0.0), 12.0)) * _lit
	for entry: Dictionary in _red:
		(entry["mat"] as StandardMaterial3D).emission_energy_multiplier = float(entry["base"]) * red_level
	var amber_level: float = 0.3 + 0.15 * (0.5 + 0.5 * sin(_clock * 2.2)) + 0.7 * _pulse
	if _clock < _strobe_until:
		# A launch alert: the pads' edge lights strobe (with motion off, they just burn bright).
		amber_level = 1.3 if calm() else (1.8 if fmod(_clock, 0.26) < 0.09 else 0.12)
	for entry: Dictionary in _amber:
		(entry["mat"] as StandardMaterial3D).emission_energy_multiplier = float(entry["base"]) * amber_level * _lit
	_boost = maxf(_boost - delta * 0.18, 0.0)
	_crop_surge = maxf(_crop_surge - delta * 0.25, 0.0)
	var spin: float = (1.0 + 5.0 * _boost + 0.8 * flow()) * (0.4 + 0.6 * _power)
	for rotor: Dictionary in _rotors:
		(rotor["node"] as Node3D).rotation.z += delta * float(rotor["speed"]) * spin
	_update_launches(delta)


func on_beat(strength: float) -> void:
	_pulse = maxf(_pulse, strength)


## Rows of crop tubes on the right, in a pattern that repeats every four slots (with gaps, so the
## fields read as separate tunnels). Each row is nudged along a little so the gaps do not line up.
func _crop_fields() -> void:
	var pattern: float = CROP_TILE * 4.0
	var green: Array[Vector3] = []
	var gold: Array[Vector3] = []
	for r: int in CROP_ROWS.size():
		var x: float = road_half + float(CROP_ROWS[r][0])
		var slots: String = CROP_ROWS[r][1]
		for rep: int in 6:
			for k: int in 4:
				var spot := Vector3(x, 0.0, pattern - float(rep) * pattern - float(k) * CROP_TILE - float(r) * 4.5)
				if slots[k] == "g":
					green.append(spot)
				elif slots[k] == "o":
					gold.append(spot)
	repeat(asset("models/crop_tube.glb"), green, pattern)
	repeat(asset("models/crop_tube_gold.glb"), gold, pattern)


## Like landmarks(), but returns the node so lights and rotors can be attached.
## Left-side props are turned round so their road face (-X in Blender) faces the road.
func _place(model: String, side: float, from_edge: float, along: float, size: float) -> Node3D:
	var node: Node3D = (load(asset("models/%s.glb" % model)) as PackedScene).instantiate()
	node.position.x = side * (road_half + from_edge)
	node.scale = Vector3.ONE * size
	node.rotation_degrees.y = 0.0 if side > 0.0 else 180.0
	add_child(node)
	_looped.append({"node": node, "along": along, "loop": LOOP, "near": 18.0})
	return node


## A dust turbine with its own rotor, turning at its own speed from its own starting angle.
func _turbine(side: float, from_edge: float, along: float) -> void:
	var tower := _place("turbine", side, from_edge, along, 1.0)
	var rotor: Node3D = (load(asset("models/rotor.glb")) as PackedScene).instantiate()
	rotor.position = ROTOR_HUB
	rotor.rotation.z = _spin.randf_range(0.0, TAU)
	tower.add_child(rotor)
	_rotors.append({"node": rotor, "speed": _spin.randf_range(0.5, 0.95)})


## Warm light spilling from a lit door onto the regolith (scenery light, not dimmed by the fuel gauge).
func _glow(node: Node3D, at: Vector3, colour: Color, reach: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = colour
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.light_energy = energy
	light.position = at
	node.add_child(light)
	_house_lights.append({"light": light, "base": energy})


# ---------------------------------------------------------------- answering the player

var _lit: float = 1.0
var _flick: float = 1.0
var _flick_next: float = 0.0


func on_milestone(level: int) -> void:
	_strobe_until = _clock + 4.0 + float(mini(level, 5))
	_boost = maxf(_boost, 0.7)
	if level >= 2:
		_launch(0, level, 0.0)
		event_sound("launch", -11.0)
	if level >= 4:
		_launch(1, level, 1.4)
	super(level)


func on_streak(strength: float) -> void:
	_boost = maxf(_boost, 0.5 + 0.6 * strength)
	_crop_surge = maxf(_crop_surge, 0.6 + 0.5 * strength)
	super(strength * 0.5)


func on_burst(strength: float, kind: String) -> void:
	_crop_surge = maxf(_crop_surge, 0.5 * strength)
	_strobe_until = maxf(_strobe_until, _clock + 1.2)
	super(strength, kind)


func on_falter(severity: float) -> void:
	_target_power = minf(_target_power, 1.0 - 0.78 * severity)
	event_sound("brownout", -12.0)
	if calm():
		return
	# Sparks off the insulators of a pylon a little way ahead (the anchor rides with the ground, as
	# the pylon does).
	var z: float = _pylons.position.z + 2.0 * PYLON_SPACING
	while z > -55.0:
		z -= PYLON_SPACING
	_spark_anchor.position = Vector3(-(road_half + 7.0), PYLON_TOP, z)
	_sparks.restart()


func on_recover() -> void:
	_target_power = 1.0
	super()


func on_settle() -> void:
	_target_power = 1.0
	_power = 1.0
	_boost = 0.0
	_crop_surge = 0.0
	_strobe_until = 0.0
	_sparks.restart()
	_sparks.emitting = false
	for i: int in _sites.size():
		_end_launch(_sites[i])


## The colony's supply: it browns out on faltering and comes back when the player does. A failing or
## returning supply stutters (never with motion off).
func _update_power(delta: float) -> void:
	_power = move_toward(_power, _target_power, delta * (1.4 if _target_power < _power else 0.6))
	if _clock >= _flick_next:
		_flick_next = _clock + _fx_rng.randf_range(0.05, 0.13)
		var unsteady: bool = absf(_power - _target_power) > 0.02 or _power < 0.9
		_flick = _fx_rng.randf_range(0.15, 0.75) if unsteady and _fx_rng.randf() < 0.3 else 1.0
	_lit = _power * (1.0 if calm() else _flick)
	set_emission(_windows, _lit)
	set_emission(_grow, _lit * (1.0 + 0.35 * flow() + _crop_surge * (1.1 + 1.8 * _pulse)))
	# The tubes' own green fades too, so a brown-out reads even where the headlights fall.
	for entry: Dictionary in _grow:
		(entry["mat"] as StandardMaterial3D).albedo_color = (entry["albedo"] as Color) * (0.3 + 0.7 * _lit)
	for entry: Dictionary in _house_lights:
		(entry["light"] as OmniLight3D).light_energy = float(entry["base"]) * _lit


## Two launch sites (right, then left for the biggest milestones), each a pad with a shuttle on it,
## hidden until a launch puts it on the plain ahead and lets the drive carry it past.
func _build_events() -> void:
	_fx_rng.seed = 2611
	for side: float in [1.0, -1.0]:
		_sites.append(_launch_site(side))
	_spark_anchor = Node3D.new()
	add_child(_spark_anchor)
	ride(_spark_anchor)
	_sparks = fx_particles(fx_material("glow", 5.0), 140, 1.4, 0.4, fx_ramp([
		[0.0, Color(1.0, 0.97, 0.85, 1.0)], [0.35, Color(0.75, 0.85, 1.0, 1.0)], [1.0, Color(1.0, 0.55, 0.2, 0.0)]]))
	_sparks.local_coords = true
	_sparks.one_shot = true
	_sparks.explosiveness = 0.55
	_sparks.direction = Vector3(0.0, -0.2, 0.0)
	_sparks.spread = 180.0
	_sparks.initial_velocity_min = 3.0
	_sparks.initial_velocity_max = 9.0
	_sparks.gravity = Vector3(0.0, -11.0, 0.0)
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sparks.emission_box_extents = Vector3(2.9, 0.3, 0.3)  # along the cross-arm, insulator to insulator
	_spark_anchor.add_child(_sparks)


func _launch_site(side: float) -> Dictionary:
	var root := Node3D.new()
	root.visible = false
	root.scale = Vector3.ONE * LAUNCH_SCALE
	add_child(root)
	root.add_child((load(asset("models/pad.glb")) as PackedScene).instantiate())
	var shuttle: Node3D = (load(asset("models/shuttle.glb")) as PackedScene).instantiate()
	root.add_child(shuttle)
	# Main engines: a flame out of the three bells (Blender -Y, so toward the camera as it climbs away),
	# a bright core, and a trail of smoke left hanging in the air.
	var engines := Node3D.new()
	engines.position = Vector3(0.0, 2.5, 6.0)
	shuttle.add_child(engines)
	var flame := fx_beam(16.0, 1.5, 0.25, Color(1.0, 0.68, 0.32), 0.0)
	flame.rotation_degrees.x = 90.0
	engines.add_child(flame)
	var core := fx_sprite(Color(1.0, 0.82, 0.55, 0.0), 9.0, 4.0, false)
	engines.add_child(core)
	var belly := fx_sprite(Color(0.75, 0.85, 1.0, 0.0), 7.0, 3.0, false)
	belly.position = Vector3(0.0, 0.4, 0.0)
	shuttle.add_child(belly)
	var trail := fx_particles(fx_material("smoke", 1.0, false), 320, 7.0, 6.0, fx_ramp([
		[0.0, Color(1.0, 0.8, 0.55, 0.0)], [0.04, Color(1.0, 0.66, 0.4, 0.75)], [0.3, Color(0.6, 0.45, 0.4, 0.55)],
		[1.0, Color(0.42, 0.32, 0.3, 0.0)]]))
	var grow := Curve.new()
	grow.max_value = 4.0
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 3.6))
	trail.scale_amount_curve = grow
	trail.spread = 6.0
	trail.gravity = Vector3(0.0, 0.8, 0.0)
	engines.add_child(trail)
	# The jets' dust: a ring blown out across the pad, riding with it.
	var dust := fx_particles(fx_material("smoke", 1.0, false), 60, 3.8, 7.0, fx_ramp([
		[0.0, Color(0.75, 0.5, 0.36, 0.0)], [0.1, Color(0.72, 0.48, 0.36, 0.6)], [1.0, Color(0.45, 0.3, 0.25, 0.0)]]))
	dust.local_coords = true
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	dust.emission_ring_axis = Vector3.UP
	dust.emission_ring_radius = 5.0
	dust.emission_ring_inner_radius = 2.0
	dust.emission_ring_height = 0.4
	dust.direction = Vector3.UP
	dust.spread = 60.0
	dust.initial_velocity_min = 1.5
	dust.initial_velocity_max = 4.0
	dust.radial_accel_min = 5.0
	dust.radial_accel_max = 9.0
	dust.damping_min = 1.0
	dust.damping_max = 1.6
	dust.scale_amount_curve = grow
	dust.position.y = 0.6
	root.add_child(dust)
	# The light that washes the plain round the pad as the engines light.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.45)
	light.omni_range = 70.0
	light.omni_attenuation = 1.1
	light.light_energy = 0.0
	light.position = Vector3(0.0, 8.0, 3.0)
	root.add_child(light)
	return {"root": root, "shuttle": shuttle, "flame": flame.get_meta("beam_material"), "core": core,
		"belly": belly, "trail": trail, "dust": dust, "light": light, "side": side, "age": -1.0, "delay": 0.0,
		"level": 2, "ignited": false}


func _launch(index: int, level: int, delay: float) -> void:
	var site: Dictionary = _sites[index]
	if float(site["age"]) >= 0.0:
		return  # still flying the last one
	var root: Node3D = site["root"]
	root.position = Vector3(float(site["side"]) * (road_half + 46.0), 0.0, -150.0 - 25.0 * delay)
	root.visible = true
	ride(root)
	site["age"] = 0.0
	site["delay"] = delay
	site["level"] = mini(level, 6)
	site["ignited"] = false


## A launch over time (seconds from its start): jets spool up and blow dust across the pad (0-1.8),
## the shuttle lifts clear (to 3.4), then pitches up, lights its main engines and climbs away down the
## road, leaving a trail. The pad rides past and is put away once it is behind the camera.
func _update_launches(delta: float) -> void:
	for site: Dictionary in _sites:
		if float(site["age"]) < 0.0:
			continue
		site["age"] = float(site["age"]) + delta
		var a: float = float(site["age"]) - float(site["delay"])
		var root: Node3D = site["root"]
		var shuttle: Node3D = site["shuttle"]
		var level: int = site["level"]
		var big: float = 1.0 + 0.25 * float(level - 2)
		(site["dust"] as CPUParticles3D).emitting = a > 0.2 and a < 3.4
		var belly: float = clampf(a / 1.8, 0.0, 1.0) * clampf((4.4 - a) / 1.0, 0.0, 1.0)
		((site["belly"] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(
			"tint", Color(0.75, 0.85, 1.0, belly if a > 0.0 else 0.0))
		if a > 1.8 and a <= 3.4:
			shuttle.position.y = 5.0 * (a - 1.8) * (a - 1.8)
		var burning: float = 0.0
		if a > 3.4 and shuttle.visible:
			var t: float = a - 3.4
			if not bool(site["ignited"]):
				site["ignited"] = true
				var yaw: float = rad_to_deg(atan2(root.position.x, 13.6 - root.position.z))
				flash(Color(1.0, 0.74, 0.5), 0.45 + 0.12 * float(level), yaw)
			if level >= 3 and t - delta < 2.6 and t >= 2.6:
				flash(Color(1.0, 0.85, 0.7), 0.35, rad_to_deg(atan2(root.position.x, 13.6 - root.position.z)))
			shuttle.rotation.x = deg_to_rad(30.0) * clampf(t / 1.5, 0.0, 1.0)
			var nose := Vector3(0.0, sin(shuttle.rotation.x), -cos(shuttle.rotation.x))
			# Slow at first, so it climbs away through the band of sky in view rather than out of it.
			shuttle.position += nose * (5.0 + 13.0 * big * t) * delta
			burning = clampf(t / 0.4, 0.0, 1.0) * big
			if shuttle.global_position.y > 260.0 or t > 11.0:
				shuttle.visible = false
		var trail: CPUParticles3D = site["trail"]
		trail.emitting = burning > 0.0
		if trail.emitting:
			# Smoke hangs in the air, so it drifts back with the ground at the scenery's speed.
			var along: float = (Highway.LENGTH / Highway.lookahead) * _speed * (1.0 + HEAT_SPEED * _heat)
			trail.direction = Vector3(0.0, 0.0, 1.0)
			trail.initial_velocity_min = along
			trail.initial_velocity_max = along * 1.1
		(site["flame"] as ShaderMaterial).set_shader_parameter("strength", 1.6 * burning)
		((site["core"] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(
			"tint", Color(1.0, 0.82, 0.55, clampf(burning, 0.0, 1.0)))
		var wash: float = clampf(a / 1.8, 0.0, 1.0) * 2.5 + (6.0 * big if a > 3.4 else 0.0) * clampf((9.0 - a) / 4.0, 0.0, 1.0)
		(site["light"] as OmniLight3D).light_energy = wash if a > 0.0 else 0.0
		if root.position.z > 45.0 and not shuttle.visible:
			_end_launch(site)


func _end_launch(site: Dictionary) -> void:
	var root: Node3D = site["root"]
	var shuttle: Node3D = site["shuttle"]
	unride(root)
	root.visible = false
	shuttle.visible = true
	shuttle.position = Vector3.ZERO
	shuttle.rotation = Vector3.ZERO
	(site["trail"] as CPUParticles3D).emitting = false
	(site["dust"] as CPUParticles3D).emitting = false
	(site["flame"] as ShaderMaterial).set_shader_parameter("strength", 0.0)
	(site["light"] as OmniLight3D).light_energy = 0.0
	site["age"] = -1.0


## Imported materials are shared by every copy of a model, so each beacon material is listed once.
func _collect_beacons(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	for s: int in mesh_instance.mesh.get_surface_count():
		var mat := mesh_instance.mesh.surface_get_material(s) as StandardMaterial3D
		if mat == null or _seen_materials.has(mat.get_instance_id()):
			continue
		if mat.resource_name.begins_with("beacon_red"):
			_red.append({"mat": mat, "base": mat.emission_energy_multiplier})
		elif mat.resource_name.begins_with("beacon_amber"):
			_amber.append({"mat": mat, "base": mat.emission_energy_multiplier})
		else:
			continue
		_seen_materials[mat.get_instance_id()] = true
