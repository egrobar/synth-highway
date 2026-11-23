class_name TideSkin
extends RouteSkin
## Tidewater's song select: a night shore on an ocean moon (canvas "Final", FinalTide).
##
## A deep teal sky with a few stars and a small moon; the banded gas giant (teal, cream and coral
## bands, darkened toward its rim) rising half out of a dark sea that carries a glitter path and
## two ice floes; a lighthouse between the list and the panels, its soft beam sweeping left across
## the song list; a guard rail along the shore. Pill tabs (the chosen one coral); DM Serif Display
## for the region name, the titles and the italic "feel" lines, Manrope for the rest. The chosen
## song is a translucent cream plate with a lamp dot; frosted plates hold the selected song (the
## giant shows above it) and the Easy / Normal / Hard cards; a pill practice toggle and a coral pill to
## drive. The design's frosted glass (backdrop blur) is a darker translucent fill here, so the
## giant's bands and the glitter behind never show through text.

const NIGHT := Color("#020A10")
const INK := Color("#04131D")
const FOAM := Color("#EEF4F2")
const MIST := Color("#DCE8E6")
const SPRAY := Color("#C9DADA")
const SLATE := Color("#A9C2C2")
const DEEP := Color("#7FA6A8")
const SHOAL := Color("#8FB0B0")
const CORAL := Color("#FF8F78")
const CYAN := Color("#7FE6E0")
const LAMP := Color("#FFE9B5")
const BEAM := Color("#FFF1D2")
const CREAM := Color("#F1E6CC")
const STAR := Color("#E6F3FF")
## The frosted glass: the design's rgba(2,12,18,0.8) plus blur. Without the blur the giant's band
## edges showed through it as hard lines across the text at 0.8 (and still at 0.9), so it is tinted
## nearly solid; the giant reads above the plate and between the panels instead.
const GLASS := Color(Color("#020C12"), 0.95)
const GLASS_WARM := Color(Color("#28100E"), 0.95)
const GLASS_TEAL := Color(Color("#062628"), 0.95)
## Hard's accent and glass: a deeper rose past Normal's coral.
const ROSE := Color("#FF5E86")
const GLASS_ROSE := Color(Color("#2A0A16"), 0.95)

## The giant: the top half of a 600 px disc sitting on the horizon, behind the sea.
const GIANT_C := Vector2(920, 470)
const GIANT_R := 300.0
const GIANT_BOX := Rect2(620, 170, 600, 300)
## Its bands (CSS hard stops, fractions of the 600 px disc from its top).
const BANDS: Array = [[0.0, 0.14, "#2F7F86"], [0.14, 0.24, "#E9DFC4"], [0.24, 0.33, "#3E8F92"],
		[0.33, 0.39, "#E98470"], [0.39, 0.47, "#F1E6CC"], [0.47, 0.58, "#2F7F86"]]
## The design's stars at (300, 120) and (140, 150) sat on the genres and blurb lines, showing
## between the letters; those two moved into open sky above the giant.
const STARS: Array = [[612, 126, 1.0], [470, 96, 1.0], [700, 104, 1.2], [1010, 112, 1.0], [836, 156, 1.0]]
## The glitter path under the giant: [x1, y, x2, opacity, width], round-capped.
const GLITTER: Array = [[908, 478, 932, 0.8, 2.0], [896, 496, 944, 0.65, 2.5], [884, 600, 956, 0.5, 3.0],
		[860, 620, 990, 0.45, 3.5], [840, 648, 960, 0.38, 4.0], [800, 690, 1040, 0.3, 4.0]]

static var _arc := PackedVector2Array()
static var _disc_uv := PackedVector2Array()
static var _bands: Array = []
static var _shade: Texture2D


func _init() -> void:
	ground = NIGHT


func draw(s: RouteScreen, m: Dictionary) -> void:
	_scene(s)
	_tabs(s, m)
	_header(s, m)
	_rows(s, m)
	if not m.get("pick", false):
		_load(s)
	_plate(s, m)
	if not (m["song"] as Dictionary).is_empty():
		for i: int in mini((m["cards"] as Array).size(), CARDS.size()):
			_card(s, CARDS[i], m["cards"][i])
		if not m.get("pick", false):
			_practice(s, m)
	_drive(s, m)
	_hints(s, m)
	_battle(s, m)
	if not str(m.get("message", "")).is_empty():
		_message(s, str(m["message"]))
	register_hits(s, m)


