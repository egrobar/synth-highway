class_name Highway
extends Node3D
## Draws what the player reads: the home-row keyboard at the hit line, the notes
## riding toward it, lane guides and beat lines. It only displays Judge's state
## and decides nothing.
##
## Ten equal lanes, A S D F G H J K L ;, the same for every song, so hands never
## move. F and J carry homing bumps like a real keyboard; G and H, the index-finger
## reaches, are tinted; a brighter line down the middle splits the two hands.
## Sharps (Normal only) are orange notes riding between two lanes, played on the
## dark top-row keys set between the home keys like a piano's black keys.

const LOOKAHEAD := 3.0
const LENGTH := 46.0
const KEY_WIDTH := 1.6
const HEAD_LENGTH := 1.0
const NOTE_HEIGHT := 0.3
const COLOR_YOU := Color(0.247, 0.847, 1.0)
const COLOR_SHARP := Color(1.0, 0.58, 0.18)
const COLOR_MISS := Color(1.0, 0.247, 0.4)
const COLOR_HOT := Color(0.85, 0.98, 1.0)
const COLOR_DEAD := Color(0.26, 0.28, 0.36)
const COLOR_WRONG := Color(1.0, 0.25, 0.4)
const KEY_REST := Color(0.945, 0.95, 0.98)
const KEY_REACH := Color(0.66, 0.72, 0.86)


class NoteView:
	var root: Node3D
	var head: MeshInstance3D
	var body: MeshInstance3D
	var label: Label3D
	var note: Chart.Note


var _chart: Chart
var _keys: Dictionary = {}
var _pool: Array[NoteView] = []
var _active: Array[NoteView] = []
var _spawn_index: int = 0
var _beat_pool: Array[MeshInstance3D] = []
var _bursts: Array[Dictionary] = []
var _sparks: Array[CPUParticles3D] = []
var _next_spark: int = 0
var _hold_light: OmniLight3D

var _box := BoxMesh.new()
var _mat_you: StandardMaterial3D
var _mat_sharp: StandardMaterial3D
var _mat_body_sharp: StandardMaterial3D
var _mat_miss: StandardMaterial3D
var _mat_body: StandardMaterial3D
var _mat_hot: StandardMaterial3D
var _mat_dead: StandardMaterial3D
var _mat_beat: StandardMaterial3D
var _mat_bar: StandardMaterial3D


func setup(chart: Chart) -> void:
	_chart = chart
	_build_materials()
	_build_keyboard()
	_build_lane_guides()
	_build_effects()
	for i: int in 24:
		var line := MeshInstance3D.new()
		line.mesh = _box
		line.visible = false
		add_child(line)
		_beat_pool.append(line)


## Half the keyboard's width. The same for every song, so a region's road never changes width.
static func half_width() -> float:
	return float(KeyMap.COUNT) * KEY_WIDTH * 0.5


## Home lanes sit side by side; a sharp sits on the line between its two home lanes.
static func lane_x(lane: int) -> float:
	if KeyMap.is_sharp(lane):
		return lane_x(lane - KeyMap.SHARP_BASE) + KEY_WIDTH * 0.5
	return (float(lane) - (KeyMap.COUNT - 1) * 0.5) * KEY_WIDTH


func units_per_second() -> float:
	return LENGTH / LOOKAHEAD


func reset_run() -> void:
	for view: NoteView in _active:
		_release(view)
	_active.clear()
	_spawn_index = 0
	# A run can be restarted from pause with keys still down; start every run with them up.
	for key: Dictionary in _keys.values():
		key["pressed"] = 0
		key["wrong"] = 0.0


func set_key_pressed(lane: int, down: bool) -> void:
	if _keys.has(lane):
		_keys[lane]["pressed"] = int(_keys[lane]["pressed"]) + (1 if down else -1)


func flash_wrong(lane: int) -> void:
	if _keys.has(lane):
		_keys[lane]["wrong"] = 0.18


func celebrate(lane: int, perfect: bool) -> void:
	var color: Color = Color(1.0, 0.95, 0.75) if perfect else COLOR_YOU
	var x: float = lane_x(lane)
	for burst: Dictionary in _bursts:
		if float(burst["t"]) >= 1.0:
			burst["t"] = 0.0
			var ring: MeshInstance3D = burst["mesh"]
			ring.visible = true
			ring.position = Vector3(x, 0.45, -0.1)
			var mat: StandardMaterial3D = ring.material_override
			mat.albedo_color = color
			mat.emission = color
			break
	var sparks: CPUParticles3D = _sparks[_next_spark]
	_next_spark = (_next_spark + 1) % _sparks.size()
	sparks.position = Vector3(x, 0.4, -0.1)
	sparks.color = color
	sparks.restart()
	sparks.emitting = true


