extends Node
## Game flow: title → the route (regions and their songs on one screen) → drive →
## results; plus settings (which holds the timing check) and loading your own song.
## The selected region's world keeps rolling behind every screen.
##
## A song can be driven for a score or as a practice run (P on the route, or on
## the results screen after running out of gas): no fail, optionally slower, never
## saved. A player with no saved runs starts on Easy.
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

enum Screen { TITLE, ROUTE, IMPORT, CALIBRATE, PLAYING, RESULTS, SETTINGS }

## P on the route steps through these: off, then practice at each speed.
const PRACTICE_SPEEDS: Array[float] = [0.0, 1.0, 0.85, 0.7]
const SETTING_ROWS: Array[String] = ["music", "effects", "note_speed", "letters", "motion", "graphics", "fullscreen", "timing"]
const SETTING_NAMES := {"music": "Music volume", "effects": "Sound effects volume", "note_speed": "Note speed",
	"letters": "Letters on notes", "motion": "Beat flashes and camera movement",
	"graphics": "High-detail graphics", "fullscreen": "Fullscreen",
	"timing": "Timing check"}

const CALIBRATE_CLICKS := 12
const CALIBRATE_INTERVAL := 0.6
const CALIBRATE_SKIP := 2
const SHOT_TIMES: Array[float] = [-1.0, 9.0, 12.2, 33.0, 60.0]
const SFX_NAMES: Array[String] = ["click", "wrong", "ui", "held", "out_of_gas", "milestone", "clear"]
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
var _practice_step: int = 0
var _last_result: Dictionary = {}
var _settings_row: int = 0
## Where Escape leads from settings and from the timing check: the screen they were opened from.
var _settings_return: Callable

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
## The Escape menu on the title and route screens, while it is open.
var _menu: MenuOverlay


func _ready() -> void:
	_parse_args()
	_save = SaveData.load_or_new()
	Settings.apply(_save.settings)
	# Someone who has never finished a song starts on Easy; Normal ended a first run in seconds.
	if _save.best.is_empty():
		_difficulty = "easy"
	_settings_return = _show_title
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
	_ambient.bus = Settings.BUS_MUSIC
	add_child(_ambient)
	for sfx_name: String in SFX_NAMES:
		var player := AudioStreamPlayer.new()
		player.bus = Settings.BUS_EFFECTS
		# A checkout whose effects have not been rebuilt still runs; that effect is just silent.
		if ResourceLoader.exists("res://assets/audio/sfx_%s.wav" % sfx_name):
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
	if _menu:
		_menu.handle_key(code)
		return
	match _screen:
		Screen.TITLE:
			if code == KEY_SPACE or code == KEY_ENTER:
				_click()
				_show_route()
			elif code == KEY_S:
				_click()
				_open_settings(_show_title)
			elif code == KEY_ESCAPE:
				_open_menu()
		Screen.ROUTE:
			_route_key(code)
		Screen.SETTINGS:
			_settings_key(code)
		Screen.CALIBRATE:
			if code == KEY_ESCAPE:
				_show_settings()
			elif code == KEY_SPACE and not _calib_done:
				_calib_taps.append(Time.get_ticks_usec())
		Screen.RESULTS:
			# Out of gas, there is no "next song": the offers are to try again or to practise this one.
			if code == KEY_ENTER and not _last_result.get("failed", false):
				_click()
				_drive_next()
			elif code == KEY_SPACE:
				_click()
				_start_run(_current_song)
			elif code == KEY_P:
				_click()
				if _practice_step == 0:
					_practice_step = 2
				_start_run(_current_song)
			elif code == KEY_ESCAPE:
				_click()
				_show_route()


func _click() -> void:
	(_sfx["ui"] as AudioStreamPlayer).play()