# ---------------------------------------------------------------- the seascape

func _scene(s: RouteScreen) -> void:
	s.draw_rect(Rect2(0, 0, W, H), NIGHT)
	vgradient(s, Rect2(0, 0, W, 470), [Color("#04131D"), Color("#0B2C3C"), Color("#1A5060")], [0.0, 0.6, 1.0])
	for star: Array in STARS:
		s.draw_circle(Vector2(star[0], star[1]), float(star[2]), STAR, true, -1.0, true)
	s.draw_circle(Vector2(1190, 132), 12.0, Color(STAR, 0.85), true, -1.0, true)
	_giant(s)
	vgradient(s, Rect2(0, 468, W, 252), [Color("#082230"), Color("#04131C"), NIGHT], [0.0, 0.4, 1.0])
	for g: Array in GLITTER:
		poly(s, _capsule(Vector2(g[0], g[1]), Vector2(g[2], g[1]), float(g[4])), Color(CREAM, float(g[3])))
	poly(s, _points([1100, 620, 1160, 616, 1172, 624, 1094, 628]), Color(STAR, 0.7))
	poly(s, _points([640, 640, 690, 636, 700, 646, 634, 648]), Color(STAR, 0.7))
	_beam(s)
	# The lighthouse: its rock, the striped tower, the lit lamp room under a coral cap.
	poly(s, _points([530, 720, 536, 486, 552, 470, 572, 470, 586, 490, 592, 720]), Color("#0A1A22"))
	poly(s, _points([549, 472, 552, 342, 568, 342, 571, 472]), CREAM)
	poly(s, _points([550, 440, 570, 440, 569.5, 418, 550.5, 418]), CORAL)
	poly(s, _points([551, 396, 569, 396, 568.6, 374, 551.4, 374]), CORAL)
	s.draw_rect(Rect2(550, 324, 20, 18), LAMP)
	poly(s, _points([547, 324, 560, 310, 573, 324]), Color("#E98470"))
	s.draw_circle(Vector2(560, 332), 16.0, Color(BEAM, 0.22), true, -1.0, true)
	# The guard rail along the shore.
	var rail := Color(Color("#9DB3BC"), 0.5)
	s.draw_line(Vector2(0, 646), Vector2(520, 640), rail, 2.0, true)
	s.draw_line(Vector2(0, 656), Vector2(520, 650), rail, 2.0, true)


## The lighthouse beam (the design's wedge from the lamp at (560, 330) to x = 0 between y 318 and
## 402, rgba(255,241,210) .42 at the lamp fading to .06): brightest at the lamp, fading to the
## left. The design's hard lower edge cut diagonally through the selected row's title, so the
## wedge is one mesh of quads with feathered edges: the design's light down the middle, fading to
## nothing over the outer quarter on each side. (Nested translucent layers did the same but left
## coloured 8-bit rounding blotches where the light is faint.)
func _beam(s: RouteScreen) -> void:
	var slices: int = 12
	var across: Array[float] = [0.0, 0.25, 0.75, 1.0]
	var weight: Array[float] = [0.0, 1.0, 1.0, 0.0]
	for i: int in slices:
		var u0: float = float(i) / float(slices)
		var u1: float = float(i + 1) / float(slices)
		for j: int in 3:
			var points := PackedVector2Array([_beam_at(u0, across[j]), _beam_at(u1, across[j]),
					_beam_at(u1, across[j + 1]), _beam_at(u0, across[j + 1])])
			var colors := PackedColorArray([Color(BEAM, lerpf(0.42, 0.06, u0) * weight[j]), Color(BEAM, lerpf(0.42, 0.06, u1) * weight[j]),
					Color(BEAM, lerpf(0.42, 0.06, u1) * weight[j + 1]), Color(BEAM, lerpf(0.42, 0.06, u0) * weight[j + 1])])
			s.draw_primitive(points, colors, PackedVector2Array())


## A point of the beam: `u` from the lamp (0) to the screen's left edge (1), `v` across it from its
## upper edge (0) to its lower (1).
static func _beam_at(u: float, v: float) -> Vector2:
	var top: float = 330.0 - 12.0 * u
	var bottom: float = 330.0 + 72.0 * u
	return Vector2(560.0 * (1.0 - u), lerpf(top, bottom, v))


