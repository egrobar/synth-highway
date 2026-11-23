class_name TitleMenu
extends Control
## The title screen's menu (main.gd, _show_title): the logo, the two ways to play as big cards
## side by side (Drive alone, or Battle friends), and a row of smaller buttons under them (How to
## play, Settings, Quit). Built in the region's style (Ui) over the rolling world.
##
## Battle used to be one word in the title's hint line, and nothing past the title mentioned it
## (playtest, 2026-11-23: "way too hidden"), so it gets a card as big as Drive's.
##
## Arrow keys move through the items and Enter picks (main.gd passes keys in through handle_key);
## each item also has its own key, which main.gd handles. The mouse hovers and clicks.
##
## The model (main.gd, _title_model):
##   drive    {line, status}       the solo game in a line, and where the player is in it
##   battle   {line, status, new}  how a battle goes, how to reach one here; `new` shows a NEW tag
##   can_quit bool                 false in a browser (Ui.can_quit)
## Actions it emits: "drive", "battle", "how", "settings", "quit".

signal acted(action: String)
## The selection moved (main.gd plays the click).
signal moved

const CARD_W := 600.0
const CARD_H := 250.0
const CARD_GAP := 36.0
const CARD_TOP := 364.0
const BUTTON_H := 64.0
## The small buttons share the cards' gap and span the same width, so the two rows line up.
const BUTTON_GAP := CARD_GAP
const BUTTON_TOP := CARD_TOP + CARD_H + 34.0

