class_name RouteSkin
extends RefCounted
## Base for a region's song-select skin: the shared layout's zones and the drawing helpers.
##
## Design: the "Song Select Redesigns" canvas (2026-11-11), page "Final": one shared layout and
## five region skins, all at 1280x720. RouteScreen scales that design space to the window and
## calls draw() whenever the model changes; a skin draws every zone itself (immediate drawing,
## so skewed buttons, dashed seams, halftones and little illustrated scenes are all possible)
## and registers each clickable area with screen.hit(rect, action, arg).
##
## The model (built by main.gd, _route_model):
##   regions   [{num, name, upper, cleared, total, locked, selected}] for the tabs
##   region    {name, upper, genres, blurb, locked, locked_text}
##   rows      7 slots, the selected song always in slot 3 (the 4th); a slot is {} past either
##             end of the list, else {index, n ("04"), title, upper, grades ("E– N– H–"),
##             level (1-10), selected, imported, freq (an AM dial frequency, for Red Frontier)}
##   count     songs in the region
##   song      the selected song, or {}: {title, upper, bpm, length ("1:39"), number (4),
##             best (grade at the chosen difficulty or ""), imported, remove_armed}
##   cards     [easy, normal, hard]: {name ("EASY"), key ("easy"), available, level, notes, holds,
##             counts ("147 notes · 1 hold", singular and plural right: use it rather than
##             formatting notes and holds), keys, sharps, power (power chords), feel, selected,
##             best}. A level the song has no chart for (Hard, on charts made before it) has
##             available false: draw it dimmed with a short "not charted yet", no level or counts.
##   practice  {on, text ("off" or "85% speed")}
##   locked    true when the region is not open yet (Enter Drive reads LOCKED)
##   message   a passing note to show (an import finished, a song removed), or ""
##   battle    {text ("BATTLE", or "BACK TO LOBBY" while picking a battle's song), key ("B")}:
##             the button at the right end of the hints row (battle_contents)
##   drive_text what Enter Drive reads instead ("ENTER PICK SONG" while picking), or ""
## Actions a skin can register: "region" (index), "song" (index), "difficulty" ("easy",
## "normal" or "hard"), "practice", "drive", "load", "battle".

const W := 1280.0
const H := 720.0
## The shared layout's zones (FinalLayout).
const TABS := Rect2(40, 24, 1200, 60)
const HEADER := Rect2(40, 100, 500, 52)
const LIST_TOP := 164.0
const ROW_H := 50.0
const ROW_PITCH := 56.0
const LOAD := Rect2(40, 566, 500, 46)
const DETAIL := Rect2(580, 100, 660, 230)
## Easy, Normal and Hard across the zone the design gave two cards (x 580-1240, y 350-490), with the
## design's 20 px gaps: 207, 206 and 207 wide.
const CARDS: Array[Rect2] = [Rect2(580, 350, 207, 140), Rect2(807, 350, 206, 140), Rect2(1033, 350, 207, 140)]
const PRACTICE := Rect2(580, 512, 180, 80)
const DRIVE := Rect2(776, 512, 464, 80)
const HINTS_Y := 660.0
## Battle, at the right end of the hints row (added 2026-11-23: nothing past the title showed
## battles). Right of every skin's hints, below its passing message (y 604-646).
const BATTLE := Rect2(1010, 654, 230, 42)
const DASH := "–"

## The fill outside the 1280x720 design when the window is a different shape.
var ground: Color = Color.BLACK

static var _tiles: Dictionary = {}


## Override: draw the whole screen and register its clickable areas.
func draw(_screen: RouteScreen, _m: Dictionary) -> void:
	pass


## Where a row slot sits.
static func row_rect(slot: int, left: float = 40.0, width: float = 500.0) -> Rect2:
	return Rect2(left, LIST_TOP + slot * ROW_PITCH, width, ROW_H)


