extends ThemeWorld
## Ring Road (region id `aurora`; classical, choral): a skyway along an orbital ring under Saturn.
##
## A clean, dark panelled road runs inside a glass-walled skyway. The glass walls lean outward,
## with a white I-section mullion every WALL_LENGTH, a handrail, and a green-white light channel
## in their kerbs;
## they stand WALL_OFFSET beyond the road edge, clear of the hood's nacelles. Beyond the glass lies
## the ring's dark metal deck: guide-light strips on both sides, a pipe conduit on the left, rows of
## solar panels on the right, maintenance drones hovering over the deck (static), and round the loop
## observation domes glowing softly inside, big solar wings, and docking arms reaching out over the
## deck with a pod docked and slow blinking green and white lights. Far off on the right another ring
## station hangs in space, turning slowly (it is fixed in place, far beyond the fog, like the sky).
##
## The sky (tools/themes/aurora/textures.py) is deep space: stars, a faint green nebula, Saturn large
## on the left with its rings sweeping up across the sky, and our own ring rising from the road's
## vanishing point and curving up to the right. The sun is behind and to the left (it lights Saturn
## from the left), so the key light is a calm white from there; the ambient is a soft green-white,
## and the fog is near-black and thin (there is no air: it only stands in for distance). Dim motes
## drift past. Nothing stands on the road: the nearest things are the wall kerbs.
##
## The props' glass is opaque out of Blender; materials named glass* are made see-through here, and
## materials named beacon_* blink here. Imported materials are shared by every copy of a model, so
## each is changed once. With high graphics on, ThemeWorld then weathers the rest (barely: this is a
## maintained station) and lays the surface maps chosen in `surfaces` on them by material name.

const WALL_LENGTH := 8.0  # must match WALL_LENGTH in tools/themes/aurora/props.py
const STRIP_LENGTH := 12.0  # must match STRIP_LENGTH in tools/themes/aurora/props.py
const CONDUIT_TILE := 16.0  # must match CONDUIT_TILE in tools/themes/aurora/props.py
const SOLAR_TILE := 16.0  # must match SOLAR_TILE in tools/themes/aurora/props.py
const WALL_OFFSET := 2.0  # the hood's nacelles reach about 1.7 past the road edge
const LOOP := 420.0  # landmark loop length, the same as ThemeWorld.landmarks()' default
## Solar fields on the right: each row's distance from the road edge, and what fills the four
## SOLAR_TILE slots of its repeating pattern: panels (s) or a gap (.).
const SOLAR_ROWS := [[17.0, "ss.s"], [22.0, "s.ss"], [27.0, "sss."]]
## The distant station: far ahead and to the right, high enough to stand clear of the horizon.
const STATION_POSITION := Vector3(300.0, 60.0, -640.0)

var _green: Array[Dictionary] = []
var _white: Array[Dictionary] = []
var _seen_materials: Dictionary = {}
var _clock: float = 0.0
var _station: Node3D


