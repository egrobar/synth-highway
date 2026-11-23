class_name LoopMap
extends Control
## The loop map: the route's five regions as stops on one ring road, drawn as a night-sky
## route chart. A new player picks where to start here; later it shows how far round the loop
## they have opened (RouteLoop has the rule: two clears in a region open the next one clockwise).
##
## Drawn in a 1280x720 design space, scaled to fit and centred like the song select (RouteScreen),
## and animated: the road's centre line flows clockwise, a light runs round the loop, the stars
## twinkle and the focused stop pulses. All of that holds still when the player has turned
## "beat flashes and camera movement" off (Settings.motion).
##
## The road between two stops belongs to the first one: it lights up as that region's two clears
## come in (a diamond pip for each), so the way on is literally paved by clearing songs.
##
## main.gd builds the model and handles the keyboard; this control draws it and turns clicks into
## `acted` signals: "node" (a stop's index: focus it, or pick it when already focused) and "pick".
##
## The model:
##   regions  [{id, name, genres, blurb, cleared, total, open, needs, prev_name, start}] in loop
##            order: `open` is how the stop is drawn (all of them while no start is picked: any
##            can be the start), `needs` the clears still wanted in the region before it, `start`
##            whether it is the player's start
##   focus    the focused stop
##   picking  true while a start can be picked (none yet, or nothing cleared since)
##   chosen   true once a start is picked

signal acted(action: String, arg: Variant)

const DESIGN := Vector2(1280.0, 720.0)
const CENTER := Vector2(640.0, 380.0)
const RADII := Vector2(455.0, 220.0)
const SAMPLES := 360
const ROAD_W := 20.0
const NODE_R := 27.0
const DASH := 13.0
const DASH_PERIOD := 26.0
## Each region's colour on the map. Distinct hues round the ring: the skins' own accents would
## put two oranges side by side (Red Frontier's and Tidewater's coral).
const COLORS := {"backroads": Color("#FF8A3D"), "neon": Color("#FF2E88"), "coast": Color("#4FD6FF"),
	"mesa": Color("#FFC81E"), "aurora": Color("#7DFFC8")}
const INK := Color("#E9ECFF")
const MUTED := Color("#8A90B8")
const DIM := Color("#454964")
const ASPHALT := Color("#14162B")
const PANEL := Color("#080A1BD9")

var model: Dictionary = {}
var _hits: Array = []
var _scale: float = 1.0
## The design-space scale and the transform drawing goes through, for RouteSkin.draw_text, which
## draws text at its on-screen size so it stays sharp (as on the song select).
var draw_scale: float = 1.0
var draw_matrix := Transform2D.IDENTITY
var _origin := Vector2.ZERO
## Stars as (x, y, twinkle phase).
var _stars: Array[Vector3] = []
## The ring sampled once, closed (the last point repeats the first): centre line, the two road
## edges, each point's place round the loop (0 = the first region, clockwise, 1 = back again)
## and the distance along the road to it.
var _ring := PackedVector2Array()
var _inner := PackedVector2Array()
var _outer := PackedVector2Array()
var _ring_u := PackedFloat32Array()
var _ring_d := PackedFloat32Array()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 170:
		_stars.append(Vector3(rng.randf_range(0, DESIGN.x), rng.randf_range(0, DESIGN.y), rng.randf_range(0, TAU)))
	var travelled: float = 0.0
	for i: int in SAMPLES + 1:
		var u: float = float(i) / float(SAMPLES)
		var angle: float = -PI * 0.5 + u * TAU
		var direction := Vector2(cos(angle), sin(angle))
		var point: Vector2 = CENTER + direction * RADII
		if i > 0:
			travelled += point.distance_to(_ring[i - 1])
		_ring.append(point)
		_inner.append(CENTER + direction * (RADII - Vector2(10, 10)))
		_outer.append(CENTER + direction * (RADII + Vector2(10, 10)))
		_ring_u.append(u)
		_ring_d.append(travelled)


func present(new_model: Dictionary) -> void:
	model = new_model
	queue_redraw()