## Registers the standard clickable areas for whatever the skin drew in the shared zones.
static func register_hits(screen: RouteScreen, m: Dictionary) -> void:
	var regions: Array = m.get("regions", [])
	var tab_w: float = (TABS.size.x - 8.0 * float(regions.size() - 1)) / maxf(float(regions.size()), 1.0)
	for i: int in regions.size():
		screen.hit(Rect2(TABS.position.x + i * (tab_w + 8.0), TABS.position.y, tab_w, TABS.size.y), "region", i)
	var rows: Array = m.get("rows", [])
	for slot: int in rows.size():
		var row: Dictionary = rows[slot]
		if not row.is_empty():
			screen.hit(row_rect(slot), "song", row["index"])
	screen.hit(LOAD, "load")
	if not (m.get("song", {}) as Dictionary).is_empty():
		var cards: Array = m.get("cards", [])
		for i: int in mini(cards.size(), CARDS.size()):
			screen.hit(CARDS[i], "difficulty", str((cards[i] as Dictionary).get("key", Chart.DIFFICULTIES[i])))
		screen.hit(PRACTICE, "practice")
		screen.hit(DRIVE, "drive")
	screen.hit(BATTLE, "battle")


## The Battle button's contents inside `rect`, over the frame the skin drew: a key cap, the label,
## and a short note at the right end when the label is Battle's own.
##   cap   [font, size, ink, fill, edge, radius]
##   label [font, size, colour]; `sentence` sets "BACK TO LOBBY" as "Back to lobby" for the skins
##         whose buttons are in sentence case
##   note  [font, size, colour, text]
static func battle_contents(c: CanvasItem, rect: Rect2, m: Dictionary, cap: Array, label: Array, note: Array,
		sentence: bool = false) -> void:
	var battle: Dictionary = m.get("battle", {})
	var key: String = str(battle.get("key", "B"))
	var cap_font: Font = cap[0]
	var cap_size: int = int(cap[1])
	var edge: Color = cap[4]
	var cap_w: float = maxf(text_width(key, cap_font, cap_size) + 14.0, 26.0)
	var cap_rect := Rect2(rect.position.x + 14.0, rect.get_center().y - 12.0, cap_w, 24.0)
	box(c, cap_rect, cap[3], edge, 1.0 if edge.a > 0.0 else 0.0, float(cap[5]))
	text(c, cap_rect, key, cap_font, cap_size, cap[2], HORIZONTAL_ALIGNMENT_CENTER)
	var title: String = str(battle.get("text", "BATTLE"))
	var own: bool = title == "BATTLE"
	if sentence:
		title = title.left(1) + title.substr(1).to_lower()
	var left: float = cap_rect.end.x + 12.0
	var right: float = rect.end.x - 14.0
	if own:
		var note_font: Font = note[0]
		var note_w: float = text_width(str(note[3]), note_font, int(note[1]))
		text(c, Rect2(right - note_w, rect.position.y, note_w + 1.0, rect.size.y), str(note[3]), note_font, int(note[1]), note[2])
		right -= note_w + 10.0
	# A longer label ("Back to lobby") steps its size down until it fits rather than cutting off.
	var label_font: Font = label[0]
	var label_size: int = int(label[1])
	while label_size > 11 and text_width(title, label_font, label_size) > right - left:
		label_size -= 1
	text(c, Rect2(left, rect.position.y, right - left, rect.size.y), title, label_font, label_size, label[2])


## What the big Enter button reads.
static func drive_label(m: Dictionary) -> String:
	if m["locked"]:
		return "LOCKED"
	if not str(m.get("drive_text", "")).is_empty():
		return str(m["drive_text"])
	return "ENTER PRACTICE" if m["practice"]["on"] else "ENTER DRIVE"


# ---------------------------------------------------------------- text

static func font(family: String, weight: int = 400, spacing: float = 0.0) -> Font:
	return Fonts.get_font(family, weight, spacing)


static func text_width(value: String, f: Font, size: int) -> float:
	return f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## `value` shortened with an ellipsis until it fits `width`.
static func fit(value: String, f: Font, size: int, width: float) -> String:
	if text_width(value, f, size) <= width:
		return value
	var cut: String = value
	while cut.length() > 1 and text_width(cut + "…", f, size) > width:
		cut = cut.left(cut.length() - 1)
	return cut.strip_edges() + "…"


## A list like "Fast runs, finger jumps" cut back an item at a time until it fits `width`, then
## ellipsized: on the narrow difficulty cards the first reason says more than half of two.
static func fit_list(value: String, f: Font, size: int, width: float) -> String:
	var items: PackedStringArray = value.split(", ")
	while items.size() > 1 and text_width(", ".join(items), f, size) > width:
		items.resize(items.size() - 1)
	return fit(", ".join(items), f, size, width)


