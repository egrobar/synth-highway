extends Node
## Game flow: title, the route map, a region's songs, the drive, results; plus
## the timing check and loading your own song. The region's world keeps rolling
## behind every screen.
##
## Regions unlock in order: clearing any song in one opens the next.
## Options for automated checks, passed after "--" on the command line:
##   --bot=perfect|tapper|sloppy|afk  --song=<id>  --difficulty=easy|normal
##       play a song with a bot through the real input path (add --fast for headless, no audio)
##   --muted                silence output (timing still runs on the real device)
##   --shots=DIR [--shot-at=SECONDS]   screenshots during a real-time bot run
##   --screen=title|map|songs --shot=PATH [--region=<id>]   capture a menu and quit
##   --import-file=PATH [--import-title=...] [--region=<id>]   run an import without the file picker
##   --unlock-all           open every region

enum Screen { TITLE, MAP, SONGS, IMPORT, CALIBRATE, PLAYING, RESULTS }

const CALIBRATE_CLICKS := 12
const CALIBRATE_INTERVAL := 0.6
const CALIBRATE_SKIP := 2
const SHOT_TIMES: Array[float] = [-1.0, 9.0, 12.2, 33.0, 60.0]
const SFX_NAMES: Array[String] = ["click", "wrong", "ui", "held", "out_of_gas"]
const SONG_ROWS := 7
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
var _songs: Array[Dictionary] = []
var _song_index: int = 0
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
		_region_index = maxi(0, _regions.map(func(r: Dictionary) -> String: return r["id"]).find(_options["region"]))
	if _options.has("difficulty"):
		_difficulty = str(_options["difficulty"])
	if _options.has("bot"):
		var song: Dictionary = SongLibrary.find(str(_options.get("song", "county_line")))
		_start_run(song)
		if _options.has("fast"):
			var result: Dictionary = _session.run_to_end_headless()
			print("RESULT ", JSON.stringify(result))
			get_tree().quit()
		return
	if _options.has("import-file"):
		_show_songs()
		_begin_import(str(_options["import-file"]), str(_options.get("import-title", "")), _regions[_region_index]["id"])
		return
	match str(_options.get("screen", "title")):
		"map":
			_show_map()
		"songs":
			_show_songs()
		_:
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
	if _options.has("shot") and Time.get_ticks_msec() > 4000:
		_save_shot(str(_options["shot"]))
		get_tree().quit()


func _input(event: InputEvent) -> void:
	# The import form has a text box, so Escape is caught before the box can swallow it.
	if _screen == Screen.IMPORT and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_importer.cancel()
		_show_songs()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo or not event.pressed:
		return
	var code: Key = (event as InputEventKey).physical_keycode
	match _screen:
		Screen.TITLE:
			if code == KEY_SPACE or code == KEY_ENTER:
				_click()
				_show_map()
			elif code == KEY_C:
				_click()
				_show_calibration()
		Screen.MAP:
			_map_key(code)
		Screen.SONGS:
			_songs_key(code)
		Screen.CALIBRATE:
			if code == KEY_ESCAPE:
				_show_title()
			elif code == KEY_SPACE and not _calib_done:
				_calib_taps.append(Time.get_ticks_usec())
		Screen.RESULTS:
			if code == KEY_SPACE or code == KEY_ENTER:
				_click()
				_start_run(_current_song)
			elif code == KEY_ESCAPE:
				_click()
				_show_songs()


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