func build() -> void:
	# A maintained station: almost no dirt (a faint grey film at the very foot of things, no dust to
	# speak of) and very little procedural grain, so the plating, brushed steel and glass read crisp
	# and clean under the white sun. The surface maps carry the detail instead.
	weathering = {"grime_color": Color(0.3, 0.33, 0.34), "grime": 0.04, "grime_height": 0.7,
		"dust_color": Color(0.72, 0.76, 0.76), "dust": 0.02, "grain": 0.05, "mottle": 0.05,
		"detail_tone": 0.45, "detail_bump": 0.8}
	# Surface maps per material name (tools/themes/aurora/props.py), each with its own settings:
	#   hull_*      white hull plating: the riveted panel map at 1.2 m plates, seams and rivets crisp.
	#   deck_plate  the dark kerbs, footings and housings: smaller plates (40 cm), a little more relief.
	#   steel       brushed stainless (rails, clamps, base plates, rams): brush lines, almost no grain,
	#               which made glossy metal glitter like foil.
	#   pearl       painted white structure (mullions, trusses, frames): only a whisper of brushing.
	#   solar_cell  the grate map as a cell grid, about 15 by 30 cm cells, strongly toned.
	#   foil_*      gold blanket boxes and the gimbal drum: the membrane map as crinkled insulation.
	surfaces = {
		"hull": ["panel", 0.2, {"detail_tone": 0.4, "detail_bump": 0.9, "grain": 0.03}],
		"deck": ["panel", 0.6, {"detail_tone": 0.55, "detail_bump": 0.8, "grain": 0.04}],
		"steel": ["brushed", 0.6, {"detail_tone": 0.35, "detail_bump": 0.3, "grain": 0.02}],
		"pearl": ["brushed", 0.35, {"detail_tone": 0.12, "detail_bump": 0.12, "grain": 0.02}],
		"solar": ["grate", 0.2, {"detail_tone": 0.9, "detail_bump": 0.35, "grain": 0.0, "mottle": 0.03}],
		"foil": ["membrane", 0.8, {"detail_tone": 0.5, "detail_bump": 0.7, "grain": 0.12}],
	}
	var world := make_environment({
		"sky": asset("textures/sky.png"),
		"ambient": Color(0.62, 0.76, 0.72), "ambient_energy": 0.34,
		# Pressurised and clean: barely any haze, only enough to catch the beams.
		"haze": 0.0012, "haze_color": Color(0.2, 0.32, 0.3), "haze_glow": 0.05,
		"fog": Color(0.012, 0.02, 0.026), "fog_density": 0.0045,
		"glow": 0.8, "glow_threshold": 1.0,
		# Sunlight from behind-left and above: it lights the right side's road-facing fronts and
		# never lays a glint down the lanes ahead.
		"light_color": Color(0.95, 1.0, 0.98), "light_energy": 0.7,
		"light_rotation": Vector3(-38.0, -62.0, 0.0),
	})
	var env: Environment = world.environment
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.95

	make_ground(asset("textures/ground.png"), Color(0.74, 0.79, 0.82))
	# Satin panels: glossier, the headlights laid a white sheen down the middle lanes.
	make_road(asset("textures/road.png"), Color(0.92, 0.96, 0.96), Color(0.62, 1.0, 0.8), 0.6,
		{"roughness": 0.88, "specular": 0.25, "bump": 1.2, "grain": 0.2})
	make_vehicle(asset("models/hood.glb"), Color(0.9, 1.0, 0.96), 24.0)

	row(asset("models/wall.glb"), road_half + WALL_OFFSET, WALL_LENGTH, 48)
	row(asset("models/wall.glb"), -(road_half + WALL_OFFSET), WALL_LENGTH, 48, 180.0)
	row(asset("models/light_strip.glb"), road_half + 8.0, STRIP_LENGTH, 30)
	row(asset("models/light_strip.glb"), -(road_half + 8.0), STRIP_LENGTH, 30, 180.0)
	row(asset("models/light_strip.glb"), -(road_half + 48.0), STRIP_LENGTH, 30, 180.0)
	row(asset("models/conduit.glb"), -(road_half + 14.0), CONDUIT_TILE, 22, 180.0)
	_solar_fields()
	scatter(asset("models/drone.glb"), 5, 5.0, 45.0, 48.0, 0.8, 1.25, 909)

	# Left: domes and solar wings past the conduit. Right: docking arms reaching away from the road
	# past the solar fields, a dome and wings between them.
	for entry: Array in [
		["dome", -1.0, 26.0, 30.0, 1.0], ["solar_wing", -1.0, 34.0, 95.0, 1.0], ["dome", -1.0, 29.0, 160.0, 1.3],
		["docking_arm", -1.0, 36.0, 230.0, 1.0], ["dome", -1.0, 26.0, 300.0, 0.9], ["solar_wing", -1.0, 30.0, 370.0, 1.1],
		["docking_arm", 1.0, 36.0, 60.0, 1.0], ["solar_wing", 1.0, 40.0, 130.0, 1.2], ["dome", 1.0, 38.0, 200.0, 1.1],
		["docking_arm", 1.0, 34.0, 270.0, 1.15], ["solar_wing", 1.0, 42.0, 335.0, 1.0], ["dome", 1.0, 40.0, 400.0, 1.0],
	]:
		var node := _place(entry[0], entry[1], entry[2], entry[3], entry[4])
		if entry[0] == "dome":
			_glow(node, Vector3(0.0, 2.6, 0.0), Color(0.86, 1.0, 0.92), 13.0, 1.4)

	_station = (load(asset("models/station_hub.glb")) as PackedScene).instantiate()
	_station.position = STATION_POSITION
	_station.rotation_degrees = Vector3(8.0, 28.0, 0.0)
	_station.scale = Vector3.ONE * 1.6
	add_child(_station)

	# Motes: very dim specks drifting slowly past (their colour is their brightness: the bead is unshaded).
	drifters(Color(0.5, 0.64, 0.6), 60, 3.0, 12.0, Vector3(0.0, 0.08, 6.0), 0.03, Vector3.ZERO, 0.35)

	for found: Node in find_children("*", "MeshInstance3D", true, false):
		_prepare_materials(found as MeshInstance3D)
	# The distant station sits far beyond the fog: it keeps its own colours instead.
	for found: Node in _station.find_children("*", "MeshInstance3D", true, false):
		var mesh := (found as MeshInstance3D).mesh
		for s: int in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as BaseMaterial3D
			if mat:
				mat.disable_fog = true