func _process(_delta: float) -> void:
	if Settings.motion:
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var regions: Array = model.get("regions", [])
	if regions.is_empty():
		return
	_scale = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = (size - DESIGN * _scale) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color("#05060C"))
	draw_scale = _scale
	draw_matrix = Transform2D(0.0, Vector2(_scale, _scale), 0.0, _origin)
	draw_set_transform_matrix(draw_matrix)
	_hits.clear()
	var t: float = Time.get_ticks_msec() / 1000.0 if Settings.motion else 0.0
	_draw_sky(regions, t)
	_draw_road(regions, t)
	_draw_pips(regions)
	if Settings.motion:
		_draw_light(regions, t)
	for k: int in regions.size():
		_draw_stop(regions, k, t)
	_draw_centre(regions)
	_draw_header()
	_draw_footer()
	draw_scale = 1.0
	draw_matrix = Transform2D.IDENTITY
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- the sky and the chart

func _draw_sky(regions: Array, t: float) -> void:
	RouteSkin.vgradient(self, Rect2(Vector2.ZERO, DESIGN), [Color("#0C0F2A"), Color("#080A1C"), Color("#05060C")], [0.0, 0.55, 1.0])
	var focused: Dictionary = regions[int(model.get("focus", 0))]
	RouteSkin.glow(self, CENTER, Vector2(560, 330), Color(_color(focused), 0.16), 18)
	for star: Vector3 in _stars:
		var alpha: float = 0.18 + 0.32 * (0.5 + 0.5 * sin(t * 1.3 + star.z))
		draw_rect(Rect2(star.x, star.y, 1.6, 1.6), Color(1, 1, 1, alpha))
	# A navigation chart's rings and bearing ticks round the loop.
	for k: float in [0.4, 0.7, 1.3]:
		RouteSkin.outline(self, RouteSkin.ellipse_points(CENTER, RADII * k, 120), Color(MUTED, 0.08), 1.0)
	for i: int in 72:
		var angle: float = TAU * float(i) / 72.0
		var direction := Vector2(cos(angle), sin(angle))
		var reach: float = 1.36 if i % 6 == 0 else 1.33
		draw_line(CENTER + direction * RADII * 1.3, CENTER + direction * RADII * reach, Color(MUTED, 0.16), 1.0)


# ---------------------------------------------------------------- the road

func _draw_road(regions: Array, t: float) -> void:
	var halo := PackedColorArray()
	var haze := PackedColorArray()
	var edges := PackedColorArray()
	for i: int in _ring.size():
		var hue: Color = _hue(regions, _ring_u[i])
		var lit: float = _lit(regions, _ring_u[i])
		halo.append(Color(hue, 0.07 * lit))
		haze.append(Color(hue, 0.14 * lit))
		edges.append(Color(DIM.lerp(hue, lit), 0.45 + 0.55 * lit))
	draw_polyline_colors(_ring, halo, 50.0, true)
	draw_polyline_colors(_ring, haze, 32.0, true)
	draw_polyline(_ring, ASPHALT, ROAD_W, true)
	draw_polyline_colors(_inner, edges, 2.5, true)
	draw_polyline_colors(_outer, edges, 2.5, true)
	# The centre line's dashes run clockwise, the way the loop is driven.
	var shift: float = fposmod(t * 42.0, DASH_PERIOD)
	var dashes := PackedVector2Array()
	var colors := PackedColorArray()
	for i: int in _ring.size() - 1:
		if fposmod(_ring_d[i] - shift, DASH_PERIOD) < DASH:
			dashes.append(_ring[i])
			dashes.append(_ring[i + 1])
			colors.append(Color(1, 1, 1, 0.14 + 0.62 * _lit(regions, _ring_u[i])))
	if not dashes.is_empty():
		draw_multiline_colors(dashes, colors, 2.0)


