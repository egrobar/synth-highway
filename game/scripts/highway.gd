class_name Highway
extends Node3D
## Draws what the player reads: the home-row keyboard at the hit line, the notes
## riding toward it, lane guides and beat lines. It only displays Judge's state
## and decides nothing.
##
## Ten equal lanes, A S D F G H J K L ;, the same for every song, so hands never
## move. F and J carry homing bumps like a real keyboard; G and H, the index-finger
## reaches, are tinted; a brighter line down the middle splits the two hands.
## Sharps (Normal and Hard) are orange notes riding between two lanes, played on the
## dark top-row keys set between the home keys like a piano's black keys.
##
## Home-row notes, their lanes and their keys are coloured by the finger that plays
## them (KeyMap.FINGER_COLORS), mirrored across the hands.
##
## Power chords (Hard: Chart.power_chords) must read at a glance as ONE event, two or three keys
## struck together: a raised white bar joins the chord's notes across the lanes, each head stands
## taller (in its own finger colour) on a white halo plate, and the halos and the bar shimmer
## together (steady with Settings.motion off). White is the one colour no other cue uses: fingers
## are violet, yellow, green, cyan and pink, sharps orange, a miss dark red, and the faint beat and
## bar lines that also cross the road are flat, full-width and cream. Missing any note of a chord
## greys its bar; hitting every note sets off a wide white flash, a ring and a fountain of sparks
## across the chord, on top of each note's own burst.

## Seconds a note is visible before it reaches the hit line. A setting: see Settings.NOTE_SPEEDS.
static var lookahead: float = 3.0
## Whether notes carry their key's letter. A setting.
static var show_letters: bool = true
## Whether this highway shows letters at all (notes and keys): off on a rival's miniature road
## (RivalHighway), where letters a few pixels high read as noise.
var letters: bool = true
## Battle items (ItemEffects) acting on this road. paint: lane -> the finger colour (0-4, or 5 for the
## sharps' orange) its notes wear instead of their own (Paint Bomb). speed_scale: how much faster the
## notes travel (Turbo: same timing, half the warning). fog_depth: notes farther up the road than this
## stay hidden (Fog Bank; 0 for none).
var paint: Dictionary = {}
var speed_scale: float = 1.0
var fog_depth: float = 0.0

const LENGTH := 46.0
const KEY_WIDTH := 1.6
const HEAD_LENGTH := 1.0
const NOTE_HEIGHT := 0.3
## How strongly each lane's floor carries its finger's colour. Godot blends transparency in linear
## light, so on the dark sci-fi roads even 4.5% of a bright colour read as a heavy stripe: the notes
## got lost in a rainbow and G and H came out maroon, close to a missed note's red (2026-11-10).
## 2% keeps every lane readable on all five roads without competing with the notes.
const LANE_TINT := 0.02
const COLOR_SHARP := Color(1.0, 0.58, 0.18)
const COLOR_MISS := Color(0.62, 0.14, 0.18)  # dark red: never mistaken for the pink of G and H
const COLOR_HOT := Color(0.85, 0.98, 1.0)
const COLOR_DEAD := Color(0.26, 0.28, 0.36)
const COLOR_WRONG := Color(1.0, 0.25, 0.4)
const COLOR_POWER := Color(0.96, 0.98, 1.0)
## A power head's height over an ordinary head's, so the chord stands up off the road.
const POWER_HEIGHT := 1.35
## Emission of power heads (the same as ordinary heads, so the finger colour holds under the bloom),
## their halo plates and the chord bar.
const POWER_HEAD_GLOW := 1.5
const POWER_AURA_GLOW := 0.9
const POWER_BAR_GLOW := 2.0
const KEY_REST := Color(0.945, 0.95, 0.98)
const KEY_REACH := Color(0.66, 0.72, 0.86)