func _hint(text: String) -> void:
	var hint := Ui.label(text, 24, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(hint, 0.0, 1.0, 1.0, 1.0, 0, -72, 0, -36, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(hint)


func _show_toast(text: String) -> void:
	_toast = Ui.label(text, 26, Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(_toast, 0.0, 1.0, 1.0, 1.0, 0, -118, 0, -82, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(_toast)


# ---------------------------------------------------------------- title

func _show_title() -> void:
	_end_session()
	_clear_ui()
	_screen = Screen.TITLE
	_show_world(_regions[_region_index]["id"])
	_ambient.volume_db = -9.0
	_ui.add_child(Ui.dim_panel(0.25))
	var logo := Ui.image("res://assets/textures/logo.png")
	Ui.anchor(logo, 0.5, 0.0, 0.5, 0.0, -520, 60, 520, 330)
	_ui.add_child(logo)
	var line := Ui.label("A night drive in five regions, played on your keyboard.", 32, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(line, 0.0, 0.0, 1.0, 0.0, 0, 340, 0, 390, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(line)
	var how := Ui.label("Press the letter on each note as it reaches the line. Long notes: keep holding.", 26, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(how, 0.0, 0.0, 1.0, 0.0, 0, 396, 0, 436, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(how)
	_hint("SPACE  start        C  timing check")


# ---------------------------------------------------------------- the route map

func _show_map() -> void:
	_end_session()
	_clear_ui()
	_screen = Screen.MAP
	var region: Dictionary = _regions[_region_index]
	_show_world(region["id"])
	_ambient.volume_db = -9.0
	_ui.add_child(Ui.dim_panel(0.3))
	var heading := Ui.label("THE ROUTE", 30, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(heading, 0.0, 0.0, 1.0, 0.0, 0, 40, 0, 80, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(heading)
	var count: int = _regions.size()
	var card_w: float = 270.0
	var gap: float = 22.0
	var total: float = count * card_w + (count - 1) * gap
	for i: int in count:
		_ui.add_child(_region_card(i, -total * 0.5 + i * (card_w + gap), card_w))
	var unlocked: bool = _region_unlocked(_region_index)
	var accent: Color = Ui.color_from_hex(str(region.get("accent", "#3fd8ff")))
	var name := Ui.label(str(region["name"]).to_upper(), 64, accent, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(name, 0.0, 0.62, 1.0, 0.62, 0, 0, 0, 80, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(name)
	var blurb_text: String = str(region.get("blurb", ""))
	if not unlocked:
		blurb_text = "Clear any song in %s to open this road." % _regions[_region_index - 1]["name"]
	var blurb := Ui.label(blurb_text, 28, Ui.TEXT if unlocked else Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(blurb, 0.0, 0.62, 1.0, 0.62, 0, 84, 0, 124, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(blurb)
	_hint("← →  choose region        ENTER  songs        L  load your own song        ESC  back")


func _region_card(index: int, x: float, width: float) -> Control:
	var region: Dictionary = _regions[index]
	var selected: bool = index == _region_index
	var unlocked: bool = _region_unlocked(index)
	var accent: Color = Ui.color_from_hex(str(region.get("accent", "#3fd8ff")))
	var card := Ui.card(selected, accent)
	var top: float = 110.0 if selected else 126.0
	Ui.anchor(card, 0.5, 0.0, 0.5, 0.0, x, top, x + width, top + (300.0 if selected else 268.0))
	var logo_path: String = "res://assets/themes/%s/textures/region_logo.png" % region["id"]
	if ResourceLoader.exists(logo_path):
		var logo := Ui.image(logo_path)
		Ui.anchor(logo, 0.0, 0.0, 1.0, 0.0, 10, 16, -10, 96)
		logo.modulate.a = 1.0 if unlocked else 0.35
		card.add_child(logo)
	var genres := Ui.label(str(region.get("genres", "")), 20, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	genres.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Ui.anchor(genres, 0.0, 0.0, 1.0, 0.0, 12, 104, -12, 160, HORIZONTAL_ALIGNMENT_CENTER)
	card.add_child(genres)
	var songs: Array[Dictionary] = SongLibrary.in_region(region["id"])
	var cleared: int = 0
	for song: Dictionary in songs:
		if _save.cleared(song["id"]):
			cleared += 1
	var status_text: String = "LOCKED" if not unlocked else "%d song%s   %d cleared" % [songs.size(), "" if songs.size() == 1 else "s", cleared]
	var status := Ui.label(status_text, 22, Ui.WARM if not unlocked else Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(status, 0.0, 1.0, 1.0, 1.0, 0, -62, 0, -28, HORIZONTAL_ALIGNMENT_CENTER)
	card.add_child(status)
	var order := Ui.label(str(index + 1), 22, accent, HORIZONTAL_ALIGNMENT_LEFT)
	Ui.anchor(order, 0.0, 0.0, 0.0, 0.0, 14, 8, 60, 34)
	card.add_child(order)
	return card


func _map_key(code: Key) -> void:
	match code:
		KEY_LEFT, KEY_A:
			_region_index = wrapi(_region_index - 1, 0, _regions.size())
			_click()
			_show_map()
		KEY_RIGHT, KEY_D:
			_region_index = wrapi(_region_index + 1, 0, _regions.size())
			_click()
			_show_map()
		KEY_ENTER, KEY_SPACE:
			if _region_unlocked(_region_index):
				_click()
				_song_index = 0
				_show_songs()
		KEY_L:
			_click()
			_open_file_picker()
		KEY_ESCAPE:
			_click()
			_show_title()


# ---------------------------------------------------------------- a region's songs

func _show_songs(select_id: String = "") -> void:
	_end_session()
	_clear_ui()
	_screen = Screen.SONGS
	var region: Dictionary = _regions[_region_index]
	_show_world(region["id"])
	_ambient.volume_db = -9.0
	_songs = SongLibrary.in_region(region["id"])
	if not select_id.is_empty():
		for i: int in _songs.size():
			if _songs[i]["id"] == select_id:
				_song_index = i
	_song_index = clampi(_song_index, 0, maxi(0, _songs.size() - 1))
	_ui.add_child(Ui.dim_panel(0.42))
	var accent: Color = Ui.color_from_hex(str(region.get("accent", "#3fd8ff")))
	var logo_path: String = "res://assets/themes/%s/textures/region_logo.png" % region["id"]
	if ResourceLoader.exists(logo_path):
		var logo := Ui.image(logo_path)
		Ui.anchor(logo, 0.5, 0.0, 0.5, 0.0, -300, 20, 300, 130)
		_ui.add_child(logo)
	var level := Ui.label("◀  %s  ▶" % _difficulty.to_upper(), 30, accent, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(level, 0.0, 0.0, 1.0, 0.0, 0, 136, 0, 176, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(level)
	if _songs.is_empty():
		var empty := Ui.label("No songs here yet. Press L to load one of yours.", 32, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(empty, 0.0, 0.4, 1.0, 0.4, 0, 0, 0, 60, HORIZONTAL_ALIGNMENT_CENTER)
		_ui.add_child(empty)
	var first: int = clampi(_song_index - SONG_ROWS / 2, 0, maxi(0, _songs.size() - SONG_ROWS))
	for row: int in range(first, mini(first + SONG_ROWS, _songs.size())):
		_ui.add_child(_song_row(_songs[row], row == _song_index, 196.0 + float(row - first) * 76.0, accent))
	_hint("↑ ↓  song     ← →  difficulty     ENTER  drive     L  load your own song     X  remove yours     ESC  map")


func _song_row(song: Dictionary, selected: bool, y: float, accent: Color) -> Control:
	var row := Ui.card(selected, accent)
	Ui.anchor(row, 0.5, 0.0, 0.5, 0.0, -560, y, 560, y + 66)
	var title := Ui.label(str(song["title"]), 32, Ui.TEXT)
	Ui.anchor(title, 0.0, 0.0, 0.62, 1.0, 24, 10, 0, -10)
	title.clip_text = true
	row.add_child(title)
	if song["source"] == "imported":
		# Title moves up to make room for the tag underneath it.
		title.add_theme_font_size_override("font_size", 28)
		Ui.anchor(title, 0.0, 0.0, 0.62, 1.0, 24, 2, 0, -24)
		var tag := Ui.label("YOUR SONG", 17, Ui.WARM)
		Ui.anchor(tag, 0.0, 1.0, 0.0, 1.0, 26, -26, 200, -4)
		row.add_child(tag)
	var length: int = int(round(float(song["duration"])))
	var info := Ui.label("%d BPM   %d:%02d" % [int(round(float(song["bpm"]))), length / 60, length % 60], 22, Ui.MUTED)
	Ui.anchor(info, 0.6, 0.0, 0.78, 1.0, 0, 18, 0, -14)
	row.add_child(info)
	var bests: Array[String] = []
	for level: String in Chart.DIFFICULTIES:
		var best: Dictionary = _save.best_for(song["id"], level)
		bests.append("%s %s" % [level.left(1).to_upper(), best.get("grade", "–")])
	var grades := Ui.label("   ".join(bests), 26, Ui.WARM, HORIZONTAL_ALIGNMENT_RIGHT)
	Ui.anchor(grades, 0.78, 0.0, 1.0, 1.0, 0, 14, -24, -14, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(grades)
	if selected and _remove_armed_until > Time.get_ticks_msec():
		title.text = "Press X again to move this song to the Trash"
		title.add_theme_color_override("font_color", Ui.WARM)
	return row


func _songs_key(code: Key) -> void:
	match code:
		KEY_UP, KEY_W:
			_song_index = maxi(0, _song_index - 1)
			_remove_armed_until = 0
			_click()
			_show_songs()
		KEY_DOWN, KEY_S:
			_song_index = mini(maxi(0, _songs.size() - 1), _song_index + 1)
			_remove_armed_until = 0
			_click()
			_show_songs()
		KEY_LEFT, KEY_RIGHT, KEY_TAB, KEY_A, KEY_D:
			_difficulty = "easy" if _difficulty == "normal" else "normal"
			_click()
			_show_songs()
		KEY_ENTER, KEY_SPACE:
			if not _songs.is_empty():
				_click()
				_start_run(_songs[_song_index])
		KEY_L:
			_click()
			_open_file_picker()
		KEY_X:
			_try_remove()
		KEY_ESCAPE:
			_click()
			_show_map()


## Removing one of your songs takes a second press, and goes to the Trash so it can be restored.
func _try_remove() -> void:
	if _songs.is_empty() or _songs[_song_index]["source"] != "imported":
		return
	if _remove_armed_until > Time.get_ticks_msec():
		_remove_armed_until = 0
		var title: String = _songs[_song_index]["title"]
		var err: Error = SongLibrary.remove_import(_songs[_song_index])
		_song_index = maxi(0, _song_index - 1)
		_show_songs()
		_show_toast("Moved \"%s\" to the Trash" % title if err == OK else "Could not remove that song")
	else:
		_remove_armed_until = Time.get_ticks_msec() + 3000
		_show_songs()


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
	if _screen != Screen.IMPORT or _import_bar == null:
		return
	_import_bar.anchor_right = clampf(fraction, 0.0, 1.0)
	_import_status.text = message


func _on_import_finished(chart_path: String) -> void:
	var meta: Dictionary = Chart.read_meta(chart_path)
	for i: int in _regions.size():
		if _regions[i]["id"] == meta.get("theme", ""):
			_region_index = i
	_show_songs(str(meta.get("id", "")))
	var levels: Dictionary = meta.get("difficulties", {})
	_show_toast("Ready: %d notes on Normal, %d on Easy" % [(levels.get("normal", []) as Array).size(), (levels.get("easy", []) as Array).size()])
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
	_session.quit_to_menu.connect(_show_songs)
	_session.restart_requested.connect(func() -> void: _start_run(_current_song))
	var options := {"offset": _save.calibration}
	if _options.has("bot"):
		options["bot"] = str(_options["bot"])
	if _options.has("fast"):
		options["manual"] = true
	_session.begin(chart, highway, _stage.world, _sfx, options)


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
		news.append("NEW ROAD OPEN ON THE MAP")
	if not news.is_empty():
		var banner := Ui.label("     ".join(news), 34, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(banner, 0.0, 0.0, 1.0, 0.0, 0, 566, 0, 614, HORIZONTAL_ALIGNMENT_CENTER)
		_ui.add_child(banner)
	_hint("SPACE  drive again        ESC  songs")


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