## The banded giant: bands as clipped polygons (crisp at any window size), the shading (the
## design's radial gradient, light upper left, dark at the rim) a small smooth texture laid over
## the same half disc, and an antialiased rim.
func _giant(s: RouteScreen) -> void:
	_build_giant()
	for band: Array in _bands:
		poly(s, band[0], band[1])
	s.draw_colored_polygon(_arc, Color.WHITE, _disc_uv, _shade)
	s.draw_polyline(_arc, Color(NIGHT, 0.7), 1.5, true)


static func _build_giant() -> void:
	if not _arc.is_empty():
		return
	var segments: int = 160
	for i: int in segments + 1:
		var a: float = PI + PI * float(i) / float(segments)
		_arc.append(GIANT_C + Vector2(cos(a), sin(a)) * GIANT_R)
	for p: Vector2 in _arc:
		_disc_uv.append((p - GIANT_BOX.position) / GIANT_BOX.size)
	for band: Array in BANDS:
		var y0: float = GIANT_BOX.position.y + 600.0 * float(band[0])
		var y1: float = minf(GIANT_BOX.position.y + 600.0 * float(band[1]), GIANT_C.y)
		if y1 <= y0:
			continue
		for part: PackedVector2Array in Geometry2D.intersect_polygons(_arc, rect_points(Rect2(600, y0, 640, y1 - y0))):
			_bands.append([part, Color(str(band[2]))])
	# radial-gradient(circle at 40% 30%) of the 600 px disc, to its farthest corner, at half
	# resolution: rgba(255,255,255,.12) to 30%, rgba(2,10,16,.55) at 75%, rgba(2,10,16,.85) at 100%.
	var image := Image.create(300, 150, false, Image.FORMAT_RGBA8)
	var focus := Vector2(240, 180)
	var reach: float = Vector2(360, 420).length()
	var lit := Color(1, 1, 1, 0.12)
	var dusk := Color(Color("#020A10"), 0.55)
	var dark := Color(Color("#020A10"), 0.85)
	for y: int in 150:
		for x: int in 300:
			var t: float = (Vector2(x + 0.5, y + 0.5) * 2.0).distance_to(focus) / reach
			var c: Color = lit
			if t > 0.75:
				c = _mix_premultiplied(dusk, dark, (t - 0.75) / 0.25)
			elif t > 0.3:
				c = _mix_premultiplied(lit, dusk, (t - 0.3) / 0.45)
			image.set_pixel(x, y, c)
	_shade = ImageTexture.create_from_image(image)


## CSS interpolates gradient stops in premultiplied alpha.
static func _mix_premultiplied(a: Color, b: Color, t: float) -> Color:
	var alpha: float = lerpf(a.a, b.a, clampf(t, 0.0, 1.0))
	if alpha <= 0.0:
		return Color(0, 0, 0, 0)
	var k: float = clampf(t, 0.0, 1.0)
	return Color(lerpf(a.r * a.a, b.r * b.a, k) / alpha, lerpf(a.g * a.a, b.g * b.a, k) / alpha,
			lerpf(a.b * a.a, b.b * b.a, k) / alpha, alpha)


# ---------------------------------------------------------------- tabs and header

func _tabs(s: RouteScreen, m: Dictionary) -> void:
	var regions: Array = m["regions"]
	var w: float = (TABS.size.x - 8.0 * (regions.size() - 1)) / regions.size()
	for i: int in regions.size():
		var r: Dictionary = regions[i]
		var rect := Rect2(TABS.position.x + i * (w + 8.0), TABS.position.y, w, TABS.size.y)
		var on: bool = r["selected"]
		var locked: bool = r["locked"]
		if on:
			box(s, rect, CORAL, Color.TRANSPARENT, 0.0, 30.0)
		else:
			box(s, rect, Color(INK, 0.6 if not locked else 0.4), Color(FOAM, 0.3 if not locked else 0.16), 1.0, 30.0)
		var name_color: Color = INK if on else (MIST if not locked else DEEP)
		text(s, Rect2(rect.position.x + 14, rect.position.y + 12, rect.size.x - 28, 20), "%d · %s" % [r["num"], r["upper"]],
				font("Manrope", 800 if on else 700, 1.5), 14, name_color, HORIZONTAL_ALIGNMENT_CENTER)
		var status_rect := Rect2(rect.position.x + 14, rect.position.y + 32, rect.size.x - 28, 15)
		var status_color: Color = INK if on else (SLATE if not locked else DEEP)
		var status_font: Font = font("Manrope", 600 if on else 500)
		if locked:
			# A small padlock ahead of the word, the pair centred.
			var lw: float = text_width("Locked", status_font, 11)
			var left: float = status_rect.get_center().x - (lw + 13.0) * 0.5
			_padlock(s, Vector2(left + 4.0, status_rect.get_center().y + 0.5), status_color)
			text(s, Rect2(left + 13.0, status_rect.position.y, lw + 1.0, status_rect.size.y), "Locked", status_font, 11, status_color)
		else:
			text(s, status_rect, "%d/%d cleared" % [r["cleared"], r["total"]], status_font, 11, status_color,
					HORIZONTAL_ALIGNMENT_CENTER)


