class_name FrontierSkin
extends RouteSkin
## Red Frontier's song select: the dashboard of a homestead truck (canvas "1 · Red Frontier").
##
## Vinyl dash with stitched seams; region presets as chunky radio buttons (the chosen one pushed
## in); the song list is the radio's slide-rule dial, AM frequencies down the side and a red
## needle across the tuned station; the selected song shows through the windshield (a Mars
## dusk: banded sky, blue sun, mesas, a pylon line, a dome) with a "now tuned" plate under it;
## difficulty plates, a toggle switch for practice, a big amber pill to drive; key hints on a
## Dymo label strip.

const BG := Color("#2A1611")
const INK := Color("#1E0F0C")
const EDGE := Color("#120806")
const CREAM := Color("#EDE2CC")
const DIAL := Color("#F2DFC0")
const AMBER := Color("#FFA552")
const TUNED := Color("#F7B562")
const PAPER := Color("#F2E6D4")
const DUST := Color("#D8BFA6")
const RUST := Color("#6A3A1C")
const SEAM := Color("#5A3426")
const NEEDLE := Color("#C8261C")


func _init() -> void:
	ground = BG


func draw(s: RouteScreen, m: Dictionary) -> void:
	s.draw_rect(Rect2(0, 0, W, H), BG)
	pattern(s, Rect2(0, 0, W, H), dot_tile(Color(0, 0, 0, 0.22), 5, 1.0))
	dashed_line(s, Vector2(0, 97), Vector2(W, 97), SEAM, 2.0, 6.0, 4.0)
	dashed_line(s, Vector2(0, 641), Vector2(W, 641), SEAM, 2.0, 6.0, 4.0)
	_tabs(s, m)
	_header(s, m)
	_dial(s, m)
	if not m.get("pick", false):
		_load(s)
	_windshield(s, m)
	if not (m["song"] as Dictionary).is_empty():
		for i: int in mini((m["cards"] as Array).size(), CARDS.size()):
			_plate(s, CARDS[i], m["cards"][i])
		if not m.get("pick", false):
			_practice(s, m)
	_drive(s, m)
	_hints(s, m)
	_battle(s, m)
	if not str(m.get("message", "")).is_empty():
		_message(s, str(m["message"]))
	register_hits(s, m)


func _tabs(s: RouteScreen, m: Dictionary) -> void:
	var regions: Array = m["regions"]
	var w: float = (TABS.size.x - 8.0 * (regions.size() - 1)) / regions.size()
	for i: int in regions.size():
		var r: Dictionary = regions[i]
		var rect := Rect2(TABS.position.x + i * (w + 8.0), TABS.position.y, w, TABS.size.y)
		var on: bool = r["selected"]
		if on:
			rect.position.y += 3.0  # pushed in
			hard_shadow(s, rect, Vector2(0, 1), EDGE, 4.0)
		else:
			hard_shadow(s, rect, Vector2(0, 4), EDGE, 4.0)
		box(s, rect, AMBER if on else CREAM, EDGE, 2.0, 4.0)
		text(s, Rect2(rect.position.x, rect.position.y + 10, rect.size.x, 22), "%d · %s" % [r["num"], r["upper"]],
				font("Oswald", 600, 1.5), 15, INK, HORIZONTAL_ALIGNMENT_CENTER)
		var status: String = "LOCKED" if r["locked"] else "%d/%d cleared" % [r["cleared"], r["total"]]
		text(s, Rect2(rect.position.x, rect.position.y + 33, rect.size.x, 16), status, font("Oswald", 500), 11,
				INK if on else Color("#5A4636"), HORIZONTAL_ALIGNMENT_CENTER)


func _header(s: RouteScreen, m: Dictionary) -> void:
	var region: Dictionary = m["region"]
	var title_font: Font = font("Rye")
	var baseline: float = 102.0 + title_font.get_ascent(30)
	text_at(s, Vector2(40, baseline), str(region["name"]), title_font, 30, Color("#FFC78C"))
	var x: float = 40.0 + text_width(str(region["name"]), title_font, 30) + 12.0
	text_at(s, Vector2(x, baseline), str(region["genres"]).to_upper().replace(", ", " · "), font("Oswald", 600, 2.5), 12, DUST)
	var line: String = str(region["locked_text"]) if region["locked"] else str(region["blurb"])
	text(s, Rect2(40, 134, 500, 18), line, font("Oswald"), 13, AMBER if region["locked"] else DUST)