func update_view(now: float, delta: float, holding: bool) -> void:
	var speed: float = units_per_second()
	var notes: Array[Chart.Note] = _chart.notes
	while _spawn_index < notes.size() and notes[_spawn_index].t < now + LOOKAHEAD + 0.4:
		_acquire(notes[_spawn_index])
		_spawn_index += 1
	var hold_x: float = 0.0
	var any_hold := false
	var i: int = _active.size() - 1
	while i >= 0:
		var view: NoteView = _active[i]
		var n: Chart.Note = view.note
		var done: bool = n.end_time() < now - 0.7
		var tap_hit: bool = n.state == Chart.NoteState.HIT and not n.is_hold
		var hold_finished: bool = n.hold_state == Chart.HoldState.COMPLETE
		if done or tap_hit or hold_finished:
			_release(view)
			_active.remove_at(i)
		else:
			if n.hold_state == Chart.HoldState.HOLDING:
				any_hold = true
				hold_x = lane_x(n.lane)
			_place(view, now, speed)
		i -= 1
	if _hold_light:
		_hold_light.visible = holding and any_hold
		_hold_light.position.x = hold_x
	_update_beat_lines(now, speed)
	_update_keys(now, delta)
	_update_bursts(delta)


func _place(view: NoteView, now: float, speed: float) -> void:
	var n: Chart.Note = view.note
	var z_head: float = -(n.t - now) * speed
	var z_tail: float = -(n.end_time() - now) * speed
	var hit: bool = n.state == Chart.NoteState.HIT
	var missed: bool = n.state == Chart.NoteState.MISSED
	view.root.position = Vector3(lane_x(n.lane), 0.0, 0.0)
	view.head.visible = not hit
	view.label.visible = not hit and not missed
	if not hit:
		view.head.position.z = z_head - HEAD_LENGTH * 0.5
		view.head.material_override = _mat_miss if missed else (_mat_sharp if KeyMap.is_sharp(n.lane) else _mat_you)
		view.label.position.z = z_head - HEAD_LENGTH * 0.5
	if not n.is_hold:
		view.body.visible = false
		return
	var holding: bool = n.hold_state == Chart.HoldState.HOLDING
	var near: float = 0.0 if holding else z_head - HEAD_LENGTH * 0.5
	var length: float = near - z_tail
	view.body.visible = length > 0.02
	if view.body.visible:
		view.body.position.z = (near + z_tail) * 0.5
		view.body.scale.z = length
		if holding:
			view.body.material_override = _mat_hot
		elif missed or n.hold_state == Chart.HoldState.DROPPED:
			view.body.material_override = _mat_dead
		else:
			view.body.material_override = _mat_body_sharp if KeyMap.is_sharp(n.lane) else _mat_body


func _acquire(n: Chart.Note) -> void:
	var view: NoteView
	if _pool.is_empty():
		view = NoteView.new()
		view.root = Node3D.new()
		view.head = MeshInstance3D.new()
		view.head.mesh = _box
		view.body = MeshInstance3D.new()
		view.body.mesh = _box
		view.label = Label3D.new()
		view.label.font_size = 110
		view.label.pixel_size = 0.0095
		view.label.modulate = Color(0.02, 0.1, 0.16)
		view.label.outline_size = 0
		# Tilted up toward the camera: lying flat, far-off letters foreshortened into slivers.
		view.label.rotation_degrees = Vector3(-50, 0, 0)
		view.label.shaded = false
		view.root.add_child(view.head)
		view.root.add_child(view.body)
		view.root.add_child(view.label)
		add_child(view.root)
	else:
		view = _pool.pop_back()
	# Sharps are narrower, so a note on the line between two lanes never reads as either one.
	var width: float = KEY_WIDTH * (0.5 if KeyMap.is_sharp(n.lane) else 0.84)
	view.head.scale = Vector3(width, NOTE_HEIGHT, HEAD_LENGTH)
	view.head.position.y = NOTE_HEIGHT * 0.5
	view.body.scale = Vector3(width * 0.46, 0.14, 1.0)
	view.body.position.y = 0.09
	view.label.text = KeyMap.label_for(n.lane)
	view.label.position.y = NOTE_HEIGHT + 0.012
	view.note = n
	view.root.visible = true
	_active.append(view)


func _release(view: NoteView) -> void:
	view.root.visible = false
	view.note = null
	_pool.append(view)


