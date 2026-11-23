class_name NeonSkin
extends RouteSkin
## Neon Sprawl's song select (canvas "Final", FinalNeon): a street poster for the megacity.
##
## A black ground with faint diagonal lines and a giant outlined "SPRAWL" behind; a hot-pink slab
## slicing down the right side, a pink halftone band along its edge and an acid-yellow hairline
## beside that. Region tabs are skewed (the chosen one black with a yellow border and a hard
## yellow shadow); songs are Anton caps, the selected one a skewed acid-yellow bar with a pink
## hard shadow, levels yellow (pink from 7 up); the selected title is huge, stacked one or two
## words a line and right-aligned over the pink, under a mono status chip; black difficulty
## cards with big level numbers; a skewed practice toggle and a skewed acid-yellow ENTER DRIVE;
## boxed mono key hints.
##
## Where the design lets decoration run behind text, this keeps it legible: the list's grades and
## levels and the key-hint labels carry a thin black halo (the hairline and the halftones cross
## those columns), and the outlined "SPRAWL", which hangs off the bottom-left corner, is cut at
## the design's edges by a matte in the ground colour so it never spills into a letterbox.

const BG := Color("#0A0A0E")
const PANEL := Color("#15151C")
const EDGE := Color("#2B2B36")
const RULE := Color("#23232C")
const WHITE := Color("#F4F4F6")
const TAB_TEXT := Color("#D9D9E0")
const SOFT := Color("#C4C4CE")
const DIM := Color("#A9A9B6")
const MUTED := Color("#8D8D9A")
const KEY_EDGE := Color("#55556A")
const TOGGLE := Color("#6A6A78")
const DASHES := Color("#3A3A47")
const PINK := Color("#FF2E88")
const ACID := Color("#E8FF3A")
const LOCK_FILL := Color("#0F0F14")
const LOCK_EDGE := Color("#1F1F27")
const LOCK_TEXT := Color("#6E6E7C")
## How much of the detail zone the stacked title may fill: the design's two 96 px lines at
## line-height 0.88 (it overhangs the zone's top by 4 px, which the chip absorbs), and no wider
## than the solid pink, so a long title's first line never runs onto the halftone band (black
## dots on black there, under black type).
const TITLE_W := 615.0
const TITLE_SPACE := 169.0
## The ENTER DRIVE arrow (the design's 46x28 SVG, stroke 5, mitred tip) as one outline.
const ARROW_HEAD := [29.69, 1.16, 43.70, 14.0, 29.69, 26.84, 26.31, 23.16, 36.30, 14.0, 26.31, 4.84]

## Stacked title layouts by title: [font size, lines]. Laid out once per title.
static var _titles: Dictionary = {}


func _init() -> void:
	ground = BG


func draw(s: RouteScreen, m: Dictionary) -> void:
	_backdrop(s)
	_tabs(s, m)
	_header(s, m)
	_list(s, m)
	_load(s)
	_detail(s, m)
	if not (m["song"] as Dictionary).is_empty():
		var cards: Array = m["cards"]
		for i: int in mini(CARDS.size(), cards.size()):
			_card(s, CARDS[i], cards[i])
		_practice(s, m)
	_drive(s, m)
	_hints(s, m)
	_battle(s, m)
	if not str(m.get("message", "")).is_empty():
		_message(s, str(m["message"]))
	_matte(s)
	register_hits(s, m)


# ---------------------------------------------------------------- backdrop