## Two diamonds on each stretch of road, one per clear the region before it needs, and a
## chevron between them pointing the way round.
func _draw_pips(regions: Array) -> void:
	var count: int = regions.size()
	for s: int in count:
		var region: Dictionary = regions[s]
		var next_open: bool = bool((regions[(s + 1) % count] as Dictionary).get("open", false))
		var hue: Color = _color(region)
		for j: int in RouteLoop.CLEARS_TO_ADVANCE:
			var u: float = (float(s) + float(j + 1) / float(RouteLoop.CLEARS_TO_ADVANCE + 1)) / float(count)
			var p: Vector2 = _point(u)
			# Lit for a clear, or on road already driven past. Before a start is picked every stop
			# is drawn open, but nothing is cleared: the diamonds stay empty.
			var done: bool = bool(region.get("open", false)) and (int(region.get("cleared", 0)) > j
				or (next_open and bool(model.get("chosen", false))))
			var diamond := PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)])
			if done:
				RouteSkin.glow(self, p, Vector2(16, 16), Color(hue, 0.7), 8)
				RouteSkin.poly(self, diamond, hue)
			else:
				RouteSkin.poly(self, diamond, ASPHALT)
				RouteSkin.outline(self, diamond, Color(hue, 0.75) if region.get("open", false) else DIM, 1.5)
		var mid: float = (float(s) + 0.5) / float(count)
		var at: Vector2 = _point(mid)
		var ahead: Vector2 = (_point(mid + 0.003) - _point(mid - 0.003)).normalized()
		var side := Vector2(-ahead.y, ahead.x)
		var lit: float = _lit(regions, mid)
		var chevron := PackedVector2Array([at - ahead * 3.0 + side * 5.0, at + ahead * 3.0, at - ahead * 3.0 - side * 5.0])
		draw_polyline(chevron, Color(1, 1, 1, 0.25 + 0.6 * lit), 2.0, true)


## A light running round the loop: bright on the open road, a faint glint past it.
func _draw_light(regions: Array, t: float) -> void:
	var head: float = fposmod(t * 0.045, 1.0)
	for k: int in range(26, -1, -1):
		var u: float = fposmod(head - float(k) * 0.0028, 1.0)
		var fade: float = 1.0 - float(k) / 27.0
		var strength: float = 0.25 + 0.75 * _lit(regions, u)
		draw_circle(_point(u), 1.0 + 3.2 * fade, Color(_hue(regions, u).lightened(0.3), 0.85 * fade * strength))
	RouteSkin.glow(self, _point(head), Vector2(20, 20), Color(_hue(regions, head), 0.7 * (0.3 + 0.7 * _lit(regions, head))), 8)
	draw_circle(_point(head), 2.2, Color(1, 1, 1, 0.9))


# ---------------------------------------------------------------- the stops

func _draw_stop(regions: Array, k: int, t: float) -> void:
	var region: Dictionary = regions[k]
	var p: Vector2 = _stop(k, regions.size())
	var hue: Color = _color(region)
	var open: bool = bool(region.get("open", false))
	var focused: bool = k == int(model.get("focus", 0))
	var radius: float = NODE_R * (1.18 if focused else 1.0)
	if open:
		RouteSkin.glow(self, p, Vector2(radius * 2.7, radius * 2.7), Color(hue, 0.55))
	# A small planet, lit from the upper left.
	RouteSkin.ellipse(self, p, Vector2(radius, radius), hue.darkened(0.74) if open else Color("#171929"), 48)
	RouteSkin.ellipse(self, p + Vector2(-radius, -radius) * 0.24, Vector2(radius, radius) * 0.62,
		Color(hue.darkened(0.5) if open else Color("#212436"), 0.85), 40)
	_emblem(str(region.get("id", "")), p, radius, Color(INK, 0.95 if open else 0.3))
	RouteSkin.outline(self, RouteSkin.ellipse_points(p, Vector2(radius, radius), 56), hue if open else DIM, 3.0)
	if not open:
		_padlock(p + Vector2(radius, radius) * 0.7)
	if focused:
		var ring: Color = hue if open else MUTED
		var pulse: float = 0.5 + 0.5 * sin(t * 3.2)
		draw_arc(p, radius + 8.0 + 4.0 * pulse, 0.0, TAU, 64, Color(ring, 0.3 + 0.3 * pulse), 2.0, true)
		for q: int in 4:
			var from: float = t * 0.9 + float(q) * TAU / 4.0
			draw_arc(p, radius + 17.0, from, from + 0.6, 12, Color(ring, 0.9), 3.0, true)
	if bool(region.get("start", false)):
		_flag(p + Vector2(-radius * 0.55, -radius - 4.0), hue)
	_label(region, p, open)
	_hits.append([Rect2(p - Vector2(48, 48), Vector2(96, 96)), "node", k])


