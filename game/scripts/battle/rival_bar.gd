class_name RivalBar
extends Control
## The other racers in a battle run, as a strip of small panels along the top of the screen (Evan,
## 2026-11-23: "we dont necessarily have to show all on one screen ... could do mini view up top as
## like a bar with small panels"). Between your combo and gas (top left) and your score (top right),
## one panel per rival, best first, sliding when places change:
##   - place, name and score, and how far ahead of or behind you they are;
##   - their own highway in miniature (RivalHighway): the same notes, in the fingers' colours, with
##     their keycaps lighting, bursts on their hits and red on their misses, a moment behind the race.
##     (It replaced a mini keyboard of soft white lights: Evan wanted the rivals more visual, "glow and
##     caps but highway alone is fine", 2026-11-23.)
##   - their gas along the bottom edge; OUT OF GAS, FINISHED or LEFT over the road when it applies.
## Under your score, on the same kind of plate: your own place, and your lead over the next racer or
## the gap to the one ahead. Names are cut to NAME_CHARS everywhere (short_name).
## Fed every frame by main.gd from Battle.standings(); it never touches the run. main.gd hands it the
## race's chart and clock (race()) so each rival's road plays the same song at the same moment.

const PANEL_W := 300.0
const PANEL_H := 156.0
const GAP := 16.0
const TOP := 14.0
## The mini highway's place in a panel, under the name and score.
const VIEW := Rect2(6, 46, PANEL_W - 12, PANEL_H - 56)
## Panels glide to a new place over about this long when places change.
const SLIDE := 0.25
const ORDINALS: Array[String] = ["1ST", "2ND", "3RD", "4TH"]
## A name longer than this is cut, with an ellipsis, on the panels and the line under your score alike.
const NAME_CHARS := 12
const LIT := Color(0.94, 0.96, 1.0)
const MISSED := Color(1.0, 0.36, 0.42)

var _panels: Dictionary = {}
var _my_place: Label
var _my_gap: Label
## The race: the chart file and level everyone plays, and the run's song clock (seconds).
var _chart_path: String = ""
var _level: String = "normal"
var _clock: Callable
## Battle items (BattleItems): the rivals' peers in panel order, left to right (1, 2, 3 send to them),
## and whether you are holding an attack (their key badges light up).
var _order: Array[int] = []
var aiming: bool = false


