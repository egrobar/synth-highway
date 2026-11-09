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

const LAMP_SPACING := 20.0  # must match LAMP_SPACING in tools/themes/neon/props.py
const BARRIER_LENGTH := 5.0  # must match BARRIER_LENGTH in tools/themes/neon/props.py
const DECK_LENGTH := 30.0  # must match DECK_LENGTH in tools/themes/neon/props.py
const GANTRY_ROAD_HALF := 8.4  # the gantry model is built for this road half-width; it is stretched to fit
const STREET_LEVEL := -26.0  # the city floor, far below the freeway deck
const LOOP := 420.0  # landmark loop length, the same as ThemeWorld.landmarks()' default

var _signs: Array[Dictionary] = []
var _glitch := RandomNumberGenerator.new()
var _clock: float = 0.0


func build() -> void:
	_glitch.seed = 2077
	var world := make_environment({
		"sky": asset("textures/sky.png"),
		"ambient": Color(0.42, 0.3, 0.7), "ambient_energy": 0.32,
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
	var road := make_road(asset("textures/asphalt.png"), Color(0.72, 0.72, 0.84), Color(1.0, 0.18, 0.72), 2.2)
	var wet := road.material_override as StandardMaterial3D
	wet.roughness = 1.0
	wet.roughness_texture = load(asset("textures/asphalt_rough.png"))
	wet.metallic_specular = 0.75
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
		row(asset("models/barrier.glb"), side * (road_half + 1.4), BARRIER_LENGTH, 64, yaw)
		var lamps := row(asset("models/lamp.glb"), side * (road_half + 2.6), LAMP_SPACING, 16, yaw)
		for lamp: Node in lamps.get_children():
			var pool := OmniLight3D.new()
			pool.light_color = Color(1.0, 0.72, 0.95)
			pool.omni_range = 15.0
			pool.omni_attenuation = 1.4
			pool.light_energy = 1.4
			pool.position = Vector3(-2.45, 10.0, 0.0)
			(lamp as Node3D).add_child(pool)
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
		for entry: Dictionary in sign["mats"]:
			(entry["mat"] as StandardMaterial3D).emission_energy_multiplier = float(entry["base"]) * level
		(sign["light"] as OmniLight3D).light_energy = float(sign["energy"]) * level


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
				mats.append({"mat": own, "base": own.emission_energy_multiplier})
	var energy: float = 3.0
	light.light_energy = energy
	_signs.append({"mats": mats, "light": light, "energy": energy, "until": 0.0,
		"next": _glitch.randf_range(1.0, 6.0)})