func _clear_ui() -> void:
	# Every screen is styled after the region in view (Ui.STYLES), like its song-select skin.
	Ui.use_region(str(_regions[_region_index]["id"]))
	get_viewport().disable_3d = false
	for child: Node in _ui.get_children():
		child.queue_free()
	_menu = null
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
	var hint := Ui.caption(text, 22, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
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
	_hint("SPACE  start        S  settings        ESC  menu")


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
		# Each key wears its finger's colour, the same one its notes arrive in.
		var key := Ui.card(true, KeyMap.color_for(lane))
		var x: float = start + lane * (cap + gap)
		Ui.anchor(key, 0.0, 0.0, 0.0, 0.0, x, 40, x + cap, 40 + cap)
		var letter := Ui.label(KeyMap.label_for(lane), 40, Ui.TEXT if not reach else KeyMap.color_for(lane), HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(letter, 0.0, 0.0, 1.0, 1.0, 0, 12, 0, -10, HORIZONTAL_ALIGNMENT_CENTER)
		key.add_child(letter)
		if KeyMap.HOMING.has(lane):
			var bump := ColorRect.new()
			bump.color = KeyMap.color_for(lane)
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
	var note := Ui.label("Notes arrive in the colour of the finger that plays them. Index fingers reach for G and H; Easy never uses them.", 24, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
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
	_songs = SongLibrary.in_region(region["id"])
	# The song select is a full-screen illustrated skin (RouteScreen; the Song Select Redesigns
	# canvas), so the 3D world is neither built nor drawn behind it: switching regions here
	# no longer rebuilds a whole world. The region's ambience still plays.
	_play_ambience(region["id"])
	_ambient.volume_db = -9.0
	get_viewport().disable_3d = true
	var screen := RouteScreen.new()
	screen.acted.connect(_on_route_action)
	_ui.add_child(screen)
	screen.present(_route_skin(str(region["id"])), _route_model(message))


## Each region's song-select skin (scripts/ui/skins/). A region without one yet borrows Red Frontier's.
const ROUTE_SKINS := {
	"backroads": "res://scripts/ui/skins/frontier.gd", "neon": "res://scripts/ui/skins/neon.gd",
	"coast": "res://scripts/ui/skins/tide.gd", "mesa": "res://scripts/ui/skins/io.gd", "aurora": "res://scripts/ui/skins/ring.gd",
}


func _route_skin(region_id: String) -> RouteSkin:
	var path: String = str(ROUTE_SKINS.get(region_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		path = str(ROUTE_SKINS["backroads"])
	return (load(path) as GDScript).new()


## Everything the skin draws (the model is documented in RouteSkin).
func _route_model(message: String) -> Dictionary:
	var region: Dictionary = _regions[_region_index]
	var unlocked: bool = _region_unlocked(_region_index)
	var tabs: Array = []
	for i: int in _regions.size():
		var other: Dictionary = _regions[i]
		var songs: Array[Dictionary] = SongLibrary.in_region(other["id"])
		var cleared: int = 0
		for song: Dictionary in songs:
			if _save.cleared(song["id"]):
				cleared += 1
		tabs.append({"num": i + 1, "name": other["name"], "upper": str(other["name"]).to_upper(), "cleared": cleared,
			"total": songs.size(), "locked": not _region_unlocked(i), "selected": i == _region_index})
	var selected: int = _selected_index()
	var rows: Array = []
	for slot: int in 7:
		var index: int = selected - 3 + slot
		if index < 0 or index >= _songs.size():
			rows.append({})
			continue
		var song: Dictionary = _songs[index]
		rows.append({"index": index, "n": "%02d" % (index + 1), "title": song["title"], "upper": str(song["title"]).to_upper(),
			"grades": _grades_text(song), "level": SongLibrary.level_of(song, _difficulty), "selected": index == selected,
			"imported": song["source"] == "imported", "freq": _dial_frequency(index, _songs.size())})
	var detail: Dictionary = {}
	var cards: Array = []
	if not _songs.is_empty():
		var song: Dictionary = _songs[selected]
		var length: int = int(round(float(song["duration"])))
		detail = {"title": song["title"], "upper": str(song["title"]).to_upper(), "bpm": int(round(float(song["bpm"]))),
			"length": "%d:%02d" % [length / 60, length % 60], "number": selected + 1,
			"best": str(_save.best_for(song["id"], _difficulty).get("grade", "")), "imported": song["source"] == "imported",
			"remove_armed": _remove_armed_until > Time.get_ticks_msec(), "station": str(song.get("station", ""))}
		cards = _difficulty_cards(song)
	var practising: bool = _practice_step > 0
	return {
		"regions": tabs,
		"region": {"name": region["name"], "upper": str(region["name"]).to_upper(), "genres": region.get("genres", ""),
			"blurb": region.get("blurb", ""), "locked": not unlocked,
			"locked_text": "Locked: clear any song in %s to open this road." % _regions[maxi(_region_index - 1, 0)]["name"]},
		"rows": rows, "count": _songs.size(), "song": detail, "cards": cards,
		"practice": {"on": practising, "text": ("%d%% speed" % int(round(PRACTICE_SPEEDS[_practice_step] * 100.0))) if practising else "off"},
		"locked": not unlocked, "message": message,
	}


## "E– N–", with each difficulty's best grade in place of the dash once it has one.
func _grades_text(song: Dictionary) -> String:
	var parts: Array[String] = []
	for level: String in Chart.DIFFICULTIES:
		var grade: String = str(_save.best_for(song["id"], level).get("grade", ""))
		parts.append("%s%s" % [level.left(1).to_upper(), (" " + grade) if not grade.is_empty() else RouteSkin.DASH])
	return " ".join(parts)


## Red Frontier lists songs as stations on an AM dial: 540 to 1600, spread over the region's songs.
func _dial_frequency(index: int, count: int) -> String:
	var t: float = float(index) / maxf(float(count - 1), 1.0)
	return str(int(round(lerpf(540.0, 1600.0, t) / 10.0)) * 10)


## The Easy and Normal cards: level, notes and holds, which keys, and what makes it hard.
func _difficulty_cards(song: Dictionary) -> Array:
	var cards: Array = []
	var meta: Dictionary = Chart.read_meta(song["path"])
	var levels: Dictionary = meta.get("difficulties", {})
	for level: String in Chart.DIFFICULTIES:
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
		var keys: String = "8 resting keys"
		if sharps > 0:
			keys = "10 keys + %d sharp%s on the top row" % [sharps, "" if sharps == 1 else "s"]
		elif reach:
			keys = "10 keys, adds G and H"
		var rating: Dictionary = (song.get("ratings", {}) as Dictionary).get(level, {})
		var reasons: Array = rating.get("reasons", [])
		var feel: String = "Steady and even"
		if not reasons.is_empty():
			feel = ", ".join(reasons)
			feel = feel.left(1).to_upper() + feel.substr(1)
		var counts: String = "%d note%s · %d hold%s" % [notes.size(), "" if notes.size() == 1 else "s", holds, "" if holds == 1 else "s"]
		cards.append({"name": level.to_upper(), "level": Difficulty.level_of(rating), "notes": notes.size(), "holds": holds, "counts": counts,
			"keys": keys, "sharps": sharps, "feel": feel, "selected": level == _difficulty,
			"best": str(_save.best_for(song["id"], level).get("grade", ""))})
	return cards


func _on_route_action(action: String, arg: Variant) -> void:
	match action:
		"region":
			if int(arg) != _region_index:
				_region_index = int(arg)
				_remove_armed_until = 0
				_click()
				_show_route()
		"song":
			if int(arg) == _selected_index():
				_drive_selected()
			else:
				_choose_song(int(arg))
				_click()
				_show_route()
		"difficulty":
			if _difficulty != str(arg):
				_difficulty = str(arg)
				_click()
				_show_route()
		"practice":
			_step_practice()
		"drive":
			_drive_selected()
		"load":
			_open_file_picker()



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
		KEY_P:
			_click()
			_step_practice()
		KEY_S:
			_click()
			_open_settings(_show_route)
		KEY_X:
			_try_remove()
		KEY_ESCAPE:
			_open_menu()


## Escape on the title or route: carry on, settings, back to the title, or quit the game.
func _open_menu() -> void:
	if _menu:
		return
	_click()
	var back: Callable = _show_title if _screen == Screen.TITLE else _show_route
	var items: Array[Dictionary] = [
		{"text": "Resume", "key_text": "ESC", "action": _close_menu},
		{"text": "Settings", "key": KEY_S, "key_text": "S", "action": func() -> void:
			_close_menu()
			_open_settings(back)},
	]
	if _screen == Screen.ROUTE:
		items.append({"text": "Title screen", "key": KEY_T, "key_text": "T", "action": func() -> void:
			_close_menu()
			_show_title()})
	items.append({"text": "Quit game", "key": KEY_Q, "key_text": "Q", "action": func() -> void: get_tree().quit()})
	_menu = MenuOverlay.new().setup("MENU", items, _close_menu, Ui.ACCENT, "", _click)
	_ui.add_child(_menu)


func _close_menu() -> void:
	if _menu:
		_menu.queue_free()
		_menu = null


func _step_practice() -> void:
	_practice_step = (_practice_step + 1) % PRACTICE_SPEEDS.size()
	_show_route()


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
		SongLibrary.invalidate()
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
	var heading := Ui.heading("LOAD YOUR SONG", 54, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
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
	var heading := Ui.heading(title, 54, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
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
	SongLibrary.invalidate()
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
	var options := {"offset": _save.calibration, "stage": _stage}
	if _practice_step > 0 and not _options.has("bot"):
		options["practice"] = true
		options["speed"] = PRACTICE_SPEEDS[_practice_step]
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
	_last_result = result
	if not _options.has("bot") and not result.get("practice", false):
		new_best = _save.record(result)
	_stage.world.set_target_speed(0.0 if result["failed"] else 0.6)
	_ambient.volume_db = -9.0
	var opened_region: bool = _open_region_count() > regions_open_before
	# One fanfare, kept for the runs that changed something: a new best or a new road.
	if new_best or opened_region:
		(_sfx["clear"] as AudioStreamPlayer).play()
	_show_results(result, new_best, opened_region)
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
	# The run's numbers sit on a solid card, so the keyboard and lanes behind never read through them.
	var sheet := Panel.new()
	var sheet_box: StyleBoxFlat = Ui.card_style(true)
	sheet_box.bg_color = Color(Ui.card_style(false).bg_color, 0.96)
	sheet.add_theme_stylebox_override("panel", sheet_box)
	Ui.anchor(sheet, 0.5, 0.0, 0.5, 0.0, -600, 70, 600, 650)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(sheet)
	var failed: bool = result["failed"]
	var heading := Ui.heading("OUT OF GAS" if failed else str(result["title"]), 62, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(heading, 0.0, 0.0, 1.0, 0.0, 0, 96, 0, 176, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(heading)
	var practice: bool = result.get("practice", false)
	var level_text: String = str(result.get("difficulty", "normal")).to_upper()
	if practice:
		level_text += "   ·   PRACTICE AT %d%% SPEED, NOT SAVED" % int(round(float(result.get("speed", 1.0)) * 100.0))
	elif failed:
		level_text += "   ·   HOW FAR YOU GOT"
	var level := Ui.label(level_text, 26, Ui.WARM if practice else Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(level, 0.0, 0.0, 1.0, 0.0, 0, 176, 0, 208, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(level)
	var grade_text: String = "%d%%" % int(round(float(result.get("progress", 0.0)) * 100.0)) if failed else str(result["grade"])
	var grade := Ui.heading(grade_text, 190, Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER)
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
	# What to work on: a steady habit of rushing or dragging, and the keys that slipped most.
	var insights: Array[String] = []
	if int(result.get("offsets_counted", 0)) >= 8:
		var ms: int = int(round(float(result["typical_offset"]) * 1000.0))
		if absi(ms) < 20:
			insights.append("Timing: right on the beat")
		else:
			var habit: String = "Timing: you tend to press %d ms %s" % [absi(ms), "late" if ms > 0 else "early"]
			if absi(ms) >= 45:
				habit += "  (the timing check in Settings can correct for your speakers)"
			insights.append(habit)
	var trouble: Array = result.get("trouble", [])
	if not trouble.is_empty():
		var keys: Array[String] = []
		for entry: Array in trouble.slice(0, 3):
			keys.append("%s ×%d" % [KeyMap.label_for(int(entry[0])), int(entry[1])])
		insights.append("Slipped most on:   " + "     ".join(keys))
	for i: int in insights.size():
		var insight := Ui.label(insights[i], 26, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(insight, 0.0, 0.0, 1.0, 0.0, 0, 566 + i * 38, 0, 602 + i * 38, HORIZONTAL_ALIGNMENT_CENTER)
		_ui.add_child(insight)
	var news: Array[String] = []
	if new_best:
		news.append("NEW BEST")
	if opened_region:
		news.append("NEW ROAD OPEN ON THE ROUTE")
	if not news.is_empty():
		var banner := Ui.label("     ".join(news), 34, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(banner, 0.0, 0.0, 1.0, 0.0, 0, 656, 0, 704, HORIZONTAL_ALIGNMENT_CENTER)
		_ui.add_child(banner)
	if failed:
		_hint("SPACE  try again        P  practise it (no fail, slower)        ESC  route")
	else:
		_hint("ENTER  next song        SPACE  drive again        ESC  route")


# ---------------------------------------------------------------- settings

func _open_settings(back: Callable) -> void:
	_settings_return = back
	_show_settings()


func _show_settings() -> void:
	_clear_ui()
	_screen = Screen.SETTINGS
	_ui.add_child(Ui.dim_panel(0.72))
	var heading := Ui.heading("SETTINGS", 62, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(heading, 0.0, 0.0, 1.0, 0.0, 0, 70, 0, 150, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(heading)
	for i: int in SETTING_ROWS.size():
		var key: String = SETTING_ROWS[i]
		var selected: bool = i == _settings_row
		var row := Ui.card(selected)
		var y: float = 190.0 + i * 74.0
		Ui.anchor(row, 0.5, 0.0, 0.5, 0.0, -520, y, 520, y + 64)
		var name := Ui.label(str(SETTING_NAMES[key]), 28, Ui.TEXT if selected else Ui.MUTED)
		Ui.anchor(name, 0.0, 0.0, 0.6, 1.0, 26, 12, 0, -10)
		row.add_child(name)
		var shown: String = _setting_text(key)
		if selected:
			shown = "ENTER  " + shown if key == "timing" else "‹   %s   ›" % shown
		var current := Ui.label(shown, 28, Ui.ACCENT if selected else Ui.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		Ui.anchor(current, 0.45, 0.0, 1.0, 1.0, 0, 12, -26, -10, HORIZONTAL_ALIGNMENT_RIGHT)
		row.add_child(current)
		_on_click(row, func() -> void:
			if _settings_row == i:
				_change_setting(1)
			else:
				_settings_row = i
				_click()
				_show_settings())
		_ui.add_child(row)
	_hint("↑ ↓  choose        ← →  change        ESC  back")


func _setting_text(key: String) -> String:
	var current: Variant = Settings.value(_save.settings, key) if key != "timing" else null
	match key:
		"music", "effects":
			return "%d%%" % int(round(float(current) * 100.0))
		"note_speed":
			return str(Settings.NOTE_SPEEDS[int(current)][0])
		"timing":
			return "run it   (offset now %+d ms)" % int(round(_save.calibration * 1000.0))
	return "On" if bool(current) else "Off"


func _settings_key(code: Key) -> void:
	match code:
		KEY_UP:
			_settings_row = wrapi(_settings_row - 1, 0, SETTING_ROWS.size())
			_click()
			_show_settings()
		KEY_DOWN:
			_settings_row = wrapi(_settings_row + 1, 0, SETTING_ROWS.size())
			_click()
			_show_settings()
		KEY_LEFT:
			_change_setting(-1)
		KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_change_setting(1)
		KEY_ESCAPE:
			_click()
			_settings_return.call()


func _change_setting(step: int) -> void:
	var key: String = SETTING_ROWS[_settings_row]
	var current: Variant = Settings.value(_save.settings, key) if key != "timing" else null
	match key:
		"music", "effects":
			_save.settings[key] = clampf(snappedf(float(current) + 0.1 * step, 0.1), 0.0, 1.0)
		"note_speed":
			_save.settings[key] = clampi(int(current) + step, 0, Settings.NOTE_SPEEDS.size() - 1)
		"timing":
			_click()
			_show_calibration()
			return
		_:
			_save.settings[key] = not bool(current)
	Settings.apply(_save.settings)
	_save.write()
	if key == "graphics":
		_stage.rebuild_world()
	# After applying, so the click is heard at the new effects volume.
	_click()
	_show_settings()


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
	var heading := Ui.heading("TIMING CHECK", 62, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
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
		_show_settings()
