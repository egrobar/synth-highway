class_name RingSkin
extends RouteSkin
## Ring Road's song select: glass panes on the orbital ring (canvas "5 · Ring Road").
##
## Deep space with a faint violet nebula, the ring itself arcing up across the sky in mint
## light and the skyway's floor running to a glowing horizon. Thin Outfit type and Azeret Mono
## captions; songs are "stations" on the ring: each row carries an orbit glyph (a dot at the
## station's angle round the ring), and the selected song sits in an orrery: the visible
## stations on an orbit round a small ringed planet, the selected one lit, a dashed leader line
## to its name. Glass panes for the cards, a mint pill to drive.

const BG := Color("#020304")
const MINT := Color("#9EFFCC")
const MINT_DEEP := Color("#7DFFC8")
const FROST := Color("#E9FFF6")
const PALE := Color("#F2FFF9")
const SAGE := Color("#9EC2B8")
const MIST := Color("#CFE2DC")
const SOFT := Color("#DCEBE6")
const GLASS_EDGE := Color(0.914, 1.0, 0.965, 0.55)

## Where a station sits on the ring, in degrees: the songs are spread evenly round it,
## starting at 200 degrees as on the canvas.
static func station_angle(index: int, count: int) -> float:
	return 200.0 - 360.0 * float(index) / maxf(float(count), 1.0)


func _init() -> void:
	ground = BG


func draw(s: RouteScreen, m: Dictionary) -> void:
	_backdrop(s)
	_tabs(s, m)
	_header(s, m)
	_glass(s, Rect2(34, 158, 512, 400))
	_rows(s, m)
	_load(s)
	_title_pane(s, m)
	if not (m["song"] as Dictionary).is_empty():
		for i: int in mini((m["cards"] as Array).size(), CARDS.size()):
			_card(s, CARDS[i], m["cards"][i])
		_practice(s, m)
	_drive(s, m)
	_hints(s, m)
	_battle(s, m)
	if not str(m.get("message", "")).is_empty():
		_message(s, str(m["message"]))
	register_hits(s, m)


func _backdrop(s: RouteScreen) -> void:
	s.draw_rect(Rect2(0, 0, W, H), BG)
	glow(s, Vector2(1050, 70), Vector2(350, 210) * 0.7, Color(140.0 / 255.0, 110.0 / 255.0, 230.0 / 255.0, 0.14), 16)
	for star: Array in [[420, 96, 1.0], [560, 140, 1.2], [1010, 96, 1.0], [300, 150, 1.0], [760, 500, 1.0], [1250, 320, 1.0],
			[180, 60, 0.8], [880, 40, 0.9], [1150, 180, 0.8], [640, 30, 0.7]]:
		s.draw_circle(Vector2(star[0], star[1]), float(star[2]), Color(1, 1, 1, 0.6))
	# The ring, arcing up across the sky: a bright line and a broad faint band beside it.
	s.draw_polyline(quad(Vector2(-80, 740), Vector2(560, -30), Vector2(1360, 330), 48), Color(FROST, 0.14), 10.0, true)
	s.draw_polyline(quad(Vector2(-80, 720), Vector2(560, -60), Vector2(1360, 300), 48), Color(MINT, 0.45), 2.0, true)
	# The skyway floor, its seams running to the horizon.
	s.draw_rect(Rect2(0, 640, W, 80), Color("#0C1112"))
	for end_x: float in [220.0, 1060.0, -300.0, 1580.0]:
		s.draw_line(Vector2(640, 640), Vector2(end_x, 720), Color("#2A3634"), 1.0, true)
	s.draw_rect(Rect2(0, 636, W, 10), Color(MINT, 0.3))
	s.draw_rect(Rect2(0, 640, W, 2), MINT)


## A pane of glass: tinted dark (standing in for the design's backdrop blur, so the ring
## arcing behind never crosses the lettering), a faint sheen across it and a bright edge.
func _glass(s: RouteScreen, rect: Rect2, edge: Color = GLASS_EDGE, edge_w: float = 2.0) -> void:
	s.draw_rect(rect, Color(BG, 0.8))
	hgradient(s, rect, [Color(FROST, 0.07), Color(FROST, 0.02), Color(FROST, 0.06), Color(FROST, 0.02)], [0.0, 0.4, 0.6, 1.0])
	box(s, rect, Color.TRANSPARENT, edge, edge_w)


