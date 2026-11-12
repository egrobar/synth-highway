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
## The world answers the player (2026-11-11, ThemeWorld's on_* events). A volcano stands on the
## horizon ahead and to the right, smoking quietly. On a combo milestone it erupts for real: a lava
## fountain, an ash column lit orange from below, glowing bombs arcing out over its flanks, the
## eruption flash, its rivulets and crater flaring; each milestone bigger than the last. A fast
## streak sends lava surging down the river beside the road, spurting as it goes, and the vents
## flare; a long combo keeps the crater fountaining. Faltering chokes the plumes, lava and vents dark
## while the volcano coughs black smoke, and a drill rig in view throws sparks and slumps; when the
## player gets going again the rig rights itself and the fire comes back.
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
## The volcano: ahead and to the right (Jupiter hangs left), beyond the far landmarks' loop so none of
## them drives through it, and hung like the sky (it never comes nearer). Its summit sits about six
## degrees over the horizon, in the band of sky above the scenery, well clear of the note lanes.
const VOLCANO_POSITION := Vector3(330.0, 0.0, -760.0)
const VOLCANO_SCALE := 2.4
const CRATER_HEIGHT := 30.0  # the crater floor in volcano.glb (tools/themes/mesa/props.py), unscaled
const VOLCANO_YAW := 23.0  # degrees right of straight ahead, for the eruption flash
const VOLCANO_LIGHT := Color(1.0, 0.45, 0.12)

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
# The volcano and the player's events.
var _volcano_glow: Array[Dictionary] = []
var _fountain: CPUParticles3D
var _bombs: CPUParticles3D
var _ash: CPUParticles3D
var _wisp: CPUParticles3D
var _soot: CPUParticles3D
var _trickle: CPUParticles3D
var _crater_light: OmniLight3D
var _volcano_age: float = -1.0
var _volcano_level: int = 1
var _volcano_heat: float = 0.0
var _volcano_target: float = 0.0
var _trickle_until: float = 0.0
var _surge: float = 0.0
var _river_spurts: CPUParticles3D
var _choke: float = 0.0
var _target_choke: float = 0.0
var _rigs: Array[Node3D] = []
var _slumped: Array[Node3D] = []
var _sparks: CPUParticles3D
var _sparks_until: float = 0.0


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
	event_tint = Color(1.0, 0.55, 0.2)
	_build_volcano()
	_build_event_effects()

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
	_update_events(delta)
	# Lava breathes slowly, swells a touch on the beat and flares with an eruption; a streak surges it,
	# faltering chokes it (and the vents and plumes) dark.
	var lava_level: float = ((0.9 + 0.07 * sin(_clock * 1.3) + 0.03 * sin(_clock * 3.7) + 0.12 * _pulse + 0.35 * _flash
		+ 0.9 * _surge) * (1.0 - 0.65 * _choke))
	_set_levels(_lava, lava_level)
	_set_levels(_vents, (0.75 + 0.25 * absf(sin(_clock * 2.1 + sin(_clock * 0.7))) + 0.4 * _flash + 0.7 * _surge)
		* (1.0 - 0.65 * _choke))
	_set_levels(_plumes, (0.7 + 0.3 * (0.5 + 0.5 * sin(_clock * TAU / 7.0)) + 1.3 * _flash) * (1.0 + 0.4 * flow())
		* (1.0 - 0.8 * _choke))
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
	# Faltering chokes the fires, and the whole scene goes a little darker with them.
	_env.background_energy_multiplier = SKY_ENERGY * (1.0 + 0.3 * _flash) * (1.0 - 0.2 * _choke)
	_env.ambient_light_energy = (AMBIENT_ENERGY + 0.25 * _flash) * (1.0 - 0.3 * _choke)
	_flash_light.light_energy = _flash * 1.3