## The race's chart and the run's clock, for the rivals' roads. Before any refresh.
func race(chart_path: String, level: String, clock: Callable) -> void:
	_chart_path = chart_path
	_level = level
	_clock = clock


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Your place sits on a plate like the rivals' panels, so it reads over a busy sky as theirs do.
	var plate := Panel.new()
	var box: StyleBoxFlat = Ui.card_style(false)
	box.bg_color = Color(box.bg_color, 0.9)
	plate.add_theme_stylebox_override("panel", box)
	Ui.anchor(plate, 1.0, 0.0, 1.0, 0.0, -300, 104, -22, 166)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	_my_place = Ui.heading("", 26, Ui.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	Ui.anchor(_my_place, 1.0, 0.0, 1.0, 0.0, -290, 106, -34, 138, HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_my_place)
	_my_gap = Ui.label("", 21, Ui.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	Ui.anchor(_my_gap, 1.0, 0.0, 1.0, 0.0, -290, 135, -34, 162, HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_my_gap)


## A racer's name as the battle HUD shows it: at most NAME_CHARS, then an ellipsis.
static func short_name(name: String) -> String:
	return name if name.length() <= NAME_CHARS else name.left(NAME_CHARS - 1).strip_edges() + "…"


func refresh(delta: float) -> void:
	var rows: Array = Battle.standings()
	var my_row: Dictionary = {}
	var my_place: int = 0
	var rivals: Array = []
	for i: int in rows.size():
		if bool(rows[i]["me"]):
			my_row = rows[i]
			my_place = i
		else:
			rivals.append(rows[i])
	_show_me(rows, my_row, my_place)
	_order.clear()
	for row: Dictionary in rivals:
		_order.append(int(row["peer"]))
	var count: int = rivals.size()
	var span: float = count * PANEL_W + maxf(count - 1, 0) * GAP
	for i: int in count:
		var row: Dictionary = rivals[i]
		var peer: int = int(row["peer"])
		if not _panels.has(peer):
			_panels[peer] = _make_panel(-span * 0.5 + i * (PANEL_W + GAP))
		var place: int = rows.find(row)
		_update_panel(_panels[peer], row, place, int(my_row.get("score", 0)), -span * 0.5 + i * (PANEL_W + GAP), delta)


func _show_me(rows: Array, my_row: Dictionary, place: int) -> void:
	if my_row.is_empty():
		return
	_set_text(_my_place, "%s OF %d" % [ORDINALS[mini(place, 3)], rows.size()])
	var gap_text: String = ""
	var level_with: Dictionary = {}
	for row: Dictionary in rows:
		if not bool(row["me"]) and int(row["score"]) == int(my_row["score"]):
			level_with = row
	if not level_with.is_empty():
		var even: String = str(level_with["name"])
		gap_text = "level with %s" % (even if even.length() <= NAME_CHARS else "the %s" % ORDINALS[rows.find(level_with)].to_lower())
	elif place == 0 and rows.size() > 1:
		gap_text = "ahead by %s" % _num(int(my_row["score"]) - int(rows[1]["score"]))
	elif place > 0:
		# The name when it fits whole; a cut name would be cut twice on screen (panel and here).
		var ahead: String = str(rows[place - 1]["name"])
		gap_text = "%s behind %s" % [_num(int(rows[place - 1]["score"]) - int(my_row["score"])),
			ahead if ahead.length() <= NAME_CHARS else ORDINALS[mini(place - 1, 3)]]
	_set_text(_my_gap, gap_text)


func _make_panel(x: float) -> Dictionary:
	var root := Panel.new()
	var box: StyleBoxFlat = Ui.card_style(false)
	box.bg_color = Color(box.bg_color, 0.92)
	# A soft shadow holds the panel's edge over a bright sky (Ring Road's planet glow, review 2).
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 2)
	root.add_theme_stylebox_override("panel", box)
	Ui.anchor(root, 0.5, 0.0, 0.5, 0.0, x, TOP, x + PANEL_W, TOP + PANEL_H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# The place gets its own column (a 30 px "2ND" ran into the name in the first two-window test).
	var place := Ui.shrink_to_fit(Ui.heading("4TH", 26, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), 64.0, 16)
	place.text = ""
	Ui.anchor(place, 0.0, 0.0, 0.0, 0.0, 6, 6, 74, 40, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(place)
	var name := Ui.label("", 18, Ui.TEXT)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Ui.anchor(name, 0.0, 0.0, 0.0, 0.0, 80, 3, 176, 25)
	root.add_child(name)
	var gap := Ui.caption("", 17, Color(Ui.TEXT, 0.82))
	Ui.anchor(gap, 0.0, 0.0, 0.0, 0.0, 80, 23, 176, 43)
	root.add_child(gap)
	# Sized so a six-figure score fits beside the name in the widest region face.
	var score := Ui.shrink_to_fit(Ui.heading("888,888", 30, Ui.TEXT, HORIZONTAL_ALIGNMENT_RIGHT), PANEL_W - 12.0 - 180.0, 18)
	score.text = "0"
	Ui.anchor(score, 0.0, 0.0, 0.0, 0.0, 180, 2, PANEL_W - 12, 40, HORIZONTAL_ALIGNMENT_RIGHT)
	root.add_child(score)
	# Their road in miniature (RivalHighway), on the race's chart, in a thin frame so it holds its edge
	# against a dark sky (graphics review 2).
	var frame := Panel.new()
	var frame_box := StyleBoxFlat.new()
	frame_box.bg_color = Color(0, 0, 0, 0)
	frame_box.set_border_width_all(1)
	frame_box.border_color = Color(Ui.TEXT, 0.28)
	frame.add_theme_stylebox_override("panel", frame_box)
	Ui.anchor(frame, 0.0, 0.0, 0.0, 0.0, VIEW.position.x - 1, VIEW.position.y - 1, VIEW.end.x + 1, VIEW.end.y + 1)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	var keys := RivalHighway.new()
	Ui.anchor(keys, 0.0, 0.0, 0.0, 0.0, VIEW.position.x, VIEW.position.y, VIEW.end.x, VIEW.end.y)
	root.add_child(keys)
	if not _chart_path.is_empty():
		keys.setup(_chart_path, _level)
		keys.stagger(_panels.size())
	var gas_track := ColorRect.new()
	gas_track.color = Color(1, 1, 1, 0.1)
	Ui.anchor(gas_track, 0.0, 1.0, 1.0, 1.0, 10, -7, -10, -3)
	gas_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gas_track)
	var gas := ColorRect.new()
	gas.anchor_bottom = 1.0
	gas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gas_track.add_child(gas)
	# The key that sends them an item (1, 2, 3 by panel, left to right): over the panel's top-left
	# corner, lit while you hold an attack.
	var key_chip := Panel.new()
	var chip_box := StyleBoxFlat.new()
	chip_box.bg_color = Color(0.03, 0.03, 0.06, 0.95)
	chip_box.set_border_width_all(2)
	chip_box.border_color = Ui.ACCENT
	chip_box.set_corner_radius_all(6)
	key_chip.add_theme_stylebox_override("panel", chip_box)
	Ui.anchor(key_chip, 0.0, 0.0, 0.0, 0.0, -16, -12, 14, 18)
	key_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_text := Ui.caption("", 18, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	key_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.anchor(key_text, 0.0, 0.0, 1.0, 1.0, 0, 0, 0, 0, HORIZONTAL_ALIGNMENT_CENTER)
	key_chip.add_child(key_text)
	root.add_child(key_chip)
	# An item hitting them: its icon on their road, with the time it has left.
	var badge := TextureRect.new()
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	Ui.anchor(badge, 0.0, 0.0, 0.0, 0.0, VIEW.end.x - 44, VIEW.position.y + 4, VIEW.end.x - 4, VIEW.position.y + 44)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	root.add_child(badge)
	# OUT OF GAS, FINISHED or LEFT across their road, which stops where it was.
	var status := Ui.heading("", 20, Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.anchor(status, 0.0, 0.0, 0.0, 0.0, VIEW.position.x, VIEW.position.y, VIEW.end.x, VIEW.end.y, HORIZONTAL_ALIGNMENT_CENTER)
	status.add_theme_constant_override("outline_size", 6)
	status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	status.visible = false
	root.add_child(status)
	return {"root": root, "keys": keys, "place": place, "name": name, "score": score, "gap": gap, "gas": gas,
		"status": status, "at": -1, "x": x, "key_chip": key_chip, "key_text": key_text, "badge": badge,
		"item": "", "item_left": 0.0}


func _update_panel(p: Dictionary, row: Dictionary, place: int, my_score: int, target_x: float, delta: float) -> void:
	var entry: Dictionary = Battle.live.get(int(row["peer"]), {})
	var state: int = int(row["state"])
	_set_text(p["place"], ORDINALS[mini(place, 3)])
	var name_label: Label = p["name"]
	var shown_name: String = short_name(str(row["name"]))
	if name_label.text != shown_name:
		name_label.text = shown_name
		# A long name steps down a size or two before it is cut.
		name_label.add_theme_font_size_override("font_size", 18)
		Ui.shrink_to_fit(name_label, 94.0, 13)
	_set_text(p["score"], _num(int(row["score"])))
	var lead: int = int(row["score"]) - my_score
	_set_text(p["gap"], ("+" if lead > 0 else ("−" if lead < 0 else "±")) + _short(absi(lead)))
	(p["gap"] as Label).add_theme_color_override("font_color", Ui.WARM if lead > 0 else Color(Ui.TEXT, 0.82))
	# Places change: the panel glides to its new slot instead of jumping.
	var x: float = lerpf(float(p["x"]), target_x, clampf(delta / SLIDE * 3.0, 0.0, 1.0))
	if absf(x - target_x) < 0.5:
		x = target_x
	p["x"] = x
	var root: Panel = p["root"]
	root.offset_left = x
	root.offset_right = x + PANEL_W
	# Their road: each new report lands its hits and misses, and it plays on with the race's clock.
	var view: RivalHighway = p["keys"]
	var race_now: float = float(_clock.call()) if _clock.is_valid() else 0.0
	if int(entry.get("at", -1)) != int(p["at"]):
		p["at"] = int(entry.get("at", -1))
		view.report(int(entry.get("hit_lanes", 0)), int(entry.get("miss_lanes", 0)), int(entry.get("hits", 0)), race_now)
	if state == Battle.STATE_DRIVING:
		view.advance(race_now, delta)
	else:
		view.freeze()
	# Their key, and an item hitting them: its icon, and their road shaking, swaying or dark to match.
	var slot: int = _order.find(int(row["peer"]))
	_set_text(p["key_text"], str(slot + 1) if slot >= 0 and slot < 3 else "")
	(p["key_chip"] as Control).visible = slot >= 0 and slot < 3 and state == Battle.STATE_DRIVING
	(p["key_chip"] as Control).modulate.a = 1.0 if aiming else 0.45
	var badge: TextureRect = p["badge"]
	var item: String = str(p["item"])
	p["item_left"] = maxf(float(p["item_left"]) - delta, 0.0)
	var hit_on: bool = not item.is_empty() and float(p["item_left"]) > 0.0
	badge.visible = hit_on
	view.position = VIEW.position
	view.modulate = Color.WHITE
	if hit_on:
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		badge.modulate.a = 0.7 + 0.3 * sin(t * 8.0)
		match item:
			"quake":
				view.position += Vector2(randf_range(-2.0, 2.0), absf(sin(t * 10.5)) * -3.0)
			"wobble":
				view.position.x += sin(t * 1.4) * 4.0
			"blackout":
				view.modulate = Color(0.25, 0.25, 0.3)
			"disco":
				view.modulate = Color.from_hsv(fmod(t * 0.7, 1.0), 0.35, 1.0)
	var fuel: float = clampf(float(entry.get("fuel", 1.0)), 0.0, 1.0)
	var gas: ColorRect = p["gas"]
	gas.anchor_right = fuel
	gas.color = Color(1.0, 0.3, 0.3) if fuel < 0.3 else Color(1.0, 0.76, 0.32)
	var status: Label = p["status"]
	var words: String = {Battle.STATE_OUT: "OUT OF GAS", Battle.STATE_DONE: "FINISHED", Battle.STATE_LEFT: "LEFT"}.get(state, "")
	status.visible = not words.is_empty()
	_set_text(status, words)
	status.add_theme_color_override("font_color", Color(MISSED, 0.9) if state == Battle.STATE_OUT else Ui.TEXT)
	# A racer who's out, finished or gone steps back, so the eye goes to the ones still racing.
	var dim: float = 1.0 if words.is_empty() else 0.4
	for child: Node in root.get_children():
		if child != status and child is CanvasItem:
			(child as CanvasItem).modulate.a = dim


## The rival that key 1, 2 or 3 (`index` 0 to 2) sends to: their panel's, left to right, or the last
## panel's when there are fewer rivals. 0 when that rival is out of the race.
func target_peer(index: int) -> int:
	if _order.is_empty():
		return 0
	var peer: int = _order[mini(index, _order.size() - 1)]
	var entry: Dictionary = Battle.live.get(peer, {})
	return peer if int(entry.get("state", Battle.STATE_LEFT)) == Battle.STATE_DRIVING else 0


## An item is hitting this rival: its icon on their panel for its time (a moment for one at once).
func show_item(peer: int, item: String) -> void:
	if not _panels.has(peer):
		return
	var p: Dictionary = _panels[peer]
	p["item"] = item
	p["item_left"] = maxf(BattleItems.seconds(item), 1.5)
	(p["badge"] as TextureRect).texture = BattleItems.icon(item)


## Their Shield took it: the badge goes.
func clear_item(peer: int) -> void:
	if _panels.has(peer):
		(_panels[peer] as Dictionary)["item_left"] = 0.0


## Labels re-shape their text on every assignment; most frames nothing changed.
func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


## 12,480.
static func _num(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## 380, 1.2k, 15k: the gap under a panel's place has room for four characters.
static func _short(n: int) -> String:
	if n < 1000:
		return str(n)
	if n < 10000:
		return "%.1fk" % (n / 1000.0)
	return "%dk" % (n / 1000)
