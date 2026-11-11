extends ThemeWorld
## Io Burn (region id `mesa`; alt, punk, the strange stuff): a volcanic moon at night under Jupiter.
##
## A black basalt road paved in hexagonal column tops runs across sulphur-yellow plains. A lava
## river runs beside it on the right, glowing and lighting its banks; a second one far out on the
## left. Heavy cable pylons march down the left, hazard bollards line both shoulders, and lava-vent
## fissures open beside the road now and then. Round the loop come basalt crags, cliffs of basalt
## columns, spatter cones with lava fountains, drill rigs and an ore smelter with warning beacons,
## and a radiation-hazard sign gantry (always beside the road on the right, never over it). Far
## out, umbrella plumes stand against the stars. Sulphur rocks, crystals and little glowing
## fumaroles are scattered over the plain, and dim embers drift past.
##
## Jupiter, huge and banded, hangs over the left of the road in the sky panorama
## (tools/themes/mesa/textures.py); its light is the key light, from ahead and to the left.
## The lava breathes, the plumes swell and fade, the red aviation lights flash slowly and the amber
## warning beacons strobe. Every so often an eruption somewhere ahead throws an orange flash over
## the scene: the sky, the ambient light and the plumes flare, then die away.
##
## High detail (2026-11-10): the props are faceted, fractured rock and real plant (props.py), and
## `weathering` / `surfaces` below give them their surfaces: sulphur frost on every upward face,
## soot low down, rock maps on basalt, crust and sulphur, brushed steel, riveted cladding. The lava
## river, fissures, crystals and vents cast no shadows (flat or glowing; they only cost shadow passes).

const PYLON_SPACING := 32.0  # must match PYLON_SPACING in tools/themes/mesa/props.py
const LAVA_TILE := 24.0  # must match LAVA_TILE in tools/themes/mesa/props.py
const BOLLARD_SPACING := 12.0  # must match BOLLARD_SPACING in tools/themes/mesa/props.py
const LOOP := 420.0  # the near landmarks' loop, the same as ThemeWorld.landmarks()' default
const FAR_LOOP := 760.0  # the far landmarks come round on a longer loop, fading in from the dark
const AMBIENT_ENERGY := 0.3
const SKY_ENERGY := 1.0
const LAVA_LIGHT := Color(1.0, 0.42, 0.12)
const RIVER_X := 15.0  # the right lava river's centre, from the road edge
const PYLON_X := 12.0  # the pylons' centre line, from the road edge (their footings stay clear of the fissures)

var _env: Environment
var _flash_light: DirectionalLight3D
var _lava: Array[Dictionary] = []
var _vents: Array[Dictionary] = []
var _plumes: Array[Dictionary] = []
var _red: Array[Dictionary] = []
var _amber: Array[Dictionary] = []
var _glows: Array[Dictionary] = []  # scenery lights that breathe with the lava
var _seen_materials: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _clock: float = 0.0
var _pulse: float = 0.0
var _next_eruption: float = 5.0
var _eruption_age: float = -1.0
var _eruption_strength: float = 1.0
var _flash: float = 0.0