## The items as the arrow keys see them: the two cards on top, the small buttons below.
var _grid: Array = []
var _row: int = 0
var _col: int = 0
var _panels: Dictionary = {}
var _small: Dictionary = {}
## Each item's key cap (Panel, with its Label child): it brightens on the chosen item.
var _chips: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func present(model: Dictionary) -> void:
	for child: Node in get_children():
		child.queue_free()
	_panels.clear()
	_small.clear()
	_chips.clear()
	add_child(Ui.dim_panel(0.5))
	# A darker band rising from the bottom, so the key hints don't sit on the bright road stripes.
	add_child(_footer_shade())
	var logo := Ui.image("res://assets/textures/logo.png")
	Ui.anchor(logo, 0.5, 0.0, 0.5, 0.0, -470, 60, 470, 260)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	var line := Ui.shrink_to_fit(Ui.label("A night drive in five regions, played on your keyboard's home row.", 30, Ui.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER), Ui.DESIGN_WIDTH - 80.0, 18)
	Ui.anchor(line, 0.0, 0.0, 1.0, 0.0, 0, 266, 0, 310, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(line)
	var drive: Dictionary = model.get("drive", {})
	var battle: Dictionary = model.get("battle", {})
	_mode_card("drive", -CARD_W - CARD_GAP * 0.5, "DRIVE", str(drive.get("line", "")), str(drive.get("status", "")), "SPACE", false)
	_mode_card("battle", CARD_GAP * 0.5, "BATTLE", str(battle.get("line", "")), str(battle.get("status", "")), "B",
		bool(battle.get("new", false)))
	var buttons: Array = [["how", "How to play", "H"], ["settings", "Settings", "S"]]
	if bool(model.get("can_quit", false)):
		buttons.append(["quit", "Quit", "Q"])
	var total: float = CARD_W * 2.0 + CARD_GAP
	var button_w: float = (total - (buttons.size() - 1) * BUTTON_GAP) / buttons.size()
	var bottom_row: Array[String] = []
	for i: int in buttons.size():
		var x: float = -total * 0.5 + i * (button_w + BUTTON_GAP)
		_small_button(str(buttons[i][0]), x, button_w, str(buttons[i][1]), str(buttons[i][2]))
		bottom_row.append(str(buttons[i][0]))
	_grid = [["drive", "battle"], bottom_row]
	var hint := Ui.shrink_to_fit(Ui.caption("ARROWS  choose        ENTER  select        %s  menu" % Ui.back_key(), 22, Ui.ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER), Ui.DESIGN_WIDTH - 80.0, 15)
	Ui.anchor(hint, 0.0, 1.0, 1.0, 1.0, 0, -60, 0, -26, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(hint)
	_refresh()


## Arrow keys move, Enter picks. Returns true when the key was the menu's.
func handle_key(code: Key) -> bool:
	match code:
		KEY_LEFT:
			_move(0, -1)
		KEY_RIGHT:
			_move(0, 1)
		KEY_UP:
			_move(-1, 0)
		KEY_DOWN:
			_move(1, 0)
		KEY_ENTER, KEY_KP_ENTER:
			acted.emit(selected())
		_:
			return false
	return true


func selected() -> String:
	return str(_grid[_row][_col]) if not _grid.is_empty() else "drive"


## Selects an item by its action, as the mouse does on hover.
func select(id: String) -> void:
	for r: int in _grid.size():
		var at: int = (_grid[r] as Array).find(id)
		if at >= 0 and (r != _row or at != _col):
			_row = r
			_col = at
			moved.emit()
			_refresh()
			return


func _move(dr: int, dc: int) -> void:
	if _grid.is_empty():
		return
	var row: int = clampi(_row + dr, 0, _grid.size() - 1)
	var col: int = _col
	if dr != 0:
		# Down from a card lands on the button under it; up from a button lands on the card above.
		var from: Array = _grid[_row]
		var to: Array = _grid[row]
		col = clampi(int(round(float(_col) / maxf(from.size() - 1, 1) * (to.size() - 1))), 0, to.size() - 1)
	else:
		col = clampi(_col + dc, 0, (_grid[row] as Array).size() - 1)
	if row != _row or col != _col:
		_row = row
		_col = col
		moved.emit()
		_refresh()


## The chosen item takes the region's selected panel (accent border, hard shadow) and grows a
## little, so which one Enter picks reads at a glance.
func _refresh() -> void:
	var chosen: String = selected()
	for group: Dictionary in [_panels, _small]:
		for id: String in group:
			var panel: Panel = group[id]
			var on: bool = id == chosen
			var style: StyleBoxFlat = Ui.card_style(on)
			if on:
				# A step heavier than the region's own selected border, which is thin at this size.
				style.set_border_width_all(style.border_width_left + 1)
			elif id == "battle":
				# Battle keeps a warm edge when it isn't chosen, so it still pulls the eye: battles
				# were "way too hidden" (playtest, 2026-11-23).
				style.border_color = Color(Ui.WARM, 0.6)
				style.set_border_width_all(maxi(style.border_width_left, 2))
			panel.add_theme_stylebox_override("panel", style)
			# The mode card not chosen steps back a little, so the chosen one reads at once.
			panel.modulate = Color.WHITE if on or group == _small else Color(0.86, 0.86, 0.86)
			if _chips.has(id):
				var chip: Panel = _chips[id]
				var chip_box: StyleBoxFlat = chip.get_theme_stylebox("panel") as StyleBoxFlat
				chip_box.border_color = Ui.ACCENT if on else Color(Ui.MUTED, 0.55)
				(chip.get_child(0) as Label).add_theme_color_override("font_color", Ui.ACCENT if on else Ui.MUTED)
			panel.pivot_offset = panel.size * 0.5
			panel.z_index = 1 if on else 0
			var grow: float = (1.04 if group == _panels else 1.06) if on else 1.0
			if panel.is_inside_tree() and panel.size != Vector2.ZERO:
				panel.create_tween().tween_property(panel, "scale", Vector2.ONE * grow, 0.12).set_trans(Tween.TRANS_QUAD)
			else:
				panel.scale = Vector2.ONE * grow



# ---------------------------------------------------------------- pieces

func _mode_card(id: String, x: float, title: String, line: String, status: String, key: String, new: bool) -> void:
	var card := Panel.new()
	Ui.anchor(card, 0.5, 0.0, 0.5, 0.0, x, CARD_TOP, x + CARD_W, CARD_TOP + CARD_H)
	_clickable(card, id)
	add_child(card)
	_panels[id] = card
	var icon := _Icon.new()
	icon.kind = id
	Ui.anchor(icon, 0.0, 0.0, 0.0, 0.0, 30, 46, 180, 196)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	var heading := Ui.heading(title, 72, Ui.TEXT)
	Ui.anchor(heading, 0.0, 0.0, 1.0, 0.0, 206, 22, -24, 108)
	card.add_child(heading)
	var text := Ui.label(line, 24, Ui.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.max_lines_visible = 2
	Ui.anchor(text, 0.0, 0.0, 1.0, 0.0, 206, 110, -24, 176)
	card.add_child(text)
	# The status steps down a size or two in the regions with wider type (Neon Sprawl's Space
	# Grotesk) rather than cutting off.
	var note_size: int = 21
	while note_size > 16 and Ui.font().get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, note_size).x > CARD_W - 206.0 - 24.0:
		note_size -= 1
	# The region's warm colour lifted toward its text colour: the plain warm (Neon Sprawl's hot pink)
	# was too dark on the panels to read at this size.
	var note := Ui.label(status, note_size, Ui.WARM.lerp(Ui.TEXT, 0.3))
	note.clip_text = true
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Ui.anchor(note, 0.0, 1.0, 1.0, 1.0, 206, -60, -24, -24)
	card.add_child(note)
	# The card's key in the top-right corner.
	_chips[id] = _key_chip(key, Vector2(-24, 26))
	card.add_child(_chips[id])
	if new:
		# A sticker in the region's warm colour over the card's top-left corner: battles are the new
		# thing to try. (Beside the key it ran into the heading.)
		var tag := Panel.new()
		var box := StyleBoxFlat.new()
		box.bg_color = Ui.WARM
		box.set_corner_radius_all(4)
		box.shadow_color = Color(0, 0, 0, 0.45)
		box.shadow_size = 4
		box.shadow_offset = Vector2(0, 2)
		tag.add_theme_stylebox_override("panel", box)
		Ui.anchor(tag, 0.0, 0.0, 0.0, 0.0, 20, -20, 128, 24)
		tag.rotation_degrees = -4.0
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tag_text := Ui.heading("NEW", 26, Color(0.06, 0.04, 0.05), HORIZONTAL_ALIGNMENT_CENTER)
		tag_text.remove_theme_color_override("font_shadow_color")
		Ui.anchor(tag_text, 0.0, 0.0, 1.0, 1.0, 0, 4, 0, -4, HORIZONTAL_ALIGNMENT_CENTER)
		tag.add_child(tag_text)
		card.add_child(tag)


func _small_button(id: String, x: float, width: float, title: String, key: String) -> void:
	var button := Panel.new()
	Ui.anchor(button, 0.5, 0.0, 0.5, 0.0, x, BUTTON_TOP, x + width, BUTTON_TOP + BUTTON_H)
	_clickable(button, id)
	add_child(button)
	_small[id] = button
	var text := Ui.label(title, 27, Ui.TEXT)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.anchor(text, 0.0, 0.0, 1.0, 1.0, 24, 4, -80, -4)
	button.add_child(text)
	# The same key cap as the cards', centred on the button's right end.
	_chips[id] = _key_chip(key, Vector2(-18, (BUTTON_H - 36.0) * 0.5))
	button.add_child(_chips[id])


## A key cap in the card's top-right corner: its right edge `inset.x` from the card's, its top at
## `inset.y`.
func _key_chip(key: String, inset: Vector2) -> Panel:
	var face: Font = Ui.mono_font()
	# At least square-ish, so a one-letter key is not a sliver beside SPACE.
	var w: float = maxf(face.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 26.0, 40.0)
	var chip := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.25)
	box.set_border_width_all(2)
	box.border_color = Ui.ACCENT
	box.set_corner_radius_all(4)
	chip.add_theme_stylebox_override("panel", box)
	Ui.anchor(chip, 1.0, 0.0, 1.0, 0.0, inset.x - w, inset.y, inset.x, inset.y + 36)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := Ui.caption(key, 20, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.anchor(text, 0.0, 0.0, 1.0, 1.0, 0, 0, 0, 0, HORIZONTAL_ALIGNMENT_CENTER)
	chip.add_child(text)
	return chip


func _footer_shade() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0, 0, 0, 0.7))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 64
	var shade := TextureRect.new()
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	Ui.anchor(shade, 0.0, 1.0, 1.0, 1.0, 0, -170, 0, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shade


func _clickable(control: Control, id: String) -> void:
	# The chosen item grows about its centre (_refresh).
	control.resized.connect(func() -> void: control.pivot_offset = control.size * 0.5)
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.mouse_entered.connect(select.bind(id))
	control.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			acted.emit(id))