## The volcano on the horizon and its eruption: emitters at the crater (not under the scaled mountain,
## so sizes and speeds are plain metres). Everything there is fog-free, as the sky is: 800 m out, the
## distance fog would swallow it whole. Nothing there casts a shadow.
func _build_volcano() -> void:
	var volcano: Node3D = (load(asset("models/volcano.glb")) as PackedScene).instantiate()
	volcano.position = VOLCANO_POSITION
	volcano.scale = Vector3.ONE * VOLCANO_SCALE
	volcano.rotation_degrees.y = 200.0
	add_child(volcano)
	_no_shadows(volcano)
	for found: Node in volcano.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (found as MeshInstance3D).mesh
		for s: int in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as StandardMaterial3D
			if mat:
				mat.disable_fog = true  # also keeps the weathering pass off it: too far for detail
				# Dimmed a little instead: free of the fog, it would stand out of the haze too sharply.
				mat.albedo_color = mat.albedo_color.darkened(0.3)
	_volcano_glow = emissive_materials(["volcano_lava", "volcano_crater"], volcano)
	var crater := Node3D.new()
	crater.position = VOLCANO_POSITION + Vector3(0.0, CRATER_HEIGHT * VOLCANO_SCALE, 0.0)
	add_child(crater)
	# The lava fountain: hot beads thrown up out of the crater and falling back on the cone.
	_fountain = fx_particles(fx_material("glow", 3.2, false), 280, 3.2, 7.5, fx_ramp([
		[0.0, Color(1.0, 0.78, 0.4, 1.0)], [0.3, Color(1.0, 0.45, 0.08, 1.0)], [1.0, Color(0.7, 0.12, 0.02, 0.0)]]))
	_fountain.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fountain.emission_sphere_radius = 9.0
	_fountain.direction = Vector3.UP
	_fountain.spread = 15.0
	_fountain.initial_velocity_min = 38.0
	_fountain.initial_velocity_max = 62.0
	_fountain.gravity = Vector3(0.0, -26.0, 0.0)
	_fountain.scale_amount_min = 0.6
	_fountain.scale_amount_max = 1.5
	crater.add_child(_fountain)
	# Bombs: big glowing clots arcing out over the flanks.
	_bombs = fx_particles(fx_material("glow", 5.0, false), 40, 5.5, 9.0, fx_ramp([
		[0.0, Color(1.0, 0.95, 0.7, 1.0)], [0.5, Color(1.0, 0.45, 0.1, 1.0)], [1.0, Color(0.6, 0.1, 0.02, 0.0)]]))
	_bombs.one_shot = true
	_bombs.explosiveness = 0.85
	_bombs.direction = Vector3.UP
	_bombs.spread = 38.0
	_bombs.initial_velocity_min = 42.0
	_bombs.initial_velocity_max = 72.0
	_bombs.gravity = Vector3(0.0, -22.0, 0.0)
	_bombs.scale_amount_min = 0.5
	_bombs.scale_amount_max = 1.3
	crater.add_child(_bombs)
	# The ash column: puffs that start hot (lit from below by the fountain) and cool to dark ash as
	# they climb and spread.
	# Many small puffs stack into a column; a few big ones read as grey discs.
	_ash = fx_particles(fx_material("smoke", 1.0, false), 130, 9.0, 15.0, fx_ramp([
		[0.0, Color(1.0, 0.6, 0.2, 0.0)], [0.04, Color(1.0, 0.55, 0.18, 0.95)], [0.25, Color(0.72, 0.33, 0.14, 0.9)],
		[0.55, Color(0.3, 0.17, 0.12, 0.8)], [1.0, Color(0.12, 0.09, 0.08, 0.0)]]))
	_ash.direction = Vector3.UP
	_ash.spread = 9.0
	# Slow enough that the column builds in view rather than shooting off the top of the screen.
	_ash.initial_velocity_min = 9.0
	_ash.initial_velocity_max = 14.0
	_ash.damping_min = 0.4
	_ash.damping_max = 0.8
	_ash.gravity = Vector3(1.5, 0.5, 0.0)
	var swell := Curve.new()
	swell.max_value = 4.0
	swell.add_point(Vector2(0.0, 0.6))
	swell.add_point(Vector2(1.0, 3.0))
	_ash.scale_amount_curve = swell
	_ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_ash.emission_sphere_radius = 8.0
	crater.add_child(_ash)
	# At rest a thin wisp of fume, so it reads as alive; choked, thick black soot.
	_wisp = fx_particles(fx_material("smoke", 1.0, false), 20, 10.0, 11.0, fx_ramp([
		[0.0, Color(0.5, 0.26, 0.14, 0.0)], [0.12, Color(0.42, 0.24, 0.15, 0.22)], [1.0, Color(0.2, 0.15, 0.13, 0.0)]]))
	_wisp.direction = Vector3(0.15, 1.0, 0.0)
	_wisp.spread = 8.0
	_wisp.initial_velocity_min = 4.0
	_wisp.initial_velocity_max = 6.0
	_wisp.scale_amount_curve = swell
	_wisp.preprocess = 10.0
	crater.add_child(_wisp)
	_wisp.emitting = true  # only once it is in the tree: its preprocess reads its global transform
	_soot = fx_particles(fx_material("smoke", 1.0, false), 70, 9.0, 16.0, fx_ramp([
		[0.0, Color(0.2, 0.15, 0.12, 0.0)], [0.08, Color(0.2, 0.15, 0.13, 0.85)], [1.0, Color(0.12, 0.1, 0.09, 0.0)]]))
	_soot.direction = Vector3(0.2, 1.0, 0.0)
	_soot.spread = 14.0
	_soot.initial_velocity_min = 8.0
	_soot.initial_velocity_max = 12.0
	_soot.scale_amount_curve = swell
	crater.add_child(_soot)
	# A long combo keeps a small fountain going.
	_trickle = fx_particles(fx_material("glow", 4.0, false), 60, 2.4, 4.5, fx_ramp([
		[0.0, Color(1.0, 0.8, 0.45, 1.0)], [1.0, Color(0.8, 0.2, 0.03, 0.0)]]))
	_trickle.direction = Vector3.UP
	_trickle.spread = 12.0
	_trickle.initial_velocity_min = 18.0
	_trickle.initial_velocity_max = 30.0
	_trickle.gravity = Vector3(0.0, -26.0, 0.0)
	_trickle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trickle.emission_sphere_radius = 5.0
	crater.add_child(_trickle)
	# The fire lights the mountain's own flanks (its range ends well short of the road).
	_crater_light = OmniLight3D.new()
	_crater_light.light_color = VOLCANO_LIGHT
	_crater_light.omni_range = 280.0
	_crater_light.omni_attenuation = 1.2
	_crater_light.light_energy = 0.0
	_crater_light.position = Vector3(0.0, 14.0, 30.0)
	crater.add_child(_crater_light)