func _update_beat_lines(now: float, speed: float) -> void:
	var beat: float = _chart.beat_seconds()
	# Imported songs rarely start on a downbeat at 0 s, so lines are laid from the detected first beat.
	var offset: float = _chart.beat_offset
	var index: int = int(ceil((now - offset) / beat))
	var used: int = 0
	while used < _beat_pool.size():
		var t: float = offset + float(index) * beat
		if t > now + LOOKAHEAD + 0.3:
			break
		var line: MeshInstance3D = _beat_pool[used]
		if index >= 0:
			var bar: bool = index % _chart.beats_per_bar == 0
			line.visible = true
			line.material_override = _mat_bar if bar else _mat_beat
			line.scale = Vector3(half_width() * 2.0 + 1.0, 0.012, 0.16 if bar else 0.07)
			line.position = Vector3(0.0, 0.02, -(t - now) * speed)
			used += 1
		index += 1
	for j: int in range(used, _beat_pool.size()):
		_beat_pool[j].visible = false


func _update_keys(now: float, delta: float) -> void:
	# The next note's key breathes as it approaches: a teaching aid for a new layout.
	var hint: Dictionary = {}
	for view: NoteView in _active:
		var n: Chart.Note = view.note
		var until: float = n.t - now
		if n.state == Chart.NoteState.PENDING and until < 0.7:
			hint[n.lane] = maxf(float(hint.get(n.lane, 0.0)), 1.0 - maxf(until, 0.0) / 0.7)
	for lane: int in _keys:
		var key: Dictionary = _keys[lane]
		var glow: Color = COLOR_SHARP if KeyMap.is_sharp(lane) else COLOR_YOU
		var mat: StandardMaterial3D = key["material"]
		key["wrong"] = maxf(float(key["wrong"]) - delta, 0.0)
		var down: bool = int(key["pressed"]) > 0
		mat.emission_enabled = true
		if float(key["wrong"]) > 0.0:
			mat.emission = COLOR_WRONG
			mat.emission_energy_multiplier = 2.2
		elif down:
			mat.emission = glow
			mat.emission_energy_multiplier = 2.0
		elif hint.has(lane):
			mat.emission = glow
			mat.emission_energy_multiplier = 0.2 + 1.0 * float(hint[lane])
		else:
			mat.emission_energy_multiplier = 0.0
		var sink: float = 0.1 if down else 0.0
		for part: Node3D in key["parts"]:
			part.position.y = float(part.get_meta("rest_y")) - sink


func _update_bursts(delta: float) -> void:
	for burst: Dictionary in _bursts:
		var t: float = burst["t"]
		if t >= 1.0:
			continue
		t = minf(1.0, t + delta * 3.0)
		burst["t"] = t
		var ring: MeshInstance3D = burst["mesh"]
		var s: float = 0.9 + t * 2.2
		ring.scale = Vector3(s, 1.0, s)
		var mat: StandardMaterial3D = ring.material_override
		mat.albedo_color.a = 0.9 * (1.0 - t)
		ring.visible = t < 1.0