func build() -> void:
	# Sulphur frost settles on upward faces, soot from the vents darkens everything low down.
	weathering = {"grime_color": Color(0.075, 0.062, 0.055), "grime": 0.6, "grime_height": 1.8,
		"dust_color": Color(0.88, 0.74, 0.28), "dust": 0.5, "grain": 0.32, "mottle": 0.16,
		"detail_tone": 0.6, "detail_bump": 1.0}
	# Surface maps by material name (tools/themes/mesa/props.py), each tuned on its own: rock reads
	# fractured and pitted; bare steel gets fine brushing but little grain (at the region-wide grain
	# glossy metal glitters like foil); the plant's cladding is riveted plate; hazard paint, glazed
	# insulators and sign ink stay smooth.
	surfaces = {
		"basalt": ["rock", 0.3, {"grain": 0.45, "detail_bump": 1.4, "detail_tone": 0.7}],
		"crust": ["rock", 0.45, {"grain": 0.5, "detail_bump": 1.3}],
		"sulphur": ["rock", 0.8, {"grain": 0.35, "detail_tone": 0.45, "dust": 0.15}],
		"frost": ["ice", 0.8, {"grain": 0.1, "dust": 0.0}],
		"steel": ["brushed", 0.6, {"grain": 0.06, "detail_bump": 0.35, "detail_tone": 0.3}],
		"hull": ["panel", 0.4, {"grain": 0.1, "detail_bump": 0.9, "detail_tone": 0.55}],
		"hazard": ["", 0.0, {"grain": 0.18, "mottle": 0.25}],
		"concrete": ["concrete", 0.3, {"grain": 0.35}],
		"insulator": ["", 0.0, {"grain": 0.0, "mottle": 0.05, "dust": 0.1}],
		"sign": ["", 0.0, {"grain": 0.04}],
	}
	_rng.seed = 4040
	var world := make_environment({
		"sky": asset("textures/sky.png"),
		"ambient": Color(0.64, 0.54, 0.44), "ambient_energy": AMBIENT_ENERGY,
		"haze": 0.0025, "haze_color": Color(0.3, 0.16, 0.06), "haze_glow": 0.12,
		# No air on Io: only a thin dark haze, so far things stay sharp and the plumes stand out.
		"fog": Color(0.07, 0.035, 0.05), "fog_density": 0.006,
		"glow": 0.9, "glow_threshold": 1.0,
		# Jupiter-shine from ahead-left and fairly high (Jupiter hangs left of the road), so it
		# never lays a glint straight down the lanes.
		# Bright enough that the sulphur reads yellow, not khaki.
		"light_color": Color(1.0, 0.88, 0.7), "light_energy": 0.8,
		"light_rotation": Vector3(-24.0, 198.0, 0.0),
	})
	_env = world.environment
	_env.background_energy_multiplier = SKY_ENERGY
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.08

	make_ground(asset("textures/ground.png"))
	# Matt basalt: a sheen would lay the headlights down the middle lanes, where notes arrive.
	make_road(asset("textures/road.png"), Color(0.86, 0.84, 0.88), Color(1.0, 0.78, 0.16), 0.6,
		{"roughness": 0.9, "specular": 0.25, "bump": 2.2, "grain": 0.5})
	make_vehicle(asset("models/hood.glb"), Color(1.0, 0.9, 0.74), 26.0)

	row(asset("models/pylon.glb"), -(road_half + PYLON_X), PYLON_SPACING, 11)
	row(asset("models/bollard.glb"), road_half + 2.2, BOLLARD_SPACING, 28)
	row(asset("models/bollard.glb"), -(road_half + 2.2), BOLLARD_SPACING, 28, 180.0)
	# The near river lights its banks: one light per tile, riding with the tiles as they wrap.
	var river := row(asset("models/lava_river.glb"), road_half + RIVER_X, LAVA_TILE, 22)
	for tile: Node in river.get_children():
		_glow(tile as Node3D, Vector3(0.0, 1.6, 0.0), LAVA_LIGHT, 13.0, 1.5)
	_no_shadows(river)
	_no_shadows(row(asset("models/lava_river.glb"), -(road_half + 46.0), LAVA_TILE, 22, 180.0))

	scatter(asset("models/sulphur_rock.glb"), 170, 3.0, 70.0, 48.0, 0.7, 1.8, 4041)
	# The crystals glow and the vents are low mounds: neither casts a shadow worth its pass (the
	# hull-faceted scatter barely simplifies with distance, so its shadow draws are not cheap).
	_no_shadows(scatter(asset("models/crystal.glb"), 90, 3.0, 40.0, 48.0, 0.8, 1.6, 4043))
	_no_shadows(scatter(asset("models/vent.glb"), 10, 7.0, 70.0, 48.0, 0.8, 1.5, 4045))

	# Near loop. Right: the gantry and fissures by the road, everything else past the river.
	# Left: fissures inside the pylon line, the rest past it.
	for entry: Array in [
		["fissure", -1.0, 4.5, 20.0, 1.0], ["drill_rig", -1.0, 24.0, 48.0, 1.0], ["crag", -1.0, 23.0, 95.0, 1.0],
		["spatter_cone", -1.0, 31.0, 140.0, 1.0], ["fissure", -1.0, 4.5, 175.0, 1.1], ["smelter", -1.0, 26.0, 210.0, 1.0],
		["columns", -1.0, 22.0, 262.0, 1.1], ["fissure", -1.0, 4.8, 300.0, 0.9], ["drill_rig", -1.0, 28.0, 330.0, 1.1],
		["spatter_cone", -1.0, 33.0, 385.0, 0.8],
		["hazard_gantry", 1.0, 5.0, 70.0, 1.0], ["columns", 1.0, 27.0, 30.0, 1.0], ["spatter_cone", 1.0, 33.0, 112.0, 1.1],
		["fissure", 1.0, 5.0, 150.0, 1.0], ["smelter", 1.0, 34.0, 185.0, 1.0], ["crag", 1.0, 27.0, 238.0, 1.2],
		["hazard_gantry", 1.0, 5.0, 280.0, 1.0], ["drill_rig", 1.0, 31.0, 300.0, 1.0], ["fissure", 1.0, 5.0, 352.0, 1.2],
		["crag", 1.0, 29.0, 395.0, 0.9],
	]:
		_dress(_place(entry[0], entry[1], entry[2], entry[3], entry[4], LOOP, 18.0), entry[0])
	# Far loop: plumes against the stars, big crags and columns, cones further out.
	for entry: Array in [
		["plume", -1.0, 170.0, 60.0, 1.3], ["crag", 1.0, 70.0, 110.0, 2.4], ["columns", -1.0, 64.0, 180.0, 2.6],
		["plume", 1.0, 200.0, 250.0, 1.6], ["spatter_cone", -1.0, 80.0, 300.0, 2.0], ["crag", -1.0, 90.0, 380.0, 2.8],
		["plume", -1.0, 240.0, 470.0, 1.8], ["columns", 1.0, 80.0, 520.0, 2.4], ["spatter_cone", 1.0, 95.0, 600.0, 2.2],
		["plume", 1.0, 160.0, 680.0, 1.2], ["crag", 1.0, 120.0, 730.0, 3.0],
	]:
		_dress(_place(entry[0], entry[1], entry[2], entry[3], entry[4], FAR_LOOP, 60.0), entry[0])

	# Embers: dim (their colour is their brightness, as the bead is unshaded), rising as they drift past.
	drifters(Color(1.0, 0.45, 0.12), 50, 1.8, 14.0, Vector3(0.4, 1.0, 9.0), 0.03, Vector3(0.0, 0.25, 0.0), 1.4)

	# The eruptions' flash: dark until one goes off somewhere ahead.
	_flash_light = DirectionalLight3D.new()
	_flash_light.light_color = Color(1.0, 0.5, 0.18)
	_flash_light.light_energy = 0.0
	_flash_light.rotation_degrees = Vector3(-12.0, 180.0, 0.0)
	add_child(_flash_light)

	for found: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance and mesh_instance.mesh:
			_collect(mesh_instance.mesh)
	for found: Node in find_children("*", "MultiMeshInstance3D", true, false):
		var multi := found as MultiMeshInstance3D
		if multi and multi.multimesh and multi.multimesh.mesh:
			_collect(multi.multimesh.mesh)


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	_pulse = maxf(_pulse - delta * 2.5, 0.0)
	_update_eruption(delta)
	# Lava breathes slowly, swells a touch on the beat and flares with an eruption.
	var lava_level: float = 0.9 + 0.07 * sin(_clock * 1.3) + 0.03 * sin(_clock * 3.7) + 0.12 * _pulse + 0.35 * _flash
	_set_levels(_lava, lava_level)
	_set_levels(_vents, 0.75 + 0.25 * absf(sin(_clock * 2.1 + sin(_clock * 0.7))) + 0.4 * _flash)
	_set_levels(_plumes, 0.7 + 0.3 * (0.5 + 0.5 * sin(_clock * TAU / 7.0)) + 1.3 * _flash)
	for entry: Dictionary in _glows:
		(entry["light"] as OmniLight3D).light_energy = float(entry["base"]) * lava_level
	# Red aviation lights flash slowly; the amber warning beacons strobe.
	_set_levels(_red, 0.06 + 0.94 * pow(maxf(sin(_clock * PI * 0.8), 0.0), 12.0))
	_set_levels(_amber, 0.08 + 0.92 * pow(maxf(sin(_clock * TAU * 0.9), 0.0), 16.0))


