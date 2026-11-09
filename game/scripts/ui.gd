class_name Ui
extends RefCounted
## Small helpers for building the menus and HUD in code.

const TEXT := Color(0.93, 0.95, 1.0)
const MUTED := Color(0.62, 0.66, 0.8)
const ACCENT := Color(0.247, 0.847, 1.0)
const WARM := Color(1.0, 0.82, 0.52)

static var _font: SystemFont


static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Avenir Next Condensed", "Helvetica Neue", "Arial"])
		_font.font_weight = 700
	return _font


static func label(text: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = align
	node.add_theme_font_override("font", font())
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	node.add_theme_constant_override("shadow_offset_y", 2)
	return node


## Places a control by anchors and pixel offsets. Passing an alignment also sets a label's.
static func anchor(control: Control, left: float, top: float, right: float, bottom: float, offset_left: float,
		offset_top: float, offset_right: float, offset_bottom: float, align: int = -1) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = offset_left
	control.offset_top = offset_top
	control.offset_right = offset_right
	control.offset_bottom = offset_bottom
	if align >= 0 and control is Label:
		(control as Label).horizontal_alignment = align as HorizontalAlignment


static func dim_panel(alpha: float = 0.72) -> ColorRect:
	var panel := ColorRect.new()
	panel.color = Color(0.015, 0.02, 0.05, alpha)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	return panel


## A rounded translucent card, outlined in the accent colour when selected.
static func card(selected: bool, accent: Color = ACCENT) -> Panel:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.04, 0.09, 0.84 if selected else 0.62)
	box.set_corner_radius_all(14)
	box.set_border_width_all(3 if selected else 1)
	box.border_color = accent if selected else Color(1, 1, 1, 0.12)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", box)
	return panel


static func color_from_hex(hex: String, fallback: Color = ACCENT) -> Color:
	return Color.from_string(hex, fallback)


static func image(path: String) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return node
