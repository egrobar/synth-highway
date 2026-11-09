extends Node
## Game flow: title → the route (regions and their songs on one screen) → drive →
## results; plus the timing check and loading your own song. The selected region's
## world keeps rolling behind every screen.
##
## The route screen shows everything at once: a strip of regions along the top,
## the selected region's songs in the middle, and the selected song's details on
## the right. Regions unlock in order: clearing any song in one opens the next.
##
## Options for automated checks, passed after "--" on the command line:
##   --bot=perfect|tapper|sloppy|afk  --song=<id>  --difficulty=easy|normal
##       play a song with a bot through the real input path (add --fast for headless, no audio)
##   --muted                silence output (timing still runs on the real device)
##   --shots=DIR [--shot-at=SECONDS]   screenshots during a real-time bot run
##   --screen=title|route --shot=PATH [--region=<id>] [--song=<id>]   capture a screen and quit
##   --import-file=PATH [--import-title=...] [--region=<id>]   run an import without the file picker
##   --unlock-all           open every region

enum Screen { TITLE, ROUTE, IMPORT, CALIBRATE, PLAYING, RESULTS }

const CALIBRATE_CLICKS := 12
const CALIBRATE_INTERVAL := 0.6
const CALIBRATE_SKIP := 2
const SHOT_TIMES: Array[float] = [-1.0, 9.0, 12.2, 33.0, 60.0]
const SFX_NAMES: Array[String] = ["click", "wrong", "ui", "held", "out_of_gas"]
const SONG_ROWS := 7
const ROW_HEIGHT := 62.0
const LIST_TOP := 196.0
const AUDIO_FILTERS := "*.mp3, *.wav, *.flac, *.ogg, *.aiff, *.aif, *.mid, *.midi ; Songs (audio or MIDI)"

var _screen: Screen = Screen.TITLE
var _stage: Stage
var _ambient: AudioStreamPlayer
var _ambient_theme: String = ""
var _sfx: Dictionary = {}
var _save: SaveData
var _session: PlaySession
var _ui: CanvasLayer
var _options: Dictionary = {}
var _shot_index: int = 0

var _regions: Array[Dictionary] = []
var _region_index: int = 0
var _song_choice: Dictionary = {}
var _songs: Array[Dictionary] = []
var _difficulty: String = "normal"
var _current_song: Dictionary = {}
var _remove_armed_until: int = 0

var _importer: SongImporter
var _import_title: LineEdit
var _import_regions: OptionButton
var _import_file: String = ""
var _import_status: Label
var _import_bar: ColorRect
var _import_dir: String = ""

var _calib_next: int = 0
var _calib_start_usec: int = 0
var _calib_fired: Array[int] = []
var _calib_taps: Array[int] = []
var _calib_status: Label
var _calib_done: bool = false
var _toast: Label


func _ready() -> void:
	_parse_args()
	_save = SaveData.load_or_new()
	_load_regions()
	_stage = Stage.new()
	add_child(_stage)
	_build_audio()
	_ui = CanvasLayer.new()
	add_child(_ui)
	_importer = SongImporter.new()
	add_child(_importer)
	_importer.progressed.connect(_on_import_progress)
	_importer.finished.connect(_on_import_finished)
	_importer.failed.connect(_on_import_failed)
	if _options.has("muted"):
		AudioServer.set_bus_mute(0, true)
	if _options.has("region"):
		_region_index = maxi(0, _region_ids().find(str(_options["region"])))
	if _options.has("difficulty"):
		_difficulty = str(_options["difficulty"])
	if _options.has("bot"):
		_start_run(SongLibrary.find(str(_options.get("song", "county_line"))))
		if _options.has("fast"):
			var result: Dictionary = _session.run_to_end_headless()
			print("RESULT ", JSON.stringify(result))
			get_tree().quit()
		return
	if _options.has("import-file"):
		_show_route()
		_begin_import(str(_options["import-file"]), str(_options.get("import-title", "")), _regions[_region_index]["id"])
		return
	if _options.has("song"):
		_select_song_id(str(_options["song"]))
	if str(_options.get("screen", "title")) == "route":
		_show_route()
	else:
		_show_title()


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		_options[parts[0]] = parts[1] if parts.size() > 1 else true


func _load_regions() -> void:
	for id: String in Stage.region_ids():
		if ResourceLoader.exists("res://scripts/themes/%s.gd" % id):
			_regions.append(Stage.region_info(id))
	_regions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 99)) < int(b.get("order", 99)))


func _region_ids() -> Array:
	return _regions.map(func(r: Dictionary) -> String: return r["id"])


func _build_audio() -> void:
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = -9.0
	add_child(_ambient)
	for sfx_name: String in SFX_NAMES:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/sfx_%s.wav" % sfx_name)
		add_child(player)
		_sfx[sfx_name] = player


