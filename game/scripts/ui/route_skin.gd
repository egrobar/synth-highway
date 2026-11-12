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
## Actions a skin can register: "region" (index), "song" (index), "difficulty" ("easy",
## "normal" or "hard"), "practice", "drive", "load".

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
	c.draw_string(f, Vector2(rect.position.x, baseline), shown, align, rect.size.x, size, color)


## Text from a baseline point, unbounded.
static func text_at(c: CanvasItem, baseline_left: Vector2, value: String, f: Font, size: int, color: Color) -> void:
	c.draw_string(f, baseline_left, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Outlined text (CSS -webkit-text-stroke over a transparent fill).
static func text_outline(c: CanvasItem, baseline_left: Vector2, value: String, f: Font, size: int, color: Color, width: int) -> void:
	c.draw_string_outline(f, baseline_left, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, width, color)


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