## Each region's mark on its planet: a dome on the Mars plain, a city skyline, waves under a
## rising moon, a volcano, a ringed world.
func _emblem(id: String, p: Vector2, radius: float, ink: Color) -> void:
	var s: float = radius / NODE_R
	match id:
		"backroads":
			draw_line(p + Vector2(-15, 7) * s, p + Vector2(15, 7) * s, ink, 2.0, true)
			draw_arc(p + Vector2(0, 7) * s, 9.0 * s, PI, TAU, 20, ink, 2.0, true)
			draw_line(p + Vector2(-4, 7) * s, p + Vector2(-4, 0) * s, Color(ink, ink.a * 0.6), 1.5)
			draw_line(p + Vector2(4, 7) * s, p + Vector2(4, 0) * s, Color(ink, ink.a * 0.6), 1.5)
		"neon":
			for bar: Rect2 in [Rect2(-14, -1, 5, 11), Rect2(-8, -10, 6, 20), Rect2(-1, -4, 5, 14), Rect2(5, -13, 6, 23), Rect2(12, 2, 3, 8)]:
				draw_rect(Rect2(p + bar.position * s, bar.size * s), ink)
		"coast":
			draw_arc(p + Vector2(0, 1) * s, 8.0 * s, PI, TAU, 18, ink, 2.0, true)
			for row: float in [3.0, 9.0]:
				var wave := PackedVector2Array()
				for i: int in 13:
					var x: float = -15.0 + 2.5 * float(i)
					wave.append(p + Vector2(x, row + 2.0 * sin(x * 0.55)) * s)
				draw_polyline(wave, ink, 2.0, true)
		"mesa":
			RouteSkin.poly(self, PackedVector2Array([p + Vector2(-15, 10) * s, p + Vector2(-4, -7) * s,
				p + Vector2(4, -7) * s, p + Vector2(15, 10) * s]), ink)
			draw_circle(p + Vector2(0, -11) * s, 2.6 * s, Color(1.0, 0.45, 0.1, ink.a))
			draw_circle(p + Vector2(-4, -15) * s, 1.6 * s, Color(1.0, 0.6, 0.2, ink.a * 0.8))
		"aurora":
			draw_circle(p, 7.0 * s, ink)
			RouteSkin.outline(self, RouteSkin.ellipse_points(p, Vector2(17, 5) * s, 40, -18.0), ink, 2.0)


func _padlock(p: Vector2) -> void:
	draw_arc(p + Vector2(0, -3), 4.0, PI, TAU, 12, MUTED, 2.0, true)
	RouteSkin.box(self, Rect2(p + Vector2(-6, -3), Vector2(12, 9)), MUTED, Color.TRANSPARENT, 0.0, 2.0)


func _flag(foot: Vector2, hue: Color) -> void:
	draw_line(foot, foot + Vector2(0, -22), INK, 2.0, true)
	RouteSkin.poly(self, PackedVector2Array([foot + Vector2(0, -22), foot + Vector2(15, -17), foot + Vector2(0, -12)]), hue)


## Name in the region's own display face, its genres, and how far it has come.
func _label(region: Dictionary, p: Vector2, open: bool) -> void:
	var id: String = str(region.get("id", ""))
	var style: Dictionary = Ui.STYLES.get(id, Ui.STYLES["backroads"])
	var display: Font = RouteSkin.font(str(style["display"][0]), int(style["display"][1]))
	var mono: Font = RouteSkin.font("JetBrains Mono", 600, 1.0)
	var hue: Color = _color(region)
	var lines: Array = [
		[str(region.get("name", "")).to_upper(), display, 25, hue if open else MUTED],
		[str(region.get("genres", "")).to_upper(), mono, 11, MUTED if open else DIM],
		[_status(region), mono, 11, INK if open else DIM],
	]
	var heights: Array[float] = [30.0, 16.0, 16.0]
	var block: float = 62.0
	# The same gap focused or not, clear of the focus ring, so a label never moves or overlaps.
	var gap: float = NODE_R * 1.18 + 34.0
	var align := HORIZONTAL_ALIGNMENT_CENTER
	var left: float = p.x - 160.0
	var width: float = 320.0
	var top: float = p.y - block * 0.5
	var outward: Vector2 = p - CENTER
	if absf(outward.x) < 60.0:
		top = p.y - gap - block if outward.y < 0.0 else p.y + gap
	elif outward.x > 0.0:
		align = HORIZONTAL_ALIGNMENT_LEFT
		left = p.x + gap
		width = DESIGN.x - 12.0 - left
	else:
		align = HORIZONTAL_ALIGNMENT_RIGHT
		width = 300.0
		left = p.x - gap - width
	var y: float = top
	for i: int in lines.size():
		var line: Array = lines[i]
		var f: Font = line[1]
		var value: String = RouteSkin.fit_list(str(line[0]), f, int(line[2]), width) if i == 1 else str(line[0])
		RouteSkin.text(self, Rect2(left, y, width, heights[i]), value, f, int(line[2]), line[3], align)
		y += heights[i]