func _backdrop(s: RouteScreen) -> void:
	var screen := Rect2(0, 0, W, H)
	s.draw_rect(screen, BG)
	# repeating-linear-gradient(104deg, white 3.5% 0 2px, transparent 2px 46px): near-vertical
	# hairlines leaning right, 46 px apart measured across them.
	var across := Vector2(sin(deg_to_rad(104.0)), -cos(deg_to_rad(104.0)))
	var along: Vector2 = Vector2(-across.y, across.x) * 1000.0
	var length: float = W * absf(across.x) + H * absf(across.y)
	var start: Vector2 = screen.get_center() - across * length * 0.5
	var t: float = 0.0
	while t < length:
		var a: Vector2 = start + across * t
		var b: Vector2 = a + across * 2.0
		clipped_poly(s, PackedVector2Array([a - along, a + along, b + along, b - along]), screen, Color(1, 1, 1, 0.035))
		t += 46.0
	# The giant outlined SPRAWL: Anton 300 px, line-height 1, its box's bottom 70 px below the
	# screen and its left 20 px off it (the matte trims what hangs outside).
	var big: Font = font("Anton", 400, -4.0)
	text_outline(s, Vector2(-20, _baseline(490.0, 300.0, big, 300)), "SPRAWL", big, 300, Color(1, 1, 1, 0.07), 3)
	# The pink slab, the pink halftone band down its edge, the acid hairline, dark dots on the slab.
	poly(s, _pts([640, 0, 1280, 0, 1280, 720, 486.4, 720]), PINK)
	pattern_poly(s, _pts([576, 0, 640, 0, 486.4, 720, 422.4, 720]), dot_tile(PINK, 9, 1.85))
	poly(s, _pts([552.96, 0, 560.64, 0, 407.04, 720, 399.36, 720]), ACID)
	pattern_poly(s, _pts([1075.2, 0, 1280, 0, 1280, 720, 921.6, 720]), dot_tile(Color(BG, 0.22), 9, 1.65))


## Ground-coloured mattes outside the 1280x720 design (CSS overflow: hidden on the screen), so
## the lettering that hangs off the edge never shows in a letterbox.
func _matte(s: RouteScreen) -> void:
	var far: float = 8000.0
	s.draw_rect(Rect2(-far, -far, far, H + far * 2.0), BG)
	s.draw_rect(Rect2(W, -far, far, H + far * 2.0), BG)
	s.draw_rect(Rect2(0, -far, W, far), BG)
	s.draw_rect(Rect2(0, H, W, far), BG)


# ---------------------------------------------------------------- tabs and header

func _tabs(s: RouteScreen, m: Dictionary) -> void:
	var regions: Array = m["regions"]
	var w: float = (TABS.size.x - 8.0 * (regions.size() - 1)) / maxf(float(regions.size()), 1.0)
	var num_font: Font = font("Anton")
	var name_font: Font = font("Anton", 400, 0.5)
	var sub_font: Font = font("JetBrains Mono", 500)
	var lean: float = tan(deg_to_rad(14.0)) * TABS.size.y * 0.5
	for i: int in regions.size():
		var r: Dictionary = regions[i]
		var rect := Rect2(TABS.position.x + i * (w + 8.0), TABS.position.y, w, TABS.size.y)
		var on: bool = r["selected"]
		var locked: bool = r["locked"]
		if on:
			poly(s, _skew_shadow(rect, 14.0, Vector2(6, 6)), ACID)
			poly(s, skewed(rect, 14.0), ACID)
			poly(s, skewed(rect.grow(-3.0), 14.0), BG)
		else:
			poly(s, skewed(rect, 14.0), LOCK_EDGE if locked else EDGE)
			poly(s, skewed(rect.grow(-2.0), 14.0), LOCK_FILL if locked else PANEL)
		var num: String = "%02d" % int(r["num"])
		var sub: String = "LOCKED" if locked else "%d/%d CLEARED" % [r["cleared"], r["total"]]
		var num_w: float = text_width(num, num_font, 30)
		var label: String = fit(str(r["upper"]), name_font, 18, rect.size.x - lean * 2.0 - 24.0 - num_w - 10.0)
		var col_w: float = maxf(text_width(label, name_font, 18), text_width(sub, sub_font, 11))
		var x: float = rect.get_center().x - (num_w + 10.0 + col_w) * 0.5
		var cy: float = rect.get_center().y
		var num_base := Vector2(x, _baseline(cy, 0.0, num_font, 30))
		if on:
			text_at(s, num_base, num, num_font, 30, ACID)
		else:
			text_outline(s, num_base, num, num_font, 30, LOCK_TEXT if locked else ACID, 3)
		# The name over "n/n CLEARED", line-height 1.05, centred on the tab.
		var top: float = cy - (18.0 + 11.0) * 1.05 * 0.5
		var col_x: float = x + num_w + 10.0
		var name_color: Color = Color.WHITE if on else (LOCK_TEXT if locked else TAB_TEXT)
		text_at(s, Vector2(col_x, _baseline(top, 18.9, name_font, 18)), label, name_font, 18, name_color)
		var sub_color: Color = ACID if on else (LOCK_TEXT if locked else DIM)
		text_at(s, Vector2(col_x, _baseline(top + 18.9, 11.55, sub_font, 11)), sub, sub_font, 11, sub_color)


