class_name IoSkin
extends RouteSkin
## Io Burn's song select: a reactor control room (canvas "Final · Io Burn", FinalIo).
##
## Warm grey steel under fine scanlines, yellow-and-black hazard bands along the top and bottom
## edges; regions as chunky sector keys with indicator lamps and stencil numbers; a radiation
## trefoil by the region name; the song list is a breaker panel (a toggle beside each label
## strip, thrown up for the armed circuit); the selected song on a black phosphor readout
## (VT323, amber glow, dot screen); difficulty as mode buttons, the chosen one pressed in;
## practice under a red switch cover; Enter Drive as a red mushroom button in a hazard ring;
## key hints on a riveted plate in the region's own words (SECTOR / CIRCUIT / MODE).

const BG := Color("#2B2A28")
const STEEL := Color("#3A3834")
const STEEL_LEDGE := Color("#24221F")
const PANEL := Color("#1E1D1B")
const INK := Color("#0B0709")
const RIM := Color("#4A4640")
const SULPHUR := Color("#FFC81E")
const SULPHUR_LEDGE := Color("#C99A0E")
const AMBER := Color("#E0A80E")
const LAMP := Color("#FF5A1F")
const LAMP_OFF := Color("#4A1A10")
const BONE := Color("#E8E2D2")
const LABEL := Color("#D8D2C2")
const DIM := Color("#A9A294")
const MUTED := Color("#BDB6A6")
const GRIP := Color("#6A665E")
const LEVER := Color("#9A958A")
const COVER := Color("#E3261B")
const SCREEN := Color("#0D0B06")
const LOCKED_FACE := Color("#302E2B")
const LOCKED_INK := Color("#8A857A")

## The readout's content box (inside its 6 px frame and 18/24 px padding) and title sizes.
const READOUT := Rect2(610, 124, 600, 182)
const TITLE_SIZES: Array[int] = [66, 60, 54, 48]

## The Enter Drive button (hazard ring, shadow, red cap) as one antialiased image per state.
static var _buttons: Dictionary = {}


func _init() -> void:
	ground = BG


func draw(s: RouteScreen, m: Dictionary) -> void:
	_backdrop(s)
	_tabs(s, m)
	_header(s, m)
	_panel(s, m)
	_load(s)
	_readout(s, m)
	if not (m["song"] as Dictionary).is_empty():
		for i: int in mini((m["cards"] as Array).size(), CARDS.size()):
			_mode(s, CARDS[i], m["cards"][i])
		_practice(s, m)
	_drive(s, m)
	_hints(s, m)
	if not str(m.get("message", "")).is_empty():
		_message(s, str(m["message"]))
	register_hits(s, m)


func _backdrop(s: RouteScreen) -> void:
	s.draw_rect(Rect2(0, 0, W, H), BG)
	# Two scanline layers: a dark 2 px band every 11 px under a faint light line every 3 px.
	stripes(s, Rect2(0, 0, W, H), Color(0, 0, 0, 0.12), 2.0, 11.0)
	stripes(s, Rect2(0, 0, W, H), Color(1, 1, 1, 0.025), 1.0, 3.0)
	# CSS repeating-linear-gradient(-45deg, 16 px each): 16 * sqrt(2) measured along the edge.
	hazard(s, Rect2(0, 0, W, 12), SULPHUR, INK, 16.0 * sqrt(2.0))
	hazard(s, Rect2(0, H - 12, W, 12), SULPHUR, INK, 16.0 * sqrt(2.0))