## The start needs no word here: its flag marks it.
func _status(region: Dictionary) -> String:
	if not bool(region.get("open", false)):
		return "LOCKED"
	return "%d / %d CLEARED" % [int(region.get("cleared", 0)), int(region.get("total", 0))]


# ---------------------------------------------------------------- the centre, header and footer

func _draw_centre(regions: Array) -> void:
	var focus: int = int(model.get("focus", 0))
	var region: Dictionary = regions[focus]
	var id: String = str(region.get("id", ""))
	var style: Dictionary = Ui.STYLES.get(id, Ui.STYLES["backroads"])
	var hue: Color = _color(region)
	var open: bool = bool(region.get("open", false))
	var picking: bool = bool(model.get("picking", false))
	var panel := Rect2(392, 258, 496, 244)
	RouteSkin.box(self, panel, PANEL, Color(hue, 0.4), 1.0, 14.0)
	var mono: Font = RouteSkin.font("JetBrains Mono", 600, 2.0)
	var kicker: String = "ROAD %02d OF %02d" % [focus + 1, regions.size()]
	if bool(region.get("start", false)):
		kicker += "  ·  YOUR START"
	RouteSkin.text(self, Rect2(panel.position.x, 272, panel.size.x, 16), kicker, mono, 12, hue, HORIZONTAL_ALIGNMENT_CENTER)
	var display: Font = RouteSkin.font(str(style["display"][0]), int(style["display"][1]))
	RouteSkin.text(self, Rect2(panel.position.x + 16, 292, panel.size.x - 32, 60), str(region.get("name", "")).to_upper(),
		display, 48, hue if open else INK, HORIZONTAL_ALIGNMENT_CENTER)
	var body: Font = RouteSkin.font(str(style["body"][0]), int(style["body"][1]))
	RouteSkin.text(self, Rect2(panel.position.x + 16, 354, panel.size.x - 32, 22), str(region.get("genres", "")), body, 17,
		INK, HORIZONTAL_ALIGNMENT_CENTER)
	var blurb_font: Font = RouteSkin.font("Space Grotesk", 400)
	RouteSkin.draw_multiline_text(self, blurb_font, Vector2(panel.position.x + 36, 396), str(region.get("blurb", "")),
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 72, 14, 2, MUTED)
	RouteSkin.text(self, Rect2(panel.position.x, 428, panel.size.x, 16),
		"%d SONGS  ·  %d CLEARED" % [int(region.get("total", 0)), int(region.get("cleared", 0))],
		RouteSkin.font("JetBrains Mono", 600, 1.0), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var action := Rect2(panel.position.x + 44, 454, panel.size.x - 88, 32)
	var label: String
	var filled: bool = true
	if picking:
		label = "ENTER  ·  START HERE INSTEAD" if model.get("chosen", false) and not region.get("start", false) else "ENTER  ·  START HERE"
	elif open:
		label = "ENTER  ·  DRIVE THIS ROAD"
	else:
		filled = false
		var needs: int = int(region.get("needs", 0))
		var before: String = str(region.get("prev_name", "")).to_upper()
		label = ("LOCKED  ·  CLEAR %d MORE IN %s" % [needs, before]) if needs > 0 else ("LOCKED  ·  OPEN %s FIRST" % before)
	if filled:
		RouteSkin.box(self, action, hue, Color.TRANSPARENT, 0.0, 16.0)
	else:
		RouteSkin.box(self, action, Color(0, 0, 0, 0), DIM, 1.5, 16.0)
	RouteSkin.text(self, action, label, RouteSkin.font("JetBrains Mono", 700, 1.5), 12, Color("#0A0B16") if filled else MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)
	_hits.append([action, "pick", focus])


func _draw_header() -> void:
	var picking: bool = bool(model.get("picking", false))
	var chosen: bool = bool(model.get("chosen", false))
	RouteSkin.text(self, Rect2(48, 30, 520, 16), "SYNTH HIGHWAY  //  ROUTE CHART", RouteSkin.font("JetBrains Mono", 600, 3.0), 11, MUTED)
	RouteSkin.text(self, Rect2(46, 46, 520, 56), "PICK YOUR ON-RAMP" if picking and not chosen else "THE LOOP",
		RouteSkin.font("Anton"), 44, INK)
	var x: float = 48.0
	for id: String in ["backroads", "neon", "coast", "mesa", "aurora"]:
		draw_rect(Rect2(x, 104, 30, 4), COLORS[id])
		x += 32.0
	var body: Font = RouteSkin.font("Space Grotesk", 500)
	var first: String = "Five roads on one loop, driven clockwise."
	var second: String = "Clear 2 songs on a road to open the next one."
	if picking and chosen:
		first = "Your flag marks your start. Until you clear"
		second = "a song, you can move it to any road."
	elif picking:
		first = "Five roads on one loop. Start on any of them."
	RouteSkin.text(self, Rect2(48, 116, 470, 20), first, body, 15, INK)
	RouteSkin.text(self, Rect2(48, 136, 470, 20), second, body, 15, MUTED)
	# The legend, top right: what the diamonds and the lit road mean.
	var mono: Font = RouteSkin.font("JetBrains Mono", 600, 1.5)
	var right: float = 1232.0
	RouteSkin.text(self, Rect2(right - 300, 34, 300, 16), "EACH CLEAR LIGHTS A DIAMOND", mono, 11, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	RouteSkin.text(self, Rect2(right - 300, 54, 300, 16), "TWO OPEN THE NEXT ROAD", mono, 11, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var lead: float = right - RouteSkin.text_width("EACH CLEAR LIGHTS A DIAMOND", mono, 11) - 26.0
	for j: int in 2:
		var p := Vector2(lead + float(j) * 14.0, 42)
		var diamond := PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)])
		if j == 0:
			RouteSkin.poly(self, diamond, COLORS["neon"])
		else:
			RouteSkin.outline(self, diamond, COLORS["neon"], 1.5)