func _emissive(color: Color, energy: float, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.35
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _build_materials() -> void:
	_mat_you = _emissive(COLOR_YOU, 1.5)
	_mat_sharp = _emissive(COLOR_SHARP, 1.6)
	_mat_body_sharp = _emissive(COLOR_SHARP, 0.55, 0.72)
	_mat_miss = _emissive(COLOR_MISS, 0.7, 0.75)
	_mat_body = _emissive(COLOR_YOU, 0.55, 0.72)
	_mat_hot = _emissive(COLOR_HOT, 3.4)
	_mat_dead = _emissive(COLOR_DEAD, 0.08, 0.6)
	_mat_beat = _emissive(Color(0.9, 0.82, 0.62), 0.12, 0.2)
	_mat_bar = _emissive(Color(1.0, 0.86, 0.55), 0.4, 0.42)


func _part(mesh: Mesh, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.scale = size
	node.position = position
	node.material_override = material
	node.set_meta("rest_y", position.y)
	add_child(node)
	return node


func _build_keyboard() -> void:
	for lane: int in KeyMap.COUNT:
		var x: float = lane_x(lane)
		var reach: bool = KeyMap.REACH.has(lane)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = KEY_REACH if reach else KEY_REST
		mat.roughness = 0.4
		var parts: Array[Node3D] = []
		parts.append(_part(_box, Vector3(KEY_WIDTH * 0.92, 0.5, 2.3), Vector3(x, 0.25, 1.15), mat))
		if KeyMap.HOMING.has(lane):
			# The bump you feel on F and J, so the hands find home without looking.
			var bump := StandardMaterial3D.new()
			bump.albedo_color = Color(0.55, 0.58, 0.7)
			parts.append(_part(_box, Vector3(0.5, 0.05, 0.1), Vector3(x, 0.52, 2.05), bump))
		var label := Label3D.new()
		label.text = KeyMap.label_for(lane)
		label.font_size = 110
		label.pixel_size = 0.011
		label.modulate = Color(0.14, 0.16, 0.3) if not reach else Color(0.2, 0.24, 0.42)
		label.outline_size = 0
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.shaded = false
		label.position = Vector3(x, 0.512, 1.2)
		label.set_meta("rest_y", 0.512)
		add_child(label)
		parts.append(label)
		_keys[lane] = {"material": mat, "pressed": 0, "wrong": 0.0, "parts": parts}
	if _chart.has_sharps():
		_build_sharp_keys()
	var line := MeshInstance3D.new()
	line.mesh = _box
	line.material_override = _emissive(COLOR_YOU, 3.2)
	line.scale = Vector3(half_width() * 2.0 + 1.2, 0.05, 0.1)
	line.position = Vector3(0.0, 0.05, 0.0)
	add_child(line)


## The dark keys between the home keys, set back like a piano's black keys and
## labelled with the top-row letter that plays them. Only for charts with sharps.
func _build_sharp_keys() -> void:
	for i: int in KeyMap.SHARPS.size():
		var lane: int = KeyMap.SHARP_BASE + i
		var x: float = lane_x(lane)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.1, 0.16)
		mat.roughness = 0.5
		var parts: Array[Node3D] = []
		parts.append(_part(_box, Vector3(KEY_WIDTH * 0.5, 0.5, 1.1), Vector3(x, 0.72, 0.5), mat))
		var label := Label3D.new()
		label.text = KeyMap.label_for(lane)
		label.font_size = 96
		label.pixel_size = 0.0075
		label.modulate = COLOR_SHARP
		label.outline_size = 0
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.shaded = false
		label.position = Vector3(x, 0.98, 0.55)
		label.set_meta("rest_y", 0.98)
		add_child(label)
		parts.append(label)
		_keys[lane] = {"material": mat, "pressed": 0, "wrong": 0.0, "parts": parts}


## Faint lines down the road between lanes, so a note's lane reads at a distance,
## and a brighter one between G and H where the left hand ends and the right begins.
func _build_lane_guides() -> void:
	var faint := _emissive(Color(0.7, 0.8, 1.0), 0.05, 0.12)
	var split := _emissive(COLOR_YOU, 0.35, 0.3)
	for edge: int in range(1, KeyMap.COUNT):
		var guide := MeshInstance3D.new()
		guide.mesh = _box
		var middle: bool = edge == KeyMap.COUNT / 2
		guide.material_override = split if middle else faint
		guide.scale = Vector3(0.06 if middle else 0.03, 0.01, LENGTH + 4.0)
		guide.position = Vector3(lane_x(edge) - KEY_WIDTH * 0.5, 0.012, -(LENGTH + 4.0) * 0.5)
		add_child(guide)


func _build_effects() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.5
	for i: int in 16:
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.visible = false
		var mat := _emissive(Color.WHITE, 3.0, 0.9)
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = mat
		add_child(ring)
		_bursts.append({"mesh": ring, "t": 1.0})
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.05
	spark_mesh.height = 0.1
	spark_mesh.radial_segments = 6
	spark_mesh.rings = 3
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.vertex_color_use_as_albedo = true
	spark_mesh.material = spark_mat
	for i: int in 10:
		var sparks := CPUParticles3D.new()
		sparks.mesh = spark_mesh
		sparks.emitting = false
		sparks.one_shot = true
		sparks.amount = 14
		sparks.lifetime = 0.42
		sparks.explosiveness = 1.0
		sparks.direction = Vector3(0, 1, -0.25)
		sparks.spread = 58.0
		sparks.initial_velocity_min = 3.5
		sparks.initial_velocity_max = 8.0
		sparks.gravity = Vector3(0, -22, 0)
		add_child(sparks)
		_sparks.append(sparks)
	_hold_light = OmniLight3D.new()
	_hold_light.light_color = COLOR_YOU
	_hold_light.light_energy = 3.5
	_hold_light.omni_range = 9.0
	_hold_light.position = Vector3(0, 1.4, -0.6)
	_hold_light.visible = false
	add_child(_hold_light)