## Docking and station beacons blink slowly (green and white out of step); the distant station turns.
func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	var green_level: float = 0.06 + 0.94 * pow(maxf(sin(_clock * TAU / 3.2), 0.0), 10.0)
	for entry: Dictionary in _green:
		(entry["mat"] as StandardMaterial3D).emission_energy_multiplier = float(entry["base"]) * green_level
	var white_level: float = 0.05 + 0.95 * pow(maxf(sin(_clock * TAU / 2.4 + 1.9), 0.0), 14.0)
	for entry: Dictionary in _white:
		(entry["mat"] as StandardMaterial3D).emission_energy_multiplier = float(entry["base"]) * white_level
	if _station:
		_station.rotate_object_local(Vector3.FORWARD, delta * 0.025)


## Rows of solar panels on the right, in a pattern that repeats every four slots (with gaps, so the
## rows read as separate arrays). Each row is nudged along a little so the gaps do not line up.
func _solar_fields() -> void:
	var pattern: float = SOLAR_TILE * 4.0
	var spots: Array[Vector3] = []
	for r: int in SOLAR_ROWS.size():
		var x: float = road_half + float(SOLAR_ROWS[r][0])
		var slots: String = SOLAR_ROWS[r][1]
		for rep: int in 6:
			for k: int in 4:
				if slots[k] == "s":
					spots.append(Vector3(x, 0.0, pattern - float(rep) * pattern - float(k) * SOLAR_TILE - float(r) * 5.0))
	repeat(asset("models/solar_row.glb"), spots, pattern)


## Like landmarks(), but returns the node so lights can be attached.
## Left-side props are turned round so their road face (-X in Blender) faces the road.
func _place(model: String, side: float, from_edge: float, along: float, size: float) -> Node3D:
	var node: Node3D = (load(asset("models/%s.glb" % model)) as PackedScene).instantiate()
	node.position.x = side * (road_half + from_edge)
	node.scale = Vector3.ONE * size
	node.rotation_degrees.y = 0.0 if side > 0.0 else 180.0
	add_child(node)
	_looped.append({"node": node, "along": along, "loop": LOOP, "near": 18.0})
	return node


## Soft light inside a dome (scenery light, not dimmed by the fuel gauge).
func _glow(node: Node3D, at: Vector3, colour: Color, reach: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = colour
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.light_energy = energy
	light.position = at
	node.add_child(light)


## Glass becomes see-through (the skyway walls barely there, the domes a little more frosted);
## beacons are listed for blinking.
func _prepare_materials(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	for s: int in mesh_instance.mesh.get_surface_count():
		var mat := mesh_instance.mesh.surface_get_material(s) as StandardMaterial3D
		if mat == null or _seen_materials.has(mat.get_instance_id()):
			continue
		_seen_materials[mat.get_instance_id()] = true
		var key: String = mat.resource_name
		if key.begins_with("glass"):
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			# Faint and barely specular: brighter, the near panes read as milky green sheets.
			mat.roughness = 0.12
			mat.metallic_specular = 0.45
			if key.begins_with("glass_dome"):
				mat.albedo_color = Color(0.7, 0.92, 0.85, 0.28)
				mat.emission_enabled = true
				mat.emission = Color(0.55, 0.9, 0.75)
				mat.emission_energy_multiplier = 0.12
			else:
				mat.albedo_color = Color(0.6, 0.84, 0.8, 0.06)
		elif key.begins_with("beacon_green"):
			_green.append({"mat": mat, "base": mat.emission_energy_multiplier})
		elif key.begins_with("beacon_white"):
			_white.append({"mat": mat, "base": mat.emission_energy_multiplier})