class NoteView:
	var root: Node3D
	var head: MeshInstance3D
	var body: MeshInstance3D
	var label: Label3D
	## The white halo plate under a power note's head; hidden on ordinary notes.
	var aura: MeshInstance3D
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
var _mat_heads: Array[StandardMaterial3D] = []
var _mat_bodies: Array[StandardMaterial3D] = []
var _line_mat: StandardMaterial3D
var _pulse: float = 0.0
var _mat_sharp: StandardMaterial3D
var _mat_body_sharp: StandardMaterial3D
var _mat_miss: StandardMaterial3D
var _mat_hot: StandardMaterial3D
var _mat_dead: StandardMaterial3D
var _mat_beat: StandardMaterial3D
var _mat_bar: StandardMaterial3D
## Power chords: [{"t", "notes", "left", "right", "bar"}] in time order, the next one to show,
## the ones on the road, and the pools and materials that draw them.
var _chords: Array = []
var _chord_spawn: int = 0
var _chords_live: Array = []
var _chord_bars: Array[MeshInstance3D] = []
var _power_flashes: Array[Dictionary] = []
var _power_sparks: Array[CPUParticles3D] = []
var _next_power_spark: int = 0
var _power_phase: float = 0.0
var _mat_heads_power: Array[StandardMaterial3D] = []
var _mat_sharp_power: StandardMaterial3D
var _mat_aura: StandardMaterial3D
var _mat_chord_bar: StandardMaterial3D
var _mat_chord_dead: StandardMaterial3D


func setup(chart: Chart) -> void:
	_chart = chart
	for notes: Array in chart.power_chords():
		var left: float = INF
		var right: float = -INF
		for n: Chart.Note in notes:
			left = minf(left, lane_x(n.lane))
			right = maxf(right, lane_x(n.lane))
		_chords.append({"t": (notes[0] as Chart.Note).t, "notes": notes, "left": left, "right": right, "bar": null})
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
	_shadowless(self)


## The keys and notes neither cast nor receive shadows. Under the high-detail shadows the key tops
## showed acne (diagonal stripes) and the soft shadows of power cables wandering across them: noise
## exactly where the player reads. A note's shadow on the road would only be a darker note to misread.
func _shadowless(root: Node) -> void:
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if geometry.material_override is StandardMaterial3D:
			(geometry.material_override as StandardMaterial3D).disable_receive_shadows = true


## Half the keyboard's width. The same for every song, so a region's road never changes width.
static func half_width() -> float:
	return float(KeyMap.COUNT) * KEY_WIDTH * 0.5


## Home lanes sit side by side; a sharp sits on the line between its two home lanes.
static func lane_x(lane: int) -> float:
	if KeyMap.is_sharp(lane):
		return lane_x(lane - KeyMap.SHARP_BASE) + KEY_WIDTH * 0.5
	return (float(lane) - (KeyMap.COUNT - 1) * 0.5) * KEY_WIDTH


func units_per_second() -> float:
	return LENGTH / lookahead * speed_scale


## A beat landed: the hit line flares and settles. Display only.
func pulse(strength: float) -> void:
	_pulse = maxf(_pulse, strength)


func reset_run() -> void:
	for view: NoteView in _active:
		_release(view)
	_active.clear()
	_spawn_index = 0
	for chord: Dictionary in _chords_live:
		_drop_bar(chord)
	_chords_live.clear()
	_chord_spawn = 0
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
	var color: Color = Color(1.0, 0.95, 0.75) if perfect else _lane_color(lane)
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
	while _spawn_index < notes.size() and notes[_spawn_index].t < now + lookahead + 0.4:
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
	_pulse = maxf(_pulse - delta * 4.0, 0.0)
	if _line_mat:
		_line_mat.emission_energy_multiplier = 2.6 + 4.0 * _pulse
	_update_beat_lines(now, speed)
	_update_chords(now, speed, delta)
	_update_keys(now, delta)
	_update_bursts(delta)


