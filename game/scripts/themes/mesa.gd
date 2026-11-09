extends ThemeWorld
## Red Mesa (rock, metal, blues): canyon blacktop at dusk. Banded red mesas and buttes come round,
## saguaros, scrub and bunchgrass line the shoulders, a rusted barbed-wire fence runs on the right and
## an H-frame power line on the left, with a neon-signed motel, a gas station and a windmill now and
## then. A thunderstorm sits off to the left of the road and throws heat lightning; dust embers drift.

const LINE_SPACING := 36.0  # must match LINE_SPACING in tools/themes/mesa/props.py
const FENCE_LENGTH := 8.0  # must match FENCE_LENGTH in tools/themes/mesa/props.py
const AMBIENT_ENERGY := 0.22
const SKY_ENERGY := 0.82  # tonemapping and bloom lift the panorama; this keeps its top near-black indigo
const NEON_RED_ENERGY := 4.5  # the Blender emission strengths in props.py
const NEON_GREEN_ENERGY := 3.5
const SIGN_LIGHT_ENERGY := 2.4

var _env: Environment
var _flash_light: DirectionalLight3D
var _neon_red: BaseMaterial3D
var _neon_green: BaseMaterial3D
var _sign_lights: Array[OmniLight3D] = []
var _rng := RandomNumberGenerator.new()
var _clock: float = 0.0
var _next_flash: float = 4.0
var _flash_age: float = -1.0
var _flash_pulses: Array[Vector2] = []  # (start time, strength) of each stroke in one flash


func build() -> void:
	_rng.seed = 4040
	var world := make_environment({
		"sky": asset("textures/sky.png"),
		"ambient": Color(0.56, 0.34, 0.36), "ambient_energy": AMBIENT_ENERGY,
		"fog": Color(0.15, 0.06, 0.06), "fog_density": 0.0085,
		"light_color": Color(1.0, 0.52, 0.3), "light_energy": 0.5,
		"light_rotation": Vector3(-20, -150, 0),
	})
	_env = world.environment
	_env.background_energy_multiplier = SKY_ENERGY
	make_ground(asset("textures/ground.png"))
	make_road(asset("textures/asphalt.png"), Color(0.95, 0.9, 0.86), Color(0.95, 0.72, 0.35), 0.2)
	make_vehicle(asset("models/hood.glb"), Color(1.0, 0.86, 0.62))

	# Barbed wire close on the right, the power line further out on the left.
	var fence: Array[Vector3] = []
	for i: int in 34:
		fence.append(Vector3(road_half + 3.2, 0.0, -float(i) * FENCE_LENGTH + FENCE_LENGTH * 3.0))
	repeat(asset("models/fence.glb"), fence, FENCE_LENGTH)
	row(asset("models/powerline.glb"), -(road_half + 13.0), LINE_SPACING, 10)

	scatter(asset("models/scrub.glb"), 240, 1.6, 40.0, 48.0, 0.7, 1.5, 11)
	scatter(asset("models/grass.glb"), 420, 1.2, 32.0, 48.0, 0.8, 1.4, 12)
	scatter(asset("models/rocks.glb"), 150, 1.4, 45.0, 48.0, 0.6, 1.6, 13)
	scatter(asset("models/saguaro.glb"), 9, 6.0, 60.0, 48.0, 0.75, 1.25, 14)

	# Roadside places. The motel stays on the right and the gas station sits beyond the power line,
	# so neither runs into the line.
	landmarks([
		["water_tank", -1.0, 24.0, 30.0, 1.0], ["boulders", -1.0, 18.0, 72.0, 1.2],
		["motel", 1.0, 13.0, 112.0, 1.0], ["hoodoos", 1.0, 20.0, 160.0, 1.3],
		["gas_station", -1.0, 24.0, 205.0, 1.0], ["saguaro", 1.0, 9.0, 238.0, 1.4],
		["boulders", 1.0, 22.0, 262.0, 0.9], ["hoodoos", -1.0, 26.0, 300.0, 1.0],
		["saguaro", -1.0, 7.0, 330.0, 1.3], ["water_tank", 1.0, 26.0, 372.0, 0.9],
	])
	# The big formations come round on a longer loop, far out, emerging from the dust haze.
	landmarks([
		["mesa", 1.0, 70.0, 80.0, 1.6], ["butte", -1.0, 60.0, 190.0, 1.3],
		["mesa", -1.0, 110.0, 330.0, 2.0], ["butte", 1.0, 95.0, 450.0, 1.5],
		["mesa", 1.0, 140.0, 560.0, 2.2], ["hoodoos", -1.0, 50.0, 640.0, 2.0],
		["butte", -1.0, 130.0, 700.0, 1.8],
	], 760.0, 60.0)
	drifters(Color(1.0, 0.48, 0.18), 22, 1.4, 14.0, Vector3(2.0, 0.4, 11.0), 0.035)

	# Light spilling from the motel's neon and the gas station canopy.
	for child: Node in get_children():
		var node := child as Node3D
		if node == null:
			continue
		if node.scene_file_path.ends_with("motel.glb"):
			_sign_lights.append(_add_glow(node, Vector3(-8.0, 7.0, 14.0), Color(1.0, 0.22, 0.08), SIGN_LIGHT_ENERGY, 18.0))
		elif node.scene_file_path.ends_with("gas_station.glb"):
			_add_glow(node, Vector3(0.0, 4.4, 0.0), Color(1.0, 0.9, 0.74), 2.6, 14.0)
	_neon_red = _material("motel", "neon_red")
	_neon_green = _material("motel", "neon_green")

	# Heat lightning comes from the storm on the left; this light is dark until a flash.
	_flash_light = DirectionalLight3D.new()
	_flash_light.light_color = Color(0.78, 0.72, 1.0)
	_flash_light.light_energy = 0.0
	_flash_light.rotation_degrees = Vector3(-35, -110, 0)
	add_child(_flash_light)


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	_update_lightning(delta)
	_update_signs()