func _tabs(s: RouteScreen, m: Dictionary) -> void:
	var regions: Array = m["regions"]
	var w: float = (TABS.size.x - 8.0 * (regions.size() - 1)) / regions.size()
	for i: int in regions.size():
		var r: Dictionary = regions[i]
		var rect := Rect2(TABS.position.x + i * (w + 8.0), TABS.position.y, w, TABS.size.y)
		var on: bool = r["selected"]
		s.draw_rect(rect, Color(BG, 0.8))
		box(s, rect, Color(MINT, 0.16) if on else Color(FROST, 0.04), MINT if on else Color(FROST, 0.3), 2.0 if on else 1.0)
		var caption: String = "0%d · %s" % [r["num"], "locked" if r["locked"] else "%d/%d cleared" % [r["cleared"], r["total"]]]
		text(s, Rect2(rect.position.x + 16, rect.position.y + 12, w - 32, 14), caption, font("Azeret Mono"), 10, MINT if on else SAGE)
		text(s, Rect2(rect.position.x + 16, rect.position.y + 28, w - 32, 22), str(r["name"]), font("Outfit", 400 if on else 300, 1.0), 16,
				Color.WHITE if on else MIST)


func _header(s: RouteScreen, m: Dictionary) -> void:
	var region: Dictionary = m["region"]
	var title_font: Font = font("Outfit", 200, 1.0)
	var baseline: float = 100.0 + title_font.get_ascent(34)
	text_at(s, Vector2(40, baseline), str(region["name"]), title_font, 34, PALE)
	var x: float = 40.0 + text_width(str(region["name"]), title_font, 34) + 14.0
	text_at(s, Vector2(x, baseline), str(region["genres"]).to_upper().replace(", ", " · "), font("Azeret Mono", 400, 2.5), 11, MINT)
	var line: String = str(region["locked_text"]) if region["locked"] else str(region["blurb"])
	text(s, Rect2(40, 136, 500, 18), line, font("Outfit", 300), 13, MINT if region["locked"] else Color("#B6D3CB"))


## An orbit glyph: a ring, its planet, and the station's dot at its angle.
func _glyph(s: RouteScreen, center: Vector2, angle_deg: float, on: bool) -> void:
	var a: float = deg_to_rad(angle_deg)
	s.draw_arc(center, 8.0, 0.0, TAU, 32, MINT if on else Color(SAGE, 0.6), 1.0, true)
	s.draw_circle(center, 2.5 if on else 2.0, MINT if on else SAGE)
	s.draw_circle(center + Vector2(cos(a), -sin(a)) * 8.0, 3.5 if on else 2.5, MINT if on else SOFT)