## Near the road: lava spurting out of the river on a streak, and sparks for a failing drill rig.
func _build_event_effects() -> void:
	_river_spurts = fx_particles(fx_material("glow", 3.5), 110, 1.0, 0.55, fx_ramp([
		[0.0, Color(1.0, 0.85, 0.45, 1.0)], [0.6, Color(1.0, 0.4, 0.08, 1.0)], [1.0, Color(0.7, 0.12, 0.02, 0.0)]]))
	_river_spurts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_river_spurts.emission_box_extents = Vector3(2.4, 0.2, 60.0)
	_river_spurts.position = Vector3(road_half + RIVER_X, 0.4, -75.0)
	_river_spurts.spread = 9.0
	_river_spurts.gravity = Vector3(0.0, -14.0, 0.0)
	_river_spurts.scale_amount_min = 0.5
	_river_spurts.scale_amount_max = 1.4
	add_child(_river_spurts)
	_sparks = fx_particles(fx_material("glow", 5.0), 90, 1.3, 0.28, fx_ramp([
		[0.0, Color(1.0, 0.95, 0.75, 1.0)], [0.4, Color(1.0, 0.6, 0.15, 1.0)], [1.0, Color(0.9, 0.25, 0.05, 0.0)]]))
	_sparks.local_coords = true  # they ride with the rig they fall from
	_sparks.direction = Vector3.UP
	_sparks.spread = 80.0
	_sparks.initial_velocity_min = 5.0
	_sparks.initial_velocity_max = 13.0
	_sparks.gravity = Vector3(0.0, -12.0, 0.0)
	add_child(_sparks)


# ---------------------------------------------------------------- answering the player

func on_milestone(level: int) -> void:
	_volcano_level = mini(level, 5)
	_volcano_age = 0.0
	_volcano_target = 1.0 + 0.2 * float(_volcano_level)
	event_sound("erupt", -10.0)
	var bigger: float = float(_volcano_level - 1) / 4.0
	_fountain.initial_velocity_max = lerpf(48.0, 70.0, bigger)
	_bombs.restart()
	if not calm():
		# The eruption flash, from the volcano's side of the sky, and no random eruption on top of it.
		_eruption_age = 0.0
		_eruption_strength = 0.8 + 0.18 * float(_volcano_level)
		_flash_light.rotation_degrees = Vector3(-9.0, 180.0 - VOLCANO_YAW, 0.0)
		_next_eruption = _clock + _rng.randf_range(12.0, 20.0)


func on_streak(strength: float) -> void:
	_surge = maxf(_surge, 0.5 + 0.6 * strength)
	_volcano_target = maxf(_volcano_target, 0.3 * strength)
	super(strength * 0.6)


func on_burst(strength: float, kind: String) -> void:
	_volcano_target = maxf(_volcano_target, 0.45 * strength)
	_trickle_until = _clock + 1.4
	super(strength, kind)


func on_falter(severity: float) -> void:
	_target_choke = maxf(_target_choke, severity)
	_slump_a_rig(severity)
	event_sound("choke", -12.0)


func on_recover() -> void:
	_target_choke = 0.0
	for rig: Node3D in _slumped:
		var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(rig, "rotation:z", 0.0, 1.8)
		tween.tween_property(rig, "position:y", 0.0, 1.8)
	_slumped.clear()
	super()