func _show_world(theme: String) -> void:
	_stage.show_region(theme)
	_play_ambience(theme)


func _play_ambience(theme: String) -> void:
	if theme == _ambient_theme or _options.has("fast"):
		return
	_ambient_theme = theme
	var path: String = "res://assets/themes/%s/audio/ambience.wav" % theme
	if not ResourceLoader.exists(path):
		_ambient.stop()
		return
	var stream: AudioStreamWAV = load(path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
	_ambient.stream = stream
	_ambient.play()


func _process(_delta: float) -> void:
	if _screen == Screen.CALIBRATE:
		_tick_calibration()
	elif _screen == Screen.PLAYING and _options.has("shots"):
		_take_due_shots()
	if _options.has("shot") and not _options.has("import-file") and Time.get_ticks_msec() > 4000:
		_save_shot(str(_options["shot"]))
		get_tree().quit()


func _input(event: InputEvent) -> void:
	# The import form has a text box, so Escape is caught before the box can swallow it.
	if _screen == Screen.IMPORT and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_importer.cancel()
		_show_route()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo or not event.pressed:
		return
	var code: Key = (event as InputEventKey).physical_keycode
	match _screen:
		Screen.TITLE:
			if code == KEY_SPACE or code == KEY_ENTER:
				_click()
				_show_route()
			elif code == KEY_C:
				_click()
				_show_calibration()
		Screen.ROUTE:
			_route_key(code)
		Screen.CALIBRATE:
			if code == KEY_ESCAPE:
				_show_title()
			elif code == KEY_SPACE and not _calib_done:
				_calib_taps.append(Time.get_ticks_usec())
		Screen.RESULTS:
			if code == KEY_ENTER:
				_click()
				_drive_next()
			elif code == KEY_SPACE:
				_click()
				_start_run(_current_song)
			elif code == KEY_ESCAPE:
				_click()
				_show_route()


func _click() -> void:
	(_sfx["ui"] as AudioStreamPlayer).play()


func _clear_ui() -> void:
	for child: Node in _ui.get_children():
		child.queue_free()
	_toast = null


func _end_session() -> void:
	if _session:
		_session.queue_free()
		_session = null


func _region_unlocked(index: int) -> bool:
	if index <= 0 or _options.has("unlock-all"):
		return true
	for song: Dictionary in SongLibrary.in_region(_regions[index - 1]["id"]):
		if _save.cleared(song["id"]):
			return true
	return false


func _accent(region: Dictionary) -> Color:
	return Ui.color_from_hex(str(region.get("accent", "#3fd8ff")))


func _hint(text: String) -> void:
	var hint := Ui.label(text, 24, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(hint, 0.0, 1.0, 1.0, 1.0, 0, -60, 0, -26, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(hint)


func _show_toast(text: String) -> void:
	if _toast and is_instance_valid(_toast):
		_toast.queue_free()
	_toast = Ui.label(text, 26, Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(_toast, 0.0, 1.0, 1.0, 1.0, 0, -104, 0, -70, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(_toast)


## Calls `action` when the control is clicked with the left button.
func _on_click(control: Control, action: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			action.call())


# ---------------------------------------------------------------- title

func _show_title() -> void:
	_end_session()
	_clear_ui()
	_screen = Screen.TITLE
	_show_world(_regions[_region_index]["id"])
	_ambient.volume_db = -9.0
	_ui.add_child(Ui.dim_panel(0.3))
	var logo := Ui.image("res://assets/textures/logo.png")
	Ui.anchor(logo, 0.5, 0.0, 0.5, 0.0, -500, 40, 500, 300)
	_ui.add_child(logo)
	var line := Ui.label("A night drive in five regions, played on your keyboard's home row.", 32, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(line, 0.0, 0.0, 1.0, 0.0, 0, 300, 0, 348, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(line)
	_ui.add_child(_home_row_guide(400.0))
	_hint("SPACE  start        C  timing check")


## The ten keys, as they sit under your hands: fingers rest on A S D F and J K L ;,
## the index fingers reach for G and H, and F and J have the bumps.
func _home_row_guide(top: float) -> Control:
	var box := Control.new()
	Ui.anchor(box, 0.5, 0.0, 0.5, 0.0, -460, top, 460, top + 230)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap: float = 80.0
	var gap: float = 8.0
	var start: float = 460.0 - (cap * 10.0 + gap * 9.0) * 0.5
	for lane: int in KeyMap.COUNT:
		var reach: bool = KeyMap.REACH.has(lane)
		var key := Ui.card(not reach, Ui.ACCENT if not reach else Color(1, 1, 1, 0.2))
		var x: float = start + lane * (cap + gap)
		Ui.anchor(key, 0.0, 0.0, 0.0, 0.0, x, 40, x + cap, 40 + cap)
		var letter := Ui.label(KeyMap.label_for(lane), 40, Ui.TEXT if not reach else Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(letter, 0.0, 0.0, 1.0, 1.0, 0, 12, 0, -10, HORIZONTAL_ALIGNMENT_CENTER)
		key.add_child(letter)
		if KeyMap.HOMING.has(lane):
			var bump := ColorRect.new()
			bump.color = Ui.ACCENT
			Ui.anchor(bump, 0.5, 1.0, 0.5, 1.0, -14, -14, 14, -10)
			key.add_child(bump)
		box.add_child(key)
	var left := Ui.label("LEFT HAND RESTS HERE", 20, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(left, 0.0, 0.0, 0.0, 0.0, start, 4, start + cap * 4 + gap * 3, 34, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(left)
	var right_x: float = start + 6 * (cap + gap)
	var right := Ui.label("RIGHT HAND RESTS HERE", 20, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(right, 0.0, 0.0, 0.0, 0.0, right_x, 4, right_x + cap * 4 + gap * 3, 34, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(right)
	var note := Ui.label("Index fingers reach for G and H. Easy never uses them. Your hands stay put for every song.", 24, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(note, 0.0, 0.0, 1.0, 0.0, -100, 140, 100, 176, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(note)
	var sharps := Ui.label("On Normal, sharps arrive in orange: play them on the row above, W E R T Y U I O P, between the home keys.", 24, Color(1.0, 0.62, 0.25), HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(sharps, 0.0, 0.0, 1.0, 0.0, -140, 178, 140, 214, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(sharps)
	return box


# ---------------------------------------------------------------- the route

func _select_song_id(song_id: String) -> void:
	var song: Dictionary = SongLibrary.find(song_id)
	if song.is_empty():
		return
	_region_index = maxi(0, _region_ids().find(song["theme"]))
	_song_choice[song["theme"]] = song_id


func _selected_index() -> int:
	var chosen: String = str(_song_choice.get(_regions[_region_index]["id"], ""))
	for i: int in _songs.size():
		if _songs[i]["id"] == chosen:
			return i
	return 0


func _choose_song(index: int) -> void:
	if _songs.is_empty():
		return
	_song_choice[_regions[_region_index]["id"]] = _songs[clampi(index, 0, _songs.size() - 1)]["id"]


func _show_route(message: String = "") -> void:
	_end_session()
	_clear_ui()
	_screen = Screen.ROUTE
	var region: Dictionary = _regions[_region_index]
	var accent: Color = _accent(region)
	var unlocked: bool = _region_unlocked(_region_index)
	_show_world(region["id"])
	_ambient.volume_db = -9.0
	_songs = SongLibrary.in_region(region["id"])
	_ui.add_child(Ui.dim_panel(0.4))

	# Regions along the top. The world behind always shows the selected one.
	var count: int = _regions.size()
	var tab_w: float = 270.0
	var gap: float = 14.0
	var left: float = -(count * tab_w + (count - 1) * gap) * 0.5
	for i: int in count:
		_ui.add_child(_region_tab(i, left + i * (tab_w + gap), tab_w))
	var about_text: String = "%s   ·   %s" % [region.get("genres", ""), region.get("blurb", "")]
	if not unlocked:
		about_text = "Locked: clear any song in %s to open this road." % _regions[_region_index - 1]["name"]
	var about := Ui.label(about_text, 24, Ui.TEXT if unlocked else Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(about, 0.0, 0.0, 1.0, 0.0, 0, 128, 0, 160, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(about)

	# The region's songs on the left, the selected song in detail on the right.
	var selected: int = _selected_index()
	var first: int = clampi(selected - SONG_ROWS / 2, 0, maxi(0, _songs.size() - SONG_ROWS))
	var shown: int = 0
	for row: int in range(first, mini(first + SONG_ROWS, _songs.size())):
		_ui.add_child(_song_row(row, row == selected, LIST_TOP + shown * (ROW_HEIGHT + 8.0), accent, unlocked))
		shown += 1
	if _songs.is_empty():
		var empty := Ui.label("No songs here yet.", 30, Ui.TEXT)
		Ui.anchor(empty, 0.5, 0.0, 0.5, 0.0, -720, LIST_TOP + 12, 0, LIST_TOP + 56)
		_ui.add_child(empty)
	var load_y: float = LIST_TOP + maxi(shown, 1) * (ROW_HEIGHT + 8.0) + 6.0
	var load_row := Ui.card(false, accent)
	Ui.anchor(load_row, 0.5, 0.0, 0.5, 0.0, -720, load_y, -80, load_y + 54)
	var load_label := Ui.label("+  Load your own song (L)", 26, Ui.ACCENT)
	Ui.anchor(load_label, 0.0, 0.0, 1.0, 1.0, 22, 10, 0, -8)
	load_row.add_child(load_label)
	_on_click(load_row, _open_file_picker)
	_ui.add_child(load_row)
	if not _songs.is_empty():
		_ui.add_child(_song_detail(_songs[selected], accent, unlocked))
	_hint("← →  region      ↑ ↓  song      TAB  easy / normal      ENTER  drive      L  load your song      ESC  title")
	if not message.is_empty():
		_show_toast(message)


func _region_tab(index: int, x: float, width: float) -> Control:
	var region: Dictionary = _regions[index]
	var selected: bool = index == _region_index
	var unlocked: bool = _region_unlocked(index)
	var accent: Color = _accent(region)
	var tab := Ui.card(selected, accent)
	Ui.anchor(tab, 0.5, 0.0, 0.5, 0.0, x, 28, x + width, 112)
	var name := Ui.label("%d  %s" % [index + 1, str(region["name"]).to_upper()], 26, accent if unlocked else Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(name, 0.0, 0.0, 1.0, 0.0, 6, 10, -6, 46, HORIZONTAL_ALIGNMENT_CENTER)
	tab.add_child(name)
	var songs: Array[Dictionary] = SongLibrary.in_region(region["id"])
	var cleared: int = 0
	for song: Dictionary in songs:
		if _save.cleared(song["id"]):
			cleared += 1
	var status_text: String = "LOCKED" if not unlocked else "%d of %d cleared" % [cleared, songs.size()]
	var status := Ui.label(status_text, 20, Ui.WARM if not unlocked else Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(status, 0.0, 0.0, 1.0, 0.0, 6, 46, -6, 74, HORIZONTAL_ALIGNMENT_CENTER)
	tab.add_child(status)
	_on_click(tab, func() -> void:
		if index != _region_index:
			_region_index = index
			_click()
			_show_route())
	return tab


func _song_row(index: int, selected: bool, y: float, accent: Color, unlocked: bool) -> Control:
	var song: Dictionary = _songs[index]
	var row := Ui.card(selected, accent)
	Ui.anchor(row, 0.5, 0.0, 0.5, 0.0, -720, y, -80, y + ROW_HEIGHT)
	if not unlocked:
		row.modulate.a = 0.55
	var title := Ui.label(str(song["title"]), 28, Ui.TEXT)
	Ui.anchor(title, 0.0, 0.0, 0.72, 1.0, 22, 6, 0, -6)
	title.clip_text = true
	row.add_child(title)
	if song["source"] == "imported":
		Ui.anchor(title, 0.0, 0.0, 0.72, 1.0, 22, 0, 0, -20)
		var tag := Ui.label("YOUR SONG", 16, Ui.WARM)
		Ui.anchor(tag, 0.0, 1.0, 0.0, 1.0, 24, -24, 200, -2)
		row.add_child(tag)
	var bests: Array[String] = []
	for level: String in Chart.DIFFICULTIES:
		bests.append(str(_save.best_for(song["id"], level).get("grade", "·")))
	var grades := Ui.label("  ".join(bests), 26, Ui.WARM, HORIZONTAL_ALIGNMENT_RIGHT)
	Ui.anchor(grades, 0.72, 0.0, 1.0, 1.0, 0, 12, -20, -10, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(grades)
	if selected and _remove_armed_until > Time.get_ticks_msec():
		title.text = "Press X again to move it to the Trash"
		title.add_theme_color_override("font_color", Ui.WARM)
	_on_click(row, func() -> void:
		if selected:
			_drive_selected()
		else:
			_choose_song(index)
			_click()
			_show_route())
	return row


func _song_detail(song: Dictionary, accent: Color, unlocked: bool) -> Control:
	var card := Ui.card(true, accent)
	Ui.anchor(card, 0.5, 0.0, 0.5, 0.0, -50, LIST_TOP, 720, LIST_TOP + 470)
	var title := Ui.label(str(song["title"]), 38, Ui.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Ui.anchor(title, 0.0, 0.0, 1.0, 0.0, 28, 18, -28, 104)
	card.add_child(title)
	var length: int = int(round(float(song["duration"])))
	var facts: String = "%d BPM   ·   %d:%02d" % [int(round(float(song["bpm"]))), length / 60, length % 60]
	if song["source"] == "imported":
		facts += "   ·   your song"
	var info := Ui.label(facts, 24, Ui.MUTED)
	Ui.anchor(info, 0.0, 0.0, 1.0, 0.0, 28, 108, -28, 140)
	card.add_child(info)

	# Easy and Normal side by side; TAB or a click switches.
	var meta: Dictionary = Chart.read_meta(song["path"])
	var levels: Dictionary = meta.get("difficulties", {})
	for i: int in Chart.DIFFICULTIES.size():
		var level: String = Chart.DIFFICULTIES[i]
		var on: bool = level == _difficulty
		var chip := Ui.card(on, accent)
		var x: float = 28.0 + i * 352.0
		Ui.anchor(chip, 0.0, 0.0, 0.0, 0.0, x, 158, x + 336, 300)
		var notes: Array = levels.get(level, [])
		var holds: int = 0
		var reach: bool = false
		var sharps: int = 0
		for n: Dictionary in notes:
			if float(n["d"]) >= Chart.HOLD_MIN_SECONDS:
				holds += 1
			if int(n.get("s", 0)) == 1:
				sharps += 1
			elif KeyMap.REACH.has(int(n.get("l", 0))):
				reach = true
		var head := Ui.label(level.to_upper(), 28, accent if on else Ui.MUTED)
		Ui.anchor(head, 0.0, 0.0, 1.0, 0.0, 18, 10, -18, 46)
		chip.add_child(head)
		var best: Dictionary = _save.best_for(song["id"], level)
		var best_text: String = "Best  %s   %d" % [best["grade"], int(best["score"])] if not best.is_empty() else "Not driven yet"
		var best_label := Ui.label(best_text, 24, Ui.WARM if not best.is_empty() else Ui.MUTED)
		Ui.anchor(best_label, 0.0, 0.0, 1.0, 0.0, 18, 48, -18, 80)
		chip.add_child(best_label)
		var shape := Ui.label("%d notes, %d holds" % [notes.size(), holds], 22, Ui.TEXT)
		Ui.anchor(shape, 0.0, 0.0, 1.0, 0.0, 18, 82, -18, 110)
		chip.add_child(shape)
		var keys_text: String = "8 resting keys"
		if sharps > 0:
			keys_text = "10 keys + %d sharps on the top row" % sharps
		elif reach:
			keys_text = "10 keys: adds G and H"
		var keys := Ui.label(keys_text, 20, Color(1.0, 0.62, 0.25) if sharps > 0 else Ui.MUTED)
		Ui.anchor(keys, 0.0, 0.0, 1.0, 0.0, 18, 108, -18, 134)
		chip.add_child(keys)
		_on_click(chip, func() -> void:
			if _difficulty != level:
				_difficulty = level
				_click()
				_show_route())
		card.add_child(chip)

	var drive := Ui.card(unlocked, accent)
	Ui.anchor(drive, 0.0, 0.0, 1.0, 0.0, 28, 330, -28, 410)
	var drive_text: String = "ENTER   DRIVE" if unlocked else "LOCKED"
	var drive_label := Ui.label(drive_text, 38, accent if unlocked else Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(drive_label, 0.0, 0.0, 1.0, 1.0, 0, 14, 0, -12, HORIZONTAL_ALIGNMENT_CENTER)
	drive.add_child(drive_label)
	_on_click(drive, _drive_selected)
	card.add_child(drive)
	if song["source"] == "imported":
		var remove := Ui.label("X  remove this song", 20, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(remove, 0.0, 0.0, 1.0, 0.0, 0, 420, 0, 450, HORIZONTAL_ALIGNMENT_CENTER)
		card.add_child(remove)
	return card


func _route_key(code: Key) -> void:
	match code:
		KEY_LEFT:
			_region_index = wrapi(_region_index - 1, 0, _regions.size())
			_remove_armed_until = 0
			_click()
			_show_route()
		KEY_RIGHT:
			_region_index = wrapi(_region_index + 1, 0, _regions.size())
			_remove_armed_until = 0
			_click()
			_show_route()
		KEY_UP:
			_choose_song(_selected_index() - 1)
			_remove_armed_until = 0
			_click()
			_show_route()
		KEY_DOWN:
			_choose_song(_selected_index() + 1)
			_remove_armed_until = 0
			_click()
			_show_route()
		KEY_TAB:
			_difficulty = "easy" if _difficulty == "normal" else "normal"
			_click()
			_show_route()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_drive_selected()
		KEY_L:
			_click()
			_open_file_picker()
		KEY_X:
			_try_remove()
		KEY_ESCAPE:
			_click()
			_show_title()


func _drive_selected() -> void:
	if _songs.is_empty():
		return
	if not _region_unlocked(_region_index):
		_show_toast("Clear any song in %s first to open %s." % [_regions[_region_index - 1]["name"], _regions[_region_index]["name"]])
		return
	_click()
	_start_run(_songs[_selected_index()])


## Removing one of your songs takes a second press, and goes to the Trash so it can be restored.
func _try_remove() -> void:
	if _songs.is_empty() or _songs[_selected_index()]["source"] != "imported":
		return
	if _remove_armed_until > Time.get_ticks_msec():
		_remove_armed_until = 0
		var song: Dictionary = _songs[_selected_index()]
		var err: Error = SongLibrary.remove_import(song)
		_choose_song(_selected_index() - 1)
		_show_route("Moved \"%s\" to the Trash" % song["title"] if err == OK else "Could not remove that song")
	else:
		_remove_armed_until = Time.get_ticks_msec() + 3000
		_show_route()


# ---------------------------------------------------------------- loading your own song

func _open_file_picker() -> void:
	var problem: String = SongImporter.setup_problem()
	if not problem.is_empty():
		_show_import_message(problem)
		return
	var dialog := FileDialog.new()
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.title = "Load your song"
	dialog.filters = PackedStringArray([AUDIO_FILTERS])
	dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	dialog.file_selected.connect(_show_import_form)
	dialog.canceled.connect(dialog.queue_free)
	dialog.file_selected.connect(func(_p: String) -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _show_import_form(file: String) -> void:
	_clear_ui()
	_screen = Screen.IMPORT
	_import_file = file
	_ui.add_child(Ui.dim_panel(0.7))
	var heading := Ui.label("LOAD YOUR SONG", 54, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(heading, 0.0, 0.0, 1.0, 0.0, 0, 120, 0, 190, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(heading)
	var name := Ui.label(file.get_file(), 26, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(name, 0.0, 0.0, 1.0, 0.0, 0, 196, 0, 232, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(name)
	var title_caption := Ui.label("Title", 24, Ui.MUTED)
	Ui.anchor(title_caption, 0.5, 0.0, 0.5, 0.0, -360, 270, 0, 300)
	_ui.add_child(title_caption)
	_import_title = LineEdit.new()
	_import_title.text = file.get_file().get_basename().replace("_", " ").replace("-", " ").strip_edges()
	_import_title.add_theme_font_override("font", Ui.font())
	_import_title.add_theme_font_size_override("font_size", 30)
	Ui.anchor(_import_title, 0.5, 0.0, 0.5, 0.0, -360, 304, 360, 356)
	_import_title.text_submitted.connect(func(_t: String) -> void: _confirm_import())
	_ui.add_child(_import_title)
	var region_caption := Ui.label("Region (sets the road and the lead instrument for MIDI songs)", 24, Ui.MUTED)
	Ui.anchor(region_caption, 0.5, 0.0, 0.5, 0.0, -360, 378, 360, 408)
	_ui.add_child(region_caption)
	_import_regions = OptionButton.new()
	_import_regions.add_theme_font_override("font", Ui.font())
	_import_regions.add_theme_font_size_override("font_size", 28)
	for region: Dictionary in _regions:
		_import_regions.add_item("%s   (%s)" % [region["name"], region.get("genres", "")])
	_import_regions.selected = _region_index
	Ui.anchor(_import_regions, 0.5, 0.0, 0.5, 0.0, -360, 412, 360, 464)
	_ui.add_child(_import_regions)
	var go := Button.new()
	go.text = "Make it playable"
	go.add_theme_font_override("font", Ui.font())
	go.add_theme_font_size_override("font_size", 30)
	Ui.anchor(go, 0.5, 0.0, 0.5, 0.0, -180, 500, 180, 560)
	go.pressed.connect(_confirm_import)
	_ui.add_child(go)
	var note := Ui.label("Audio files take a minute or two: the vocals are separated and transcribed on this computer.", 22, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(note, 0.0, 0.0, 1.0, 0.0, 0, 580, 0, 612, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(note)
	_hint("ENTER  start        ESC  cancel")
	_import_title.grab_focus()
	_import_title.select_all()


func _confirm_import() -> void:
	var title: String = _import_title.text.strip_edges()
	var region: String = _regions[_import_regions.selected]["id"]
	_region_index = _import_regions.selected
	_begin_import(_import_file, title if not title.is_empty() else _import_file.get_file().get_basename(), region)


func _begin_import(file: String, title: String, region: String) -> void:
	_clear_ui()
	_screen = Screen.IMPORT
	_show_world(region)
	if title.is_empty():
		title = file.get_file().get_basename()
	_ui.add_child(Ui.dim_panel(0.7))
	var heading := Ui.label(title, 54, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(heading, 0.0, 0.0, 1.0, 0.0, 0, 220, 0, 290, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(heading)
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.14)
	Ui.anchor(track, 0.5, 0.0, 0.5, 0.0, -420, 330, 420, 346)
	_ui.add_child(track)
	_import_bar = ColorRect.new()
	_import_bar.color = Ui.ACCENT
	_import_bar.anchor_bottom = 1.0
	_import_bar.anchor_right = 0.0
	track.add_child(_import_bar)
	_import_status = Ui.label("Starting", 28, Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(_import_status, 0.0, 0.0, 1.0, 0.0, 0, 366, 0, 406, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(_import_status)
	_hint("ESC  cancel")
	_import_dir = _importer.start(ProjectSettings.globalize_path(file), title, region)


func _on_import_progress(fraction: float, message: String) -> void:
	if _screen != Screen.IMPORT or _import_bar == null or not is_instance_valid(_import_bar):
		return
	_import_bar.anchor_right = clampf(fraction, 0.0, 1.0)
	_import_status.text = message


func _on_import_finished(chart_path: String) -> void:
	var meta: Dictionary = Chart.read_meta(chart_path)
	_select_song_id(str(meta.get("id", "")))
	var levels: Dictionary = meta.get("difficulties", {})
	_show_route("Ready: \"%s\", %d notes on Normal, %d on Easy" % [meta.get("title", ""),
		(levels.get("normal", []) as Array).size(), (levels.get("easy", []) as Array).size()])
	print("IMPORTED ", chart_path)
	if _options.has("import-file"):
		await get_tree().create_timer(1.0).timeout
		if _options.has("shot"):
			_save_shot(str(_options["shot"]))
		get_tree().quit()


func _on_import_failed(message: String) -> void:
	if _import_dir.begins_with(SongLibrary.USER_DIR):
		# A half-written import would show up in the library; it holds nothing worth keeping.
		OS.move_to_trash(ProjectSettings.globalize_path(_import_dir))
	_show_import_message("That song could not be loaded.\n" + message)
	print("IMPORT FAILED ", message)
	if _options.has("import-file"):
		get_tree().quit(1)


func _show_import_message(text: String) -> void:
	_clear_ui()
	_screen = Screen.IMPORT
	_ui.add_child(Ui.dim_panel(0.7))
	var label := Ui.label(text, 30, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Ui.anchor(label, 0.15, 0.3, 0.85, 0.3, 0, 0, 0, 260, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(label)
	_hint("ESC  back")


# ---------------------------------------------------------------- the drive

func _start_run(song: Dictionary) -> void:
	assert(not song.is_empty(), "Unknown song")
	_current_song = song
	_song_choice[song["theme"]] = song["id"]
	_end_session()
	_clear_ui()
	_screen = Screen.PLAYING
	var chart := Chart.load_file(song["path"], _difficulty)
	var highway: Highway = _stage.show_chart(chart.theme, chart)
	_play_ambience(chart.theme)
	_ambient.volume_db = -18.0
	_session = PlaySession.new()
	add_child(_session)
	_session.finished.connect(_on_run_finished)
	_session.quit_to_menu.connect(_show_route)
	_session.restart_requested.connect(func() -> void: _start_run(_current_song))
	var options := {"offset": _save.calibration}
	if _options.has("bot"):
		options["bot"] = str(_options["bot"])
	if _options.has("fast"):
		options["manual"] = true
	_session.begin(chart, highway, _stage.world, _sfx, options)


## The next song in this region, or the first of the next region once it is open.
func _drive_next() -> void:
	var songs: Array[Dictionary] = SongLibrary.in_region(_current_song["theme"])
	var at: int = songs.map(func(s: Dictionary) -> String: return s["id"]).find(_current_song["id"])
	if at >= 0 and at + 1 < songs.size():
		_start_run(songs[at + 1])
		return
	var region_at: int = _region_ids().find(_current_song["theme"])
	if region_at + 1 < _regions.size() and _region_unlocked(region_at + 1):
		var next_songs: Array[Dictionary] = SongLibrary.in_region(_regions[region_at + 1]["id"])
		if not next_songs.is_empty():
			_region_index = region_at + 1
			_start_run(next_songs[0])
			return
	_show_route("That was the last open song here. Pick another on the route.")


func _on_run_finished(result: Dictionary) -> void:
	if _options.has("fast"):
		return
	var regions_open_before: int = _open_region_count()
	var new_best: bool = false
	if not _options.has("bot"):
		new_best = _save.record(result)
	_stage.world.set_target_speed(0.0 if result["failed"] else 0.6)
	_ambient.volume_db = -9.0
	_show_results(result, new_best, _open_region_count() > regions_open_before)
	if _options.has("bot"):
		print("RESULT ", JSON.stringify(result))
		print("TIMING ", JSON.stringify(_session.timing))
		if _options.has("shots"):
			await get_tree().create_timer(1.0).timeout
			_save_shot(str(_options["shots"]).path_join("results.png"))
		get_tree().quit()


func _open_region_count() -> int:
	var open: int = 0
	for i: int in _regions.size():
		if _region_unlocked(i):
			open += 1
	return open


func _take_due_shots() -> void:
	if _session == null or _session.clock == null:
		return
	if _options.has("shot-at"):
		if _session.clock.now() >= float(_options["shot-at"]):
			_save_shot(str(_options["shots"]).path_join("frame.png"))
			get_tree().quit()
		return
	if _shot_index < SHOT_TIMES.size() and _session.clock.now() >= SHOT_TIMES[_shot_index]:
		_save_shot(str(_options["shots"]).path_join("play_%d.png" % _shot_index))
		_shot_index += 1


func _save_shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)


func _show_results(result: Dictionary, new_best: bool, opened_region: bool) -> void:
	_clear_ui()
	_screen = Screen.RESULTS
	_ui.add_child(Ui.dim_panel())
	var failed: bool = result["failed"]
	var heading := Ui.label("OUT OF GAS" if failed else str(result["title"]), 62, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(heading, 0.0, 0.0, 1.0, 0.0, 0, 96, 0, 176, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(heading)
	var level := Ui.label(str(result.get("difficulty", "normal")).to_upper(), 26, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(level, 0.0, 0.0, 1.0, 0.0, 0, 176, 0, 208, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(level)
	var grade := Ui.label("—" if failed else str(result["grade"]), 190, Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(grade, 0.0, 0.0, 1.0, 0.0, 0, 200, 0, 440, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(grade)
	var summary: String = "Score %d     Accuracy %d%%     Max combo %d" % [
		int(result["score"]), int(round(float(result["accuracy"]) * 100.0)), int(result["max_combo"])]
	var line_one := Ui.label(summary, 36, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(line_one, 0.0, 0.0, 1.0, 0.0, 0, 452, 0, 502, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(line_one)
	var detail: String = "Perfect %d     Good %d     Missed %d     Wrong keys %d     Holds %d / %d" % [
		int(result["perfects"]), int(result["goods"]), int(result["misses"]), int(result["wrong"]),
		int(result["holds_completed"]), int(result["holds_total"])]
	var line_two := Ui.label(detail, 28, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(line_two, 0.0, 0.0, 1.0, 0.0, 0, 510, 0, 552, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(line_two)
	var news: Array[String] = []
	if new_best:
		news.append("NEW BEST")
	if opened_region:
		news.append("NEW ROAD OPEN ON THE ROUTE")
	if not news.is_empty():
		var banner := Ui.label("     ".join(news), 34, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(banner, 0.0, 0.0, 1.0, 0.0, 0, 566, 0, 614, HORIZONTAL_ALIGNMENT_CENTER)
		_ui.add_child(banner)
	_hint("ENTER  next song        SPACE  drive again        ESC  route")


# ---------------------------------------------------------------- timing check

func _show_calibration() -> void:
	_clear_ui()
	_screen = Screen.CALIBRATE
	_calib_done = false
	_calib_next = 0
	_calib_fired.clear()
	_calib_taps.clear()
	_calib_start_usec = Time.get_ticks_usec() + 1200000
	_ui.add_child(Ui.dim_panel())
	var heading := Ui.label("TIMING CHECK", 62, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(heading, 0.0, 0.3, 1.0, 0.3, 0, 0, 0, 80, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(heading)
	var note := Ui.label("Press SPACE exactly when you hear each click.", 32, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(note, 0.0, 0.3, 1.0, 0.3, 0, 96, 0, 146, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(note)
	_calib_status = Ui.label("Listen for the clicks", 30, Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(_calib_status, 0.0, 0.3, 1.0, 0.3, 0, 170, 0, 220, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(_calib_status)


func _tick_calibration() -> void:
	if _calib_done:
		return
	var due: int = _calib_start_usec + int(float(_calib_next) * CALIBRATE_INTERVAL * 1000000.0)
	if _calib_next < CALIBRATE_CLICKS and Time.get_ticks_usec() >= due:
		(_sfx["click"] as AudioStreamPlayer).play()
		_calib_fired.append(Time.get_ticks_usec())
		_calib_next += 1
		_calib_status.text = "%d / %d" % [_calib_next, CALIBRATE_CLICKS]
	elif _calib_next >= CALIBRATE_CLICKS and Time.get_ticks_usec() >= due + 400000:
		_finish_calibration()


## The tap-to-click gap is the delay the player actually experiences. The clock
## already subtracts the driver's reported latency, so only the remainder is stored.
func _finish_calibration() -> void:
	_calib_done = true
	var gaps: Array[float] = []
	for i: int in range(CALIBRATE_SKIP, _calib_fired.size()):
		var closest: float = INF
		for tap: int in _calib_taps:
			var gap: float = float(tap - _calib_fired[i]) / 1000000.0
			if absf(gap) < absf(closest):
				closest = gap
		if absf(closest) <= 0.28:
			gaps.append(closest)
	if gaps.size() < 6:
		_calib_status.text = "Not enough taps caught, so nothing changed."
	else:
		gaps.sort()
		var median: float = gaps[gaps.size() / 2]
		_save.calibration = clampf(median - AudioServer.get_output_latency(), -0.3, 0.3)
		_save.write()
		_calib_status.text = "Timing offset set to %+d ms" % int(round(_save.calibration * 1000.0))
	await get_tree().create_timer(1.8).timeout
	if _screen == Screen.CALIBRATE:
		_show_title()