func _header(s: RouteScreen, m: Dictionary) -> void:
	var region: Dictionary = m["region"]
	var title_font: Font = font("Anton", 400, 0.5)
	var name: String = str(region["upper"])
	text_at(s, Vector2(40, _baseline(102.0, 26.0, title_font, 26)), name, title_font, 26, WHITE)
	# The genres on an acid chip: "SYNTHWAVE / HEAVY ELECTRONIC".
	var genres: String = str(region["genres"]).to_upper().replace(", ", " / ")
	if not genres.is_empty():
		var chip_font: Font = font("JetBrains Mono", 700)
		var x: float = 40.0 + text_width(name, title_font, 26) + 12.0
		var chip_h: float = chip_font.get_height(11) + 6.0
		var label: String = fit(genres, chip_font, 11, 540.0 - x - 16.0)
		var chip := Rect2(x, 115.0 - chip_h * 0.5, text_width(label, chip_font, 11) + 16.0, chip_h)
		box(s, chip, ACID)
		text(s, chip, label, chip_font, 11, BG, HORIZONTAL_ALIGNMENT_CENTER)
	var line_font: Font = font("Space Grotesk", 500)
	var locked: bool = region["locked"]
	var line: String = str(region["locked_text"]) if locked else str(region["blurb"])
	text(s, Rect2(40, 132, 500, line_font.get_height(13)), line, line_font, 13, PINK if locked else SOFT)


# ---------------------------------------------------------------- the list

func _list(s: RouteScreen, m: Dictionary) -> void:
	if int(m["count"]) == 0:
		var r: Rect2 = row_rect(2)
		text(s, Rect2(56, r.position.y, 470, r.size.y), "NO SONGS ON THIS ROAD YET", font("Anton", 400, 0.5), 24, MUTED)
		text(s, Rect2(56, r.position.y + 40, 470, 20), "LOAD YOUR OWN BELOW, OR PICK ANOTHER REGION", font("JetBrains Mono", 500), 11, DIM)
		return
	var rows: Array = m["rows"]
	for slot: int in rows.size():
		var row: Dictionary = rows[slot]
		if row.is_empty():
			continue
		if row["selected"]:
			_selected_row(s, row_rect(slot), row)
		else:
			_row(s, row_rect(slot), row)


func _row(s: RouteScreen, r: Rect2, row: Dictionary) -> void:
	s.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), RULE)
	var mono: Font = font("JetBrains Mono", 500)
	var anton: Font = font("Anton")
	text(s, Rect2(r.position.x + 16, r.position.y, 22, r.size.y), str(row["n"]), mono, 13, MUTED)
	var level: int = int(row["level"])
	var level_rect := Rect2(r.end.x - 16 - 28, r.position.y, 28, r.size.y)
	_halo_text(s, level_rect, str(level), anton, 24, PINK if level >= 7 else ACID, HORIZONTAL_ALIGNMENT_RIGHT)
	var grades: String = str(row["grades"])
	var grades_w: float = text_width(grades, mono, 11)
	_halo_text(s, Rect2(level_rect.position.x - 14 - grades_w, r.position.y, grades_w, r.size.y), grades, mono, 11, DIM)
	var title_rect := Rect2(r.position.x + 52, r.position.y, level_rect.position.x - 28 - grades_w - r.position.x - 52, r.size.y)
	_title_in_row(s, title_rect, row, font("Anton", 400, 0.4), 24, WHITE, PINK, BG)


