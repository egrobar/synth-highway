class_name ItemSlot
extends Control
## The battle's item slot, top left under your combo and gas (BattleItems): when you earn a box, a
## cube with the items' icons on its faces spins and slows, lands face-on with what you got, and waits
## for 1, 2 or 3 (main.gd sends or uses it, then take()). Between boxes it shows how close the next
## one is (set_progress), and under it whatever boost you have running (set_status).
##
## The cube is real 3D in a small view of its own (six unshaded faces, no lights): a few draw calls.

## The cube landed on an item; and a face ticked past while spinning (for the click).
signal rolled(id: String)
signal ticked

enum State { EMPTY, ROLLING, READY }

const SIZE := Vector2(184, 252)
const VIEW := Rect2(16, 28, 152, 150)

var state: State = State.EMPTY
var item: String = ""
var _rng := RandomNumberGenerator.new()
var _viewport: SubViewport
var _view: TextureRect
var _cube: Node3D
var _face_mats: Array[StandardMaterial3D] = []
var _roll_left: float = 0.0
var _swap_left: float = 0.0
var _spin_axis := Vector3(1.0, 0.8, 0.25).normalized()
var _landed_for: float = 0.0
var _landed_from := Quaternion.IDENTITY
var _name: Label
var _hint: Label
var _hint_pill: Panel
var _status: Label
var _bar_track: ColorRect
var _bar: ColorRect
var _empty_icon: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.anchor(self, 0.0, 0.0, 0.0, 0.0, 32, 150, 32 + SIZE.x, 150 + SIZE.y)
	var frame := Panel.new()
	var box: StyleBoxFlat = Ui.card_style(false)
	box.bg_color = Color(box.bg_color, 0.86)
	frame.add_theme_stylebox_override("panel", box)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var caption := Ui.caption("ITEM", 16, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(caption, 0.0, 0.0, 1.0, 0.0, 0, 6, 0, 28, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(caption)
	_empty_icon = TextureRect.new()
	_empty_icon.texture = BattleItems.icon("empty")
	_empty_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_empty_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_empty_icon.modulate = Color(1, 1, 1, 0.55)
	Ui.anchor(_empty_icon, 0.0, 0.0, 0.0, 0.0, VIEW.position.x + 18, VIEW.position.y + 16, VIEW.end.x - 18, VIEW.end.y - 16)
	_empty_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty_icon)
	_build_cube()
	_name = Ui.label("", 22, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(_name, 0.0, 0.0, 1.0, 0.0, 6, 178, -6, 206, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_name)
	# "1 2 3 SEND" on a filled pill in the accent colour: bare small text didn't read at the web size.
	_hint_pill = Panel.new()
	var pill_box := StyleBoxFlat.new()
	pill_box.bg_color = Ui.ACCENT
	pill_box.set_corner_radius_all(12)
	_hint_pill.add_theme_stylebox_override("panel", pill_box)
	Ui.anchor(_hint_pill, 0.0, 0.0, 1.0, 0.0, 22, 206, -22, 230)
	_hint_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_pill)
	_hint = Ui.caption("", 18, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.anchor(_hint, 0.0, 0.0, 1.0, 0.0, 6, 206, -6, 230, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_hint)
	_bar_track = ColorRect.new()
	_bar_track.color = Color(1, 1, 1, 0.12)
	Ui.anchor(_bar_track, 0.0, 0.0, 1.0, 0.0, 18, 234, -18, 240)
	_bar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_track)
	_bar = ColorRect.new()
	_bar.color = Ui.ACCENT
	_bar.anchor_bottom = 1.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_track.add_child(_bar)
	_status = Ui.label("", 20, Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(_status, 0.0, 1.0, 1.0, 1.0, -10, 6, 10, 34, HORIZONTAL_ALIGNMENT_CENTER)
	_status.add_theme_constant_override("outline_size", 6)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(_status)
	_rng.randomize()
	_show_state()
	_fit.call_deferred()


func _build_cube() -> void:
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(int(VIEW.size.x), int(VIEW.size.y))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_cube = Node3D.new()
	_viewport.add_child(_cube)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	# The six faces: their outward direction and the rotation that turns a quad (facing +Z) to it.
	var faces: Array = [[Vector3(0, 0, 1), Vector3.ZERO], [Vector3(0, 0, -1), Vector3(0, PI, 0)],
		[Vector3(1, 0, 0), Vector3(0, PI * 0.5, 0)], [Vector3(-1, 0, 0), Vector3(0, -PI * 0.5, 0)],
		[Vector3(0, 1, 0), Vector3(-PI * 0.5, 0, 0)], [Vector3(0, -1, 0), Vector3(PI * 0.5, 0, 0)]]
	for face: Array in faces:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = BattleItems.icon("mystery")
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var node := MeshInstance3D.new()
		node.mesh = quad
		node.material_override = mat
		node.position = face[0]
		node.rotation = face[1]
		_cube.add_child(node)
		_face_mats.append(mat)
	var camera := Camera3D.new()
	camera.fov = 38.0
	_viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0, 0, 5.6), Vector3.ZERO)
	camera.current = true
	_view = TextureRect.new()
	_view.texture = _viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	Ui.anchor(_view, 0.0, 0.0, 0.0, 0.0, VIEW.position.x, VIEW.position.y, VIEW.end.x, VIEW.end.y)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.resized.connect(_fit)
	add_child(_view)