func _tabs(s: RouteScreen, m: Dictionary) -> void:
	var regions: Array = m["regions"]
	var w: float = (TABS.size.x - 8.0 * (regions.size() - 1)) / regions.size()
	for i: int in regions.size():
		var r: Dictionary = regions[i]
		var rect := Rect2(TABS.position.x + i * (w + 8.0), TABS.position.y, w, TABS.size.y)
		var on: bool = r["selected"]
		var locked: bool = r["locked"]
		var face: Color = SULPHUR if on else (LOCKED_FACE if locked else STEEL)
		_key(s, rect, face, SULPHUR_LEDGE if on else STEEL_LEDGE, 5.0, 3.0, 6.0)
		var cy: float = rect.position.y + rect.size.y * 0.5
		var x: float = rect.position.x + 17.0
		# The indicator lamp: lit on the chosen sector, dark on the rest, dead on a locked one.
		var lamp: Color = LAMP if on else (Color("#2A2826") if locked else LAMP_OFF)
		s.draw_circle(Vector2(x + 5.0, cy), 7.0, INK, true, -1.0, true)
		s.draw_circle(Vector2(x + 5.0, cy), 5.0, lamp, true, -1.0, true)
		if on:
			s.draw_circle(Vector2(x + 3.6, cy - 1.6), 1.6, Color(1, 1, 1, 0.55), true, -1.0, true)
		x += 22.0
		var ink: Color = INK if on else (LOCKED_INK if locked else LABEL)
		var num: String = str(r["num"])
		var num_font: Font = font("Saira Stencil One")
		var num_w: float = text_width(num, num_font, 28)
		text(s, Rect2(x, cy - 14.0, num_w + 2.0, 28), num, num_font, 28, ink)
		x += num_w + 12.0
		var avail: float = rect.end.x - 17.0 - x
		# Two lines at line-height 1.1 (14 px and 11 px), centred on the key.
		var top: float = cy - 13.75
		text(s, Rect2(x, top, avail, 15.4), str(r["upper"]), font("Oswald", 700 if on else 600, 1.0), 14, ink)
		var status: String = "LOCKED" if locked else "%d/%d cleared" % [r["cleared"], r["total"]]
		var status_color: Color = INK if on else (LAMP if locked else DIM)
		text(s, Rect2(x, top + 15.4, avail, 12.1), status, font("Oswald", 600 if locked else 400, 1.0 if locked else 0.0), 11, status_color)


func _header(s: RouteScreen, m: Dictionary) -> void:
	var region: Dictionary = m["region"]
	_trefoil(s, Vector2(40.05, 103.0), 0.65)
	var title_font: Font = font("Saira Stencil One", 400, 1.0)
	var name: String = str(region["upper"])
	var name_w: float = text_width(name, title_font, 32)
	var x: float = 40.0 + 30.0 + 12.0
	text(s, Rect2(x, 100, name_w + 2.0, 32), name, title_font, 32, SULPHUR)
	x += name_w + 12.0
	var genres: String = str(region["genres"]).to_upper().replace(", ", " / ")
	text(s, Rect2(x, 100, maxf(540.0 - x, 10.0), 32), genres, font("Oswald", 600, 1.5), 12, LABEL)
	var locked: bool = region["locked"]
	var line: String = str(region["locked_text"]) if locked else str(region["blurb"])
	text(s, Rect2(40, 134, 500, 19.3), line, font("Oswald", 500 if locked else 400), 13, LAMP if locked else MUTED)


## The radiation warning sign from the design's SVG (viewBox 46 x 40), scaled by `k`.
func _trefoil(s: RouteScreen, o: Vector2, k: float) -> void:
	var sign: PackedVector2Array = _pts(o, k, [23, 2, 44, 38, 2, 38])
	poly(s, sign, SULPHUR)
	outline(s, sign, INK, 2.0 * k)
	s.draw_circle(o + Vector2(23, 26) * k, 4.0 * k, INK, true, -1.0, true)
	for blade: Array in [[23, 16, 19, 23, 27, 23], [15, 30, 19, 24, 22, 29], [31, 30, 27, 24, 24, 29]]:
		poly(s, _pts(o, k, blade), INK)