func _rows(s: RouteScreen, m: Dictionary) -> void:
	var rows: Array = m["rows"]
	if (m["count"] as int) == 0:
		text(s, Rect2(60, 330, 460, 30), "No stations on this road yet.", font("Outfit", 300), 19, MIST)
	for slot: int in rows.size():
		var row: Dictionary = rows[slot]
		if row.is_empty():
			continue
		var r: Rect2 = row_rect(slot)
		var on: bool = row["selected"]
		if on:
			s.draw_rect(r, Color(MINT, 0.12))
			# A glowing rail under the selected station.
			var rail := Rect2(r.position.x + 8, r.end.y - 5, r.size.x - 16, 3)
			for spread: float in [10.0, 6.0, 3.0]:
				box(s, rail.grow(spread), Color(MINT, 0.06), Color.TRANSPARENT, 0.0, spread + 2.0)
			box(s, rail, MINT, Color.TRANSPARENT, 0.0, 2.0)
		else:
			s.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Color(FROST, 0.16))
		_glyph(s, Vector2(r.position.x + 27, r.position.y + 25), station_angle(row["index"], m["count"]), on)
		var level_rect := Rect2(r.end.x - 60, r.position.y, 44, r.size.y)
		text(s, level_rect, "Lv %d" % int(row["level"]), font("Outfit", 600 if on else 400), 15 if on else 14,
				Color.WHITE if on else SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
		var grades_font: Font = font("Azeret Mono")
		var grades_w: float = text_width(str(row["grades"]), grades_font, 10)
		text(s, Rect2(level_rect.position.x - 14 - grades_w, r.position.y, grades_w, r.size.y), str(row["grades"]), grades_font, 10,
				MINT if on else SAGE)
		var name_rect := Rect2(r.position.x + 52, r.position.y, level_rect.position.x - 28 - grades_w - r.position.x - 52, r.size.y)
		var title_font: Font = font("Outfit", 400 if on else 300)
		text(s, name_rect, str(row["title"]), title_font, 23 if on else 19, Color.WHITE if on else SOFT)
		if row.get("imported", false):
			text(s, Rect2(name_rect.position.x, r.position.y + 2, 200, 10), "YOUR SONG", font("Azeret Mono"), 8, MINT)


func _load(s: RouteScreen) -> void:
	s.draw_rect(LOAD, Color(BG, 0.8))
	box(s, LOAD, Color(FROST, 0.03))
	dashed_box(s, LOAD, Color(MINT, 0.6), 1.0, 5.0, 4.0)
	text(s, Rect2(LOAD.position.x + 16, LOAD.position.y, 380, LOAD.size.y), "+ Dock your own song", font("Outfit"), 15, MINT)
	text(s, Rect2(LOAD.end.x - 60, LOAD.position.y, 44, LOAD.size.y), "[L]", font("Azeret Mono"), 10, SAGE, HORIZONTAL_ALIGNMENT_RIGHT)


func _title_pane(s: RouteScreen, m: Dictionary) -> void:
	var pane := DETAIL
	_glass(s, pane)
	var inner := pane.grow(-2.0)
	var o: Vector2 = inner.position  # the orrery's origin, as on the canvas
	var centre: Vector2 = o + Vector2(500, 113)
	var grid := Color(SAGE, 0.14)
	_clipped_ring(s, centre, Vector2(60, 60), inner, grid, 1.0)
	_clipped_ring(s, centre, Vector2(150, 150), inner, grid, 1.0)
	s.draw_line(Vector2(centre.x, inner.position.y), Vector2(centre.x, inner.end.y), grid, 1.0)
	s.draw_line(Vector2(o.x + 340, centre.y), Vector2(inner.end.x, centre.y), grid, 1.0)
	_clipped_ring(s, centre, Vector2(125, 78), inner, Color(MINT_DEEP, 0.55), 1.5)
	s.draw_circle(centre, 22.0, Color("#1B2422"))
	s.draw_arc(centre, 22.0, 0.0, TAU, 48, Color(FROST, 0.6), 1.0, true)
	outline(s, ellipse_points(centre, Vector2(50, 10), 48, -14.0), Color(FROST, 0.7), 1.5)
	# The visible stations on the orbit; the selected one lit, with a leader to its name.
	var rows: Array = m["rows"]
	var lit := Vector2.ZERO
	for row: Dictionary in rows:
		if row.is_empty():
			continue
		var a: float = deg_to_rad(station_angle(row["index"], m["count"]))
		var p: Vector2 = centre + Vector2(125.0 * cos(a), -78.0 * sin(a))
		if row["selected"]:
			lit = p
			continue
		s.draw_circle(p, 4.5, BG)
		s.draw_arc(p, 4.5, 0.0, TAU, 24, SAGE, 1.5, true)
	if lit != Vector2.ZERO:
		var leader_x: float = lit.x - 30.0
		dashed_line(s, lit, Vector2(leader_x, o.y + 30), MINT, 1.0, 3.0, 3.0)
		dashed_line(s, Vector2(leader_x, o.y + 30), Vector2(o.x + 360, o.y + 30), MINT, 1.0, 3.0, 3.0)
		s.draw_circle(lit, 13.0, Color(MINT, 0.2))
		glow(s, lit, Vector2(18, 18), Color(MINT, 0.9), 8)
		s.draw_circle(lit, 8.0, MINT)
		s.draw_arc(lit, 8.0, 0.0, TAU, 32, FROST, 1.5, true)
	# The station's name and facts, bottom left.
	var song: Dictionary = m["song"]
	var block_x: float = o.x + 24.0
	# Narrower than the canvas's 340-360: the orbit's left edge sits at x 457 in the pane, and a
	# station lit there (with its glow) touched the end of a long title.
	var block_w: float = 320.0
	var bottom: float = inner.end.y - 20.0
	if song.is_empty():
		text(s, Rect2(block_x, bottom - 60, block_w, 56), "No station", font("Outfit", 200), 44, PALE, HORIZONTAL_ALIGNMENT_LEFT, 1.0)
		return
	var facts: String = "%d BPM · %s" % [song["bpm"], song["length"]]
	text(s, Rect2(block_x, bottom - 20, block_w, 20), facts, font("Outfit", 300), 16, MIST, HORIZONTAL_ALIGNMENT_LEFT, 1.0)
	var lines: Array = _title_lines(str(song["title"]), block_w)
	var size: int = int(lines[0])
	var title_font: Font = font("Outfit", 200)
	var line_h: float = float(size)
	var title_bottom: float = bottom - 26.0
	for i: int in range(lines.size() - 1, 0, -1):
		text(s, Rect2(block_x, title_bottom - line_h, block_w, line_h), str(lines[i]), title_font, size, PALE, HORIZONTAL_ALIGNMENT_LEFT, 1.0)
		title_bottom -= line_h
	var status: String = "STATION %02d OF %d · %s" % [song["number"], m["count"],
			("BEST " + str(song["best"])) if not str(song["best"]).is_empty() else "NOT DOCKED YET"]
	if song.get("imported", false):
		status = "YOUR STATION · " + (("BEST " + str(song["best"])) if not str(song["best"]).is_empty() else "NOT DOCKED YET")
	var status_color: Color = MINT
	if song.get("remove_armed", false):
		status = "PRESS X AGAIN TO MOVE IT TO THE TRASH"
		status_color = Color("#FF9C9C")
	text(s, Rect2(block_x, title_bottom - 22, block_w + 40, 16), status, font("Azeret Mono", 400, 2.0), 11, status_color, HORIZONTAL_ALIGNMENT_LEFT, 1.0)


## The title in as few lines as fit `width`: one line at up to 50 px, else two at up to 34 px,
## then an ellipsis. Returns [size, line, line...].
func _title_lines(title: String, width: float) -> Array:
	var f: Font = font("Outfit", 200)
	for size: int in [50, 44, 40]:
		if text_width(title, f, size) <= width:
			return [size, title]
	for size: int in [34, 30, 27]:
		var words: PackedStringArray = title.split(" ")
		var first: String = ""
		var i: int = 0
		while i < words.size() and text_width((first + " " + words[i]).strip_edges(), f, size) <= width:
			first = (first + " " + words[i]).strip_edges()
			i += 1
		var rest: String = " ".join(words.slice(i))
		if not first.is_empty() and text_width(rest, f, size) <= width:
			return [size, first, rest]
	var words2: PackedStringArray = title.split(" ")
	var head: String = ""
	var j: int = 0
	while j < words2.size() and text_width((head + " " + words2[j]).strip_edges(), f, 27) <= width:
		head = (head + " " + words2[j]).strip_edges()
		j += 1
	return [27, head if not head.is_empty() else title, " ".join(words2.slice(j))]


## An ellipse outline cut to `clip` (the pane hides what runs past its edges).
func _clipped_ring(s: RouteScreen, centre: Vector2, radii: Vector2, clip: Rect2, color: Color, width: float) -> void:
	var points: PackedVector2Array = ellipse_points(centre, radii, 120)
	for i: int in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		if clip.has_point(a) and clip.has_point(b):
			s.draw_line(a, b, color, width, true)


## A glass pane per level. Three share the zone two had: name and level on top, the best grade at
## the end of the feel line (beside the name it ran into it at this width), and the feel line
## drops its second reason (or ellipsizes) to make room.
func _card(s: RouteScreen, rect: Rect2, card: Dictionary) -> void:
	var x: float = rect.position.x + 18.0
	var w: float = rect.size.x - 36.0
	s.draw_rect(rect, Color(BG, 0.8))
	if not card.get("available", true):
		# A station not yet built: faint glass, a dashed edge, no level.
		box(s, rect, Color(FROST, 0.015), Color.TRANSPARENT, 0.0)
		dashed_box(s, rect, Color(FROST, 0.28), 1.5, 5.0, 4.0)
		text(s, Rect2(x, rect.position.y + 14, w, 34), str(card["name"]).capitalize(), font("Outfit", 300), 26, Color(PALE, 0.4))
		text(s, Rect2(x, rect.position.y + 58, w, 18), "NOT CHARTED YET", font("Azeret Mono"), 11, SAGE)
		return
	var on: bool = card["selected"]
	if on:
		box(s, rect, Color(MINT, 0.12), MINT, 2.0)
	else:
		box(s, rect, Color(FROST, 0.04), Color(FROST, 0.45), 2.0)
	var name: String = str(card["name"]).capitalize()
	text(s, Rect2(x, rect.position.y + 14, w, 34), name, font("Outfit", 400 if on else 300), 26, MINT if on else PALE)
	text(s, Rect2(x, rect.position.y + 14, w, 34), "LV %d" % int(card["level"]), font("Azeret Mono"), 13, MINT if on else SAGE,
			HORIZONTAL_ALIGNMENT_RIGHT)
	text(s, Rect2(x, rect.position.y + 66, w, 20), str(card["counts"]), font("Outfit"), 15,
			Color.WHITE if on else PALE)
	text(s, Rect2(x, rect.position.y + 88, w, 18), str(card["keys"]), font("Outfit", 300), 14, MIST if on else SAGE)
	var feel_w: float = w
	if not str(card["best"]).is_empty():
		var best: String = "BEST %s" % card["best"]
		var mono: Font = font("Azeret Mono")
		text(s, Rect2(x, rect.position.y + 108, w, 18), best, mono, 11, MINT if on else SAGE, HORIZONTAL_ALIGNMENT_RIGHT)
		feel_w -= text_width(best, mono, 11) + 10.0
	var feel_font: Font = font("Outfit", 300)
	text(s, Rect2(x, rect.position.y + 108, feel_w, 18), fit_list(str(card["feel"]), feel_font, 14, feel_w), feel_font, 14,
			MIST if on else SAGE)


func _practice(s: RouteScreen, m: Dictionary) -> void:
	var on: bool = m["practice"]["on"]
	s.draw_rect(PRACTICE, Color(BG, 0.8))
	box(s, PRACTICE, Color(MINT, 0.1) if on else Color(FROST, 0.04), MINT if on else Color(FROST, 0.45), 2.0)
	var track := Rect2(PRACTICE.position.x + 26, PRACTICE.position.y + 32, 28, 15)
	box(s, track, Color(MINT, 0.25) if on else Color.TRANSPARENT, MINT if on else SAGE, 1.0, 8.0)
	s.draw_circle(Vector2(track.end.x - 7.5 if on else track.position.x + 7.5, track.position.y + 7.5), 4.5, MINT if on else SAGE)
	if on:
		text(s, Rect2(track.end.x + 10, PRACTICE.position.y + 22, 100, 20), "Practice", font("Outfit", 300), 16, MINT)
		text(s, Rect2(track.end.x + 10, PRACTICE.position.y + 44, 100, 14), str(m["practice"]["text"]), font("Azeret Mono"), 10, MIST)
	else:
		text(s, Rect2(track.end.x + 10, PRACTICE.position.y, 100, PRACTICE.size.y), "Practice", font("Outfit", 300), 16, SOFT)


func _drive(s: RouteScreen, m: Dictionary) -> void:
	var ready: bool = not m["locked"] and not (m["song"] as Dictionary).is_empty()
	if ready:
		for spread: float in [28.0, 18.0, 10.0, 4.0]:
			box(s, DRIVE.grow(spread), Color(MINT, 0.05), Color.TRANSPARENT, 0.0, 40.0 + spread)
	box(s, DRIVE, MINT if ready else Color(FROST, 0.08), Color.TRANSPARENT if ready else Color(FROST, 0.3), 0.0 if ready else 1.0, 40.0)
	var label: String = drive_label(m)
	var f: Font = font("Outfit", 600, 8.0)
	var label_w: float = text_width(label, f, 24)
	var left: float = DRIVE.position.x + (DRIVE.size.x - label_w - (46.0 if ready else 0.0)) * 0.5
	text(s, Rect2(left, DRIVE.position.y, label_w, DRIVE.size.y), label, f, 24, BG if ready else SAGE)
	if ready:
		arrow(s, Rect2(left + label_w + 16, DRIVE.position.y + 32, 30, 16), BG, 2.5)


func _hints(s: RouteScreen, m: Dictionary) -> void:
	var line: String = "← → region    ↑ ↓ station    TAB difficulty    P practice    ENTER drive    M map    " + Ui.back_key() + " menu"
	if (m["song"] as Dictionary).get("imported", false):
		line += "    X remove"
	text(s, Rect2(40, 666, 1200, 18), line, font("Azeret Mono"), 11, SAGE)

## Battle, at the right end of the hints row: a glass pill outlined in mint.
func _battle(s: RouteScreen, m: Dictionary) -> void:
	box(s, BATTLE, Color(BG, 0.8), Color.TRANSPARENT, 0.0, 21.0)
	box(s, BATTLE, Color(MINT, 0.06), Color(MINT, 0.7), 1.0, 21.0)
	battle_contents(s, BATTLE, m, [font("Azeret Mono"), 10, SAGE, Color.TRANSPARENT, Color(FROST, 0.35), 4.0],
		[font("Outfit", 400), 16, MINT], [font("Azeret Mono"), 10, SAGE, "race friends"], true)



func _message(s: RouteScreen, message: String) -> void:
	var f: Font = font("Outfit", 400)
	var w: float = text_width(message, f, 15) + 32.0
	var rect := Rect2(1240.0 - w, 604, w, 30)
	box(s, rect, Color(BG, 0.85), MINT, 1.0, 15.0)
	text(s, rect.grow_individual(-16, 0, -16, 0), message, f, 15, MINT)