## The cube's view at its size in real screen pixels, so the icons stay sharp at any window size.
func _fit() -> void:
	if _viewport == null or not is_inside_tree():
		return
	var scale_to_screen: float = float(get_window().size.x) / maxf(get_viewport_rect().size.x, 1.0)
	_viewport.size = Vector2i(maxi(int(_view.size.x * scale_to_screen), 16), maxi(int(_view.size.y * scale_to_screen), 16))


## A box was earned: the cube spins and lands on `id`. Ignored while one is spinning or held.
func earn(id: String) -> bool:
	if state != State.EMPTY:
		return false
	item = id
	state = State.ROLLING
	_roll_left = BattleItems.ROLL_SECONDS
	_swap_left = 0.0
	_show_state()
	return true


## The held item, and the slot empties. "" when there is nothing ready.
func take() -> String:
	if state != State.READY:
		return ""
	var held: String = item
	item = ""
	state = State.EMPTY
	_show_state()
	return held


## How far along the streak is toward the next box, 0 to 1 (shown while the slot is empty).
func set_progress(fraction: float) -> void:
	_bar.anchor_right = clampf(fraction, 0.0, 1.0)


## A line under the slot: the boost you have running ("NITRO x2  5"), or "" for none.
func set_status(text: String, color: Color = Ui.WARM) -> void:
	if _status.text != text:
		_status.text = text
	_status.add_theme_color_override("font_color", color)


func _show_state() -> void:
	var empty: bool = state == State.EMPTY
	_empty_icon.visible = empty
	_hint_pill.visible = state == State.READY
	_view.visible = not empty
	_bar_track.visible = empty
	if empty:
		_name.text = ""
		_hint.text = "NEXT BOX"
		_hint.add_theme_color_override("font_color", Ui.MUTED)
	elif state == State.ROLLING:
		_name.text = ""
		_hint.text = ""
	else:
		_name.text = BattleItems.item_name(item)
		Ui.shrink_to_fit(_name, SIZE.x - 16.0, 14)
		_hint.text = "1 2 3  SEND" if BattleItems.is_attack(item) else "1 2 3  USE"
		_hint.add_theme_color_override("font_color", Color(0.04, 0.03, 0.06))
		_hint.remove_theme_color_override("font_shadow_color")


func _process(delta: float) -> void:
	if state == State.ROLLING:
		_roll_left -= delta
		var t: float = 1.0 - clampf(_roll_left / BattleItems.ROLL_SECONDS, 0.0, 1.0)
		# Fast at first, slowing toward the landing; faces show random items as they pass.
		_cube.rotate(_spin_axis, delta * lerpf(16.0, 3.0, t))
		_swap_left -= delta
		if _swap_left <= 0.0:
			_swap_left = lerpf(0.06, 0.2, t)
			var ids: Array = BattleItems.ITEMS.keys()
			for mat: StandardMaterial3D in _face_mats:
				mat.albedo_texture = BattleItems.icon(str(ids[_rng.randi() % ids.size()]))
			ticked.emit()
		if _roll_left <= 0.0:
			for mat: StandardMaterial3D in _face_mats:
				mat.albedo_texture = BattleItems.icon(item)
			state = State.READY
			_landed_for = 0.0
			_landed_from = _cube.quaternion
			_show_state()
			rolled.emit(item)
	elif state == State.READY:
		# Settle face-on, then sway a little so it reads as an object, not a sticker.
		_landed_for += delta
		var rest := Quaternion(Vector3.UP, sin(_landed_for * 2.0) * 0.22) * Quaternion(Vector3.RIGHT, -0.12)
		_cube.quaternion = _landed_from.slerp(rest, clampf(_landed_for / 0.3, 0.0, 1.0)) if _landed_for < 0.3 else rest
		var pulse: float = 1.0 + 0.06 * sin(_landed_for * 6.0)
		_cube.scale = Vector3.ONE * pulse