func _header(s: RouteScreen, m: Dictionary) -> void:
	var region: Dictionary = m["region"]
	var serif: Font = font("DM Serif Display")
	var region_name: String = str(region["name"])
	# line-height: 1 on a 32 px heading at top 102: the glyph box centred on that 32 px line.
	var baseline: float = 102.0 + (32.0 - serif.get_ascent(32) - serif.get_descent(32)) * 0.5 + serif.get_ascent(32)
	text_at(s, Vector2(40, baseline), region_name, serif, 32, FOAM)
	var x: float = 40.0 + text_width(region_name, serif, 32) + 12.0
	var genres_font: Font = font("Manrope", 700, 3.0)
	var genres: String = str(region["genres"]).to_upper().replace(", ", " · ")
	text_at(s, Vector2(x, baseline), fit(genres, genres_font, 12, 540.0 - x), genres_font, 12, CORAL)
	var locked: bool = region["locked"]
	var line: String = str(region["locked_text"]) if locked else str(region["blurb"])
	text(s, Rect2(40, 138, 500, 20), line, font("DM Serif Display Italic"), 14, CORAL if locked else SPRAY)


# ---------------------------------------------------------------- the list

func _rows(s: RouteScreen, m: Dictionary) -> void:
	if int(m["count"]) == 0:
		# Up at the top of the list, clear of the beam.
		text(s, Rect2(40, 188, 500, 34), "No songs on this shore yet.", font("DM Serif Display Italic"), 26, SPRAY)
		text(s, Rect2(40, 226, 500, 20), "Load your own below (L) and it will drive here.", font("Manrope", 500), 14, SLATE)
		return
	var rows: Array = m["rows"]
	for slot: int in rows.size():
		var row: Dictionary = rows[slot]
		if row.is_empty():
			continue
		var r: Rect2 = row_rect(slot)
		var on: bool = row["selected"]
		var mid: float = r.get_center().y
		if on:
			box(s, r, Color(BEAM, 0.18), Color(LAMP, 0.6), 1.0, 10.0)
			glow(s, Vector2(r.position.x + 21, mid), Vector2(11, 11), Color(LAMP, 0.5), 8)
			s.draw_circle(Vector2(r.position.x + 21, mid), 5.0, LAMP, true, -1.0, true)
		else:
			s.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Color(FOAM, 0.14))
		text(s, Rect2(r.position.x + 40, r.position.y, 22, r.size.y), str(row["n"]), font("Manrope", 700 if on else 600), 12,
				LAMP if on else DEEP)
		var level_box := Rect2(r.end.x - 16.0 - 44.0, r.position.y, 44, r.size.y)
		text(s, level_box, "Lv %d" % int(row["level"]), font("Manrope", 700 if on else 600), 15 if on else 14,
				Color.WHITE if on else SPRAY, HORIZONTAL_ALIGNMENT_RIGHT)
		var grades: String = str(row["grades"])
		var grades_font: Font = font("Manrope", 500 if on else 400)
		var grades_w: float = text_width(grades, grades_font, 12)
		var grades_x: float = level_box.position.x - 14.0 - grades_w
		text(s, Rect2(grades_x, r.position.y, grades_w + 1.0, r.size.y), grades, grades_font, 12, LAMP if on else SHOAL)
		var name_x: float = r.position.x + 74.0
		var name_w: float = grades_x - 14.0 - name_x
		var title_font: Font = font("DM Serif Display") if on else font("Manrope", 500)
		var title_size: int = 25 if on else 18
		var title_color: Color = Color.WHITE if on else SPRAY
		var title: String = str(row["title"])
		if row.get("imported", false):
			var tag_font: Font = font("Manrope", 800, 1.0)
			var tag_w: float = text_width("YOUR SONG", tag_font, 9) + 12.0
			var shown: String = fit(title, title_font, title_size, name_w - tag_w - 8.0)
			text(s, Rect2(name_x, r.position.y, name_w, r.size.y), shown, title_font, title_size, title_color)
			var tag := Rect2(name_x + text_width(shown, title_font, title_size) + 8.0, mid - 8.0, tag_w, 16)
			box(s, tag, Color.TRANSPARENT, Color(CORAL, 0.75), 1.0, 8.0)
			text(s, tag.grow_individual(-1, 0, 0, 0), "YOUR SONG", tag_font, 9, CORAL, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			text(s, Rect2(name_x, r.position.y, name_w, r.size.y), title, title_font, title_size, title_color)


func _load(s: RouteScreen) -> void:
	box(s, LOAD, Color(NIGHT, 0.6), Color.TRANSPARENT, 0.0, 10.0)
	_dashed_path(s, _round_rect_path(LOAD.grow(-0.5), 9.5), Color(FOAM, 0.4), 1.0, 4.0, 3.0)
	text(s, Rect2(LOAD.position.x + 16, LOAD.position.y, 400, LOAD.size.y), "+ Load your own song", font("Manrope", 600), 14, MIST)
	var key_font: Font = font("Manrope", 500)
	var key_w: float = text_width("L", key_font, 11) + 14.0
	var key := Rect2(LOAD.end.x - 16.0 - key_w, LOAD.get_center().y - 9.5, key_w, 19)
	box(s, key, Color.TRANSPARENT, Color(FOAM, 0.3), 1.0, 4.0)
	text(s, key, "L", key_font, 11, SLATE, HORIZONTAL_ALIGNMENT_CENTER)


# ---------------------------------------------------------------- the selected song

## The frosted plate under the giant: status, the title (44 px, shrinking to 32, then two lines
## at 32 with the plate growing upward into the sky), BPM and length bottom right.
func _plate(s: RouteScreen, m: Dictionary) -> void:
	var song: Dictionary = m["song"]
	var title_font: Font = font("DM Serif Display")
	var status_font: Font = font("Manrope", 700, 3.0)
	var facts_font: Font = font("Manrope", 600)
	var title: String = "No songs yet"
	var status: String = "THIS SHORE IS EMPTY"
	var facts: String = ""
	if not song.is_empty():
		title = str(song["title"])
		var best: String = str(song["best"])
		status = "TRACK %02d OF %d · %s" % [int(song["number"]), int(m["count"]), ("BEST " + best) if not best.is_empty() else "NOT DRIVEN YET"]
		facts = "%d BPM · %s" % [int(song["bpm"]), str(song["length"])]
	var facts_w: float = text_width(facts, facts_font, 15) if not facts.is_empty() else 0.0
	var title_w: float = DETAIL.size.x - 46.0 - ((facts_w + 16.0) if facts_w > 0.0 else 0.0)
	var size: int = 44
	while size > 32 and text_width(title, title_font, size) > title_w:
		size -= 2
	var lines: Array[String] = [title]
	if text_width(title, title_font, size) > title_w:
		lines = _wrap_two(title, title_font, size, title_w)
	var line_h: float = float(size) + (2.0 if lines.size() > 1 else 0.0)
	var plate_h: float = maxf(100.0, 26.0 + 17.0 + line_h * lines.size())
	var plate := Rect2(DETAIL.position.x, DETAIL.end.y - plate_h, DETAIL.size.x, plate_h)
	box(s, plate, GLASS, Color(Color("#E9DFC4"), 0.3), 1.0, 16.0)
	var x: float = plate.position.x + 23.0
	var bottom: float = plate.end.y - 13.0
	for i: int in lines.size():
		var top: float = bottom - line_h * float(lines.size() - i)
		text(s, Rect2(x, top, title_w, line_h), lines[i], title_font, size, FOAM)
	var status_top: float = bottom - line_h * lines.size() - 2.0 - 15.0
	if song.get("remove_armed", false):
		# The confirm step reads as a warning chip in the status line.
		var warn: String = "PRESS X AGAIN TO MOVE IT TO THE TRASH"
		var chip := Rect2(x - 8.0, status_top - 2.0, text_width(warn, status_font, 11) + 14.0, 19)
		box(s, chip, CORAL, Color.TRANSPARENT, 0.0, 9.5)
		text(s, Rect2(chip.position.x + 8.0, chip.position.y, chip.size.x - 8.0, chip.size.y), warn, status_font, 11, INK)
	else:
		var tag_font: Font = font("Manrope", 800, 1.0)
		var tag_w: float = text_width("YOUR SONG", tag_font, 9) + 12.0 if song.get("imported", false) else 0.0
		var room: float = title_w - (tag_w + 10.0 if tag_w > 0.0 else 0.0)
		var shown: String = fit(status, status_font, 11, room)
		text(s, Rect2(x, status_top, room, 15), shown, status_font, 11, CORAL)
		if tag_w > 0.0:
			var tag := Rect2(x + text_width(shown, status_font, 11) + 7.0, status_top - 0.5, tag_w, 16)
			box(s, tag, Color.TRANSPARENT, Color(LAMP, 0.7), 1.0, 8.0)
			text(s, tag.grow_individual(-1, 0, 0, 0), "YOUR SONG", tag_font, 9, LAMP, HORIZONTAL_ALIGNMENT_CENTER)
	if not facts.is_empty():
		text(s, Rect2(plate.end.x - 23.0 - facts_w, bottom - 26.0, facts_w + 1.0, 20), facts, facts_font, 15, SPRAY,
				HORIZONTAL_ALIGNMENT_RIGHT)


## A long title split over two lines: at " - " when both halves fit, else greedily by word;
## a dash left dangling at the break is dropped (the break is the separator).
static func _wrap_two(value: String, f: Font, size: int, width: float) -> Array[String]:
	var dash: int = value.find(" - ")
	if dash > 0:
		var head: String = value.left(dash).strip_edges()
		var tail: String = value.substr(dash + 3).strip_edges()
		if text_width(head, f, size) <= width and text_width(tail, f, size) <= width:
			return [head, tail]
	var words: PackedStringArray = value.split(" ", false)
	var first: String = ""
	var i: int = 0
	while i < words.size():
		var trial: String = words[i] if first.is_empty() else first + " " + words[i]
		if not first.is_empty() and text_width(trial, f, size) > width:
			break
		first = trial
		i += 1
	if i < words.size() and words[i - 1] in ["-", "–", "·"]:
		first = first.left(first.length() - words[i - 1].length()).strip_edges()
	var rest: String = " ".join(words.slice(i))
	var out: Array[String] = [fit(first, f, size, width)]
	if not rest.is_empty():
		out.append(fit(rest, f, size, width))
	return out


## A difficulty card, each level with its own accent: cyan Easy, coral Normal, rose Hard. Three
## share the zone two had, so the feel line drops its second reason (or ellipsizes) to fit.
func _card(s: RouteScreen, rect: Rect2, card: Dictionary) -> void:
	var level: String = str(card.get("key", str(card["name"]).to_lower()))
	var accent: Color = {"easy": CYAN, "hard": ROSE}.get(level, CORAL)
	if not card.get("available", true):
		# Dimmed by its type and edge, not by thinner glass: the giant's bands showed through
		# at 0.6 and struck through the text.
		box(s, rect, GLASS, Color(FOAM, 0.16), 1.0, 16.0)
		var bx: float = rect.position.x + 19.0
		var bw: float = rect.size.x - 38.0
		text(s, Rect2(bx, rect.position.y + 17, bw, 20), str(card["name"]), font("Manrope", 800, 2.0), 15, Color(accent, 0.45))
		text(s, Rect2(bx, rect.position.y + 44, bw, 22), "Not charted yet", font("DM Serif Display Italic"), 16, Color(SLATE, 0.8))
		return
	var on: bool = card["selected"]
	if on:
		box(s, rect, {"easy": GLASS_TEAL, "hard": GLASS_ROSE}.get(level, GLASS_WARM), accent, 2.0, 16.0)
	else:
		box(s, rect, GLASS, Color(accent, 0.45), 1.0, 16.0)
	var x: float = rect.position.x + 19.0
	var w: float = rect.size.x - 38.0
	var head_font: Font = font("Manrope", 800, 2.0)
	text(s, Rect2(x, rect.position.y + 17, w, 20), str(card["name"]), head_font, 15, accent)
	text(s, Rect2(x, rect.position.y + 17, w, 20), "LV %d" % int(card["level"]), head_font, 15, accent, HORIZONTAL_ALIGNMENT_RIGHT)
	text(s, Rect2(x, rect.position.y + 46, w, 19), str(card["counts"]), font("Manrope", 600), 14, FOAM)
	text(s, Rect2(x, rect.position.y + 68, w, 18), str(card["keys"]), font("Manrope"), 13, SPRAY if on else SLATE)
	# The best grade sits at the end of the feel line, which gives up its second reason for it
	# (beside the counts it cut "177 notes · 15 holds" short on these narrower cards).
	var best: String = str(card["best"])
	var feel_w: float = w
	if not best.is_empty():
		var best_font: Font = font("Manrope", 800, 1.0)
		text(s, Rect2(x, rect.position.y + 89, w, 22), "BEST " + best, best_font, 12, accent, HORIZONTAL_ALIGNMENT_RIGHT)
		feel_w -= text_width("BEST " + best, best_font, 12) + 10.0
	var feel_font: Font = font("DM Serif Display Italic")
	text(s, Rect2(x, rect.position.y + 89, feel_w, 22), fit_list(str(card["feel"]), feel_font, 16, feel_w), feel_font, 16, accent)


# ---------------------------------------------------------------- practice and drive

func _practice(s: RouteScreen, m: Dictionary) -> void:
	var on: bool = m["practice"]["on"]
	if on:
		box(s, PRACTICE, GLASS_WARM, CORAL, 2.0, 40.0)
	else:
		box(s, PRACTICE, GLASS, Color(FOAM, 0.35), 1.0, 40.0)
	var label_font: Font = font("Manrope", 600)
	var speed_font: Font = font("Manrope", 700)
	var speed: String = str(m["practice"]["text"])
	var label_w: float = maxf(text_width("Practice", label_font, 14), text_width(speed, speed_font, 11) if on else 0.0)
	var left: float = PRACTICE.position.x + (PRACTICE.size.x - 30.0 - 10.0 - label_w) * 0.5
	var mid: float = PRACTICE.get_center().y
	var track := Rect2(left, mid - 8.0, 30, 16)
	if on:
		box(s, track, CORAL, Color.TRANSPARENT, 0.0, 8.0)
		s.draw_circle(Vector2(track.end.x - 8.5, mid), 5.0, INK, true, -1.0, true)
		text(s, Rect2(left + 40.0, mid - 19.0, label_w + 1.0, 19), "Practice", label_font, 14, MIST)
		text(s, Rect2(left + 40.0, mid + 1.0, label_w + 1.0, 16), speed, speed_font, 11, CORAL)
	else:
		s.draw_polyline(_round_rect_path(track.grow(-0.75), 7.25), SLATE, 1.5, true)
		s.draw_circle(Vector2(track.position.x + 8.5, mid), 5.0, SLATE, true, -1.0, true)
		text(s, Rect2(left + 40.0, mid - 10.0, label_w + 1.0, 20), "Practice", label_font, 14, MIST)


func _drive(s: RouteScreen, m: Dictionary) -> void:
	var locked: bool = m["locked"]
	var ready: bool = not locked and not (m["song"] as Dictionary).is_empty()
	if ready:
		box(s, DRIVE, CORAL, Color.TRANSPARENT, 0.0, 40.0)
	else:
		box(s, DRIVE, Color(Color("#2A4048"), 0.92), Color(FOAM, 0.25), 1.0, 40.0)
	var label: String = drive_label(m)
	var f: Font = font("Manrope", 800, 5.0)
	var label_w: float = text_width(label, f, 24)
	var extra: float = 42.0 if ready else (22.0 if locked else 0.0)
	var left: float = DRIVE.position.x + (DRIVE.size.x - label_w - extra) * 0.5
	var mid: float = DRIVE.get_center().y
	var ink: Color = INK if ready else SLATE
	if locked:
		_padlock(s, Vector2(left + 6.0, mid), ink, 1.6)
		left += 22.0
	text(s, Rect2(left, DRIVE.position.y, label_w + 1.0, DRIVE.size.y), label, f, 24, ink)
	if ready:
		arrow(s, Rect2(left + label_w + 14.0 + 1.0, mid - 8.0, 24, 16), INK, 3.0)


# ---------------------------------------------------------------- hints and notes

func _hints(s: RouteScreen, m: Dictionary) -> void:
	var line: String = hint_line(m, "     ", true)
	var f: Font = font("Manrope", 600)
	# Brighter and bigger than the design's 12 px slate, which was hard to read in the WASD page's
	# game frame (playtest, 2026-11-23).
	text(s, Rect2(40, 668, HINTS_RIGHT - 40.0, 22), line, f, fit_size(line, f, 15, HINTS_RIGHT - 40.0), MIST)


## Battle, at the right end of the hints row: a frosted pill edged in coral.
func _battle(s: RouteScreen, m: Dictionary) -> void:
	box(s, BATTLE, GLASS, Color(CORAL, 0.8), 1.0, 21.0)
	battle_contents(s, BATTLE, m, [font("Manrope", 500), 11, SLATE, Color.TRANSPARENT, Color(FOAM, 0.3), 4.0],
		[font("Manrope", 700), 15, CORAL], [font("Manrope", 600), 14, MIST, "race friends"], true)


## A passing note (an import finished, a song removed): a frosted chip on the sea, right of the
## lighthouse, between Enter Drive and the hints.
func _message(s: RouteScreen, message: String) -> void:
	var f: Font = font("Manrope", 600)
	var w: float = minf(text_width(message, f, 13) + 44.0, 640.0)
	var rect := Rect2(1240.0 - w, 610, w, 30)
	box(s, rect, GLASS, Color(LAMP, 0.5), 1.0, 15.0)
	s.draw_circle(Vector2(rect.position.x + 16.0, rect.get_center().y), 3.5, LAMP, true, -1.0, true)
	text(s, Rect2(rect.position.x + 28.0, rect.position.y, w - 42.0, rect.size.y), message, f, 13, LAMP)


# ---------------------------------------------------------------- small shapes

## A small padlock: body and shackle, centred on `center`.
static func _padlock(c: CanvasItem, center: Vector2, color: Color, scale: float = 1.0) -> void:
	box(c, Rect2(center.x - 4.0 * scale, center.y - 1.5 * scale, 8.0 * scale, 6.0 * scale), color, Color.TRANSPARENT, 0.0, 1.0)
	c.draw_arc(Vector2(center.x, center.y - 1.5 * scale), 2.6 * scale, PI, TAU, 12, color, 1.4 * scale, true)


## A round-capped stroke (SVG stroke-linecap: round) as one convex polygon.
static func _capsule(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var r: float = width * 0.5
	var turn: float = (b - a).angle()
	var points := PackedVector2Array()
	for i: int in 9:
		var t: float = turn + PI * 0.5 + PI * float(i) / 8.0
		points.append(a + Vector2(cos(t), sin(t)) * r)
	for i: int in 9:
		var t: float = turn - PI * 0.5 + PI * float(i) / 8.0
		points.append(b + Vector2(cos(t), sin(t)) * r)
	return points


## The outline of a rounded rectangle as a closed path, clockwise from the top right corner.
static func _round_rect_path(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners: Array = [[rect.end.x - radius, rect.position.y + radius, -PI * 0.5], [rect.end.x - radius, rect.end.y - radius, 0.0],
			[rect.position.x + radius, rect.end.y - radius, PI * 0.5], [rect.position.x + radius, rect.position.y + radius, PI]]
	for corner: Array in corners:
		for i: int in 7:
			var a: float = float(corner[2]) + PI * 0.5 * float(i) / 6.0
			points.append(Vector2(corner[0], corner[1]) + Vector2(cos(a), sin(a)) * radius)
	points.append(points[0])
	return points


## A dashed stroke along a path (CSS border-style: dashed on a rounded box).
static func _dashed_path(c: CanvasItem, path: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	var on: bool = true
	var left: float = dash
	var run := PackedVector2Array([path[0]])
	for i: int in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var length: float = a.distance_to(b)
		var t: float = 0.0
		while length - t > left:
			t += left
			var p: Vector2 = a.lerp(b, t / length)
			if on:
				run.append(p)
				c.draw_polyline(run, color, width, true)
			run = PackedVector2Array([p])
			on = not on
			left = dash if on else gap
		left -= length - t
		if on:
			run.append(b)
	if on and run.size() > 1:
		c.draw_polyline(run, color, width, true)


static func _points(coords: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in range(0, coords.size(), 2):
		points.append(Vector2(float(coords[i]), float(coords[i + 1])))
	return points