func _dial(s: RouteScreen, m: Dictionary) -> void:
	var frame := Rect2(40, 160, 500, 394)
	hard_shadow(s, frame, Vector2(6, 6), EDGE, 6.0)
	box(s, frame, DIAL, EDGE, 4.0, 6.0)
	var inner := Rect2(44, 164, 492, 386)
	# The frequency scale: a ruled column down the left.
	var scale_rect := Rect2(inner.position.x, inner.position.y, 64, inner.size.y)
	var y: float = scale_rect.position.y + 7.0
	while y < scale_rect.end.y:
		s.draw_rect(Rect2(scale_rect.end.x - 18.0, y, 18.0, 1.0), Color(INK, 0.55))
		y += 8.0
	s.draw_rect(Rect2(scale_rect.end.x - 2.0, scale_rect.position.y, 2.0, scale_rect.size.y), INK)
	var rows: Array = m["rows"]
	if (m["count"] as int) == 0:
		text(s, Rect2(inner.position.x + 80, inner.position.y + 160, 400, 30), "NO STATIONS ON THIS ROAD YET", font("Oswald", 600, 1.5), 16, RUST)
	for slot: int in rows.size():
		var row: Dictionary = rows[slot]
		if row.is_empty():
			continue
		var r := Rect2(inner.position.x, inner.position.y + slot * ROW_PITCH, inner.size.x, ROW_H)
		var on: bool = row["selected"]
		if on:
			s.draw_rect(r, TUNED)
			s.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), INK)
			s.draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), INK)
		var text_color: Color = INK if on else Color("#2A140E")
		text(s, Rect2(r.position.x + 10, r.position.y, 54, r.size.y), str(row["freq"]), font("Oswald", 600 if on else 400), 13,
				INK if on else RUST)
		var level_text: String = "Lv %d" % int(row["level"])
		var level_font: Font = font("Alfa Slab One") if on else font("Oswald", 600)
		var level_size: int = 18 if on else 15
		text(s, Rect2(r.end.x - 86, r.position.y, 70, r.size.y), level_text, level_font, level_size, text_color, HORIZONTAL_ALIGNMENT_RIGHT)
		var grades_font: Font = font("Oswald", 600 if on else 400, 1.0)
		var grades_w: float = text_width(str(row["grades"]), grades_font, 12)
		text(s, Rect2(r.end.x - 86 - grades_w, r.position.y, grades_w, r.size.y), str(row["grades"]), grades_font, 12,
				INK if on else Color("#6A4A3A"))
		var name_left: float = r.position.x + 64.0 + 16.0
		var name_rect := Rect2(name_left, r.position.y, r.end.x - 86 - grades_w - 12 - name_left, r.size.y)
		if on:
			text(s, name_rect, str(row["title"]), font("Alfa Slab One"), 22, INK)
		else:
			text(s, name_rect, str(row["title"]), font("Oswald", 500), 19, text_color)
		if row.get("imported", false):
			text(s, Rect2(name_left, r.end.y - 14, 200, 12), "YOUR SONG", font("Oswald", 600, 1.0), 9, NEEDLE)
	# The needle runs behind the dial face: only its pointer and the stubs either side of the frame
	# show, level with the tuned station. Drawn across the face it struck through the title.
	s.draw_rect(Rect2(30, 355, 14, 4), NEEDLE)
	s.draw_rect(Rect2(536, 355, 14, 4), NEEDLE)
	poly(s, PackedVector2Array([Vector2(24, 347), Vector2(40, 357), Vector2(24, 367)]), NEEDLE)


func _load(s: RouteScreen) -> void:
	box(s, LOAD, BG, Color.TRANSPARENT, 0.0, 4.0)
	dashed_box(s, LOAD, Color("#B8A28C"), 2.0, 6.0, 4.0)
	text(s, Rect2(LOAD.position.x + 16, LOAD.position.y, 400, LOAD.size.y), "+ TUNE IN YOUR OWN SONG", font("Oswald", 600, 1.5), 15, PAPER)
	text(s, Rect2(LOAD.end.x - 40, LOAD.position.y, 24, LOAD.size.y), "L", font("Oswald"), 15, DUST, HORIZONTAL_ALIGNMENT_RIGHT)