func _place(view: NoteView, now: float, speed: float) -> void:
	var n: Chart.Note = view.note
	var z_head: float = -(n.t - now) * speed
	var z_tail: float = -(n.end_time() - now) * speed
	var hit: bool = n.state == Chart.NoteState.HIT
	var missed: bool = n.state == Chart.NoteState.MISSED
	view.root.position = Vector3(lane_x(n.lane), 0.0, 0.0)
	# Past the road's far end (Turbo sends notes from twice as far) or inside a Fog Bank: not yet shown.
	var hidden: bool = z_head < -(LENGTH + 1.0) or (fog_depth > 0.0 and z_head < -fog_depth)
	view.root.visible = not hidden
	view.head.visible = not hit
	view.label.visible = letters and show_letters and not hit and not missed
	# A missed power note loses its halo, so the dark red of a miss reads the same as anywhere else.
	view.aura.visible = n.power and not hit and not missed
	if not hit:
		view.head.position.z = z_head - HEAD_LENGTH * 0.5
		view.aura.position.z = z_head - HEAD_LENGTH * 0.5
		view.head.material_override = _mat_miss if missed else _head_material(n)
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
			view.body.material_override = _mat_body_sharp if KeyMap.is_sharp(n.lane) else _mat_bodies[KeyMap.finger_for(n.lane)]


func _acquire(n: Chart.Note) -> void:
	var view: NoteView
	if _pool.is_empty():
		view = NoteView.new()
		view.root = Node3D.new()
		view.head = MeshInstance3D.new()
		view.head.mesh = _box
		view.body = MeshInstance3D.new()
		view.body.mesh = _box
		view.aura = MeshInstance3D.new()
		view.aura.mesh = _box
		view.aura.material_override = _mat_aura
		view.label = Label3D.new()
		view.label.font_size = 110
		view.label.pixel_size = 0.0095
		view.label.modulate = Color(0.02, 0.1, 0.16)
		view.label.outline_size = 0
		# Tilted up toward the camera: lying flat, far-off letters foreshortened into slivers.
		view.label.rotation_degrees = Vector3(-50, 0, 0)
		view.label.shaded = false
		view.root.add_child(view.aura)
		view.root.add_child(view.head)
		view.root.add_child(view.body)
		view.root.add_child(view.label)
		add_child(view.root)
		_shadowless(view.root)
	else:
		view = _pool.pop_back()
	# Sharps are narrower, so a note on the line between two lanes never reads as either one.
	var width: float = KEY_WIDTH * (0.5 if KeyMap.is_sharp(n.lane) else 0.84)
	var height: float = NOTE_HEIGHT * (POWER_HEIGHT if n.power else 1.0)
	view.head.scale = Vector3(width, height, HEAD_LENGTH)
	view.head.position.y = height * 0.5
	# The halo: a flat white plate a little larger than the head, showing as a bright rim round it.
	view.aura.scale = Vector3(width + 0.3, 0.05, HEAD_LENGTH + 0.3)
	view.aura.position.y = 0.03
	view.aura.visible = n.power
	view.body.scale = Vector3(width * 0.46, 0.14, 1.0)
	view.body.position.y = 0.09
	view.label.text = KeyMap.label_for(n.lane)
	view.label.position.y = height + 0.012
	view.note = n
	view.root.visible = true
	_active.append(view)


func _release(view: NoteView) -> void:
	view.root.visible = false
	view.note = null
	_pool.append(view)


func _head_material(n: Chart.Note) -> StandardMaterial3D:
	if paint.has(n.lane):
		var swapped: int = int(paint[n.lane])
		if swapped >= KeyMap.FINGER_COLORS.size():
			return _mat_sharp_power if n.power else _mat_sharp
		return (_mat_heads_power if n.power else _mat_heads)[swapped]
	if KeyMap.is_sharp(n.lane):
		return _mat_sharp_power if n.power else _mat_sharp
	return (_mat_heads_power if n.power else _mat_heads)[KeyMap.finger_for(n.lane)]