## A flash is a few quick strokes that brighten the sky, the ambient light and a side light, then die.
func _update_lightning(delta: float) -> void:
	if _clock >= _next_flash:
		_flash_age = 0.0
		_next_flash = _clock + _rng.randf_range(6.0, 14.0)
		_flash_pulses.clear()
		_flash_pulses.append(Vector2(0.0, 1.0))
		for i: int in _rng.randi_range(1, 3):
			_flash_pulses.append(Vector2(_rng.randf_range(0.08, 0.5), _rng.randf_range(0.35, 0.9)))
	var flash: float = 0.0
	if _flash_age >= 0.0:
		_flash_age += delta
		for pulse: Vector2 in _flash_pulses:
			if _flash_age >= pulse.x:
				flash += pulse.y * exp(-(_flash_age - pulse.x) * 16.0)
		if _flash_age > 1.2:
			_flash_age = -1.0
	flash = minf(flash, 1.2)
	_env.background_energy_multiplier = SKY_ENERGY + flash * 0.7
	_env.ambient_light_energy = AMBIENT_ENERGY + flash * 0.35
	_flash_light.light_energy = flash * 0.9


## VACANCY blinks steadily; MOTEL buzzes and stutters for a moment every few seconds.
func _update_signs() -> void:
	if _neon_green:
		_neon_green.emission_energy_multiplier = NEON_GREEN_ENERGY if fposmod(_clock, 1.55) < 1.1 else 0.25
	var level: float = 1.0
	if fposmod(_clock, 7.3) > 6.95:
		level = 0.15 if _rng.randf() < 0.5 else 1.0
	if _neon_red:
		_neon_red.emission_energy_multiplier = NEON_RED_ENERGY * level
	for light: OmniLight3D in _sign_lights:
		light.light_energy = SIGN_LIGHT_ENERGY * level


func _add_glow(parent: Node3D, offset: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.position = offset
	parent.add_child(light)
	return light


## A model's material by its Blender name. Imported meshes are shared, so changing it changes every copy.
func _material(model: String, material_name: String) -> BaseMaterial3D:
	var mesh: Mesh = first_mesh(asset("models/%s.glb" % model))
	for i: int in mesh.get_surface_count():
		var mat: Material = mesh.surface_get_material(i)
		if mat and mat.resource_name == material_name:
			return mat as BaseMaterial3D
	return null