## The selected song: a skewed acid bar (skewX(-10deg) translateX(14px)) with a pink hard shadow
## down and to the left; its text stays upright.
func _selected_row(s: RouteScreen, r: Rect2, row: Dictionary) -> void:
	var bar := Rect2(r.position.x + 14, r.position.y, r.size.x, r.size.y)
	poly(s, _skew_shadow(bar, 10.0, Vector2(-8, 8)), PINK)
	poly(s, skewed(bar, 10.0), ACID)
	var mono: Font = font("JetBrains Mono", 700)
	var anton: Font = font("Anton")
	text(s, Rect2(bar.position.x + 16, bar.position.y, 22, bar.size.y), str(row["n"]), mono, 13, BG)
	var level_rect := Rect2(bar.end.x - 16 - 28, bar.position.y, 28, bar.size.y)
	text(s, level_rect, str(int(row["level"])), anton, 28, BG, HORIZONTAL_ALIGNMENT_RIGHT)
	var grades: String = str(row["grades"])
	var grades_w: float = text_width(grades, mono, 11)
	text(s, Rect2(level_rect.position.x - 14 - grades_w, bar.position.y, grades_w, bar.size.y), grades, mono, 11, BG)
	var title_rect := Rect2(bar.position.x + 52, bar.position.y, level_rect.position.x - 28 - grades_w - bar.position.x - 52, bar.size.y)
	_title_in_row(s, title_rect, row, font("Anton", 400, 0.4), 28, BG, BG, ACID)


## A row's title, with a small "YOUR SONG" tag after it for an imported song.
func _title_in_row(s: RouteScreen, rect: Rect2, row: Dictionary, f: Font, size: int, color: Color, tag_fill: Color,
		tag_ink: Color) -> void:
	if not row.get("imported", false):
		text(s, rect, str(row["upper"]), f, size, color)
		return
	var tag_font: Font = font("JetBrains Mono", 700, 0.5)
	var tag_w: float = text_width("YOUR SONG", tag_font, 9) + 10.0
	var shown: String = fit(str(row["upper"]), f, size, rect.size.x - tag_w - 10.0)
	text(s, rect, shown, f, size, color)
	var tag := Rect2(rect.position.x + text_width(shown, f, size) + 10.0, rect.get_center().y - 8.0, tag_w, 16.0)
	box(s, tag, tag_fill)
	text(s, tag, "YOUR SONG", tag_font, 9, tag_ink, HORIZONTAL_ALIGNMENT_CENTER)


func _load(s: RouteScreen) -> void:
	box(s, LOAD, BG)
	dashed_box(s, LOAD, DASHES, 2.0, 6.0, 5.0)
	# The plus (an 18 px SVG, stroke 2.5) and the label, in acid.
	var icon := Vector2(LOAD.position.x + 18, LOAD.position.y + 14)
	s.draw_line(icon + Vector2(9, 2), icon + Vector2(9, 16), ACID, 2.5)
	s.draw_line(icon + Vector2(2, 9), icon + Vector2(16, 9), ACID, 2.5)
	text(s, Rect2(icon.x + 30, LOAD.position.y, 360, LOAD.size.y), "LOAD YOUR OWN SONG", font("Anton", 400, 0.6), 19, ACID)
	_key(s, Vector2(LOAD.end.x - 18, LOAD.get_center().y), "L", DIM, Color("#4A4A58"), 7.0, true)


# ---------------------------------------------------------------- the selected song

