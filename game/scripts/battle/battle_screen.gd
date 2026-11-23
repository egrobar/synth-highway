class_name BattleScreen
extends Control
## The battle's screens outside a run (Battle, battle.gd), drawn over the rolling world like the
## title, in the region's style (Ui):
##   "connect":   host a battle, or join one by its lobby code (online) or the host's address (LAN).
##   "lobby":     the code to share, four seats, each racer's song suggestion, the difficulty
##                (the host's to change), and the host's Draw.
##   "standings": after your run, the live order while the others finish, then the final results.
## And the draw's reveal (play_reveal): the suggestions spin and land on the song that will be raced.
##
## Every screen has a Back (or Leave) button in its top-left corner for the mouse, which acts as
## Escape does ("back").
##
## main.gd owns the keys and the network and calls present(model) whenever something changes; this
## only draws, and says what was clicked through `acted`. The models:
##   connect   {"kind", "online": bool, "lan": bool, "input": ""|"code"|"address", "busy": bool, "message"}
##   lobby     {"kind", "code", "transport", "slots": [{"empty", "name", "host", "me", "suggestion"}],
##              "difficulty", "is_host", "can_draw", "draw_note", "ping": int, "message"}
##   standings {"kind", "final": bool, "headline", "rows": [{"place", "name", "score", "detail", "me",
##              "dim"}], "is_host"}

signal acted(action: String, arg: Variant)

const SEATS := 4
const LEVELS: Array[String] = ["easy", "normal", "hard"]

var _content: Control
var _input: LineEdit
var _reveal: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func present(model: Dictionary) -> void:
	if _content:
		_content.queue_free()
	_input = null
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	if _reveal:
		move_child(_reveal, -1)
	match str(model.get("kind", "")):
		"connect":
			_draw_connect(model)
		"lobby":
			_draw_lobby(model)
		"standings":
			_draw_standings(model)


func has_input_focus() -> bool:
	return _input != null and _input.has_focus()


# ---------------------------------------------------------------- connect

func _draw_connect(model: Dictionary) -> void:
	_content.add_child(Ui.dim_panel(0.62))
	_back_button("Back")
	_title("BATTLE", "Race up to three friends through the same song, at the same moment. Highest score wins.")
	_steps(270.0)
	var online: bool = bool(model.get("online", false))
	var rows: Array = []
	if online:
		rows.append(["H", "Host a battle", "Friends join with your lobby code. Everyone signs in with WASD Engine.", "host"])
		rows.append(["J", "Join a battle", "Type the six-letter code the host shares.", "join"])
	elif bool(model.get("lan", false)):
		rows.append(["H", "Host on this network", "Friends on the same Wi-Fi join with your address.", "host"])
		rows.append(["J", "Join by address", "Type the address on the host's screen.", "join"])
	for i: int in rows.size():
		var top: float = 372.0 + i * 118.0
		var card := Ui.card(false)
		Ui.anchor(card, 0.5, 0.0, 0.5, 0.0, -420, top, 420, top + 100)
		_clickable(card, str(rows[i][3]))
		_content.add_child(card)
		var key := Ui.heading(str(rows[i][0]), 46, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(key, 0.0, 0.0, 0.0, 1.0, 10, 14, 90, -14, HORIZONTAL_ALIGNMENT_CENTER)
		card.add_child(key)
		var name := Ui.label(str(rows[i][1]), 32, Ui.TEXT)
		Ui.anchor(name, 0.0, 0.0, 1.0, 0.0, 100, 12, -20, 52)
		card.add_child(name)
		var note := Ui.label(str(rows[i][2]), 21, Ui.MUTED)
		Ui.anchor(note, 0.0, 0.0, 1.0, 0.0, 100, 54, -20, 84)
		card.add_child(note)
	if rows.is_empty():
		_line("Battles need the browser version on WASD Engine, or a desktop build on the same network.", 300.0, 26, Ui.WARM)
	var input: String = str(model.get("input", ""))
	if not input.is_empty():
		_input = LineEdit.new()
		_input.placeholder_text = "LOBBY CODE" if input == "code" else "192.168.1.20"
		_input.max_length = 6 if input == "code" else 40
		_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_input.add_theme_font_override("font", Ui.mono_font())
		_input.add_theme_font_size_override("font_size", 40)
		_input.add_theme_stylebox_override("normal", Ui.card_style(true))
		_input.add_theme_stylebox_override("focus", Ui.card_style(true))
		Ui.anchor(_input, 0.5, 0.0, 0.5, 0.0, -240, 614, 240, 680)
		_input.text_submitted.connect(func(text: String) -> void: acted.emit("submit", text))
		_input.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventKey and e.pressed and (e as InputEventKey).physical_keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				acted.emit("cancel_input", null))
		_content.add_child(_input)
		_input.grab_focus.call_deferred()
		_line("ENTER to join", 688.0, 20, Ui.MUTED)
	var message: String = str(model.get("message", ""))
	if not message.is_empty():
		_line(message, 728.0, 26, Ui.WARM)
	_hint("H  host        J  join        ESC  back" if not rows.is_empty() else "ESC  back")


