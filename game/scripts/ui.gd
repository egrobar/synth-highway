class_name Ui
extends RefCounted
## Small helpers for building the menus and HUD in code, styled after the region in view.
##
## Every menu (title, settings, timing check, results, imports, the pause and Escape menus) and
## the drive's HUD take their type, colours and panel shapes from the current region's style,
## matching its song-select skin (the Song Select Redesigns canvas, 2026-11-11): Red Frontier's
## slab serif, vinyl brown and hard shadows; Neon Sprawl's Anton, acid yellow and square
## corners; Tidewater's serif display, coral and rounded frosted panels; Io Burn's stencil,
## sulphur and steel; Ring Road's thin Outfit, mint and glass. main.gd calls use_region() as each
## screen opens; the colours below are read live, so build controls after that call.

static var TEXT := Color(0.93, 0.95, 1.0)
static var MUTED := Color(0.62, 0.66, 0.8)
static var ACCENT := Color(0.247, 0.847, 1.0)
static var WARM := Color(1.0, 0.82, 0.52)


## The key that goes back or opens the menu, as the hints and menus name it. In a browser, Escape
## belongs to the page: WASD Engine's player, like any fullscreen web page, takes it to leave
## fullscreen, so a player pressing it for the menu dropped out of fullscreen instead (playtest,
## 2026-11-12). Backspace does everything Escape does outside a run (main.gd), and the web build
## names it.
static func back_key() -> String:
	return "BACKSPACE" if OS.has_feature("web") else "ESC"


## False in a browser, where quitting doesn't close the tab: it stops the game on its last frame.
## The menus leave out "Quit game" there.
static func can_quit() -> bool:
	return not OS.has_feature("web")

## Per region: display / body / mono typefaces as [family, weight]; text, muted, accent and warm
## colours; panel and selected-panel fills; border colour and width, selected border colour and
## width; corner radius; a hard shadow (offset, colour; none when the colour is clear) under
## selected panels; the dim laid over the 3D world behind a menu.
const STYLES := {
	"backroads": {"display": ["Alfa Slab One", 400], "body": ["Oswald", 500], "mono": ["Courier Prime", 700],
		"text": "#F2E6D4", "muted": "#D8BFA6", "accent": "#FFA552", "warm": "#FFC78C",
		"panel": "#2A1611F2", "panel_on": "#4A2A1CF5", "border": "#120806", "border_w": 3, "border_on": "#FFA552", "border_on_w": 3,
		"radius": 6, "shadow": [5, 5], "shadow_color": "#120806", "dim": "#1A0C08B8"},
	"neon": {"display": ["Anton", 400], "body": ["Space Grotesk", 500], "mono": ["JetBrains Mono", 600],
		"text": "#F4F4F6", "muted": "#A9A9B6", "accent": "#E8FF3A", "warm": "#FF2E88",
		"panel": "#0A0A0EF5", "panel_on": "#15151CF8", "border": "#2B2B36", "border_w": 2, "border_on": "#E8FF3A", "border_on_w": 3,
		"radius": 0, "shadow": [8, 8], "shadow_color": "#FF2E88", "dim": "#0A0A0EB8"},
	"coast": {"display": ["DM Serif Display", 400], "body": ["Manrope", 600], "mono": ["Manrope", 700],
		"text": "#EEF4F2", "muted": "#A9C2C2", "accent": "#FF8F78", "warm": "#FFE9B5",
		"panel": "#020C12E0", "panel_on": "#28100EE6", "border": "#EEF4F24D", "border_w": 1, "border_on": "#FF8F78", "border_on_w": 2,
		"radius": 16, "shadow": [0, 0], "shadow_color": "#00000000", "dim": "#020A10B0"},
	"mesa": {"display": ["Saira Stencil One", 400], "body": ["Oswald", 500], "mono": ["VT323", 400],
		"text": "#E8E2D2", "muted": "#A9A294", "accent": "#FFC81E", "warm": "#FF5A1F",
		"panel": "#2B2A28F5", "panel_on": "#3A3834F8", "border": "#0B0709", "border_w": 3, "border_on": "#FFC81E", "border_on_w": 3,
		"radius": 6, "shadow": [0, 5], "shadow_color": "#0B0709", "dim": "#0D0B06C0"},
	"aurora": {"display": ["Outfit", 200], "body": ["Outfit", 400], "mono": ["Azeret Mono", 400],
		"text": "#F2FFF9", "muted": "#9EC2B8", "accent": "#9EFFCC", "warm": "#FFD9A6",
		"panel": "#020304D9", "panel_on": "#0E1E18E6", "border": "#E9FFF673", "border_w": 2, "border_on": "#9EFFCC", "border_on_w": 2,
		"radius": 0, "shadow": [0, 0], "shadow_color": "#00000000", "dim": "#020304B0"},
}