func _panel(s: RouteScreen, m: Dictionary) -> void:
	var panel := Rect2(32, 158, 516, 400)
	box(s, panel, PANEL, INK, 2.0)
	box(s, panel.grow(-2.0), Color.TRANSPARENT, RIM, 1.0)
	if (m["count"] as int) == 0:
		text(s, Rect2(panel.position.x, 330, panel.size.x, 30), "NO CIRCUITS ON THIS PANEL YET", font("Saira Stencil One", 400, 1.0), 22,
				LABEL, HORIZONTAL_ALIGNMENT_CENTER)
		text(s, Rect2(panel.position.x, 362, panel.size.x, 20), "Patch one in with L", font("Oswald"), 13, DIM, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var rows: Array = m["rows"]
	for slot: int in rows.size():
		var row: Dictionary = rows[slot]
		if not row.is_empty():
			_breaker(s, row_rect(slot), row)


## One circuit: a toggle (up when armed), the label strip, the grades and the level.
func _breaker(s: RouteScreen, r: Rect2, row: Dictionary) -> void:
	var on: bool = row["selected"]
	if on:
		s.draw_rect(r, Color(SULPHUR, 0.12))
		box(s, r, Color.TRANSPARENT, SULPHUR, 2.0)
	# The toggle, from the design's 22 x 36 SVG drawn into 20 x 34 (centred, so 0.65 px down).
	var k: float = 20.0 / 22.0
	var o := Vector2(r.position.x + 12.0, r.position.y + 8.65)
	var body := Rect2(o + Vector2(1, 12 if on else 2) * k, Vector2(20, 22) * k)
	box(s, body, INK, GRIP, 1.0, 3.0 * k)
	if on:
		_stick(s, o + Vector2(11, 24) * k, o + Vector2(11, 3) * k, SULPHUR, 5.0 * k)
	else:
		_stick(s, o + Vector2(11, 12) * k, o + Vector2(11, 33) * k, LEVER, 5.0 * k)
	var content_end: float = r.end.x - 12.0
	var level_text: String = "LV %d" % int(row["level"])
	var level_font: Font = font("Saira Stencil One")
	var level_size: int = 18 if on else 16
	var level_w: float = maxf(52.0, text_width(level_text, level_font, level_size) + 1.0)
	text(s, Rect2(content_end - level_w, r.position.y, level_w, r.size.y), level_text, level_font, level_size,
			SULPHUR if on else LABEL, HORIZONTAL_ALIGNMENT_RIGHT)
	var grades: String = str(row["grades"])
	var grades_font: Font = font("Oswald", 500 if on else 400)
	var grades_w: float = text_width(grades, grades_font, 12)
	var grades_x: float = content_end - level_w - 12.0 - grades_w
	text(s, Rect2(grades_x, r.position.y, grades_w + 1.0, r.size.y), grades, grades_font, 12, SULPHUR if on else DIM)
	var strip_x: float = r.position.x + 44.0
	var strip := Rect2(strip_x, r.position.y + 9.0, grades_x - 12.0 - strip_x, 32.0)
	s.draw_rect(strip, SULPHUR if on else LABEL)
	var label_rect: Rect2 = strip.grow_individual(-10.0, 0.0, -10.0, 0.0)
	if row.get("imported", false):
		var tag_font: Font = font("Oswald", 600, 1.0)
		var tag_w: float = text_width("YOUR SONG", tag_font, 10) + 10.0
		var tag := Rect2(strip.end.x - 6.0 - tag_w, strip.position.y + 8.0, tag_w, 16.0)
		s.draw_rect(tag, INK)
		text(s, tag, "YOUR SONG", tag_font, 10, SULPHUR, HORIZONTAL_ALIGNMENT_CENTER)
		label_rect.size.x -= tag_w + 4.0
	text(s, label_rect, "%s · %s" % [row["n"], row["upper"]], font("Oswald", 700 if on else 600, 1.0), 17 if on else 16, INK)


func _load(s: RouteScreen) -> void:
	box(s, LOAD, PANEL)
	dashed_box(s, LOAD, GRIP, 2.0, 6.0, 5.0)
	text(s, Rect2(LOAD.position.x + 16, LOAD.position.y, 380, LOAD.size.y), "+ PATCH IN YOUR OWN SONG", font("Oswald", 600, 2.0), 15, SULPHUR)
	# The "L" key cap at the far end.
	var cap_font: Font = font("Oswald")
	var cap := Rect2(LOAD.end.x - 16.0 - 20.0, LOAD.position.y + 13.0, 20.0, 20.0)
	box(s, cap, Color.TRANSPARENT, GRIP, 1.0)
	text(s, cap, "L", cap_font, 12, DIM, HORIZONTAL_ALIGNMENT_CENTER)


func _readout(s: RouteScreen, m: Dictionary) -> void:
	box(s, DETAIL, SCREEN, INK, 6.0)
	box(s, DETAIL.grow(-6.0), Color.TRANSPARENT, RIM, 2.0)
	pattern(s, DETAIL.grow(-6.0), dot_tile(Color(0, 0, 0, 0.5), 4, 1.2))
	var song: Dictionary = m["song"]
	var small: Font = font("VT323", 400, 2.0)
	var status: String
	var status_color: Color = AMBER
	var title: String
	var facts: String
	if song.is_empty():
		status = "> NO CIRCUIT ARMED"
		title = "PANEL EMPTY"
		facts = "PATCH IN A SONG WITH L"
	else:
		var best: String = str(song["best"])
		status = "> CIRCUIT %02d OF %02d ARMED · %s" % [song["number"], m["count"], ("BEST " + best) if not best.is_empty() else "NOT DRIVEN"]
		if song.get("remove_armed", false):
			status = "> PRESS X AGAIN TO MOVE IT TO THE TRASH"
			status_color = LAMP
		title = str(song["upper"])
		facts = "%d BPM   %s" % [song["bpm"], song["length"]]
	# Stacked from the bottom up (the design's justify-content: flex-end).
	var y: float = READOUT.end.y
	var facts_h: float = small.get_ascent(26) + small.get_descent(26)
	var facts_rect := Rect2(READOUT.position.x, y - facts_h, READOUT.size.x, facts_h)
	y -= facts_h
	if song.get("imported", false):
		var tag_w: float = text_width("YOUR SONG", small, 22) + 16.0
		var tag := Rect2(READOUT.end.x - tag_w, facts_rect.position.y + 2.0, tag_w, facts_h - 4.0)
		s.draw_rect(tag.grow(2.0), Color(SULPHUR, 0.18))
		s.draw_rect(tag, SULPHUR)
		text(s, tag, "YOUR SONG", small, 22, SCREEN, HORIZONTAL_ALIGNMENT_CENTER)
		facts_rect.size.x -= tag_w + 16.0
	_lit(s, facts_rect, facts, small, 26, SULPHUR)
	var status_h: float = small.get_ascent(22) + small.get_descent(22)
	var big: Font = font("VT323")
	var fitted: Array = _fit_title(title, big, READOUT.size.x, y - READOUT.position.y - status_h)
	var size: int = fitted[0]
	var lines: Array = fitted[1]
	var line_h: float = 0.95 * float(size)
	for i: int in range(lines.size() - 1, -1, -1):
		_lit(s, Rect2(READOUT.position.x, y - line_h, READOUT.size.x, line_h), str(lines[i]), big, size, SULPHUR)
		y -= line_h
	_lit(s, Rect2(READOUT.position.x, y - status_h, READOUT.size.x, status_h), status, small, 22, status_color)


## The title on one line at 76 px, or shrunk a little (to 64) to stay on one; else split
## evenly onto two lines at the largest size that holds both; else two lines at the smallest
## with the second ellipsized. [size, lines]. (Wrapping "SYSTEM.EXE (I MISS YOU)" greedily
## at 66 left "YOU)" alone on the second line: a slight shrink reads better.)
func _fit_title(title: String, f: Font, width: float, height: float) -> Array:
	for size: int in [76, 70, 64]:
		if text_width(title, f, size) <= width:
			return [size, [title]]
	for size: int in TITLE_SIZES:
		if 2.0 * 0.95 * float(size) > height:
			continue
		var lines: Array = _wrap_two(title, f, size, width)
		if not lines.is_empty():
			return [size, lines]
	var smallest: int = TITLE_SIZES[TITLE_SIZES.size() - 1]
	var words: PackedStringArray = title.split(" ", false)
	var first: String = ""
	var used: int = 0
	for word: String in words:
		var trial: String = word if first.is_empty() else first + " " + word
		if text_width(trial, f, smallest) > width:
			break
		first = trial
		used += 1
	if used == 0:
		return [smallest, [fit(title, f, smallest, width)]]
	var rest: String = " ".join(words.slice(used))
	return [smallest, [first, fit(rest, f, smallest, width)]]


## `title` broken at the word gap that makes the two lines most even, if both then fit
## `width`; [] if no break does.
func _wrap_two(title: String, f: Font, size: int, width: float) -> Array:
	var words: PackedStringArray = title.split(" ", false)
	var best: Array = []
	var best_w: float = INF
	for cut: int in range(1, words.size()):
		var first: String = " ".join(words.slice(0, cut))
		var rest: String = " ".join(words.slice(cut))
		var widest: float = maxf(text_width(first, f, size), text_width(rest, f, size))
		if widest <= width and widest < best_w:
			best = [first, rest]
			best_w = widest
	return best


## Phosphor text: two soft outlines under the glyphs (CSS text-shadow 0 0 6px at half alpha).
func _lit(s: RouteScreen, rect: Rect2, value: String, f: Font, size: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var shown: String = fit(value, f, size, rect.size.x)
	var ascent: float = f.get_ascent(size)
	var height: float = ascent + f.get_descent(size)
	var at := Vector2(rect.position.x, rect.position.y + (rect.size.y - height) * 0.5 + ascent)
	s.draw_string_outline(f, at, shown, align, rect.size.x, size, 10, Color(color, 0.07))
	s.draw_string_outline(f, at, shown, align, rect.size.x, size, 4, Color(color, 0.14))
	s.draw_string(f, at, shown, align, rect.size.x, size, color)


## A mode button: the chosen one pressed in (sulphur, shadowed at the top), the other raised
## on its ledge. Name and level, note counts (and the best grade), then keys and feel. Three
## share the zone two had, so the stencil is 24 px (28 overran "NORMAL  LV 10") and the feel line
## drops its second reason (or ellipsizes) to fit.
func _mode(s: RouteScreen, rect: Rect2, card: Dictionary) -> void:
	if not card.get("available", true):
		# A mode with no chart behind it yet: a dead key, unlit, no level.
		_key(s, rect, LOCKED_FACE, STEEL_LEDGE, 6.0, 3.0, 8.0)
		var stencil: Font = font("Saira Stencil One")
		var label: Font = font("Oswald", 600, 1.0)
		var bx: float = rect.position.x + 18.0
		var bw: float = rect.size.x - 36.0
		var top: float = rect.position.y + (rect.size.y - 6.0 - _line_h(stencil, 24) - 4.0 - _line_h(label, 13)) * 0.5
		text(s, Rect2(bx, top, bw, _line_h(stencil, 24)), str(card["name"]), stencil, 24, LOCKED_INK)
		text(s, Rect2(bx, top + _line_h(stencil, 24) + 4.0, bw, _line_h(label, 13)), "NOT CHARTED YET", label, 13, LOCKED_INK)
		return
	var on: bool = card["selected"]
	if on:
		box(s, rect, SULPHUR, Color.TRANSPARENT, 0.0, 8.0)
		# CSS inset 0 4px 10px rgba(0,0,0,0.3): darkest along the top, a little down the sides.
		var inner: Rect2 = rect.grow(-3.0)
		vgradient(s, Rect2(inner.position, Vector2(inner.size.x, 16)), [Color(0, 0, 0, 0.26), Color(0, 0, 0, 0)], [0.0, 1.0])
		hgradient(s, Rect2(inner.position, Vector2(8, inner.size.y)), [Color(0, 0, 0, 0.1), Color(0, 0, 0, 0)], [0.0, 1.0])
		hgradient(s, Rect2(inner.end.x - 8.0, inner.position.y, 8, inner.size.y), [Color(0, 0, 0, 0), Color(0, 0, 0, 0.1)], [0.0, 1.0])
		box(s, rect, Color.TRANSPARENT, INK, 3.0, 8.0)
	else:
		_key(s, rect, STEEL, STEEL_LEDGE, 6.0, 3.0, 8.0)
	var name_font: Font = font("Saira Stencil One")
	var counts_font: Font = font("Oswald", 600 if on else 500)
	var small_font: Font = font("Oswald", 500 if on else 400)
	var heights: Array[float] = [_line_h(name_font, 24), _line_h(counts_font, 15), _line_h(small_font, 13), _line_h(small_font, 13)]
	var total: float = heights[0] + heights[1] + heights[2] + heights[3] + 9.0
	var y: float = rect.position.y + (rect.size.y - total) * 0.5
	var x: float = rect.position.x + 18.0
	var w: float = rect.size.x - 36.0
	var name_color: Color = INK if on else LABEL
	text(s, Rect2(x, y, w, heights[0]), str(card["name"]), name_font, 24, name_color)
	text(s, Rect2(x, y, w, heights[0]), "LV %d" % int(card["level"]), name_font, 24, name_color, HORIZONTAL_ALIGNMENT_RIGHT)
	y += heights[0] + 3.0
	text(s, Rect2(x, y, w, heights[1]), str(card["counts"]), counts_font, 15, INK if on else BONE)
	y += heights[1] + 3.0
	text(s, Rect2(x, y, w, heights[2]), str(card["keys"]), small_font, 13, INK if on else DIM)
	y += heights[2] + 3.0
	# The best grade ends the feel line, which gives up its second reason for it (beside the
	# counts it cut them short on these narrower buttons).
	var best: String = str(card["best"])
	var feel_w: float = w
	if not best.is_empty():
		var best_font: Font = font("Oswald", 600, 1.0)
		text(s, Rect2(x, y, w, heights[3]), "BEST " + best, best_font, 13, INK if on else SULPHUR, HORIZONTAL_ALIGNMENT_RIGHT)
		feel_w -= text_width("BEST " + best, best_font, 13) + 10.0
	text(s, Rect2(x, y, feel_w, heights[3]), fit_list(str(card["feel"]), small_font, 13, feel_w), small_font, 13, INK if on else DIM)


## Practice: a toggle under a red flip cover. Off, the cover sits closed over it (the design's
## drawing); on, the cover is flipped back and the lever thrown up in sulphur.
func _practice(s: RouteScreen, m: Dictionary) -> void:
	var on: bool = m["practice"]["on"]
	box(s, PRACTICE, PANEL, INK, 2.0)
	box(s, PRACTICE.grow(-2.0), Color.TRANSPARENT, SULPHUR if on else RIM, 1.0)
	var label_font: Font = font("Oswald", 600, 2.0)
	var sub_font: Font = font("Oswald", 500, 1.0)
	var sub: String = str(m["practice"]["text"]).to_upper()
	var label_w: float = maxf(text_width("PRACTICE", label_font, 15), text_width(sub, sub_font, 12))
	var x: float = PRACTICE.position.x + (PRACTICE.size.x - 36.0 - 12.0 - label_w) * 0.5
	var cy: float = PRACTICE.position.y + PRACTICE.size.y * 0.5
	# The design's 64 x 76 SVG in a 36 x 44 box.
	var k: float = 36.0 / 64.0
	var o := Vector2(x, cy - 22.0 + 0.6)
	box(s, Rect2(o + Vector2(12, 34) * k, Vector2(40, 40) * k), INK, GRIP, 1.0, 4.0 * k)
	if on:
		_stick(s, o + Vector2(32, 54) * k, o + Vector2(32, 22) * k, SULPHUR, 6.0 * k)
		var lifted: PackedVector2Array = _pts(o, k, [10, 2, 54, 2, 50, 10, 14, 10])
		poly(s, lifted, Color(COVER, 0.85))
		outline(s, lifted, INK, 2.0 * k)
	else:
		_stick(s, o + Vector2(32, 54) * k, o + Vector2(32, 40) * k, LEVER, 6.0 * k)
		var closed: PackedVector2Array = _pts(o, k, [8, 34, 56, 34, 50, 4, 14, 4])
		poly(s, closed, Color(COVER, 0.85))
		outline(s, closed, INK, 2.0 * k)
	var tx: float = x + 36.0 + 12.0
	text(s, Rect2(tx, cy - 21.0, label_w + 2.0, 22), "PRACTICE", label_font, 15, BONE)
	text(s, Rect2(tx, cy + 1.0, label_w + 2.0, 18), sub, sub_font, 12, SULPHUR if on else DIM)


func _drive(s: RouteScreen, m: Dictionary) -> void:
	var ready: bool = not m["locked"] and not (m["song"] as Dictionary).is_empty()
	box(s, DRIVE, PANEL, INK, 2.0)
	box(s, DRIVE.grow(-2.0), Color.TRANSPARENT, RIM, 1.0)
	s.draw_texture_rect(_button(ready), Rect2(DRIVE.position.x + 24.0, DRIVE.position.y + 8.0, 64, 64), false)
	var label: String = "LOCKED" if m["locked"] else ("ENTER PRACTICE" if m["practice"]["on"] else "ENTER DRIVE")
	var f: Font = font("Saira Stencil One", 400, 2.0)
	var left: float = DRIVE.position.x + 24.0 + 64.0 + 22.0
	var avail: float = DRIVE.end.x - 24.0 - left
	var size: int = 40
	while size > 24 and text_width(label, f, size) > avail:
		size -= 2
	text(s, Rect2(left, DRIVE.position.y, avail, DRIVE.size.y), label, f, size, SULPHUR if ready else GRIP)


func _hints(s: RouteScreen, m: Dictionary) -> void:
	var line: String = "← → SECTOR    ↑ ↓ CIRCUIT    TAB MODE    P PRACTICE    ENTER DRIVE    ESC MENU"
	if (m["song"] as Dictionary).get("imported", false):
		line += "    X REMOVE"
	var f: Font = font("Oswald", 600, 2.0)
	var line_w: float = text_width(line, f, 12)
	var plate := Rect2(40, HINTS_Y, line_w + 32.0, _line_h(f, 12) + 20.0)
	box(s, plate, LABEL, INK, 2.0)
	# A rivet in each end's padding.
	var cy: float = plate.position.y + plate.size.y * 0.5
	for rx: float in [plate.position.x + 8.0, plate.end.x - 8.0]:
		s.draw_circle(Vector2(rx, cy), 2.6, Color("#8A857A"), true, -1.0, true)
		s.draw_circle(Vector2(rx - 0.7, cy - 0.7), 1.1, Color("#F2EDE2"), true, -1.0, true)
	text(s, Rect2(plate.position.x + 16.0, plate.position.y + 2.0, line_w + 1.0, plate.size.y - 4.0), line, f, 12, INK)


## A passing note on a strip of phosphor, right-aligned between Enter Drive and the hints.
func _message(s: RouteScreen, message: String) -> void:
	var f: Font = font("VT323", 400, 1.0)
	var shown: String = "> " + message.to_upper()
	var w: float = minf(text_width(shown, f, 20) + 30.0, 660.0)
	var rect := Rect2(1240.0 - w, 606, w, 36)
	box(s, rect, SCREEN, INK, 3.0)
	box(s, rect.grow(-3.0), Color.TRANSPARENT, RIM, 1.0)
	_lit(s, rect.grow_individual(-15.0, 0.0, -15.0, 0.0), shown, f, 20, SULPHUR)


# ---------------------------------------------------------------- pieces

## A key cap: a face over a darker ledge along its bottom (CSS inset 0 -Npx 0) in a dark rim.
func _key(s: RouteScreen, rect: Rect2, face: Color, ledge: Color, ledge_h: float, border_w: float, radius: float) -> void:
	box(s, rect, ledge, Color.TRANSPARENT, 0.0, radius)
	var inner: Rect2 = rect.grow(-border_w)
	var top := StyleBoxFlat.new()
	top.bg_color = face
	top.corner_radius_top_left = int(radius - border_w)
	top.corner_radius_top_right = int(radius - border_w)
	top.anti_aliasing = true
	top.draw(s.get_canvas_item(), Rect2(inner.position, Vector2(inner.size.x, inner.size.y - ledge_h)))
	box(s, rect, Color.TRANSPARENT, INK, border_w, radius)


## A lever with round ends (SVG stroke-linecap: round).
func _stick(s: RouteScreen, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	s.draw_line(a, b, color, width, true)
	s.draw_circle(a, width * 0.5, color, true, -1.0, true)
	s.draw_circle(b, width * 0.5, color, true, -1.0, true)


static func _line_h(f: Font, size: int) -> float:
	return f.get_ascent(size) + f.get_descent(size)


static func _pts(origin: Vector2, k: float, coords: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in range(0, coords.size(), 2):
		points.append(origin + Vector2(float(coords[i]), float(coords[i + 1])) * k)
	return points


## The Enter Drive button in its 64 x 64 box, drawn once per state at twice the size: a
## hazard ring (repeating-conic-gradient, 15 degree wedges from the top), the cap's hard shadow
## 4 px down, and the red cap (radial-gradient at 40% 35%, farthest-corner), greyed when dead.
static func _button(live: bool) -> Texture2D:
	var key: String = "live" if live else "dead"
	if _buttons.has(key):
		return _buttons[key]
	var ring_a: Color = SULPHUR if live else Color("#5A5650")
	var ring_b: Color = INK
	var shadow: Color = Color("#5A0A06") if live else Color("#1A1917")
	var stops: Array = [Color("#FF7A62"), COVER, Color("#8A120C")] if live else [Color("#8A857A"), Color("#5A5650"), Color("#2F2D2A")]
	var n: int = 128
	var k: float = float(n) / 64.0
	var middle := Vector2(32, 32)
	var focal := Vector2(9.0 + 46.0 * 0.4, 9.0 + 46.0 * 0.35)
	var reach: float = focal.distance_to(Vector2(55, 55))
	var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for py: int in n:
		for px: int in n:
			var p := Vector2((px + 0.5) / k, (py + 0.5) / k)
			var c := Color(0, 0, 0, 0)
			var ring_cover: float = clampf((32.0 - p.distance_to(middle)) * k + 0.5, 0.0, 1.0)
			if ring_cover > 0.0:
				var turn: float = fposmod(rad_to_deg(atan2(p.x - middle.x, middle.y - p.y)), 360.0)
				c = Color(ring_a if int(turn / 15.0) % 2 == 0 else ring_b, ring_cover)
			var shadow_cover: float = clampf((23.0 - p.distance_to(middle + Vector2(0, 4))) * k + 0.5, 0.0, 1.0)
			if shadow_cover > 0.0:
				c = _over(c, Color(shadow, shadow_cover))
			var cap_cover: float = clampf((23.0 - p.distance_to(middle)) * k + 0.5, 0.0, 1.0)
			if cap_cover > 0.0:
				var t: float = p.distance_to(focal) / reach
				var shade: Color = stops[0].lerp(stops[1], t / 0.5) if t < 0.5 else stops[1].lerp(stops[2], clampf((t - 0.5) / 0.5, 0.0, 1.0))
				c = _over(c, Color(shade, cap_cover))
			image.set_pixel(px, py, c)
	var texture := ImageTexture.create_from_image(image)
	_buttons[key] = texture
	return texture


## `top` composited over `under` (straight alpha).
static func _over(under: Color, top: Color) -> Color:
	var a: float = top.a + under.a * (1.0 - top.a)
	if a <= 0.0:
		return Color(0, 0, 0, 0)
	var keep: float = under.a * (1.0 - top.a)
	return Color((top.r * top.a + under.r * keep) / a, (top.g * top.a + under.g * keep) / a, (top.b * top.a + under.b * keep) / a, a)
