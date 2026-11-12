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
##
## The station answers the player (2026-11-11, ThemeWorld's on_* events). On a combo milestone a
## transit ship undocks from a docking arm ahead (or from the deck beside the road when none is in
## view), lights its engines and shoots away down the ring into the sky on a glowing trail, and a
## cascade of light races away along the guide-light strips and the skyway's kerb channels; bigger
## milestones launch two ships, then three, and send more cascades. A fast streak flares the solar
## wings with the sun's glint and sends a cascade; a long combo keeps the strips brighter with slow
## cascades rolling down them. Faltering makes the station's lights flicker and sag, and a maintenance
## drone ahead sparks and tumbles to the deck; getting going again steadies the lights and a
## replacement drone flies down into its place.

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
# The player's events.
const CASCADE_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec3 colour : source_color = vec3(0.55, 1.0, 0.78);
uniform float energy = 1.5;
uniform float level = 1.0;
uniform float wave_z = 1000.0;
uniform float wave = 0.0;
uniform float wave_z2 = 1000.0;
uniform float wave2 = 0.0;
varying float wz;
void vertex() {
	wz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	float w = wave * exp(-pow((wz - wave_z) / 10.0, 2.0)) + wave2 * exp(-pow((wz - wave_z2) / 10.0, 2.0));
	ALBEDO = colour * energy * (level + 3.5 * w);
}
"""
const SHIPS := 3
var _cascade: Array[ShaderMaterial] = []
var _waves: Array[float] = []  # start times of cascades still running
var _next_flow_wave: float = 0.0
var _ships: Array[Dictionary] = []
var _arms: Array[Node3D] = []
var _wings: Array[MeshInstance3D] = []
var _glint: float = 0.0
var _dome_lights: Array[Dictionary] = []
var _power: float = 1.0
var _target_power: float = 1.0
var _flick: float = 1.0
var _flick_next: float = 0.0
var _faller: Node3D
var _faller_age: float = -1.0
var _faller_spin: Vector3 = Vector3.ZERO
var _sparks: CPUParticles3D
var _alarm: MeshInstance3D
var _relief: Node3D
var _relief_age: float = -1.0
var _fx := RandomNumberGenerator.new()


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
		elif entry[0] == "docking_arm":
			_arms.append(node)
		elif entry[0] == "solar_wing":
			# The sun's glint off the blankets, shown when a streak flares the wings.
			var glint := fx_sprite(Color(1.0, 1.0, 0.92, 0.0), 18.0, 2.5)
			glint.position = Vector3(0.0, 11.0, 0.0)
			node.add_child(glint)
			_wings.append(glint)

	_station = (load(asset("models/station_hub.glb")) as PackedScene).instantiate()
	_station.position = STATION_POSITION
	_station.rotation_degrees = Vector3(8.0, 28.0, 0.0)
	_station.scale = Vector3.ONE * 1.6
	add_child(_station)

	# Motes: very dim specks drifting slowly past (their colour is their brightness: the bead is unshaded).
	drifters(Color(0.5, 0.64, 0.6), 60, 3.0, 12.0, Vector3(0.0, 0.08, 6.0), 0.03, Vector3.ZERO, 0.35)

	_build_events()
	for found: Node in find_children("*", "MeshInstance3D", true, false):
		_prepare_materials(found as MeshInstance3D)
	_cascade_strips()
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
	_update_events(delta)


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
	_dome_lights.append({"light": light, "base": energy})


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


# ---------------------------------------------------------------- answering the player

func on_milestone(level: int) -> void:
	var ships: int = 1 if level < 3 else (2 if level == 3 else 3)
	for i: int in ships:
		_launch(i, float(i) * 0.9)
	event_sound("launch", -11.0)
	for i: int in mini(level, 4):
		_waves.append(_clock + 0.25 * float(i))
	super(level)


func on_streak(strength: float) -> void:
	_glint = maxf(_glint, 0.5 + 0.5 * strength)
	_waves.append(_clock)
	super(strength * 0.4)


func on_burst(strength: float, kind: String) -> void:
	_waves.append(_clock)
	super(strength, kind)


func on_falter(severity: float) -> void:
	_target_power = minf(_target_power, 1.0 - 0.7 * severity)
	event_sound("flicker", -13.0)
	if _faller_age >= 0.0:
		return
	# A maintenance drone ahead on the left (beyond the glass, over the deck) loses it: sparks, a
	# wobble, and a tumble down onto the deck, where the drive carries it past.
	_faller.position = Vector3(-(road_half + 9.0), 0.0, -55.0)
	_faller.rotation = Vector3.ZERO
	_faller.visible = true
	ride(_faller)
	_faller_age = 0.0
	_faller_spin = Vector3(_fx.randf_range(2.0, 4.0), _fx.randf_range(-3.0, 3.0), _fx.randf_range(3.0, 6.0))
	if not calm():
		_sparks.restart()


func on_recover() -> void:
	_target_power = 1.0
	# A replacement drone flies down into its place ahead.
	_relief.position = Vector3(-(road_half + 11.0), 26.0, -110.0)
	_relief.visible = true
	ride(_relief)
	_relief_age = 0.0
	super()


func on_settle() -> void:
	_target_power = 1.0
	_power = 1.0
	_glint = 0.0
	_waves.clear()
	_faller_age = -1.0
	_faller.visible = false
	unride(_faller)
	_relief_age = -1.0
	_relief.visible = false
	unride(_relief)
	_sparks.restart()
	_sparks.emitting = false
	for ship: Dictionary in _ships:
		_park(ship)


func _build_events() -> void:
	_fx.seed = 1610
	event_tint = Color(0.75, 1.0, 0.88)
	for i: int in SHIPS:
		var root := Node3D.new()
		root.visible = false
		root.scale = Vector3.ONE * 1.6  # a big transit ship: it has to read 200 m out
		add_child(root)
		var ship: Node3D = (load(asset("models/ship.glb")) as PackedScene).instantiate()
		root.add_child(ship)
		var engines := Node3D.new()
		engines.position = Vector3(0.0, 2.1, 0.9)
		ship.add_child(engines)
		var core := fx_sprite(Color(0.65, 1.0, 0.88, 0.0), 7.0, 4.0, false)
		engines.add_child(core)
		var trail := fx_particles(fx_material("glow", 2.2, false), 280, 2.6, 2.4, fx_ramp([
			[0.0, Color(0.85, 1.0, 0.95, 1.0)], [0.3, Color(0.4, 1.0, 0.75, 0.7)], [1.0, Color(0.2, 0.6, 0.9, 0.0)]]))
		trail.spread = 3.0
		engines.add_child(trail)
		_ships.append({"root": root, "ship": ship, "core": core, "trail": trail, "age": -1.0, "delay": 0.0, "side": 1.0})
	# The drone that falls (with its sparks), and the one that replaces it: bigger than the deck's
	# own, so they read from the road.
	_faller = (load(asset("models/drone.glb")) as PackedScene).instantiate()
	_faller.scale = Vector3.ONE * 2.4
	_faller.visible = false
	add_child(_faller)
	_sparks = fx_particles(fx_material("glow", 5.0), 90, 1.2, 0.2, fx_ramp([
		[0.0, Color(1.0, 1.0, 0.9, 1.0)], [0.4, Color(0.6, 1.0, 0.8, 1.0)], [1.0, Color(0.3, 0.8, 1.0, 0.0)]]))
	_sparks.local_coords = true
	_sparks.one_shot = true
	_sparks.explosiveness = 0.5
	_sparks.position = Vector3(0.0, 4.4, 0.0)
	_sparks.spread = 180.0
	_sparks.initial_velocity_min = 1.5
	_sparks.initial_velocity_max = 4.0
	_sparks.gravity = Vector3(0.0, -4.0, 0.0)
	_faller.add_child(_sparks)
	# Its warning light, blinking red as it goes down and dying when it lands.
	_alarm = fx_sprite(Color(1.0, 0.25, 0.2, 0.0), 1.6, 4.0)
	_alarm.position = Vector3(0.0, 4.7, 0.0)
	_faller.add_child(_alarm)
	_relief = (load(asset("models/drone.glb")) as PackedScene).instantiate()
	_relief.scale = Vector3.ONE * 2.4
	_relief.visible = false
	add_child(_relief)


## The guide-light strips and the skyway's kerb channels (materials strip*) get one shared shader
## that carries cascades of light along them by world position, and dims and flickers on faltering.
func _cascade_strips() -> void:
	var made: Dictionary = {}
	for found: Node in find_children("*", "MeshInstance3D", true, false):
		var instance := found as MeshInstance3D
		if instance.mesh == null:
			continue
		for s: int in instance.mesh.get_surface_count():
			var mat := instance.mesh.surface_get_material(s) as StandardMaterial3D
			if mat == null or not mat.resource_name.begins_with("strip"):
				continue
			var key: int = mat.get_instance_id()
			if not made.has(key):
				var cascade := ShaderMaterial.new()
				var shader := Shader.new()
				shader.code = CASCADE_SHADER
				cascade.shader = shader
				cascade.set_shader_parameter("colour", mat.emission)
				cascade.set_shader_parameter("energy", mat.emission_energy_multiplier)
				made[key] = cascade
				_cascade.append(cascade)
			instance.set_surface_override_material(s, made[key])


## A ship undocks beside a docking arm in view (or from the deck ahead on the right), then lights
## its engines and leaves down the ring, climbing into the sky.
func _launch(index: int, delay: float) -> void:
	var ship: Dictionary = _ships[index]
	if float(ship["age"]) >= 0.0:
		return
	var root: Node3D = ship["root"]
	var arm: Node3D = null
	for candidate: Node3D in _arms:
		if ahead_in_view(candidate.position, -60.0, -260.0, 50.0) and (arm == null or candidate.position.z > arm.position.z):
			arm = candidate
	if arm != null and index == 0:
		var side: float = signf(arm.position.x)
		root.position = arm.position + Vector3(side * 25.0, 9.5, 6.0)
	else:
		var side: float = 1.0 if index % 2 == 0 else -1.0
		root.position = Vector3(side * (road_half + 52.0), 9.0, -160.0 - 30.0 * float(index))
	ship["side"] = signf(root.position.x)
	root.visible = true
	(ship["ship"] as Node3D).position = Vector3.ZERO
	(ship["ship"] as Node3D).rotation = Vector3.ZERO
	ride(root)
	ship["age"] = 0.0
	ship["delay"] = delay


func _park(ship: Dictionary) -> void:
	var root: Node3D = ship["root"]
	unride(root)
	root.visible = false
	(ship["trail"] as CPUParticles3D).emitting = false
	ship["age"] = -1.0


func _update_events(delta: float) -> void:
	var along: float = (Highway.LENGTH / Highway.lookahead) * _speed * (1.0 + HEAT_SPEED * _heat)
	for ship: Dictionary in _ships:
		if float(ship["age"]) < 0.0:
			continue
		ship["age"] = float(ship["age"]) + delta
		var a: float = float(ship["age"]) - float(ship["delay"])
		var body: Node3D = ship["ship"]
		var burn: float = 0.0
		if a > 0.0 and a <= 1.3:
			# Undocking: easing out sideways, away from the road, and up.
			var u: float = smoothstep(0.0, 1.3, a)
			body.position = Vector3(float(ship["side"]) * 5.0 * u, 2.5 * u, 0.0)
		elif a > 1.3:
			var t: float = a - 1.3
			if t - delta <= 0.0:
				flash(Color(0.75, 1.0, 0.9), 0.4, rad_to_deg(atan2((ship["root"] as Node3D).position.x, 60.0)))
			body.rotation.x = deg_to_rad(11.0) * clampf(t / 1.2, 0.0, 1.0)
			var nose := Vector3(0.0, sin(body.rotation.x), -cos(body.rotation.x))
			body.position += nose * (6.0 + 34.0 * t) * delta
			burn = clampf(t / 0.3, 0.0, 1.0)
			if t > 9.0:
				_park(ship)
				continue
		var trail: CPUParticles3D = ship["trail"]
		trail.emitting = burn > 0.0
		if trail.emitting:
			# The trail stays where it was laid, so it comes back past with the ring.
			trail.direction = Vector3(0.0, 0.0, 1.0)
			trail.initial_velocity_min = along
			trail.initial_velocity_max = along
		((ship["core"] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(
			"tint", Color(0.65, 1.0, 0.88, 0.25 + 0.75 * burn if a > 0.0 else 0.15))
	# Cascades race away down the strips, about 160 m a second; flow keeps slow ones rolling.
	if flow() > 0.3 and _clock >= _next_flow_wave:
		_next_flow_wave = _clock + 3.0
		_waves.append(_clock)
	var fronts: Array[float] = []
	for i: int in range(_waves.size() - 1, -1, -1):
		var age: float = _clock - _waves[i]
		if age > 2.2:
			_waves.remove_at(i)
		elif age >= 0.0 and fronts.size() < 2:
			fronts.append(age)
	_power = move_toward(_power, _target_power, delta * (1.2 if _target_power < _power else 0.5))
	if _clock >= _flick_next:
		_flick_next = _clock + _fx.randf_range(0.04, 0.12)
		var unsteady: bool = _power < 0.95 or absf(_power - _target_power) > 0.02
		_flick = _fx.randf_range(0.1, 0.6) if unsteady and _fx.randf() < 0.35 else 1.0
	var lit: float = _power * (1.0 if calm() else _flick)
	for cascade: ShaderMaterial in _cascade:
		cascade.set_shader_parameter("level", lit * (1.0 + 0.4 * flow()))
		for k: int in 2:
			var on: bool = k < fronts.size()
			cascade.set_shader_parameter("wave_z" if k == 0 else "wave_z2", 15.0 - 160.0 * fronts[k] if on else 1000.0)
			cascade.set_shader_parameter("wave" if k == 0 else "wave2", (1.0 - fronts[k] / 2.2) if on else 0.0)
	for entry: Dictionary in _dome_lights:
		(entry["light"] as OmniLight3D).light_energy = float(entry["base"]) * lit
	_glint = maxf(_glint - delta * 0.5, 0.0)
	for glint: MeshInstance3D in _wings:
		var shine: float = _glint * (0.7 + 0.3 * sin(_clock * 9.0 + glint.global_position.z * 0.1))
		glint.visible = shine > 0.01
		(glint.material_override as ShaderMaterial).set_shader_parameter("tint", Color(1.0, 1.0, 0.92, shine))
	if _faller_age >= 0.0:
		_faller_age += delta
		var f: float = _faller_age
		if f < 0.7:
			_faller.rotation = Vector3(sin(f * 30.0) * 0.12, 0.0, sin(f * 23.0) * 0.15)  # the wobble
		else:
			var g: float = f - 0.7
			_faller.rotation += _faller_spin * delta * clampf(1.0 - g / 1.4, 0.0, 1.0)
			_faller.position.y = maxf(-2.4 * 4.4 * minf(g * g * 1.2, 1.0) + 0.3, -9.9)
		var blink: float = 1.0 if fmod(f, 0.3) < 0.15 or calm() else 0.15
		(_alarm.material_override as ShaderMaterial).set_shader_parameter("tint",
			Color(1.0, 0.25, 0.2, blink * clampf((2.6 - f) / 0.4, 0.0, 1.0)))
		if _faller.position.z > 30.0:
			_faller_age = -1.0
			_faller.visible = false
			unride(_faller)
	if _relief_age >= 0.0:
		_relief_age += delta
		_relief.position.y = 26.0 * (1.0 - smoothstep(0.0, 3.0, _relief_age))
		if _relief.position.z > 30.0:
			_relief_age = -1.0
			_relief.visible = false
			unride(_relief)