## Bottom-aligned and right-aligned over the pink: status chip, the huge stacked title, then
## BPM / length.
func _detail(s: RouteScreen, m: Dictionary) -> void:
	var song: Dictionary = m["song"]
	var right: float = DETAIL.end.x
	var mono: Font = font("JetBrains Mono", 700)
	var facts_h: float = mono.get_height(18)
	var facts_top: float = DETAIL.end.y - facts_h
	var facts: Array = ["%d BPM" % int(song["bpm"]), "/", str(song["length"])] if not song.is_empty() else []
	var x: float = right
	for i: int in range(facts.size() - 1, -1, -1):
		var w: float = text_width(str(facts[i]), mono, 18)
		x -= w
		text(s, Rect2(x, facts_top, w, facts_h), str(facts[i]), mono, 18, BG)
		x -= 18.0
	var title: String = str(song["upper"]) if not song.is_empty() else "NO SIGNAL"
	var layout: Array = _title_layout(title)
	var size: int = layout[0]
	var lines: PackedStringArray = layout[1]
	var title_font: Font = font("Anton", 400, -1.0)
	var line_h: float = size * 0.88
	var title_top: float = facts_top - 10.0 - line_h * lines.size()
	for i: int in lines.size():
		var w: float = text_width(lines[i], title_font, size)
		text_at(s, Vector2(right - w, _baseline(title_top + i * line_h, line_h, title_font, size)), lines[i], title_font, size, BG)
	# The status chip: "TRACK 04 OF 25 · NOT DRIVEN YET" in pink on black.
	var chip_font: Font = font("JetBrains Mono", 700, 1.0)
	var status: String = "NO TRACKS ON THIS ROAD"
	var status_color: Color = PINK
	if not song.is_empty():
		var best: String = str(song["best"])
		status = "TRACK %02d OF %d · %s" % [int(song["number"]), int(m["count"]), ("BEST " + best) if not best.is_empty() else "NOT DRIVEN YET"]
		if song.get("remove_armed", false):
			status = "PRESS X AGAIN TO MOVE IT TO THE TRASH"
			status_color = ACID
	var chip_h: float = chip_font.get_height(13) + 8.0
	var chip_w: float = text_width(status, chip_font, 13) + 20.0
	var chip := Rect2(right - chip_w, title_top - 6.0 - chip_h, chip_w, chip_h)
	box(s, chip, BG)
	text(s, chip, status, chip_font, 13, status_color, HORIZONTAL_ALIGNMENT_CENTER)
	if song.get("imported", false):
		var tag_w: float = text_width("YOUR SONG", chip_font, 13) + 20.0
		var tag := Rect2(chip.position.x - 8.0 - tag_w, chip.position.y, tag_w, chip_h)
		box(s, tag, ACID)
		text(s, tag, "YOUR SONG", chip_font, 13, BG, HORIZONTAL_ALIGNMENT_CENTER)


## The title stacked like the design's "CHROME / OVERPASS": at least two lines when it has two
## words, words balanced so the widest line is narrowest, at the largest size (96 down) whose
## lines fit the zone; past the smallest size the last line is ellipsized.
static func _title_layout(title: String) -> Array:
	if _titles.has(title):
		return _titles[title]
	var f: Font = font("Anton", 400, -1.0)
	var words: PackedStringArray = title.split(" ", false)
	if words.is_empty():
		words = PackedStringArray([""])
	var result: Array = []
	var size: int = 96
	while size >= 40 and result.is_empty():
		var most: int = mini(words.size(), maxi(1, int(floor(TITLE_SPACE / (size * 0.88) + 0.001))))
		for count: int in range(mini(2, words.size()), most + 1):
			var split: Array = _split(words, 0, count, f, size, {})
			if float(split[0]) <= TITLE_W:
				result = [size, PackedStringArray(split[1])]
				break
		size -= 4
	if result.is_empty():
		size = 40
		var most: int = mini(words.size(), int(floor(TITLE_SPACE / (size * 0.88) + 0.001)))
		var lines: Array = _split(words, 0, most, f, size, {})[1]
		var fitted := PackedStringArray()
		for line: String in lines:
			fitted.append(fit(line, f, size, TITLE_W))
		result = [size, fitted]
	_titles[title] = result
	return result


## [widest line, lines] for words[start..] broken into `lines` lines, widest line narrowest.
static func _split(words: PackedStringArray, start: int, lines: int, f: Font, size: int, memo: Dictionary) -> Array:
	var key: String = "%d|%d" % [start, lines]
	if memo.has(key):
		return memo[key]
	var out: Array = [INF, []]
	if lines <= 1:
		var whole: String = " ".join(words.slice(start))
		out = [text_width(whole, f, size), [whole]]
	else:
		for end: int in range(start + 1, words.size() - lines + 2):
			var line: String = " ".join(words.slice(start, end))
			var rest: Array = _split(words, end, lines - 1, f, size, memo)
			var widest: float = maxf(text_width(line, f, size), float(rest[0]))
			if widest < float(out[0]):
				out = [widest, [line] + (rest[1] as Array)]
	memo[key] = out
	return out


