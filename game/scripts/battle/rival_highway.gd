class_name RivalHighway
extends TextureRect
## One rival's highway in miniature, in their battle panel (RivalBar): a real Highway (notes in the
## fingers' colours, glow, keycaps, hit bursts) in a small 3D view of its own with nothing else in it,
## playing the race's chart at the race's moment, with that rival's hits and misses on it (Evan,
## 2026-11-23: "make the multiplayer a bit more visual ... glow and caps but highway alone is fine").
##
## A rival's reports arrive about ten times a second (Battle.report) and say which lanes they hit or
## missed since the last one, and their running count of hits. So the view runs DELAY behind the race:
## by the time a note reaches the line here, the report that covers it has come in, and a hit lands on
## the note it was for (the earliest open note in that lane near the report's time; a report with more
## hits than lanes claims more notes in those lanes). A note no report claimed is a miss: it turns red
## and slides on, as on your own road. A miss with no note near it is a wrong key: the key flashes red.
##
## Cost, measured on the web renderer (2026-11-23): three rival roads drawn every frame took a native
## run from 224 to 161 fps (about 1.7 ms a frame, ~80 draw calls each). So each draws every other
## frame (30 a second at 60), spread so the rivals' roads split between the two frames, and a road that has stopped
## (out of gas, finished, gone) draws no more. No scenery, shadows or fog; as big as the panel.

## Seconds the view runs behind the race, so a rival's report has arrived before its notes land here.
const DELAY := 0.35
## A hit reported at race time t is for a note from MATCH_BEFORE before t to MATCH_AFTER after it: the
## report left up to a tenth of a second after the hit, plus the trip, and a hit can be a little early.
const MATCH_BEFORE := 0.6
const MATCH_AFTER := 0.2
## How long after its time an unclaimed note counts as missed here (the judge's good window).
const MISS_AFTER := 0.2
## The camera: near the line your own looks down, aimed about 26 degrees down so the keycaps sit along the
## bottom edge, but pulled back 1.6 times with a narrower lens (KEEP_WIDTH, 42 degrees across: the
## keyboard and its glowing edges span the panel). The longer lens flattens the road, so notes far up it are not
## specks (graphics review, 2026-11-23); about 1.3 s of notes show above the keys.
## (A little higher than that line, so the keycaps' tops catch the light: graphics review 2.)
const CAMERA_POSITION := Vector3(0.0, 15.6, 23.6)
const CAMERA_TARGET := Vector3(0.0, 0.7, -3.2)
const FOV := 42.0
## Night behind the road. Linear light: through the filmic tone map a "dark" 0.02/0.05 came out a
## bright navy across the whole panel.
const BACKGROUND := Color(0.003, 0.003, 0.008)

var _viewport: SubViewport
var _highway: Highway
var _chart: Chart
var _camera: Camera3D
## Notes this rival has hit, by instance id: applied when the view reaches them.
var _claimed: Dictionary = {}
## The first note not yet settled (hit or missed) in time order.
var _next: int = 0
## Hit notes still being held, and keys to let up: [lane, view time].
var _holding: Array[Chart.Note] = []
var _keys_up: Array = []
## Wrong keys to flash when the view gets there: [lane, view time].
var _wrong: Array = []
var _hits_seen: int = 0
var _frozen: bool = false
## Which frames this road draws on (every other frame, staggered across rivals: stagger()).
var _phase: int = 0


func setup(chart_path: String, level: String) -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chart = Chart.load_file(chart_path, level)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport.size = Vector2i(288, 100)
	add_child(_viewport)
	# The regions' look without their scenery: their glow (ThemeWorld.make_environment), on night.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.38, 0.62)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# A touch brighter than the roads, so a few notes read in a panel a couple of hundred pixels wide.
	env.tonemap_exposure = 1.2
	env.glow_enabled = true
	# Less than the roads' glow (0.85): in a strip along the top of your screen it outshone your own
	# notes at full strength, and at half the notes went dim (graphics reviews 1 and 2).
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	var world := WorldEnvironment.new()
	world.environment = env
	_viewport.add_child(world)
	var light := DirectionalLight3D.new()
	light.light_color = Color(0.78, 0.84, 1.0)
	light.light_energy = 0.8
	light.rotation_degrees = Vector3(-50, 18, 0)
	_viewport.add_child(light)
	_highway = Highway.new()
	_highway.letters = false
	_viewport.add_child(_highway)
	_highway.setup(_chart)
	# The road's edges glow in the region's colour, as the regions' own roads do: without them a
	# miniature read as a grid on black rather than a road (graphics review 2).
	var edge := StandardMaterial3D.new()
	edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge.albedo_color = Ui.ACCENT
	edge.emission_enabled = true
	edge.emission = Ui.ACCENT
	edge.emission_energy_multiplier = 1.4
	for side: float in [-1.0, 1.0]:
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.05, Highway.LENGTH + 4.0)
		strip.mesh = box
		strip.material_override = edge
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strip.position = Vector3(side * (Highway.half_width() + 0.35), 0.03, -(Highway.LENGTH + 4.0) * 0.5 + 2.5)
		_viewport.add_child(strip)
	_camera = Camera3D.new()
	_camera.fov = FOV
	# The road's width is what has to fit: a wide, short panel crops top and bottom, not the sides.
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_viewport.add_child(_camera)
	_camera.look_at_from_position(CAMERA_POSITION, CAMERA_TARGET)
	_camera.current = true
	texture = _viewport.get_texture()
	resized.connect(_fit)
	_fit()


