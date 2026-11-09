extends ThemeWorld
## Backroads (country, folk, Americana): a moonlit two-lane road through wheat,
## telephone poles on the left, a fence on the right, farms coming round, fireflies.

const POLE_SPACING := 24.0  # must match POLE_SPACING in tools/themes/backroads/props.py
const FENCE_LENGTH := 6.0  # must match FENCE_LENGTH in tools/themes/backroads/props.py


func build() -> void:
	make_environment({
		"sky": asset("textures/sky.png"),
		"ambient": Color(0.3, 0.38, 0.62), "ambient_energy": 0.35,
		"fog": Color(0.05, 0.075, 0.17), "fog_density": 0.011,
		"light_color": Color(0.68, 0.76, 1.0), "light_energy": 0.6,
	})
	make_ground(asset("textures/ground.png"))
	make_road(asset("textures/asphalt.png"))
	make_vehicle(asset("models/hood.glb"))
	row(asset("models/pole.glb"), -(road_half + 6.0), POLE_SPACING, 11)
	var fence: Array[Vector3] = []
	for i: int in 44:
		fence.append(Vector3(road_half + 3.6, 0.0, -float(i) * FENCE_LENGTH + FENCE_LENGTH * 3.0))
	repeat(asset("models/fence.glb"), fence, FENCE_LENGTH)
	scatter(asset("models/wheat.glb"), 560, 4.8, 30.0, 48.0)
	landmarks([
		["silo", -1.0, 26.0, 40.0, 1.0], ["tree", 1.0, 13.0, 62.0, 1.15], ["barn", 1.0, 30.0, 96.0, 1.0],
		["tree", -1.0, 15.0, 118.0, 0.95], ["sign", 1.0, 2.6, 142.0, 1.0], ["house", -1.0, 25.0, 170.0, 1.0],
		["tree", -1.0, 12.0, 196.0, 1.25], ["water_tower", 1.0, 34.0, 226.0, 1.0], ["tree", 1.0, 16.0, 252.0, 1.0],
		["barn", -1.0, 34.0, 278.0, 0.9], ["silo", 1.0, 28.0, 306.0, 0.9], ["tree", -1.0, 18.0, 334.0, 1.1],
		["house", 1.0, 24.0, 362.0, 1.0], ["tree", 1.0, 12.0, 392.0, 1.2],
	])
	drifters(Color(0.85, 1.0, 0.35), 46, 2.2, 11.0, Vector3(0.0, 0.0, 10.0))