# ---------------------------------------------------------------- lobby

func _draw_lobby(model: Dictionary) -> void:
	_content.add_child(Ui.dim_panel(0.62))
	_back_button("Leave")
	var heading := Ui.heading("BATTLE LOBBY", 60, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(heading, 0.0, 0.0, 1.0, 0.0, 0, 30, 0, 102, HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(heading)
	var lan: bool = str(model.get("transport", "")) == "lan"
	var code_box := Ui.card(true)
	Ui.anchor(code_box, 0.5, 0.0, 0.5, 0.0, -300, 124, 300, 214)
	code_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(code_box)
	var code_caption := Ui.caption("ADDRESS" if lan else "LOBBY CODE", 18, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(code_caption, 0.0, 0.0, 1.0, 0.0, 0, 8, 0, 30, HORIZONTAL_ALIGNMENT_CENTER)
	code_box.add_child(code_caption)
	var code := Ui.heading(str(model.get("code", "")), 46, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(code, 0.0, 0.0, 1.0, 1.0, 0, 26, 0, -6, HORIZONTAL_ALIGNMENT_CENTER)
	code_box.add_child(code)
	_line("Friends pick Battle, then %s." % ("Join by address and type this" if lan else "Join a battle and type this code"),
		222.0, 22, Ui.MUTED)
	# Four seats in a row: who's in, and the song each put in the draw.
	var slots: Array = model.get("slots", [])
	var seat_w: float = 330.0
	var gap: float = 22.0
	var left: float = -(SEATS * seat_w + (SEATS - 1) * gap) * 0.5
	for i: int in SEATS:
		var slot: Dictionary = slots[i] if i < slots.size() else {"empty": true}
		var x: float = left + i * (seat_w + gap)
		var empty: bool = bool(slot.get("empty", false))
		var seat := Ui.card(bool(slot.get("me", false)))
		Ui.anchor(seat, 0.5, 0.0, 0.5, 0.0, x, 270, x + seat_w, 470)
		seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if empty:
			seat.modulate.a = 0.5
		_content.add_child(seat)
		var tag := Ui.caption("SEAT %d%s%s" % [i + 1, "  ·  HOST" if bool(slot.get("host", false)) else "",
			"  ·  YOU" if bool(slot.get("me", false)) else ""], 17, Ui.ACCENT if not empty else Ui.MUTED)
		Ui.anchor(tag, 0.0, 0.0, 1.0, 0.0, 20, 14, -20, 36)
		seat.add_child(tag)
		var name := Ui.heading("open seat" if empty else str(slot.get("name", "")), 32, Ui.TEXT if not empty else Ui.MUTED)
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		Ui.anchor(name, 0.0, 0.0, 1.0, 0.0, 20, 40, -20, 84)
		seat.add_child(name)
		var pick_caption := Ui.caption("SONG FOR THE DRAW", 16, Ui.MUTED)
		Ui.anchor(pick_caption, 0.0, 0.0, 1.0, 0.0, 20, 104, -20, 124)
		seat.add_child(pick_caption)
		var suggestion: String = str(slot.get("suggestion", ""))
		var pick_text: String = "waiting for a driver" if empty else ("not picked yet" if suggestion.is_empty() else suggestion)
		var pick := Ui.label(pick_text, 24, Ui.WARM if not suggestion.is_empty() else Ui.MUTED)
		pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pick.max_lines_visible = 2
		Ui.anchor(pick, 0.0, 0.0, 1.0, 0.0, 20, 124, -20, 190)
		seat.add_child(pick)
	# The level everyone plays: the host's choice.
	var is_host: bool = bool(model.get("is_host", false))
	_line("EVERYONE PLAYS", 494.0, 18, Ui.MUTED)
	for i: int in LEVELS.size():
		var level: String = LEVELS[i]
		var on: bool = level == str(model.get("difficulty", "normal"))
		var pill := Ui.card(on)
		var px: float = -270.0 + i * 186.0
		Ui.anchor(pill, 0.5, 0.0, 0.5, 0.0, px, 520, px + 170, 574)
		if is_host:
			_clickable(pill, "difficulty", level)
		else:
			pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not on:
				pill.modulate.a = 0.45
		_content.add_child(pill)
		var text := Ui.heading(level.to_upper(), 28, Ui.ACCENT if on else Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(text, 0.0, 0.0, 1.0, 1.0, 0, 8, 0, -8, HORIZONTAL_ALIGNMENT_CENTER)
		pill.add_child(text)
	var buttons: Array = [["S", "Pick your song", "suggest"]]
	if is_host:
		buttons.append(["ENTER", "Draw a song and race", "draw"])
	var button_w: float = 420.0
	var total: float = buttons.size() * button_w + (buttons.size() - 1) * 24.0
	for i: int in buttons.size():
		var bx: float = -total * 0.5 + i * (button_w + 24.0)
		var ready: bool = str(buttons[i][2]) != "draw" or bool(model.get("can_draw", false))
		var button := Ui.card(str(buttons[i][2]) == "draw" and ready)
		Ui.anchor(button, 0.5, 0.0, 0.5, 0.0, bx, 604, bx + button_w, 670)
		_clickable(button, str(buttons[i][2]))
		if not ready:
			button.modulate.a = 0.5
		_content.add_child(button)
		var key := Ui.caption(str(buttons[i][0]), 20, Ui.ACCENT)
		Ui.anchor(key, 0.0, 0.0, 0.0, 1.0, 18, 20, 110, -18)
		button.add_child(key)
		var label := Ui.label(str(buttons[i][1]), 28, Ui.TEXT)
		Ui.anchor(label, 0.0, 0.0, 1.0, 1.0, 104, 12, -16, -12)
		button.add_child(label)
	var note: String = str(model.get("draw_note", ""))
	if is_host and not note.is_empty():
		_line(note, 680.0, 22, Ui.MUTED)
	elif not is_host:
		_line("The host draws one of the picked songs. Everyone races it at the same moment.", 680.0, 22, Ui.MUTED)
	var message: String = str(model.get("message", ""))
	if not message.is_empty():
		_line(message, 716.0, 24, Ui.WARM)
	var ping: int = int(model.get("ping", 0))
	if not is_host and ping >= 0:
		var ping_label := Ui.caption("ping %d ms" % ping, 18, Ui.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		Ui.anchor(ping_label, 1.0, 0.0, 1.0, 0.0, -260, 24, -30, 48, HORIZONTAL_ALIGNMENT_RIGHT)
		_content.add_child(ping_label)
	_hint(("S  pick your song        TAB  difficulty        ENTER  draw        ESC  leave") if is_host
		else "S  pick your song        ESC  leave")


# ---------------------------------------------------------------- standings

func _draw_standings(model: Dictionary) -> void:
	_content.add_child(Ui.dim_panel(0.7))
	_back_button("Leave")
	var final: bool = bool(model.get("final", false))
	var heading := Ui.heading(str(model.get("headline", "")), 76, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(heading, 0.0, 0.0, 1.0, 0.0, 0, 60, 0, 150, HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(heading)
	_line("FINAL STANDINGS" if final else "STILL DRIVING: THE ORDER SO FAR", 156.0, 22, Ui.MUTED)
	var rows: Array = model.get("rows", [])
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		var top: float = 210.0 + i * 112.0
		var card := Ui.card(bool(row.get("me", false)), Ui.WARM if i == 0 and final else Color(0, 0, 0, 0))
		Ui.anchor(card, 0.5, 0.0, 0.5, 0.0, -560, top, 560, top + 96)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if bool(row.get("dim", false)):
			card.modulate.a = 0.6
		_content.add_child(card)
		var place := Ui.heading(str(row.get("place", "")), 52, Ui.WARM if i == 0 else Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(place, 0.0, 0.0, 0.0, 1.0, 10, 12, 150, -10, HORIZONTAL_ALIGNMENT_CENTER)
		card.add_child(place)
		var name := Ui.heading(str(row.get("name", "")), 36, Ui.TEXT)
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		Ui.anchor(name, 0.0, 0.0, 0.0, 0.0, 160, 10, 640, 56)
		card.add_child(name)
		var detail := Ui.label(str(row.get("detail", "")), 22, Ui.MUTED)
		Ui.anchor(detail, 0.0, 0.0, 0.0, 0.0, 160, 56, 760, 86)
		card.add_child(detail)
		var score := Ui.heading(RivalBar._num(int(row.get("score", 0))), 50, Ui.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		Ui.anchor(score, 1.0, 0.0, 1.0, 1.0, -380, 12, -30, -12, HORIZONTAL_ALIGNMENT_RIGHT)
		card.add_child(score)
	if final:
		_hint("ENTER  next race        ESC  leave the battle" if bool(model.get("is_host", false))
			else "The host starts the next race        ESC  leave the battle")
	else:
		_hint("ESC  leave the battle")


# ---------------------------------------------------------------- the draw

## The suggestions spin past and slow onto `chosen`, then the drawn song's title and level hold
## until the run starts. `seconds` is how long it all has.
func play_reveal(titles: Array, chosen: int, title: String, subtitle: String, seconds: float) -> void:
	if _reveal:
		_reveal.queue_free()
	_reveal = Control.new()
	_reveal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reveal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_reveal)
	_reveal.add_child(Ui.dim_panel(0.92))
	var caption := Ui.caption("THE DRAW", 24, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(caption, 0.0, 0.5, 1.0, 0.5, 0, -170, 0, -136, HORIZONTAL_ALIGNMENT_CENTER)
	_reveal.add_child(caption)
	var window := Ui.card(true)
	Ui.anchor(window, 0.5, 0.5, 0.5, 0.5, -520, -110, 520, 10)
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal.add_child(window)
	var spin := Ui.heading("", 64, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	spin.clip_text = true
	spin.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Ui.anchor(spin, 0.0, 0.0, 1.0, 1.0, 20, 12, -20, -12, HORIZONTAL_ALIGNMENT_CENTER)
	window.add_child(spin)
	var level := Ui.heading("", 34, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(level, 0.0, 0.5, 1.0, 0.5, 0, 30, 0, 80, HORIZONTAL_ALIGNMENT_CENTER)
	_reveal.add_child(level)
	var ready := Ui.label("", 30, Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(ready, 0.0, 0.5, 1.0, 0.5, 0, 96, 0, 140, HORIZONTAL_ALIGNMENT_CENTER)
	_reveal.add_child(ready)
	# One title per tick, the ticks stretching out, so the spin lands on the drawn song when its
	# time is up. With one suggestion there is nothing to spin: it shows at once.
	var spin_time: float = minf(seconds * 0.6, 2.2) if titles.size() > 1 else 0.0
	var ticks: int = 14 if titles.size() > 1 else 0
	var start: int = wrapi(chosen - ticks, 0, titles.size())
	var elapsed: float = 0.0
	for i: int in ticks + 1:
		var shown: String = str(titles[wrapi(start + i, 0, titles.size())]).to_upper()
		get_tree().create_timer(elapsed).timeout.connect(func() -> void:
			if is_instance_valid(spin):
				spin.text = shown)
		# The gaps grow so the spin settles: ease-out over the ticks.
		var t0: float = float(i) / maxf(ticks, 1)
		var t1: float = float(i + 1) / maxf(ticks, 1)
		elapsed += spin_time * ((1.0 - pow(1.0 - t1, 2.4)) - (1.0 - pow(1.0 - t0, 2.4))) if ticks > 0 else 0.0
	get_tree().create_timer(spin_time + 0.05).timeout.connect(func() -> void:
		if not is_instance_valid(spin):
			return
		spin.text = title.to_upper()
		spin.add_theme_color_override("font_color", Ui.WARM)
		level.text = subtitle
		ready.text = "Hands on the home row. Get ready to race.")


# ---------------------------------------------------------------- pieces

func _title(text: String, sub: String) -> void:
	var heading := Ui.heading(text, 110, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(heading, 0.0, 0.0, 1.0, 0.0, 0, 58, 0, 188, HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(heading)
	_line(sub, 194.0, 28, Ui.TEXT)


## How a battle goes, in three steps across the screen under the title.
func _steps(top: float) -> void:
	var steps: Array[String] = ["Host, or join a friend", "Everyone picks a song", "One is drawn: race it together"]
	var step_w: float = 340.0
	var gap: float = 40.0
	var left: float = -(steps.size() * step_w + (steps.size() - 1) * gap) * 0.5
	# One band behind all three, so the steps read as a set and not as more lines of text.
	var band := Ui.card(false)
	Ui.anchor(band, 0.5, 0.0, 0.5, 0.0, left - 26, top - 8, -left + 26, top + 62)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(band)
	for i: int in steps.size():
		var x: float = left + i * (step_w + gap)
		var number := Ui.heading(str(i + 1), 40, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(number, 0.5, 0.0, 0.5, 0.0, x, top, x + 44, top + 54, HORIZONTAL_ALIGNMENT_CENTER)
		_content.add_child(number)
		var text := Ui.label(steps[i], 24, Ui.TEXT)
		Ui.anchor(text, 0.5, 0.0, 0.5, 0.0, x + 52, top + 10, x + step_w, top + 48)
		_content.add_child(text)
		if i < steps.size() - 1:
			var arrow := Ui.caption("›", 34, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			Ui.anchor(arrow, 0.5, 0.0, 0.5, 0.0, x + step_w, top + 4, x + step_w + gap, top + 50, HORIZONTAL_ALIGNMENT_CENTER)
			_content.add_child(arrow)


## Back (or Leave) in the top-left corner, for the mouse: it does what Escape does.
func _back_button(text: String) -> void:
	var button := Ui.card(false)
	Ui.anchor(button, 0.0, 0.0, 0.0, 0.0, 32, 28, 252, 82)
	_clickable(button, "back")
	_content.add_child(button)
	var key := Ui.caption(Ui.back_key(), 18, Ui.MUTED)
	Ui.anchor(key, 0.0, 0.0, 1.0, 1.0, 18, 16, -10, -14)
	button.add_child(key)
	var label := Ui.label(text, 26, Ui.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	Ui.anchor(label, 0.0, 0.0, 1.0, 1.0, 0, 8, -20, -8, HORIZONTAL_ALIGNMENT_RIGHT)
	button.add_child(label)


func _line(text: String, top: float, size: int, color: Color) -> void:
	var label := Ui.label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(label, 0.0, 0.0, 1.0, 0.0, 40, top, -40, top + size + 14, HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(label)


func _hint(text: String) -> void:
	var hint := Ui.caption(text.replace("ESC  ", Ui.back_key() + "  "), 22, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(hint, 0.0, 1.0, 1.0, 1.0, 0, -60, 0, -26, HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(hint)


func _clickable(control: Control, action: String, arg: Variant = null) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			acted.emit(action, arg))
