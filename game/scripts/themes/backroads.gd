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

	row(asset("models/pylon.glb"), -(road_half + 7.0), PYLON_SPACING, 11)
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


## Red aviation lights flash slowly; the pads' amber edge lights breathe and jump on the beat;
## the turbines turn.
func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	_pulse = maxf(_pulse - delta * 2.5, 0.0)
	var red_level: float = 0.06 + 0.94 * pow(maxf(sin(_clock * PI * 0.8), 0.0), 12.0)
	for entry: Dictionary in _red:
		(entry["mat"] as StandardMaterial3D).emission_energy_multiplier = float(entry["base"]) * red_level
	var amber_level: float = 0.3 + 0.15 * (0.5 + 0.5 * sin(_clock * 2.2)) + 0.7 * _pulse
	for entry: Dictionary in _amber:
		(entry["mat"] as StandardMaterial3D).emission_energy_multiplier = float(entry["base"]) * amber_level
	for rotor: Dictionary in _rotors:
		(rotor["node"] as Node3D).rotation.z += delta * float(rotor["speed"])


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
