class_name RivalBar
extends Control
## The other racers in a battle run, as a strip of small panels along the top of the screen (Evan,
## 2026-11-23: "we dont necessarily have to show all on one screen ... could do mini view up top as
## like a bar with small panels"). Between your combo and gas (top left) and your score (top right),
## one panel per rival, best first, sliding when places change:
##   - place, name and score, and how far ahead of or behind you they are;
##   - a mini keyboard: their ten home keys and the nine sharps above them, lighting as they hit and
##     red where they miss; a glance says whether a rival is on fire or falling apart. One soft white,
##     not the fingers' colours: those belong to your own notes, and a rainbow strip above the road
##     kept pulling the eye off it (graphics review of the 4-player test, 2026-11-23);
##   - their gas along the bottom edge; OUT OF GAS, FINISHED or LEFT over the panel when it applies.
## Under your score, on the same kind of plate: your own place, and your lead over the next racer or
## the gap to the one ahead. Names are cut to NAME_CHARS everywhere (short_name).
## Fed every frame by main.gd from Battle.standings(); it never touches the run.

const PANEL_W := 290.0
const PANEL_H := 74.0
const GAP := 16.0
const TOP := 14.0
## A key's light fades over this long after a hit or a miss arrives.
const FLASH := 0.45
const PILL_W := 17.0
const PILL_H := 9.0
const PILL_GAP := 4.0
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
	var place := Ui.heading("", 24, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(place, 0.0, 0.0, 0.0, 0.0, 6, 8, 66, 40, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(place)
	var name := Ui.label("", 17, Ui.MUTED)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Ui.anchor(name, 0.0, 0.0, 0.0, 0.0, 76, 9, 176, 33)
	root.add_child(name)
	var score := Ui.heading("0", 28, Ui.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	Ui.anchor(score, 0.0, 0.0, 0.0, 0.0, 150, 1, PANEL_W - 12, 35, HORIZONTAL_ALIGNMENT_RIGHT)
	root.add_child(score)
	var gap := Ui.caption("", 15, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(gap, 0.0, 0.0, 0.0, 0.0, 4, 44, 68, 64, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(gap)
	# The mini keyboard: home keys along the bottom, sharps above and between them, as on a keyboard.
	var keys := Control.new()
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width: float = KeyMap.COUNT * PILL_W + (KeyMap.COUNT - 1) * PILL_GAP
	Ui.anchor(keys, 0.0, 0.0, 0.0, 0.0, PANEL_W - 12 - width, 38, PANEL_W - 12, 38 + PILL_H * 2 + 5)
	root.add_child(keys)
	var pills: Array[ColorRect] = []
	for lane: int in KeyMap.COUNT + KeyMap.SHARPS.size():
		var pill := ColorRect.new()
		var sharp: bool = KeyMap.is_sharp(lane)
		var i: int = lane - KeyMap.SHARP_BASE if sharp else lane
		var px: float = i * (PILL_W + PILL_GAP) + ((PILL_W + PILL_GAP) * 0.5 if sharp else 0.0)
		pill.position = Vector2(px + (3.0 if sharp else 0.0), 0.0 if sharp else PILL_H + 5.0)
		pill.size = Vector2(PILL_W - (6.0 if sharp else 0.0), PILL_H - (2.0 if sharp else 0.0))
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keys.add_child(pill)
		pills.append(pill)
	var gas_track := ColorRect.new()
	gas_track.color = Color(1, 1, 1, 0.1)
	Ui.anchor(gas_track, 0.0, 1.0, 1.0, 1.0, 10, -6, -10, -3)
	gas_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gas_track)
	var gas := ColorRect.new()
	gas.anchor_bottom = 1.0
	gas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gas_track.add_child(gas)
	# OUT OF GAS, FINISHED or LEFT takes the mini keyboard's place: over the name and score it hid them.
	var status := Ui.heading("", 20, Ui.WARM, HORIZONTAL_ALIGNMENT_RIGHT)
	Ui.anchor(status, 0.0, 0.0, 0.0, 0.0, 70, 34, PANEL_W - 12, 64, HORIZONTAL_ALIGNMENT_RIGHT)
	status.visible = false
	root.add_child(status)
	return {"root": root, "keys": keys, "place": place, "name": name, "score": score, "gap": gap, "pills": pills, "gas": gas,
		"status": status, "glow": PackedFloat32Array(), "miss": PackedFloat32Array(), "at": -1, "x": x}


func _update_panel(p: Dictionary, row: Dictionary, place: int, my_score: int, target_x: float, delta: float) -> void:
	var entry: Dictionary = Battle.live.get(int(row["peer"]), {})
	var state: int = int(row["state"])
	_set_text(p["place"], ORDINALS[mini(place, 3)])
	_set_text(p["name"], short_name(str(row["name"])))
	_set_text(p["score"], _num(int(row["score"])))
	var lead: int = int(row["score"]) - my_score
	_set_text(p["gap"], ("+" if lead > 0 else ("−" if lead < 0 else "±")) + _short(absi(lead)))
	(p["gap"] as Label).add_theme_color_override("font_color", Ui.WARM if lead > 0 else Ui.MUTED)
	# Places change: the panel glides to its new slot instead of jumping.
	var x: float = lerpf(float(p["x"]), target_x, clampf(delta / SLIDE * 3.0, 0.0, 1.0))
	if absf(x - target_x) < 0.5:
		x = target_x
	p["x"] = x
	var root: Panel = p["root"]
	root.offset_left = x
	root.offset_right = x + PANEL_W
	# A new state message lights the keys it reports; the light fades between messages.
	var glow: PackedFloat32Array = p["glow"]
	var miss: PackedFloat32Array = p["miss"]
	var pills: Array[ColorRect] = p["pills"]
	if glow.is_empty():
		glow.resize(pills.size())
		miss.resize(pills.size())
	if int(entry.get("at", -1)) != int(p["at"]):
		p["at"] = int(entry.get("at", -1))
		for lane: int in pills.size():
			if int(entry.get("hit_lanes", 0)) & (1 << lane):
				glow[lane] = 1.0
			if int(entry.get("miss_lanes", 0)) & (1 << lane):
				miss[lane] = 1.0
	for lane: int in pills.size():
		glow[lane] = maxf(glow[lane] - delta / FLASH, 0.0)
		miss[lane] = maxf(miss[lane] - delta / FLASH, 0.0)
		var lit: Color = Color(LIT, 0.13).lerp(Color(LIT, 0.8), glow[lane])
		pills[lane].color = lit.lerp(MISSED, miss[lane])
	p["glow"] = glow
	p["miss"] = miss
	var fuel: float = clampf(float(entry.get("fuel", 1.0)), 0.0, 1.0)
	var gas: ColorRect = p["gas"]
	gas.anchor_right = fuel
	gas.color = Color(1.0, 0.3, 0.3) if fuel < 0.3 else Color(1.0, 0.76, 0.32)
	var status: Label = p["status"]
	var words: String = {Battle.STATE_OUT: "OUT OF GAS", Battle.STATE_DONE: "FINISHED", Battle.STATE_LEFT: "LEFT"}.get(state, "")
	status.visible = not words.is_empty()
	(p["keys"] as Control).visible = words.is_empty()
	_set_text(status, words)
	status.add_theme_color_override("font_color", MISSED if state == Battle.STATE_OUT else Ui.TEXT)
	# A racer who's out, finished or gone steps back, so the eye goes to the ones still racing.
	var dim: float = 1.0 if words.is_empty() else 0.4
	for child: Node in root.get_children():
		if child != status and child is CanvasItem:
			(child as CanvasItem).modulate.a = dim


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