## The cards' pictures, a matched pair drawn in the region's colours on the same perspective road:
## Drive is one car heading for the sunset; Battle is four cars in four lanes racing for a
## chequered line, the leader in the region's warm colour.
class _Icon extends Control:
	const INK := Color(0.03, 0.02, 0.04)
	var kind: String = "drive"

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var lanes: int = 4 if kind == "battle" else 2
		var top_y: float = 14.0 if kind == "battle" else h * 0.4
		var top_l: float = w * (0.2 if kind == "battle" else 0.4)
		var top_r: float = w - top_l
		if kind == "drive":
			# The sun on the horizon, with the synthwave gaps across it.
			var sun := Vector2(w * 0.5, top_y)
			draw_circle(sun, w * 0.24, Ui.WARM, true, -1.0, true)
			draw_rect(Rect2(0, top_y, w, h - top_y), INK)
			for i: int in 3:
				draw_rect(Rect2(sun.x - w * 0.25, top_y - w * 0.05 - i * w * 0.055, w * 0.5, 2.0 + i * 0.8), INK)
			draw_line(Vector2(0, top_y), Vector2(w, top_y), Ui.ACCENT, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(top_l, top_y), Vector2(top_r, top_y), Vector2(w, h), Vector2(0, h)]),
			Color(Ui.ACCENT, 0.1))
		for i: int in lanes + 1:
			var t: float = float(i) / lanes
			var edge: bool = i == 0 or i == lanes
			draw_line(Vector2(lerpf(top_l, top_r, t), top_y), Vector2(w * t, h), Color(Ui.ACCENT, 0.9 if edge else 0.35),
				2.5 if edge else 1.5, true)
		if kind == "battle":
			# The chequered finish line: few, big squares, so it holds up at this size.
			var cells: int = 6
			for i: int in cells:
				for j: int in 2:
					var x0: float = lerpf(top_l, top_r, float(i) / cells)
					var x1: float = lerpf(top_l, top_r, float(i + 1) / cells)
					draw_rect(Rect2(x0, top_y - 14.0 + j * 7.0, x1 - x0, 7.0), Ui.TEXT if (i + j) % 2 == 0 else INK)
			var colors: Array[Color] = [KeyMap.color_for(2), Ui.WARM, Ui.ACCENT, KeyMap.color_for(4)]
			var depth: Array[float] = [0.62, 0.3, 0.46, 0.8]
			for i: int in lanes:
				_car(i, lanes, depth[i], colors[i], top_y, top_l, top_r)
		else:
			# One car in the right-hand lane, on its way to the sunset.
			_car(1, lanes, 0.72, Ui.WARM, top_y, top_l, top_r)

	## A racer in lane `i` of `lanes`, `depth` of the way from the far end (0) to the near end (1).
	func _car(i: int, lanes: int, depth: float, color: Color, top_y: float, top_l: float, top_r: float) -> void:
		var w: float = size.x
		var cx: float = lerpf(lerpf(top_l, top_r, (i + 0.5) / lanes), w * (i + 0.5) / lanes, depth)
		_car_at(cx, depth, (top_r - top_l) / lanes, w / lanes, color, top_y)

	func _car_at(cx: float, depth: float, far_lane: float, near_lane: float, color: Color, top_y: float) -> void:
		var h: float = size.y
		var y: float = lerpf(top_y, h, depth)
		var lane_w: float = lerpf(far_lane, near_lane, depth)
		var car_w: float = minf(lane_w * 0.8, size.x * 0.17)
		var car_h: float = car_w * 1.5
		var body := Rect2(cx - car_w * 0.5, y - car_h * 0.5, car_w, car_h)
		# Speed lines behind it.
		for k: int in 3:
			var sy: float = body.end.y + 4.0 + k * car_h * 0.28
			if sy < h:
				for side: float in [-0.22, 0.22]:
					draw_line(Vector2(cx + car_w * side, sy), Vector2(cx + car_w * side, minf(sy + car_h * 0.16, h)),
						Color(color, 0.55 - k * 0.15), 1.5)
		var shell := StyleBoxFlat.new()
		shell.bg_color = color
		shell.set_corner_radius_all(int(car_w * 0.3))
		shell.anti_aliasing = true
		# A dark edge, so a pale car still separates from the road.
		shell.set_border_width_all(2)
		shell.border_color = INK
		shell.shadow_color = Color(INK, 0.6)
		shell.shadow_size = 3
		shell.shadow_offset = Vector2(0, 2)
		draw_style_box(shell, body)
		# The windscreen, near the front, and a rear window.
		draw_rect(Rect2(body.position.x + car_w * 0.18, body.position.y + car_h * 0.2, car_w * 0.64, car_h * 0.18), INK)
		draw_rect(Rect2(body.position.x + car_w * 0.22, body.position.y + car_h * 0.66, car_w * 0.56, car_h * 0.12), Color(INK, 0.8))