# ---------------------------------------------------------------- difficulty, practice, drive

## A difficulty card. Three share the zone two had: the feel line drops its second reason (or
## ellipsizes) to leave room for the best grade.
func _card(s: RouteScreen, rect: Rect2, card: Dictionary) -> void:
	if not card.get("available", true):
		_blank_card(s, rect, card)
		return
	var on: bool = card["selected"]
	var border: float = 3.0 if on else 2.0
	if on:
		hard_shadow(s, rect, Vector2(8, 8), BG)
		box(s, rect, BG, ACID, border)
	else:
		box(s, rect, BG)
	var x: float = rect.position.x + border + 18.0
	var w: float = rect.size.x - (border + 18.0) * 2.0
	var y: float = rect.position.y + border + 14.0
	# Name and level share a baseline; the level (40 px, line-height 0.9) sets the row's height.
	var name_font: Font = font("Anton", 400, 1.0)
	var level_font: Font = font("Anton")
	var level_above: float = _baseline(0.0, 36.0, level_font, 40)
	var baseline: float = y + maxf(name_font.get_ascent(26), level_above)
	var tint: Color = ACID if on else WHITE
	text_at(s, Vector2(x, baseline), str(card["name"]), name_font, 26, tint)
	var level: String = str(int(card["level"]))
	text_at(s, Vector2(x + w - text_width(level, level_font, 40), baseline), level, level_font, 40, tint)
	var top: float = baseline + maxf(name_font.get_descent(26), 36.0 - level_above) + 3.0
	# Space Grotesk's line boxes in the design run about 1.12 em (Godot's ascent + descent for it
	# is taller, which spread the lines out), with the 3 px flex gap between them.
	var bold: Font = font("Space Grotesk", 700)
	var plain: Font = font("Space Grotesk", 500)
	text(s, Rect2(x, top, w, 14.0 * 1.12), str(card["counts"]), bold, 14, WHITE)
	top += 14.0 * 1.12 + 3.0
	text(s, Rect2(x, top, w, 13.0 * 1.12), str(card["keys"]), plain, 13, SOFT)
	top += 13.0 * 1.12 + 3.0
	var feel_w: float = w
	var best: String = str(card["best"])
	if not best.is_empty():
		var best_font: Font = font("JetBrains Mono", 700, 1.0)
		var best_label: String = "BEST " + best
		var best_w: float = text_width(best_label, best_font, 11)
		text(s, Rect2(x + w - best_w, top, best_w, 13.0 * 1.12), best_label, best_font, 11, tint)
		feel_w -= best_w + 12.0
	text(s, Rect2(x, top, feel_w, 13.0 * 1.12), fit_list(str(card["feel"]), bold, 13, feel_w), bold, 13, tint)


## A level the song has no chart for yet: a smoked, dashed-out slot on the pink, black type, no level.
func _blank_card(s: RouteScreen, rect: Rect2, card: Dictionary) -> void:
	box(s, rect, Color(BG, 0.32))
	dashed_box(s, rect, BG, 2.0, 7.0, 5.0)
	var x: float = rect.position.x + 20.0
	var w: float = rect.size.x - 40.0
	var name_font: Font = font("Anton", 400, 1.0)
	var baseline: float = rect.position.y + 16.0 + name_font.get_ascent(26)
	text_at(s, Vector2(x, baseline), str(card["name"]), name_font, 26, BG)
	text(s, Rect2(x, baseline + 12.0, w, 16), "NOT CHARTED YET", font("JetBrains Mono", 700, 1.0), 11, BG)