func on_beat(strength: float) -> void:
	_pulse = maxf(_pulse, strength)


## An eruption somewhere ahead: a fast orange flare with a second burst just after, fading over a
## couple of seconds. It brightens the sky, the ambient light and a side light, and the plumes flare.
func _update_eruption(delta: float) -> void:
	if _clock >= _next_eruption:
		_eruption_age = 0.0
		_next_eruption = _clock + _rng.randf_range(9.0, 18.0)
		_eruption_strength = _rng.randf_range(0.6, 1.0)
		_flash_light.rotation_degrees = Vector3(-10.0, _rng.randf_range(150.0, 210.0), 0.0)
	_flash = 0.0
	if _eruption_age >= 0.0:
		_eruption_age += delta
		var a: float = _eruption_age
		_flash = _eruption_strength * (1.0 - exp(-a * 20.0)) * exp(-a * 1.5)
		if a > 0.4:
			_flash += _eruption_strength * 0.5 * exp(-(a - 0.4) * 3.5)
		if a > 4.0:
			_eruption_age = -1.0
	_env.background_energy_multiplier = SKY_ENERGY * (1.0 + 0.3 * _flash)
	_env.ambient_light_energy = AMBIENT_ENERGY + 0.25 * _flash
	_flash_light.light_energy = _flash * 1.3