## Power chords on the road: each one's bar rides with its notes, greys if any note is missed and
## goes when the chord has passed; hitting every note of a chord sets off the big burst.
func _update_chords(now: float, speed: float, delta: float) -> void:
	_power_phase += delta
	# Halos and bars shimmer together, so a chord's parts read as one thing; steady with motion off.
	var shimmer: float = 0.82 + 0.18 * sin(_power_phase * TAU * 2.2) if Settings.motion else 1.0
	if _mat_aura:
		_mat_aura.emission_energy_multiplier = POWER_AURA_GLOW * shimmer
		_mat_chord_bar.emission_energy_multiplier = POWER_BAR_GLOW * shimmer
		for i: int in _mat_heads_power.size():
			_mat_heads_power[i].emission_energy_multiplier = POWER_HEAD_GLOW * shimmer
		_mat_sharp_power.emission_energy_multiplier = POWER_HEAD_GLOW * shimmer
	while _chord_spawn < _chords.size() and float(_chords[_chord_spawn]["t"]) < now + lookahead + 0.4:
		var chord: Dictionary = _chords[_chord_spawn]
		chord["bar"] = _take_bar()
		_chords_live.append(chord)
		_chord_spawn += 1
	var i: int = _chords_live.size() - 1
	while i >= 0:
		var chord: Dictionary = _chords_live[i]
		var all_hit := true
		var any_missed := false
		for n: Chart.Note in chord["notes"]:
			all_hit = all_hit and n.state == Chart.NoteState.HIT
			any_missed = any_missed or n.state == Chart.NoteState.MISSED
		if all_hit:
			_power_burst(chord)
			_drop_bar(chord)
			_chords_live.remove_at(i)
		elif float(chord["t"]) < now - 0.7:
			_drop_bar(chord)
			_chords_live.remove_at(i)
		else:
			var bar: MeshInstance3D = chord["bar"]
			var span: float = float(chord["right"]) - float(chord["left"])
			bar.scale = Vector3(span, 0.13, 0.26)
			bar.position = Vector3((float(chord["left"]) + float(chord["right"])) * 0.5, NOTE_HEIGHT * POWER_HEIGHT * 0.5,
				-(float(chord["t"]) - now) * speed - HEAD_LENGTH * 0.5)
			bar.material_override = _mat_chord_dead if any_missed else _mat_chord_bar
		i -= 1
	for flash: Dictionary in _power_flashes:
		var t: float = flash["t"]
		if t >= 1.0:
			continue
		t = minf(1.0, t + delta * 2.6)
		flash["t"] = t
		var plate: MeshInstance3D = flash["plate"]
		var ring: MeshInstance3D = flash["ring"]
		var width: float = flash["width"]
		plate.scale = Vector3(width + 1.6 * t, 0.04, 0.5 + 3.5 * t)
		var ring_size: float = (width * 0.5 + 0.8) * (0.7 + 0.9 * t)
		ring.scale = Vector3(ring_size, 1.0, ring_size * 0.6)
		for mesh: MeshInstance3D in [plate, ring]:
			var mat: StandardMaterial3D = mesh.material_override
			mat.albedo_color.a = 0.95 * (1.0 - t)
			mat.emission_energy_multiplier = 5.0 * (1.0 - t)
			mesh.visible = t < 1.0


func _take_bar() -> MeshInstance3D:
	var bar: MeshInstance3D
	if _chord_bars.is_empty():
		bar = MeshInstance3D.new()
		bar.mesh = _box
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bar)
	else:
		bar = _chord_bars.pop_back()
	bar.visible = true
	return bar


func _drop_bar(chord: Dictionary) -> void:
	var bar: MeshInstance3D = chord.get("bar")
	if bar:
		bar.visible = false
		_chord_bars.append(bar)
	chord["bar"] = null