func _draw_footer() -> void:
	var picking: bool = bool(model.get("picking", false))
	var line: String = "← →  CHOOSE A ROAD      ENTER  %s      %s  BACK" % ["START HERE" if picking else "OPEN ROAD", Ui.back_key()]
	RouteSkin.text(self, Rect2(0, 680, DESIGN.x, 20), line, RouteSkin.font("JetBrains Mono", 600, 1.5), 12, MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)


# ---------------------------------------------------------------- geometry and colour

func _stop(k: int, count: int) -> Vector2:
	return _point(float(k) / float(count))


## A point on the road at loop position u (0 = the first region, clockwise).
func _point(u: float) -> Vector2:
	var angle: float = -PI * 0.5 + fposmod(u, 1.0) * TAU
	return CENTER + Vector2(cos(angle), sin(angle)) * RADII


func _color(region: Dictionary) -> Color:
	return COLORS.get(str(region.get("id", "")), INK)


## The road's colour at u: from one region's colour to the next one's.
func _hue(regions: Array, u: float) -> Color:
	var count: int = regions.size()
	var along: float = fposmod(u, 1.0) * float(count)
	var s: int = int(floor(along)) % count
	var f: float = along - floor(along)
	return _color(regions[s]).lerp(_color(regions[(s + 1) % count]), smoothstep(0.2, 0.8, f))


## How lit the road is at u: open road 1, locked road 0. The stretch out of the last open region
## lights up as far as its clears have paved it (half for one clear of two).
func _lit(regions: Array, u: float) -> float:
	var count: int = regions.size()
	var along: float = fposmod(u, 1.0) * float(count)
	var s: int = int(floor(along)) % count
	var region: Dictionary = regions[s]
	if not bool(region.get("open", false)):
		return 0.0
	if bool((regions[(s + 1) % count] as Dictionary).get("open", false)):
		return 1.0
	var paved: float = float(mini(int(region.get("cleared", 0)), RouteLoop.CLEARS_TO_ADVANCE)) / float(RouteLoop.CLEARS_TO_ADVANCE)
	return 1.0 if along - floor(along) < paved else 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hit_at(event.position).size() > 0 else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var found: Array = _hit_at(event.position)
		if found.size() > 0:
			accept_event()
			acted.emit(found[1], found[2])


func _hit_at(screen_point: Vector2) -> Array:
	var p: Vector2 = (screen_point - _origin) / _scale
	for i: int in range(_hits.size() - 1, -1, -1):
		if (_hits[i][0] as Rect2).has_point(p):
			return _hits[i]
	return []