func _windshield(s: RouteScreen, m: Dictionary) -> void:
	var outer := DETAIL
	var o := Vector2(588, 108)  # the scene's origin, inside the 8 px frame
	var scene := Rect2(o, Vector2(644, 214))
	# Sky bands, sun, mesas, ground.
	var bands: Array = [[0, 34, "#43386A"], [34, 30, "#5E4A84"], [64, 26, "#8C6492"], [90, 22, "#C27D88"], [112, 22, "#E2A08A"]]
	for b: Array in bands:
		s.draw_rect(Rect2(o.x, o.y + float(b[0]), 644, float(b[1])), Color(str(b[2])))
	s.draw_circle(o + Vector2(420, 110), 26, Color("#9DB8E4"))
	s.draw_circle(o + Vector2(420, 110), 8, Color("#F4F8FF"))
	poly(s, _shift(o, [0, 134, 0, 104, 46, 104, 62, 92, 190, 92, 206, 116, 270, 116, 284, 134]), Color("#5A281E"))
	poly(s, _shift(o, [470, 134, 492, 112, 560, 112, 572, 100, 644, 100, 644, 134]), Color("#64301F"))
	s.draw_rect(Rect2(o.x, o.y + 134, 644, 80), Color("#8A3A24"))
	# The pylon line and its cables.
	var wire := Color("#2A1611")
	for seg: Array in [[30, 134, 40, 18], [40, 18, 50, 134], [33, 90, 47, 90], [36, 56, 44, 56], [32, 118, 48, 74],
			[34, 74, 46, 118], [24, 26, 56, 26], [140, 134, 146, 70], [146, 70, 152, 134], [136, 76, 156, 76], [142, 100, 150, 100]]:
		s.draw_line(o + Vector2(seg[0], seg[1]), o + Vector2(seg[2], seg[3]), wire, 2.0)
	for cable: Array in [[24, 26, 90, 66, 136, 76], [56, 26, 110, 58, 156, 76], [156, 76, 200, 96, 250, 104]]:
		s.draw_polyline(_shift_points(o, quad(Vector2(cable[0], cable[1]), Vector2(cable[2], cable[3]), Vector2(cable[4], cable[5]))), wire, 2.0, true)
	s.draw_circle(o + Vector2(40, 16), 3, Color("#E8352A"))
	# A dome with its frame and lit windows, and two crop tubes glowing on the plain.
	var dome := PackedVector2Array()
	for i: int in 25:
		var a: float = PI + PI * float(i) / 24.0
		dome.append(o + Vector2(560, 134) + Vector2(cos(a), sin(a)) * 40.0)
	poly(s, dome, Color("#D9B49A"))
	s.draw_polyline(dome, wire, 2.0, true)
	for seg: Array in [[534, 116, 560, 96], [560, 96, 586, 116], [560, 96, 560, 134], [520, 134, 560, 96], [560, 96, 600, 134]]:
		s.draw_line(o + Vector2(seg[0], seg[1]), o + Vector2(seg[2], seg[3]), wire, 1.5)
	s.draw_rect(Rect2(o + Vector2(548, 122), Vector2(8, 6)), Color("#FFD27A"))
	s.draw_rect(Rect2(o + Vector2(568, 120), Vector2(8, 6)), Color("#FFD27A"))
	s.draw_line(o + Vector2(300, 146), o + Vector2(420, 146), Color("#9BE26A"), 4.0)
	s.draw_line(o + Vector2(300, 156), o + Vector2(440, 156), Color("#E8C35A"), 4.0)
	# The "now tuned" plate along the bottom of the glass.
	var plate := Rect2(o.x, scene.end.y - 80, 644, 80)
	s.draw_rect(plate, CREAM)
	s.draw_rect(Rect2(plate.position.x, plate.position.y, plate.size.x, 3), EDGE)
	var song: Dictionary = m["song"]
	if song.is_empty():
		text(s, Rect2(plate.position.x + 20, plate.position.y + 3, 600, 77), "NOTHING TUNED", font("Alfa Slab One"), 30, INK)
	else:
		var status: String = "NOW TUNED · TRACK %02d OF %d · %s" % [song["number"], m["count"],
				("BEST " + str(song["best"])) if not str(song["best"]).is_empty() else "NOT DRIVEN YET"]
		if song.get("imported", false):
			status = "NOW TUNED · YOUR SONG · " + (("BEST " + str(song["best"])) if not str(song["best"]).is_empty() else "NOT DRIVEN YET")
		var status_color: Color = RUST
		if song.get("remove_armed", false):
			status = "PRESS X AGAIN TO MOVE IT TO THE TRASH"
			status_color = NEEDLE
		var facts: String = "%d BPM · %s" % [song["bpm"], song["length"]]
		var facts_font: Font = font("Oswald", 600)
		var facts_w: float = text_width(facts, facts_font, 17)
		text(s, Rect2(plate.end.x - 20 - facts_w, plate.position.y + 3, facts_w, 77), facts, facts_font, 17, INK)
		text(s, Rect2(plate.position.x + 20, plate.position.y + 14, plate.size.x - 60 - facts_w, 16), status, font("Oswald", 600, 3.0), 11, status_color)
		text(s, Rect2(plate.position.x + 20, plate.position.y + 30, plate.size.x - 60 - facts_w, 42), str(song["title"]), font("Alfa Slab One"), 36, INK)
	# The frame over the scene's edges: rounded at the top like a windshield.
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_color = EDGE
	frame.set_border_width_all(8)
	frame.corner_radius_top_left = 22
	frame.corner_radius_top_right = 22
	frame.corner_radius_bottom_left = 6
	frame.corner_radius_bottom_right = 6
	frame.anti_aliasing = true
	frame.draw(s.get_canvas_item(), outer)