## A skewed black slab with a pill toggle; on, the slab takes an acid border, the knob slides
## over and the speed shows under the label.
func _practice(s: RouteScreen, m: Dictionary) -> void:
	var on: bool = m["practice"]["on"]
	if on:
		poly(s, skewed(PRACTICE, 14.0), ACID)
		poly(s, skewed(PRACTICE.grow(-3.0), 14.0), BG)
	else:
		poly(s, skewed(PRACTICE, 14.0), BG)
	var label_font: Font = font("Anton", 400, 0.6)
	var speed_font: Font = font("JetBrains Mono", 700, 0.5)
	var speed: String = str(m["practice"]["text"]).to_upper()
	var label_w: float = text_width("PRACTICE", label_font, 18)
	var col_w: float = maxf(label_w, text_width(speed, speed_font, 11)) if on else label_w
	# The pill is 34x18 inside a 2 px border (38x22); its 10 px knob sits 2 px in from the top-left
	# of the inside, so a touch above centre, as in the design.
	var x: float = PRACTICE.get_center().x - (38.0 + 10.0 + col_w) * 0.5
	var cy: float = PRACTICE.get_center().y
	var tint: Color = ACID if on else TOGGLE
	box(s, Rect2(x, cy - 11.0, 38.0, 22.0), ACID if on else Color.TRANSPARENT, tint, 2.0, 10.0)
	s.draw_circle(Vector2(x + (29.0 if on else 9.0), cy - 2.0), 5.0, BG if on else tint)
	var label_h: float = label_font.get_height(18)
	if on:
		var speed_h: float = speed_font.get_height(11)
		var top: float = cy - (label_h + speed_h) * 0.5
		text(s, Rect2(x + 48.0, top, col_w, label_h), "PRACTICE", label_font, 18, WHITE)
		text(s, Rect2(x + 48.0, top + label_h, col_w, speed_h), speed, speed_font, 11, ACID)
	else:
		text(s, Rect2(x + 48.0, cy - label_h * 0.5, col_w, label_h), "PRACTICE", label_font, 18, WHITE)


func _drive(s: RouteScreen, m: Dictionary) -> void:
	var ready: bool = not m["locked"] and not (m["song"] as Dictionary).is_empty()
	poly(s, _skew_shadow(DRIVE, 14.0, Vector2(8, 8)), BG)
	poly(s, skewed(DRIVE, 14.0), ACID if ready else EDGE)
	var label: String = drive_label(m)
	var f: Font = font("Anton", 400, 2.0)
	var label_w: float = text_width(label, f, 44)
	var total: float = label_w + (18.0 + 46.0 if ready else 0.0)
	var left: float = DRIVE.get_center().x - total * 0.5
	var label_h: float = f.get_height(44)
	text(s, Rect2(left, DRIVE.get_center().y - label_h * 0.5, label_w + 4.0, label_h), label, f, 44, BG if ready else MUTED)
	if ready:
		var o := Vector2(left + label_w + 18.0, DRIVE.get_center().y - 14.0)
		s.draw_rect(Rect2(o + Vector2(2, 11.5), Vector2(38, 5)), BG)
		var head := PackedVector2Array()
		for i: int in range(0, ARROW_HEAD.size(), 2):
			head.append(o + Vector2(ARROW_HEAD[i], ARROW_HEAD[i + 1]))
		poly(s, head, BG)


# ---------------------------------------------------------------- hints and notes

func _hints(s: RouteScreen, m: Dictionary) -> void:
	var items: Array = [["← →", "REGION"], ["↑ ↓", "SONG"], ["TAB", "DIFFICULTY"], ["P", "PRACTICE"], ["ENTER", "DRIVE"], ["M", "MAP"], [Ui.back_key(), "MENU"]]
	if (m["song"] as Dictionary).get("imported", false):
		items.append(["X", "REMOVE"])
	var f: Font = font("JetBrains Mono", 500)
	var h: float = f.get_height(12) + 6.0
	var cy: float = 664.0 + h * 0.5
	var x: float = 40.0
	# The design's grey labels vanish on the pink slab: there they turn black, and over the
	# hairline and halftone band they keep a black halo.
	var pink_edge: float = lerpf(640.0, 486.4, cy / H)
	for item: Array in items:
		x += _key(s, Vector2(x, cy), str(item[0]), Color.WHITE, KEY_EDGE, 6.0, false) + 6.0
		var w: float = text_width(str(item[1]), f, 12)
		var label := Rect2(x, cy - h * 0.5, w + 2.0, h)
		if x >= pink_edge + 2.0:
			text(s, label, str(item[1]), f, 12, BG)
		else:
			_halo_text(s, label, str(item[1]), f, 12, SOFT)
		x += w + 22.0