## The whole chord landed: a wide white flash and a ring across its lanes, and a big fountain of
## sparks from its middle, on top of each note's own burst.
func _power_burst(chord: Dictionary) -> void:
	var x: float = (float(chord["left"]) + float(chord["right"])) * 0.5
	var width: float = float(chord["right"]) - float(chord["left"]) + KEY_WIDTH
	for flash: Dictionary in _power_flashes:
		if float(flash["t"]) >= 1.0:
			flash["t"] = 0.0
			flash["width"] = width
			(flash["plate"] as MeshInstance3D).position = Vector3(x, 0.5, -0.1)
			(flash["ring"] as MeshInstance3D).position = Vector3(x, 0.55, -0.1)
			break
	var sparks: CPUParticles3D = _power_sparks[_next_power_spark]
	_next_power_spark = (_next_power_spark + 1) % _power_sparks.size()
	sparks.position = Vector3(x, 0.5, -0.1)
	sparks.emission_box_extents = Vector3(width * 0.5, 0.1, 0.2)
	sparks.restart()
	sparks.emitting = true
	if Settings.motion:
		pulse(1.0)


func _update_beat_lines(now: float, speed: float) -> void:
	var beat: float = _chart.beat_seconds()
	# Imported songs rarely start on a downbeat at 0 s, so lines are laid from the detected first beat.
	var offset: float = _chart.beat_offset
	var index: int = int(ceil((now - offset) / beat))
	var used: int = 0
	while used < _beat_pool.size():
		var t: float = offset + float(index) * beat
		if t > now + lookahead + 0.3:
			break
		var line: MeshInstance3D = _beat_pool[used]
		if index >= 0:
			var bar: bool = index % _chart.beats_per_bar == 0
			line.visible = true
			line.material_override = _mat_bar if bar else _mat_beat
			line.scale = Vector3(half_width() * 2.0 + 1.0, 0.012, 0.16 if bar else 0.07)
			line.position = Vector3(0.0, 0.02, -(t - now) * speed)
			line.visible = line.position.z > -(LENGTH + 1.0)
			used += 1
		index += 1
	for j: int in range(used, _beat_pool.size()):
		_beat_pool[j].visible = false


func _update_keys(now: float, delta: float) -> void:
	# A key lights only while its note can be hit: lit means a press now counts. It comes on at the
	# edge of the good window and brightens to its peak dead on the note, the perfect moment. (It used
	# to start glowing 0.7 s early, and a press when it lit was a guaranteed miss: playtest, 2026-11-10.)
	var hint: Dictionary = {}
	for view: NoteView in _active:
		var n: Chart.Note = view.note
		var offset: float = absf(n.t - now)
		if n.state == Chart.NoteState.PENDING and offset <= Judge.GOOD_WINDOW:
			hint[n.lane] = maxf(float(hint.get(n.lane, 0.0)), 1.0 - offset / Judge.GOOD_WINDOW)
	for lane: int in _keys:
		var key: Dictionary = _keys[lane]
		var glow: Color = _lane_color(lane)
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
			# Clearly on from the first hittable moment, brightest at the centre.
			mat.emission = glow
			mat.emission_energy_multiplier = 0.5 + 1.3 * float(hint[lane])
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
	mat.disable_receive_shadows = true  # see _shadowless()
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


## Sharps keep their orange, the cue for "top row"; home lanes take their finger's colour.
func _lane_color(lane: int) -> Color:
	return COLOR_SHARP if KeyMap.is_sharp(lane) else KeyMap.color_for(lane)