func on_settle() -> void:
	_volcano_age = -1.0
	_volcano_target = 0.0
	_volcano_heat = 0.0
	_surge = 0.0
	_choke = 0.0
	_target_choke = 0.0
	_trickle_until = 0.0
	_sparks_until = 0.0
	for emitter: CPUParticles3D in [_fountain, _bombs, _ash, _soot, _trickle, _river_spurts, _sparks]:
		emitter.restart()
		emitter.emitting = false
	for rig: Node3D in _slumped:
		rig.rotation.z = 0.0
		rig.position.y = 0.0
	_slumped.clear()


## A drill rig in view (or the next one coming) throws sparks and slumps, leaning away from the road.
func _slump_a_rig(severity: float) -> void:
	var chosen: Node3D = null
	for rig: Node3D in _rigs:
		if not _slumped.has(rig) and ahead_in_view(rig.position, -30.0, -220.0, 60.0):
			if chosen == null or rig.position.z > chosen.position.z:
				chosen = rig
	if chosen == null:
		for rig: Node3D in _rigs:
			if not _slumped.has(rig) and rig.position.z < -30.0 and (chosen == null or rig.position.z > chosen.position.z):
				chosen = rig
	if chosen == null:
		return
	_slumped.append(chosen)
	var lean: float = deg_to_rad(lerpf(7.0, 15.0, severity))
	var tween := create_tween().set_parallel(true)
	if calm():
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(chosen, "rotation:z", -lean, 2.5)
		tween.tween_property(chosen, "position:y", -0.9, 2.5)
		return
	tween.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(chosen, "rotation:z", -lean, 1.1).set_delay(0.35)
	tween.tween_property(chosen, "position:y", -0.9, 1.1).set_delay(0.35)
	_sparks.reparent(chosen, false)
	_sparks.position = Vector3(0.0, 15.0, 0.0)
	_sparks.restart()
	_sparks_until = _clock + 1.6


## The volcano's eruption over time, its glow and light, the streak's surge and the choke.
func _update_events(delta: float) -> void:
	_volcano_target = maxf(_volcano_target - delta * 0.16, 0.0)
	_volcano_heat = move_toward(_volcano_heat, _volcano_target, delta * (0.8 if calm() else 6.0))
	if _volcano_age >= 0.0:
		_volcano_age += delta
		var a: float = _volcano_age
		var lasts: float = 2.2 + 0.8 * float(_volcano_level)
		_fountain.emitting = a < lasts
		_ash.emitting = _volcano_level >= 2 and a > 0.4 and a < lasts + 1.5
		# The biggest go off twice.
		if _volcano_level >= 3 and a - delta < 1.9 and a >= 1.9:
			_bombs.restart()
			if not calm():
				_eruption_age = 0.0
				_eruption_strength = 0.6 + 0.1 * float(_volcano_level)
		if a > lasts + 10.0:
			_volcano_age = -1.0
	_trickle.emitting = (flow() > 0.35 or _clock < _trickle_until) and _volcano_age < 0.0 and _choke < 0.5
	_choke = move_toward(_choke, _target_choke, delta * (0.7 if _target_choke > _choke else 0.3))
	_soot.emitting = _choke > 0.3
	_wisp.emitting = _choke <= 0.3
	_surge = maxf(_surge - delta * 0.3, 0.0)
	_river_spurts.emitting = _surge > 0.2
	if _river_spurts.emitting:
		# Thrown up and carried down the river at the scenery's own speed, so they ride with the lava.
		var along: float = (Highway.LENGTH / Highway.lookahead) * _speed * (1.0 + HEAT_SPEED * _heat)
		var up: float = 5.0 + 3.0 * _surge
		_river_spurts.direction = Vector3(0.0, up, along).normalized()
		_river_spurts.initial_velocity_min = Vector2(up * 0.7, along).length()
		_river_spurts.initial_velocity_max = Vector2(up, along).length()
	if _sparks_until > 0.0 and _clock > _sparks_until:
		_sparks.emitting = false
		_sparks_until = 0.0
	# At rest the rivulets only smoulder; an eruption sets them blazing.
	var glow: float = (0.32 + 2.6 * _volcano_heat + 0.35 * flow()) * (1.0 - 0.7 * _choke)
	if not calm():
		glow *= 1.0 + 0.12 * _volcano_heat * sin(_clock * 23.0)
	set_emission(_volcano_glow, glow)
	_crater_light.light_energy = (0.6 + 13.0 * _volcano_heat + 2.0 * flow()) * (1.0 - 0.7 * _choke)


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
			_rigs.append(node)
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