static var _style: Dictionary = STYLES["neon"]
static var _region: String = ""


## Styles everything built from here on after `region_id` (unknown ids keep the current style).
static func use_region(region_id: String) -> void:
	if region_id == _region or not STYLES.has(region_id):
		return
	_region = region_id
	_style = STYLES[region_id]
	TEXT = Color(str(_style["text"]))
	MUTED = Color(str(_style["muted"]))
	ACCENT = Color(str(_style["accent"]))
	WARM = Color(str(_style["warm"]))


## The body typeface (labels, rows, buttons).
static func font() -> Font:
	return Fonts.get_font(str(_style["body"][0]), int(_style["body"][1]))


## The display typeface (headings, big numbers, the grade).
static func display_font() -> Font:
	return Fonts.get_font(str(_style["display"][0]), int(_style["display"][1]))


## The caption typeface (key hints, small print).
static func mono_font() -> Font:
	return Fonts.get_font(str(_style["mono"][0]), int(_style["mono"][1]))


static func label(text: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _label(text, size, color, align, font())


## A heading in the region's display face.
static func heading(text: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _label(text, size, color, align, display_font())


## Small print and key hints in the region's caption face.
static func caption(text: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _label(text, size, color, align, mono_font())


static func _label(text: String, size: int, color: Color, align: HorizontalAlignment, face: Font) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = align
	node.add_theme_font_override("font", face)
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


## The region's tint laid over the 3D world behind a menu; `alpha` scales its strength.
static func dim_panel(alpha: float = 0.72) -> ColorRect:
	var panel := ColorRect.new()
	var tint := Color(str(_style["dim"]))
	panel.color = Color(tint, clampf(tint.a * alpha / 0.72, 0.0, 0.97))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	return panel


## A panel in the region's style: its fill, border and corners; selected panels take the
## accent border (or `accent` when given) and the region's hard shadow.
static func card(selected: bool, accent: Color = Color(0, 0, 0, 0)) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", card_style(selected, accent))
	return panel


static func card_style(selected: bool, accent: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(str(_style["panel_on" if selected else "panel"]))
	box.set_corner_radius_all(int(_style["radius"]))
	box.set_border_width_all(int(_style["border_on_w" if selected else "border_w"]))
	box.border_color = (accent if accent.a > 0.0 else Color(str(_style["border_on"]))) if selected else Color(str(_style["border"]))
	box.anti_aliasing = int(_style["radius"]) > 0
	var shadow := Color(str(_style["shadow_color"]))
	if selected and shadow.a > 0.0:
		# A hard, unblurred shadow: one pixel of spread, offset.
		box.shadow_color = shadow
		box.shadow_size = 1
		box.shadow_offset = Vector2(float(_style["shadow"][0]), float(_style["shadow"][1]))
	return box


static func color_from_hex(hex: String, fallback: Color = ACCENT) -> Color:
	return Color.from_string(hex, fallback)


static func image(path: String) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return node