func _set_levels(entries: Array[Dictionary], level: float) -> void:
	for entry: Dictionary in entries:
		(entry["mat"] as StandardMaterial3D).emission_energy_multiplier = float(entry["base"]) * level


## Like landmarks(), but returns the node so lights can be attached. Left-side props are turned round
## so their road face (-X in Blender) faces the road.
func _place(model: String, side: float, from_edge: float, along: float, size: float, loop: float, near: float) -> Node3D:
	var node: Node3D = (load(asset("models/%s.glb" % model)) as PackedScene).instantiate()
	node.position.x = side * (road_half + from_edge)
	node.scale = Vector3.ONE * size
	node.rotation_degrees.y = 0.0 if side > 0.0 else 180.0
	add_child(node)
	_looped.append({"node": node, "along": along, "loop": loop, "near": near})
	return node


## The lights a landmark throws on the ground round it (Blender (x, y, z) is Godot (x, z, -y)).
func _dress(node: Node3D, model: String) -> void:
	match model:
		"fissure":
			_glow(node, Vector3(0.0, 1.0, 0.0), LAVA_LIGHT, 10.0, 1.6)
			_no_shadows(node)
		"spatter_cone":
			_glow(node, Vector3(0.0, 9.0, 0.0), LAVA_LIGHT, 24.0, 2.2)
		"smelter":
			_glow(node, Vector3(-6.0, 1.6, 2.0), LAVA_LIGHT, 12.0, 2.0)
		"drill_rig":
			_glow(node, Vector3(0.0, 2.6, 0.0), LAVA_LIGHT, 9.0, 1.4)
		"hazard_gantry":
			_glow(node, Vector3(0.0, 5.0, 1.6), Color(1.0, 0.86, 0.55), 7.0, 0.8, false)
		"plume":
			_glow(node, Vector3(0.0, 6.0, 0.0), LAVA_LIGHT, 40.0, 2.5)


## Light spilling from lava or a lamp onto the ground (scenery light, not dimmed by the fuel gauge).
## Lava lights breathe with the lava.
func _glow(node: Node3D, at: Vector3, colour: Color, reach: float, energy: float, breathes: bool = true) -> void:
	var light := OmniLight3D.new()
	light.light_color = colour
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.light_energy = energy
	light.position = at
	node.add_child(light)
	if breathes:
		_glows.append({"light": light, "base": energy})


## Low, flat, glowing ground features (the lava river tiles, fissures) cast nothing worth a shadow
## pass: 44 river tiles of four surfaces each were drawn again for every shadow split.
func _no_shadows(root: Node) -> void:
	var found: Array[Node] = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		found.append(root)  # a scatter is itself the MultiMeshInstance3D
	for node: Node in found:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Imported materials are shared by every copy of a model, so each one is listed once.
func _collect(mesh: Mesh) -> void:
	for s: int in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s) as StandardMaterial3D
		if mat == null or _seen_materials.has(mat.get_instance_id()):
			continue
		var entry := {"mat": mat, "base": mat.emission_energy_multiplier}
		var mat_name: String = mat.resource_name
		if mat_name.begins_with("lava"):
			_lava.append(entry)
		elif mat_name.begins_with("vent_glow"):
			_vents.append(entry)
		elif mat_name.begins_with("plume"):
			_plumes.append(entry)
			# The plumes' veil and outer jets are glowing gas: added over the sky, seen from inside
			# too. Drawn solid, the umbrella plumes read as giant mushrooms.
			if not mat_name.begins_with("plume_hot"):
				mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		elif mat_name.begins_with("beacon_red"):
			_red.append(entry)
		elif mat_name.begins_with("beacon_amber"):
			_amber.append(entry)
		else:
			continue
		_seen_materials[mat.get_instance_id()] = true
