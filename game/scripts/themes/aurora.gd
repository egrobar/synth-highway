extends ThemeWorld
## Aurora Pass (classical, ballads, traditional): a snowbound mountain pass at night under green and
## violet aurora. Plough banks and orange snow poles with amber reflectors line both shoulders, a fence
## runs along the right, snowy firs climb away on both sides, and crags, a log cabin, a chapel, a stone
## viaduct (always beside the road, never over it) and distant peaks come round. Snow drifts down
## beside the road, the ambient light breathes slowly between the aurora's green and violet, and the
## snow 4x4's headlights are a cool white.

const POLE_SPACING := 16.0  # must match POLE_SPACING in tools/themes/aurora/props.py
const BANK_LENGTH := 12.0  # must match BANK_LENGTH in tools/themes/aurora/props.py
const FENCE_LENGTH := 6.0  # must match FENCE_LENGTH in tools/themes/aurora/props.py
const AMBIENT_GREEN := Color(0.32, 0.52, 0.58)
const AMBIENT_VIOLET := Color(0.44, 0.40, 0.66)

var _environment: Environment
var _clock: float = 0.0


func build() -> void:
	var world := make_environment({
		"sky": asset("textures/sky.png"),
		"ambient": AMBIENT_GREEN, "ambient_energy": 0.42,
		"fog": Color(0.035, 0.07, 0.095), "fog_density": 0.012,
		"light_color": Color(0.62, 0.9, 0.84), "light_energy": 0.42,
		"light_rotation": Vector3(-28, -16, 0),
	})
	_environment = world.environment
	make_ground(asset("textures/ground.png"), Color(0.66, 0.72, 0.82))
	make_road(asset("textures/asphalt.png"), Color(0.86, 0.9, 0.96), Color(0.8, 0.92, 1.0), 0.3)
	make_vehicle(asset("models/hood.glb"), Color(0.84, 0.93, 1.0), 24.0)

	# Shoulders: a plough bank and snow poles each side, the poles staggered half a gap.
	for side: float in [-1.0, 1.0]:
		var yaw: float = 0.0 if side > 0.0 else 180.0
		var banks: Array[Vector3] = []
		for i: int in 36:
			banks.append(Vector3(side * (road_half + 2.3), 0.0, -float(i) * BANK_LENGTH + BANK_LENGTH * 3.0))
		repeat(asset("models/snowbank.glb"), banks, BANK_LENGTH, yaw)
		var poles: Array[Vector3] = []
		var stagger: float = 0.0 if side > 0.0 else POLE_SPACING * 0.5
		for i: int in 26:
			poles.append(Vector3(side * (road_half + 1.15), 0.0, -float(i) * POLE_SPACING + POLE_SPACING * 2.0 + stagger))
		repeat(asset("models/snow_pole.glb"), poles, POLE_SPACING, yaw)
	var fence: Array[Vector3] = []
	for i: int in 70:
		fence.append(Vector3(road_half + 5.4, 0.0, -float(i) * FENCE_LENGTH + FENCE_LENGTH * 3.0))
	repeat(asset("models/fence.glb"), fence, FENCE_LENGTH)

	# The forest: small firs near the road, bigger ones and pairs behind, rocks in the drifts. The
	# camera sees only ~12 degrees of sky, so anything much taller than its eye height (8.8) down the
	# road hides the aurora: the big firs stay modest and further out. (Distant 3D peaks did exactly
	# that, so the mountains live in the sky panorama instead.)
	scatter(asset("models/pine_small.glb"), 34, 7.6, 30.0, 48.0, 0.8, 1.4, 501)
	scatter(asset("models/pine.glb"), 16, 16.0, 70.0, 48.0, 0.65, 1.0, 502)
	scatter(asset("models/pine_pair.glb"), 18, 14.0, 75.0, 48.0, 0.7, 1.0, 503)
	scatter(asset("models/rock.glb"), 46, 4.6, 45.0, 48.0, 0.6, 1.6, 504)
	landmarks([
		["crag", -1.0, 11.0, 30.0, 1.3], ["cabin", 1.0, 15.0, 66.0, 1.0], ["pine", -1.0, 8.0, 100.0, 1.3],
		["viaduct", 1.0, 10.0, 132.0, 1.0], ["crag", 1.0, 30.0, 168.0, 2.2], ["chapel", -1.0, 18.0, 190.0, 1.0],
		["crag", 1.0, 13.0, 226.0, 1.7], ["pine", 1.0, 8.0, 254.0, 1.3], ["cabin", -1.0, 16.0, 286.0, 0.9],
		["crag", -1.0, 28.0, 312.0, 2.0], ["crag", -1.0, 10.0, 340.0, 1.1], ["viaduct", -1.0, 12.0, 372.0, 0.9],
		["chapel", 1.0, 24.0, 400.0, 0.9],
	])

	# Snow: pale, small, drifting down and toward the car. The shared drifters glow like fireflies,
	# so their emission is turned down to read as flakes caught in the light.
	drifters(Color(0.8, 0.86, 0.95), 130, 5.0, 11.0, Vector3(0.6, -1.1, 8.5), 0.055, Vector3(0.0, -0.6, 0.0))
	for child: Node in get_children():
		if child is CPUParticles3D:
			var bead := (child as CPUParticles3D).mesh as PrimitiveMesh
			if bead and bead.material is StandardMaterial3D:
				(bead.material as StandardMaterial3D).emission_energy_multiplier = 1.1


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	# The aurora breathes: a slow drift of the ambient light between green and violet.
	var swell: float = 0.5 + 0.5 * sin(_clock * 0.29) * sin(_clock * 0.071 + 1.0)
	_environment.ambient_light_color = AMBIENT_GREEN.lerp(AMBIENT_VIOLET, swell * 0.6)