## The 3D view at the panel's size in real screen pixels, so it is sharp at any window size.
func _fit() -> void:
	if _viewport == null or not is_inside_tree():
		return
	var shown: Vector2 = get_viewport_rect().size
	var scale_to_screen: float = float(get_window().size.x) / maxf(shown.x, 1.0)
	var pixels := Vector2i(maxi(int(size.x * scale_to_screen), 16), maxi(int(size.y * scale_to_screen), 16))
	if _viewport.size != pixels:
		_viewport.size = pixels


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_fit.call_deferred()


## A report from this rival arrived at race time `race_now`: the lanes hit and missed since their
## last one, and their running count of hits.
func report(hit_lanes: int, miss_lanes: int, hits_total: int, race_now: float) -> void:
	if _chart == null or _frozen:
		return
	var new_hits: int = maxi(hits_total - _hits_seen, 0)
	_hits_seen = maxi(hits_total, _hits_seen)
	var lanes: Array[int] = []
	for lane: int in KeyMap.COUNT + KeyMap.SHARPS.size():
		if hit_lanes & (1 << lane):
			lanes.append(lane)
	# One note per lane named, then more in those lanes while the count says there were more hits.
	var claimed: int = 0
	var passes: int = 0
	while not lanes.is_empty() and passes < 4:
		var any := false
		for lane: int in lanes:
			if passes > 0 and claimed >= new_hits:
				break
			if _claim(lane, race_now):
				claimed += 1
				any = true
		passes += 1
		if not any or claimed >= new_hits:
			break
	for lane: int in KeyMap.COUNT + KeyMap.SHARPS.size():
		if miss_lanes & (1 << lane) and _open_note(lane, race_now) == null:
			_wrong.append([lane, race_now - 0.1])


## Claims the earliest open note in `lane` near `race_now` as hit. False when there is none.
func _claim(lane: int, race_now: float) -> bool:
	var n: Chart.Note = _open_note(lane, race_now)
	if n == null:
		return false
	_claimed[n.get_instance_id()] = true
	return true


func _open_note(lane: int, race_now: float) -> Chart.Note:
	var notes: Array[Chart.Note] = _chart.notes
	for i: int in range(_next, notes.size()):
		var n: Chart.Note = notes[i]
		if n.t > race_now + MATCH_AFTER:
			break
		if n.lane == lane and n.t >= race_now - MATCH_BEFORE and not _claimed.has(n.get_instance_id()) \
				and n.state != Chart.NoteState.HIT:
			return n
	return null


## Draws on frames of this parity, so rival roads take turns (0 or 1).
func stagger(phase: int) -> void:
	_phase = phase % 2


## The rival is out of gas, finished or gone: the road stops where it is and draws no more.
func freeze() -> void:
	if _frozen:
		return
	_frozen = true
	if _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Every frame, with the race's song time.
func advance(race_now: float, delta: float) -> void:
	if _highway == null or _frozen:
		return
	var now: float = race_now - DELAY
	var notes: Array[Chart.Note] = _chart.notes
	var i: int = _next
	while i < notes.size() and notes[i].t <= now:
		var n: Chart.Note = notes[i]
		if n.state == Chart.NoteState.PENDING:
			if _claimed.has(n.get_instance_id()):
				_hit(n, now)
			elif now - n.t > MISS_AFTER:
				n.state = Chart.NoteState.MISSED
		i += 1
	while _next < notes.size() and notes[_next].state != Chart.NoteState.PENDING:
		_next += 1
	# A late report can still claim a note shown as missed a moment ago: it was a hit after all.
	for j: int in range(maxi(_next - 8, 0), _next):
		var late: Chart.Note = notes[j]
		if late.state == Chart.NoteState.MISSED and _claimed.has(late.get_instance_id()) and now - late.t < 0.6:
			_hit(late, now)
	for k: int in range(_holding.size() - 1, -1, -1):
		if now >= _holding[k].end_time():
			_holding[k].hold_state = Chart.HoldState.COMPLETE
			_holding.remove_at(k)
	for k: int in range(_keys_up.size() - 1, -1, -1):
		if now >= float(_keys_up[k][1]):
			_highway.set_key_pressed(int(_keys_up[k][0]), false)
			_keys_up.remove_at(k)
	for k: int in range(_wrong.size() - 1, -1, -1):
		if now >= float(_wrong[k][1]):
			_highway.flash_wrong(int(_wrong[k][0]))
			_wrong.remove_at(k)
	_highway.update_view(now, delta, not _holding.is_empty())
	# Every other frame: the notes still move smoothly at 30 a second in a thumbnail.
	var draw_now: bool = Engine.get_frames_drawn() % 2 == _phase
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if draw_now else SubViewport.UPDATE_DISABLED


func _hit(n: Chart.Note, now: float) -> void:
	n.state = Chart.NoteState.HIT
	_highway.celebrate(n.lane, false)
	_highway.set_key_pressed(n.lane, true)
	if n.is_hold:
		n.hold_state = Chart.HoldState.HOLDING
		_holding.append(n)
		_keys_up.append([n.lane, n.end_time()])
	else:
		_keys_up.append([n.lane, now + 0.1])