## Text inside `rect`: aligned left, centre or right, and placed vertically by `valign`
## (0 top, 0.5 middle, 1 bottom) on the font's own ascent and descent. Too wide: ellipsis.
static func text(c: CanvasItem, rect: Rect2, value: String, f: Font, size: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, valign: float = 0.5) -> void:
	var shown: String = fit(value, f, size, rect.size.x)
	var ascent: float = f.get_ascent(size)
	var height: float = ascent + f.get_descent(size)
	var baseline: float = rect.position.y + (rect.size.y - height) * valign + ascent
	draw_text(c, f, Vector2(rect.position.x, baseline), shown, align, rect.size.x, size, color)


## Text from a baseline point, unbounded.
static func text_at(c: CanvasItem, baseline_left: Vector2, value: String, f: Font, size: int, color: Color) -> void:
	draw_text(c, f, baseline_left, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Outlined text (CSS -webkit-text-stroke over a transparent fill).
static func text_outline(c: CanvasItem, baseline_left: Vector2, value: String, f: Font, size: int, color: Color, width: int) -> void:
	draw_text(c, f, baseline_left, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color, width)


## Draws a string on `c`. The song select and the loop map draw their 1280x720 design through a
## scale (RouteScreen and LoopMap expose it as `draw_scale` and the transform in use as
## `draw_matrix`): text drawn straight through it was rasterised at its design size and then
## stretched, 1.25x at the game's base size and more on bigger screens, and looked blurry next to
## the crisp menus (playtest, 2026-11-23). So the glyphs are drawn at their on-screen size under
## the inverse scale, which lands them in exactly the same place. `outline` >= 0 draws an outline
## of that width (design pixels) instead of the fill.
static func draw_text(c: CanvasItem, f: Font, at: Vector2, value: String, align: HorizontalAlignment, width: float,
		size: int, color: Color, outline: int = -1) -> void:
	var scale_value: Variant = c.get("draw_scale")
	var k: float = float(scale_value) if scale_value != null else 1.0
	if is_equal_approx(k, 1.0) or k <= 0.0:
		if outline >= 0:
			c.draw_string_outline(f, at, value, align, width, size, outline, color)
		else:
			c.draw_string(f, at, value, align, width, size, color)
		return
	var matrix: Transform2D = c.get("draw_matrix")
	c.draw_set_transform_matrix(matrix * Transform2D(0.0, Vector2(1.0 / k, 1.0 / k), 0.0, Vector2.ZERO))
	# Rounded down, so text never comes out wider than the design measured it (fit() trims to that).
	var big: int = maxi(1, floori(size * k))
	# A pixel of slack: hinting at the bigger size can add one, and draw_string drops what overflows.
	var span: float = width * k + 1.0 if width > 0.0 else -1.0
	# Tracking to the nearest pixel keeps the design's look; where that would overflow a label
	# fitted to its exact width ("ENTER DRIV"), it rounds down instead.
	var face: Font = Fonts.spaced_for_scale(f, k)
	if span > 0.0 and face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x > span:
		face = Fonts.spaced_for_scale(f, k, true)
	if outline >= 0:
		c.draw_string_outline(face, at * k, value, align, span, big, maxi(1, int(round(outline * k))), color)
	else:
		c.draw_string(face, at * k, value, align, span, big, color)
	c.draw_set_transform_matrix(matrix)


## draw_multiline_string, sharp the same way as draw_text.
static func draw_multiline_text(c: CanvasItem, f: Font, at: Vector2, value: String, align: HorizontalAlignment,
		width: float, size: int, max_lines: int, color: Color) -> void:
	var scale_value: Variant = c.get("draw_scale")
	var k: float = float(scale_value) if scale_value != null else 1.0
	if is_equal_approx(k, 1.0) or k <= 0.0:
		c.draw_multiline_string(f, at, value, align, width, size, max_lines, color)
		return
	var matrix: Transform2D = c.get("draw_matrix")
	c.draw_set_transform_matrix(matrix * Transform2D(0.0, Vector2(1.0 / k, 1.0 / k), 0.0, Vector2.ZERO))
	c.draw_multiline_string(Fonts.spaced_for_scale(f, k), at * k, value, align, width * k + 1.0, maxi(1, floori(size * k)),
		max_lines, color)
	c.draw_set_transform_matrix(matrix)


# ---------------------------------------------------------------- shapes

## A filled box, optionally bordered (inside the rect, like CSS border-box) and rounded.
static func box(c: CanvasItem, rect: Rect2, fill: Color, border: Color = Color.TRANSPARENT, border_w: float = 0.0,
		radius: float = 0.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.draw_center = fill.a > 0.0
	if border_w > 0.0:
		style.border_color = border
		style.set_border_width_all(int(round(border_w)))
	style.set_corner_radius_all(int(round(radius)))
	style.anti_aliasing = radius > 0.0
	style.draw(c.get_canvas_item(), rect)


## A hard, unblurred drop shadow: the same box, offset, in one colour.
static func hard_shadow(c: CanvasItem, rect: Rect2, offset: Vector2, color: Color, radius: float = 0.0) -> void:
	box(c, Rect2(rect.position + offset, rect.size), color, Color.TRANSPARENT, 0.0, radius)


static func dashed_line(c: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 2.0, dash: float = 6.0, gap: float = 4.0) -> void:
	var length: float = a.distance_to(b)
	var direction: Vector2 = (b - a) / maxf(length, 0.001)
	var t: float = 0.0
	while t < length:
		c.draw_line(a + direction * t, a + direction * minf(t + dash, length), color, width)
		t += dash + gap


static func dashed_box(c: CanvasItem, rect: Rect2, color: Color, width: float = 2.0, dash: float = 6.0, gap: float = 4.0) -> void:
	var inset: float = width * 0.5
	var r: Rect2 = rect.grow(-inset)
	dashed_line(c, r.position, Vector2(r.end.x, r.position.y), color, width, dash, gap)
	dashed_line(c, Vector2(r.end.x, r.position.y), r.end, color, width, dash, gap)
	dashed_line(c, r.end, Vector2(r.position.x, r.end.y), color, width, dash, gap)
	dashed_line(c, Vector2(r.position.x, r.end.y), r.position, color, width, dash, gap)


## The four corners of `rect` sheared like CSS skewX(-deg) about its centre: positive `deg`
## leans the top to the right, as in the Neon Sprawl skin.
static func skewed(rect: Rect2, deg: float) -> PackedVector2Array:
	var lean: float = tan(deg_to_rad(deg)) * rect.size.y * 0.5
	return PackedVector2Array([
		Vector2(rect.position.x + lean, rect.position.y), Vector2(rect.end.x + lean, rect.position.y),
		Vector2(rect.end.x - lean, rect.end.y), Vector2(rect.position.x - lean, rect.end.y)])


static func poly(c: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	c.draw_colored_polygon(points, color)


## A closed outline around `points`.
static func outline(c: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	c.draw_polyline(closed, color, width, true)


## A vertical gradient through `colors` at `stops` (0 top to 1 bottom), filling `rect`.
static func vgradient(c: CanvasItem, rect: Rect2, colors: Array, stops: Array) -> void:
	for i: int in colors.size() - 1:
		var y0: float = rect.position.y + rect.size.y * float(stops[i])
		var y1: float = rect.position.y + rect.size.y * float(stops[i + 1])
		c.draw_polygon(PackedVector2Array([Vector2(rect.position.x, y0), Vector2(rect.end.x, y0),
				Vector2(rect.end.x, y1), Vector2(rect.position.x, y1)]),
				PackedColorArray([colors[i], colors[i], colors[i + 1], colors[i + 1]]))


## A horizontal gradient, left to right.
static func hgradient(c: CanvasItem, rect: Rect2, colors: Array, stops: Array) -> void:
	for i: int in colors.size() - 1:
		var x0: float = rect.position.x + rect.size.x * float(stops[i])
		var x1: float = rect.position.x + rect.size.x * float(stops[i + 1])
		c.draw_polygon(PackedVector2Array([Vector2(x0, rect.position.y), Vector2(x1, rect.position.y),
				Vector2(x1, rect.end.y), Vector2(x0, rect.end.y)]),
				PackedColorArray([colors[i], colors[i + 1], colors[i + 1], colors[i]]))


## A soft round glow: concentric discs fading out (CSS radial-gradient to transparent).
static func glow(c: CanvasItem, center: Vector2, radius: Vector2, color: Color, steps: int = 14) -> void:
	for i: int in steps:
		var t: float = 1.0 - float(i) / float(steps)
		var shade := Color(color, color.a * (1.0 - t) * 2.0 / float(steps))
		ellipse(c, center, radius * t, shade)


static func ellipse(c: CanvasItem, center: Vector2, radius: Vector2, color: Color, segments: int = 48) -> void:
	c.draw_colored_polygon(ellipse_points(center, radius, segments), color)


static func ellipse_points(center: Vector2, radius: Vector2, segments: int = 48, rotation_deg: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var turn: float = deg_to_rad(rotation_deg)
	for i: int in segments:
		var a: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y).rotated(turn))
	return points


## A quadratic Bezier curve as points (SVG "Q").
static func quad(a: Vector2, control: Vector2, b: Vector2, steps: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		points.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	return points


## An arrow pointing right, like the designs' "→" icons: a shaft and an open head.
static func arrow(c: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var mid: float = rect.position.y + rect.size.y * 0.5
	c.draw_line(Vector2(rect.position.x, mid), Vector2(rect.end.x - width * 0.5, mid), color, width)
	var head: float = rect.size.y * 0.5
	c.draw_polyline(PackedVector2Array([Vector2(rect.end.x - head, rect.position.y), Vector2(rect.end.x, mid),
			Vector2(rect.end.x - head, rect.end.y)]), color, width)


# ---------------------------------------------------------------- patterns

## A tile with one round dot in it (CSS radial-gradient dot patterns): drawn repeated with
## pattern(). Made once per (colour, spacing, radius).
static func dot_tile(color: Color, spacing: int, radius: float) -> Texture2D:
	var key: String = "dot|%s|%d|%.2f" % [color.to_html(), spacing, radius]
	if _tiles.has(key):
		return _tiles[key]
	var image := Image.create(spacing, spacing, false, Image.FORMAT_RGBA8)
	var middle: float = float(spacing) * 0.5
	for y: int in spacing:
		for x: int in spacing:
			var d: float = Vector2(x + 0.5 - middle, y + 0.5 - middle).length()
			var a: float = clampf(radius + 0.5 - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(color, color.a * a))
	var texture := ImageTexture.create_from_image(image)
	_tiles[key] = texture
	return texture


## A repeating texture over `rect` (the screen draws with texture repeat on).
static func pattern(c: CanvasItem, rect: Rect2, tile: Texture2D) -> void:
	c.draw_texture_rect(tile, rect, true)


## A repeating texture filling a polygon (CSS clip-path over a pattern).
static func pattern_poly(c: CanvasItem, points: PackedVector2Array, tile: Texture2D) -> void:
	var uvs := PackedVector2Array()
	var size: Vector2 = tile.get_size()
	for p: Vector2 in points:
		uvs.append(p / size)
	c.draw_colored_polygon(points, Color.WHITE, uvs, tile)


## Evenly spaced parallel lines across `rect` (CSS repeating-linear-gradient stripes),
## horizontal when `vertical_lines` is false.
static func stripes(c: CanvasItem, rect: Rect2, color: Color, width: float, period: float, vertical_lines: bool = false) -> void:
	if vertical_lines:
		var x: float = rect.position.x
		while x < rect.end.x:
			c.draw_rect(Rect2(x, rect.position.y, minf(width, rect.end.x - x), rect.size.y), color)
			x += period
	else:
		var y: float = rect.position.y
		while y < rect.end.y:
			c.draw_rect(Rect2(rect.position.x, y, rect.size.x, minf(width, rect.end.y - y)), color)
			y += period


## Diagonal hazard stripes in a band: alternating colours at 45 degrees.
static func hazard(c: CanvasItem, rect: Rect2, a: Color, b: Color, stripe: float) -> void:
	c.draw_rect(rect, b)
	var x: float = rect.position.x - rect.size.y
	while x < rect.end.x:
		var band := PackedVector2Array([Vector2(x, rect.end.y), Vector2(x + stripe, rect.end.y),
				Vector2(x + stripe + rect.size.y, rect.position.y), Vector2(x + rect.size.y, rect.position.y)])
		var clipped: Array = Geometry2D.intersect_polygons(band, rect_points(rect))
		for part: PackedVector2Array in clipped:
			c.draw_colored_polygon(part, a)
		x += stripe * 2.0


static func rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


## A polygon cut to a rectangle (CSS overflow: hidden): each piece filled in `color`.
static func clipped_poly(c: CanvasItem, points: PackedVector2Array, clip: Rect2, color: Color) -> void:
	for part: PackedVector2Array in Geometry2D.intersect_polygons(points, rect_points(clip)):
		c.draw_colored_polygon(part, color)
