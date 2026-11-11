class_name MenuOverlay
extends Control
## A small menu drawn over whatever is on screen: the pause menu in a drive, and
## the Escape menu on the title and route screens.
##
## ↑ ↓ choose, Enter picks, Escape picks the cancel action; every item can also
## have its own shortcut key, and the mouse hovers and clicks. The owner passes
## keys in through handle_key() while the menu is open, so nothing behind it
## reacts to them.

const ROW_WIDTH := 460.0
const ROW_HEIGHT := 58.0
const ROW_GAP := 12.0

var _items: Array[Dictionary] = []
var _rows: Array[Panel] = []
var _index: int = 0
var _accent: Color = Ui.ACCENT
var _cancel: Callable
var _on_move: Callable


## items: [{"text": "Resume", "key": KEY_SPACE, "key_text": "SPACE", "action": Callable}, ...]
func setup(title: String, items: Array[Dictionary], cancel: Callable, accent: Color = Ui.ACCENT,
		note: String = "", on_move: Callable = Callable()) -> MenuOverlay:
	_items = items
	_cancel = cancel
	_accent = accent
	_on_move = on_move
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Dark enough, and on a solid card, that the busy screen behind never reads through it.
	add_child(Ui.dim_panel(0.82))
	var block: float = items.size() * (ROW_HEIGHT + ROW_GAP) - ROW_GAP
	var top: float = -block * 0.5 + 40.0
	# The region's own panel (Ui.STYLES): its corners, border and fill, made nearly opaque.
	var card := Panel.new()
	var card_box: StyleBoxFlat = Ui.card_style(false)
	card_box.bg_color = Color(card_box.bg_color, 0.97)
	card.add_theme_stylebox_override("panel", card_box)
	var bottom: float = top + block + (74.0 if not note.is_empty() else 34.0)
	Ui.anchor(card, 0.5, 0.5, 0.5, 0.5, -ROW_WIDTH * 0.5 - 40.0, top - 140.0, ROW_WIDTH * 0.5 + 40.0, bottom)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var heading := Ui.heading(title, 64, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(heading, 0.0, 0.5, 1.0, 0.5, 0, top - 120.0, 0, top - 36.0, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(heading)
	for i: int in items.size():
		var y: float = top + i * (ROW_HEIGHT + ROW_GAP)
		var row := Panel.new()
		Ui.anchor(row, 0.5, 0.5, 0.5, 0.5, -ROW_WIDTH * 0.5, y, ROW_WIDTH * 0.5, y + ROW_HEIGHT)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var text := Ui.label(str(items[i]["text"]), 30, Ui.TEXT)
		Ui.anchor(text, 0.0, 0.0, 1.0, 1.0, 24, 8, -110, -8)
		row.add_child(text)
		if items[i].has("key_text"):
			var key := Ui.caption(str(items[i]["key_text"]), 20, Ui.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
			Ui.anchor(key, 0.0, 0.0, 1.0, 1.0, 0, 16, -22, -14, HORIZONTAL_ALIGNMENT_RIGHT)
			row.add_child(key)
		row.mouse_entered.connect(_select.bind(i))
		row.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_activate(i))
		add_child(row)
		_rows.append(row)
	if not note.is_empty():
		var footer := Ui.label(note, 22, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(footer, 0.0, 0.5, 1.0, 0.5, 0, top + block + 22.0, 0, top + block + 56.0, HORIZONTAL_ALIGNMENT_CENTER)
		add_child(footer)
	_refresh()
	return self


## Every key goes here while the menu is open. Returns true: an open menu swallows all keys.
func handle_key(code: Key) -> bool:
	match code:
		KEY_UP:
			_select(wrapi(_index - 1, 0, _items.size()))
		KEY_DOWN:
			_select(wrapi(_index + 1, 0, _items.size()))
		KEY_ENTER, KEY_KP_ENTER:
			_activate(_index)
		KEY_ESCAPE:
			_cancel.call()
		_:
			for i: int in _items.size():
				if _items[i].get("key", KEY_NONE) == code:
					_activate(i)
					break
	return true


func _select(i: int) -> void:
	if i == _index:
		return
	_index = i
	if _on_move.is_valid():
		_on_move.call()
	_refresh()


func _activate(i: int) -> void:
	var action: Callable = _items[i]["action"]
	action.call()


func _refresh() -> void:
	for i: int in _rows.size():
		var on: bool = i == _index
		_rows[i].add_theme_stylebox_override("panel", Ui.card_style(on, _accent))