## Battle, at the right end of the hints row: a skewed black chip on the pink, in acid.
func _battle(s: RouteScreen, m: Dictionary) -> void:
	poly(s, skewed(BATTLE, 14.0), BG)
	battle_contents(s, BATTLE, m, [font("JetBrains Mono", 500), 12, WHITE, BG, KEY_EDGE, 0.0],
		[font("Anton", 400, 0.6), 20, ACID], [font("JetBrains Mono", 500), 11, DIM, "RACE FRIENDS"])


## A boxed key cap (JetBrains Mono 12, 1 px border) centred on `at.y`, starting at `at.x` or, with
## `from_right`, ending there. Filled black so the slab or halftone never shows through it.
## Returns its width.
func _key(s: RouteScreen, at: Vector2, key: String, ink: Color, edge: Color, pad: float, from_right: bool) -> float:
	var f: Font = font("JetBrains Mono", 500)
	var w: float = text_width(key, f, 12) + pad * 2.0 + 2.0
	var h: float = f.get_height(12) + 6.0
	var rect := Rect2(at.x - (w if from_right else 0.0), at.y - h * 0.5, w, h)
	box(s, rect, BG, edge, 1.0)
	text(s, rect, key, f, 12, ink, HORIZONTAL_ALIGNMENT_CENTER)
	return w


## A passing note (an import finished, a song removed): a skewed black chip under ENTER DRIVE,
## clear of the hints.
func _message(s: RouteScreen, message: String) -> void:
	var f: Font = font("JetBrains Mono", 700, 0.5)
	var shown: String = fit(message, f, 12, 600.0)
	var w: float = text_width(shown, f, 12) + 40.0
	var rect := Rect2(DRIVE.end.x - w, 616, w, 30)
	poly(s, skewed(rect, 14.0), BG)
	poly(s, skewed(Rect2(rect.position.x + 6, rect.position.y + 7, 5, 16), 14.0), ACID)
	text(s, Rect2(rect.position.x + 18, rect.position.y, w - 26, rect.size.y), shown, f, 12, ACID)


# ---------------------------------------------------------------- helpers

## The baseline of a `size` px line set in a CSS line box `line_h` tall whose top is `top`
## (half-leading above and below); line_h 0 centres the glyphs' own box on `top`.
static func _baseline(top: float, line_h: float, f: Font, size: int) -> float:
	var ascent: float = f.get_ascent(size)
	return top + (line_h - ascent - f.get_descent(size)) * 0.5 + ascent


## Text like text(), on a thin black halo: legible where the hairline or a halftone runs behind.
static func _halo_text(c: CanvasItem, rect: Rect2, value: String, f: Font, size: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var shown: String = fit(value, f, size, rect.size.x)
	var at := Vector2(rect.position.x, _baseline(rect.get_center().y, 0.0, f, size))
	c.draw_string_outline(f, at, shown, align, rect.size.x, size, 10, BG)
	c.draw_string(f, at, shown, align, rect.size.x, size, color)


## A skewed shape's hard shadow: box-shadow offsets are in the element's own space, so the skew
## shears the offset too.
static func _skew_shadow(rect: Rect2, deg: float, offset: Vector2) -> PackedVector2Array:
	var shift := Vector2(offset.x - tan(deg_to_rad(deg)) * offset.y, offset.y)
	var points: PackedVector2Array = skewed(rect, deg)
	for i: int in points.size():
		points[i] += shift
	return points


static func _pts(coords: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in range(0, coords.size(), 2):
		points.append(Vector2(float(coords[i]), float(coords[i + 1])))
	return points