## A difficulty plate. Three share the zone two had, so the lines are short and the feel line
## drops its second reason (or ellipsizes) to leave room for the best grade.
func _plate(s: RouteScreen, rect: Rect2, card: Dictionary) -> void:
	if not card.get("available", true):
		_blank_plate(s, rect, card)
		return
	var on: bool = card["selected"]
	var r: Rect2 = rect
	if on:
		r.position += Vector2(4, 4)
		hard_shadow(s, r, Vector2(1, 1), EDGE, 6.0)
	else:
		hard_shadow(s, r, Vector2(5, 5), EDGE, 6.0)
	box(s, r, AMBER if on else CREAM, EDGE, 3.0, 6.0)
	# 20 px slab on a 207 px plate: at the design's 22, "NORMAL" ran into "Lv 8".
	var x: float = r.position.x + 16.0
	var w: float = r.size.x - 32.0
	text(s, Rect2(x, r.position.y + 12, w, 28), str(card["name"]), font("Alfa Slab One"), 20, INK)
	text(s, Rect2(x, r.position.y + 12, w, 28), "Lv %d" % int(card["level"]), font("Alfa Slab One"), 20, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	text(s, Rect2(x, r.position.y + 46, w, 22), str(card["counts"]), font("Oswald", 500), 15, INK)
	text(s, Rect2(x, r.position.y + 70, w, 20), str(card["keys"]), font("Oswald"), 14, INK if on else Color("#5A4636"))
	var feel_w: float = w
	if not str(card["best"]).is_empty():
		var best_font: Font = font("Oswald", 600, 1.0)
		text(s, Rect2(x, r.position.y + 92, w, 20), "BEST " + str(card["best"]), best_font, 13, INK, HORIZONTAL_ALIGNMENT_RIGHT)
		feel_w -= text_width("BEST " + str(card["best"]), best_font, 13) + 10.0
	var feel_font: Font = font("Oswald", 600)
	text(s, Rect2(x, r.position.y + 92, feel_w, 20), fit_list(str(card["feel"]), feel_font, 14, feel_w), feel_font, 14,
			INK if on else RUST)


## A level the song has no chart for yet: an empty slot in the dash, flat and dashed, no level.
func _blank_plate(s: RouteScreen, rect: Rect2, card: Dictionary) -> void:
	box(s, rect, Color("#3A2219"), EDGE, 3.0, 6.0)
	dashed_box(s, rect.grow(-6.0), Color("#6A4A3A"), 2.0, 6.0, 4.0)
	var x: float = rect.position.x + 16.0
	var w: float = rect.size.x - 32.0
	text(s, Rect2(x, rect.position.y + 12, w, 28), str(card["name"]), font("Alfa Slab One"), 20, Color("#8A6A56"))
	text(s, Rect2(x, rect.position.y + 50, w, 22), "not charted yet", font("Oswald", 500), 15, DUST)


func _practice(s: RouteScreen, m: Dictionary) -> void:
	var on: bool = m["practice"]["on"]
	box(s, PRACTICE, Color("#4A2A1C") if on else BG, AMBER if on else Color("#B8A28C"), 2.0, 6.0)
	# A toggle switch: lever back for off, forward for on.
	var base := Vector2(PRACTICE.position.x + 30, PRACTICE.position.y + 20)
	box(s, Rect2(base + Vector2(3, 18), Vector2(20, 20)), Color("#B8A28C"), EDGE, 2.0, 3.0)
	s.draw_line(base + Vector2(13, 28), base + (Vector2(20, 4) if on else Vector2(6, 4)), CREAM, 5.0)
	s.draw_circle(base + (Vector2(20, 4) if on else Vector2(6, 4)), 2.5, CREAM)
	text(s, Rect2(base.x + 38, PRACTICE.position.y + 20, 110, 20), "PRACTICE", font("Oswald", 600, 2.0), 15, PAPER)
	text(s, Rect2(base.x + 38, PRACTICE.position.y + 42, 110, 18), "%s · P" % m["practice"]["text"], font("Oswald"), 12, AMBER if on else DUST)


func _drive(s: RouteScreen, m: Dictionary) -> void:
	var ready: bool = not m["locked"] and not (m["song"] as Dictionary).is_empty()
	hard_shadow(s, DRIVE, Vector2(0, 6), EDGE, 40.0)
	box(s, DRIVE, AMBER if ready else Color("#8A7A6A"), EDGE, 3.0, 40.0)
	var label: String = drive_label(m)
	var with_arrow: bool = drive_arrow(m)
	var fitted: Array = fit_button_label(label, "Alfa Slab One", 400, [2.0, 1.0], 34, DRIVE.size.x - 56.0 - (50.0 if with_arrow else 0.0))
	var f: Font = fitted[0]
	var size: int = fitted[1]
	var label_w: float = text_width(label, f, size)
	var left: float = DRIVE.position.x + (DRIVE.size.x - label_w - (50.0 if with_arrow else 0.0)) * 0.5
	text(s, Rect2(left, DRIVE.position.y, label_w, DRIVE.size.y), label, f, size, INK)
	if with_arrow:
		arrow(s, Rect2(left + label_w + 16, DRIVE.position.y + 29, 34, 22), INK, 4.0)


func _hints(s: RouteScreen, m: Dictionary) -> void:
	var line: String = hint_line(m, "   ")
	var f: Font = font("Courier Prime", 700, 1.5)
	var size: int = fit_size(line, f, 15, HINTS_RIGHT - 40.0 - 28.0)
	var w: float = text_width(line, f, size) + 28.0
	var label := Rect2(0, 0, w, size + 20.0)
	s.begin_local(Transform2D(deg_to_rad(-0.6), Vector2(40 + w * 0.5, 680)) * Transform2D(0.0, -label.size * 0.5))
	s.draw_rect(label, EDGE)
	s.draw_rect(Rect2(0, 0, w, 1), Color(1, 1, 1, 0.12))
	text(s, Rect2(14, 0, w - 28, label.size.y), line, f, size, Color("#F4EDE4"))
	s.end_local()

## Battle, at the right end of the hints row: a vinyl-brown plate edged in amber.
func _battle(s: RouteScreen, m: Dictionary) -> void:
	hard_shadow(s, BATTLE, Vector2(0, 4), EDGE, 6.0)
	box(s, BATTLE, BG, AMBER, 2.0, 6.0)
	battle_contents(s, BATTLE, m, [font("Oswald", 600), 14, INK, CREAM, Color.TRANSPARENT, 3.0],
		[font("Alfa Slab One", 400, 1.0), 18, AMBER], [font("Oswald"), 15, DUST, "race friends"])



func _message(s: RouteScreen, message: String) -> void:
	var f: Font = font("Oswald", 600, 1.0)
	var w: float = text_width(message, f, 14) + 28.0
	var rect := Rect2(1240.0 - w, 604, w, 30)
	box(s, rect, CREAM, EDGE, 2.0, 4.0)
	text(s, rect.grow_individual(-14, 0, -14, 0), message, f, 14, INK)


static func _shift(origin: Vector2, coords: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in range(0, coords.size(), 2):
		points.append(origin + Vector2(float(coords[i]), float(coords[i + 1])))
	return points


static func _shift_points(origin: Vector2, points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(origin + p)
	return out