func _build_materials() -> void:
	for color: Color in KeyMap.FINGER_COLORS:
		_mat_heads.append(_emissive(color, 1.5))
		_mat_bodies.append(_emissive(color, 0.55, 0.72))
	# A power head keeps its finger's colour and glow: the white is in the bar and the
	# halo rim. (Lifted toward white and lit at 2.6, with the halo at 3.2, the bloom turned a chord
	# into one white smear: no finger colours, no letters.)
	for color: Color in KeyMap.FINGER_COLORS:
		_mat_heads_power.append(_emissive(color, POWER_HEAD_GLOW))
	_mat_sharp_power = _emissive(COLOR_SHARP, POWER_HEAD_GLOW)
	_mat_aura = _emissive(COLOR_POWER, POWER_AURA_GLOW, 0.85)
	_mat_aura.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_chord_bar = _emissive(COLOR_POWER, POWER_BAR_GLOW)
	_mat_chord_dead = _emissive(COLOR_DEAD, 0.1, 0.7)
	_mat_sharp = _emissive(COLOR_SHARP, 1.6)
	_mat_body_sharp = _emissive(COLOR_SHARP, 0.55, 0.72)
	_mat_miss = _emissive(COLOR_MISS, 0.7, 0.75)
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
		label.visible = letters
		add_child(label)
		parts.append(label)
		# A strip in the finger's colour along the key's far edge, where the notes land.
		parts.append(_part(_box, Vector3(KEY_WIDTH * 0.92, 0.04, 0.34), Vector3(x, 0.515, 0.2),
			_emissive(KeyMap.color_for(lane), 1.1)))
		_keys[lane] = {"material": mat, "pressed": 0, "wrong": 0.0, "parts": parts}
	if _chart.has_sharps():
		_build_sharp_keys()
	var line := MeshInstance3D.new()
	line.mesh = _box
	_line_mat = _emissive(Color(0.9, 0.97, 1.0), 2.6)
	line.material_override = _line_mat
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
		label.visible = letters
		add_child(label)
		parts.append(label)
		_keys[lane] = {"material": mat, "pressed": 0, "wrong": 0.0, "parts": parts}


## Faint lines down the road between lanes, so a note's lane reads at a distance,
## and a brighter one between G and H where the left hand ends and the right begins.
func _build_lane_guides() -> void:
	var faint := _emissive(Color(0.7, 0.8, 1.0), 0.05, 0.12)
	var split := _emissive(Color(0.9, 0.97, 1.0), 0.35, 0.3)
	# Each lane's floor carries a breath of its finger's colour all the way down the road.
	for lane: int in KeyMap.COUNT:
		var tint := MeshInstance3D.new()
		tint.mesh = _box
		# Unshaded, so the headlights and each region's own light leave it alone.
		var tint_mat := StandardMaterial3D.new()
		tint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tint_mat.albedo_color = Color(KeyMap.color_for(lane), LANE_TINT)
		tint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tint.material_override = tint_mat
		tint.scale = Vector3(KEY_WIDTH * 0.94, 0.008, LENGTH + 4.0)
		tint.position = Vector3(lane_x(lane), 0.008, -(LENGTH + 4.0) * 0.5)
		add_child(tint)
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
	for i: int in 3:
		var plate := MeshInstance3D.new()
		plate.mesh = _box
		plate.visible = false
		var plate_mat := _emissive(COLOR_POWER, 5.0, 0.9)
		plate_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		plate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plate.material_override = plate_mat
		add_child(plate)
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.visible = false
		var ring_mat := _emissive(COLOR_POWER, 5.0, 0.9)
		ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = ring_mat
		add_child(ring)
		_power_flashes.append({"plate": plate, "ring": ring, "t": 1.0, "width": 1.0})
		var fountain := CPUParticles3D.new()
		fountain.mesh = spark_mesh
		fountain.emitting = false
		fountain.one_shot = true
		fountain.amount = 48
		fountain.lifetime = 0.6
		fountain.explosiveness = 1.0
		fountain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		fountain.direction = Vector3(0, 1, -0.2)
		fountain.spread = 40.0
		fountain.initial_velocity_min = 6.0
		fountain.initial_velocity_max = 12.0
		fountain.gravity = Vector3(0, -24, 0)
		fountain.scale_amount_min = 1.2
		fountain.scale_amount_max = 2.0
		fountain.color = Color(1.0, 0.97, 0.88)
		add_child(fountain)
		_power_sparks.append(fountain)
	_hold_light = OmniLight3D.new()
	_hold_light.light_color = Color(0.85, 0.95, 1.0)
	_hold_light.light_energy = 3.5
	_hold_light.omni_range = 9.0
	_hold_light.position = Vector3(0, 1.4, -0.6)
	_hold_light.visible = false
	add_child(_hold_light)
