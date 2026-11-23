extends Node
## Game flow: title → the route (regions and their songs on one screen) → drive →
## results; plus settings (which holds the timing check) and loading your own song.
## The selected region's world keeps rolling behind every screen. The title (TitleMenu) offers
## Drive and Battle as two big cards, with How to play, Settings and Quit under them; How to play
## (the home-row guide) also shows before a new player's first drive.
##
## A song can be driven for a score or as a practice run (P on the route, or on
## the results screen after running out of gas): no fail, optionally slower, never
## saved. A player with no saved runs starts on Easy.
##
## Three levels, Easy, Normal and Hard (TAB cycles them on the route). Hard is missing from
## charts made before it: the chosen level is kept as the player's preference, and a song
## without Hard shows and plays Normal while its Hard card reads "not charted yet".
##
## The route screen shows everything at once: a strip of regions along the top,
## the selected region's songs in the middle, and the selected song's details on
## the right.
##
## The regions sit on one loop (RouteLoop). A new player picks where to start on the loop map
## (LoopMap, shown after the title and How to play until a start is picked, and on M from the route); clearing
## two songs in an open region opens the next one clockwise. Until they clear a song, the
## player can still move their start.
##
## Battles (the title's Battle card, B on the title or the route, the route's Battle button, or
## the Escape menu; scripts/battle/): up to four players race the same song at the same
## moment and the highest score wins. The battle screens (BattleScreen) host or join, show the lobby
## and the standings; the route doubles as the song picker for the draw (_battle_pick), and a race
## is an ordinary run with the battle options (no pause, a lead-in that ends on the race's start)
## and the rivals along the top (RivalBar). Battle runs are never saved.
##
## Options for automated checks, passed after "--" on the command line:
##   --bot=perfect|tapper|sloppy|afk  --song=<id>  --difficulty=easy|normal|hard
##       play a song with a bot through the real input path (add --fast for headless, no audio);
##       --difficulty also picks the level the route opens on. A song without Hard plays Normal,
##       and the printed RESULT's "difficulty" says which level actually played.
##   --muted                silence output (timing still runs on the real device)
##   --shots=DIR [--shot-at=SECONDS]   screenshots during a real-time bot run
##   --screen=title|route|map --shot=PATH [--region=<id>] [--song=<id>]   capture a screen and quit
##   --import-file=PATH [--import-title=...] [--region=<id>]   run an import without the file picker
##   --unlock-all           open every region
##   --save=NAME            keep progress in user://NAME instead of the player's save.json (tests)
##   --battle-host | --battle-join=ADDRESS  [--battle-port=N] [--battle-name=NAME]
##                          open the battle lobby on the LAN (desktop; two windows on one computer)
##   --battle-auto[=PLAYERS] [--battle-song=<id>] [--battle-bot=perfect|tapper|sloppy]
##                          suggest a song by itself, and as host draw once PLAYERS (2) are in;
##                          a bot plays the race. A WASD multiplayer test run does this on its own.

enum Screen { TITLE, ROUTE, IMPORT, CALIBRATE, PLAYING, RESULTS, SETTINGS, MAP, BATTLE, HOWTO }

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
var _title: TitleMenu
var _map: LoopMap
# Battles (see the top, and scripts/battle/battle.gd).
var _battle_screen: BattleScreen
## Which box the connect screen has open: "", "code" (online) or "address" (LAN).
var _battle_input: String = ""
var _battle_message: String = ""
## Where Escape goes from the battle's connect screen, and where leaving a battle lands: the title
## or the song select, whichever it was opened from.
var _battle_back: Callable
var _battle_busy: bool = false
## The route is picking a song for the battle's draw, not starting a drive.
var _battle_pick: bool = false
## This run is a battle race.
var _battle_racing: bool = false
var _rival_bar: RivalBar
## Lanes this player hit or missed since the last report to Battle (the rivals' mini keyboards).
var _battle_hit_lanes: int = 0
var _battle_miss_lanes: int = 0
## The draw's reveal is on screen; the race starts when it ends.
var _battle_revealing: bool = false
var _battle_auto_drawn: bool = false
var _battle_auto_suggested: bool = false
var _battle_roster_size: int = 0
var _battle_roster_changed_at: int = 0
var _battle_refresh_left: float = 0.0
var _battle_shown_ping: int = -2
## --battle-auto's host draws once this many are in and the roster has held still this long (a WASD
## test run's clients all join within a couple of seconds of the host).
const AUTO_PLAYERS := 2
const AUTO_SETTLE_MSEC := 5000
## Where Escape on the loop map goes back to: the title or the route.
var _map_back: Callable


func _ready() -> void:
	_parse_args()
	if _options.has("save"):
		SaveData.path = "user://" + str(_options["save"])
	_save = SaveData.load_or_new()
	Settings.apply(_save.settings)
	# Someone who has never finished a song starts on Easy; Normal ended a first run in seconds.
	if _save.best.is_empty():
		_difficulty = "easy"
	_settings_return = _show_title
	_load_regions()
	_adopt_old_progress()
	if _start_index() >= 0:
		_region_index = _start_index()
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
	if _options.has("difficulty") and Chart.DIFFICULTIES.has(str(_options["difficulty"])):
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
	Battle.changed.connect(_on_battle_changed)
	Battle.race_starting.connect(_on_race_starting)
	Battle.standings_changed.connect(_on_battle_standings)
	Battle.closed.connect(_on_battle_closed)
	if _options.has("battle-auto"):
		Battle.auto = true
	if _options.has("battle-name"):
		Battle.my_name = str(_options["battle-name"])
	# A WASD multiplayer test run hosts or joins on its own: wait for its lobby on the battle screen.
	if Battle.auto and OS.get_environment("WASD_MULTIPLAYER_TEST") != "":
		_show_battle()
		return
	if _options.has("battle-host") or _options.has("battle-join"):
		_show_battle()
		var port: int = int(_options.get("battle-port", Battle.PORT))
		var err: Error = Battle.host_lan(port) if _options.has("battle-host") else \
			Battle.join_lan(str(_options["battle-join"]), port)
		if err != OK:
			_battle_message = "Couldn't open the battle on port %d (error %d)." % [port, err]
		_show_battle()
		return
	match str(_options.get("screen", "title")):
		"route":
			_show_route()
		"map":
			_show_map(_show_title)
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


func _process(delta: float) -> void:
	if _battle_racing and _session and _session.judge:
		_report_race(delta)
	elif _screen == Screen.BATTLE and Battle.phase == Battle.Phase.RACING:
		# After your run, the others' live scores keep the standings moving.
		_battle_refresh_left -= delta
		if _battle_refresh_left <= 0.0:
			_battle_refresh_left = 0.5
			_present_battle()
	elif _screen == Screen.BATTLE and Battle.phase == Battle.Phase.LOBBY and Battle.ping_ms() != _battle_shown_ping:
		# The lobby's ping settles as replies come in (the first ones wait on the world loading).
		_battle_refresh_left -= delta
		if _battle_refresh_left <= 0.0:
			_battle_refresh_left = 1.0
			_battle_shown_ping = Battle.ping_ms()
			_present_battle()
	_battle_auto_tick()
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
	# Backspace does what Escape does on every screen here, because in a browser Escape belongs to
	# the page (Ui.back_key). A run's own keys are play_session.gd's: there Space pauses, and the
	# pause menu keeps Backspace for "Back to the route".
	if code == KEY_BACKSPACE:
		code = KEY_ESCAPE
	if _menu:
		_menu.handle_key(code)
		return
	match _screen:
		Screen.TITLE:
			# Arrows and Enter go to the menu (TitleMenu); every item also has its own key.
			if _title and _title.handle_key(code):
				return
			match code:
				KEY_SPACE:
					_on_title_action("drive")
				KEY_B:
					_on_title_action("battle")
				KEY_H:
					_on_title_action("how")
				KEY_S:
					_on_title_action("settings")
				KEY_Q:
					if Ui.can_quit():
						_on_title_action("quit")
				KEY_ESCAPE:
					_open_menu()
		Screen.HOWTO:
			if code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE:
				_click()
				_drive_from_title(false)
			elif code == KEY_ESCAPE:
				_click()
				_show_title()
		Screen.BATTLE:
			_battle_key(code)
		Screen.ROUTE:
			if _battle_pick:
				_battle_pick_key(code)
			else:
				_route_key(code)
		Screen.MAP:
			_map_key(code)
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
	_map = null
	_toast = null
	_battle_screen = null
	_rival_bar = null
	_title = null


func _end_session() -> void:
	if _session:
		_session.queue_free()
		_session = null


func _region_unlocked(index: int) -> bool:
	if _options.has("unlock-all"):
		return true
	return _open_regions()[index]


## Which regions are open on the loop (RouteLoop), by index in _regions.
func _open_regions() -> Array[bool]:
	return RouteLoop.open_regions(_regions.size(), _start_index(), _region_clears(), _kept_indexes())


## The regions an old save had open (SaveData.route_kept), by index in _regions.
func _kept_indexes() -> Array[int]:
	var kept: Array[int] = []
	for id: String in _save.route_kept:
		if _region_ids().has(id):
			kept.append(_region_ids().find(id))
	return kept


## Songs cleared in each region, by index in _regions.
func _region_clears() -> Array[int]:
	var clears: Array[int] = []
	for region: Dictionary in _regions:
		var count: int = 0
		for song: Dictionary in SongLibrary.in_region(region["id"]):
			if _save.cleared(song["id"]):
				count += 1
		clears.append(count)
	return clears


## The player's start on the loop, by index in _regions; -1 before they pick one.
func _start_index() -> int:
	return _region_ids().find(_save.route_start) if not _save.route_start.is_empty() else -1


## A save from before the loop started everyone at the first region and opened the next region
## on any one clear. It keeps every region it had open, with its start at the first region. Only
## in memory: it is written with the save's next change, so merely opening the game writes nothing.
func _adopt_old_progress() -> void:
	if not _save.route_start.is_empty() or _save.best.is_empty() or _regions.is_empty():
		return
	_save.route_start = str(_regions[0]["id"])
	_save.route_kept.clear()
	for index: int in RouteLoop.old_chain_open(_regions.size(), _region_clears()):
		_save.route_kept.append(str(_regions[index]["id"]))


## Why a region is locked, for the route's locked notice and the Drive button's toast.
func _locked_text(index: int) -> String:
	var count: int = _regions.size()
	var before: String = str(_regions[(index - 1 + count) % count]["name"])
	var needs: int = RouteLoop.clears_needed(index, count, _start_index(), _region_clears(), _kept_indexes())
	if needs > 0:
		return "Locked: clear %d more song%s in %s to open this road." % [needs, "" if needs == 1 else "s", before]
	return "Locked: open %s first. Two clears in a region open the next one round the loop (M for the map)." % before


func _accent(region: Dictionary) -> Color:
	return Ui.color_from_hex(str(region.get("accent", "#3fd8ff")))


func _hint(text: String) -> void:
	# The hints are written with Escape; the web build names Backspace instead (Ui.back_key).
	text = text.replace("ESC  ", Ui.back_key() + "  ")
	var hint := Ui.shrink_to_fit(Ui.caption(text, 22, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Ui.DESIGN_WIDTH - 80.0, 15)
	Ui.anchor(hint, 0.0, 1.0, 1.0, 1.0, 0, -60, 0, -26, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(hint)


func _show_toast(text: String) -> void:
	if _toast and is_instance_valid(_toast):
		_toast.queue_free()
	_toast = Ui.shrink_to_fit(Ui.label(text, 26, Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER), Ui.DESIGN_WIDTH - 80.0, 16)
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

## The title: Drive and Battle side by side as big cards, with How to play, Settings and Quit
## under them (TitleMenu). The home-row guide that used to fill the title is How to play's now,
## and a new player sees it before their first drive.
func _show_title() -> void:
	_end_session()
	_clear_ui()
	_screen = Screen.TITLE
	_show_world(_regions[_region_index]["id"])
	_ambient.volume_db = -9.0
	_title = TitleMenu.new()
	_title.acted.connect(_on_title_action)
	_title.moved.connect(_click)
	_ui.add_child(_title)
	_title.present(_title_model())


func _title_model() -> Dictionary:
	var built_in: int = SongLibrary.all().filter(func(s: Dictionary) -> bool: return s["source"] != "imported").size()
	var cleared: int = 0
	for count: int in _region_clears():
		cleared += count
	var drive_status: String = "First drive: pick where you start on the loop."
	if _start_index() >= 0 or _options.has("unlock-all"):
		drive_status = "Back to %s  ·  %d songs cleared" % [str(_regions[_region_index]["name"]), cleared]
	var battle_status: String = "Needs the browser version, or the same network."
	if Battle.phase != Battle.Phase.NONE:
		battle_status = "You're in a battle: back to the lobby."
	elif Battle.online_available():
		battle_status = "Online: friends join with your code."
	elif Battle.lan_available():
		battle_status = "Same Wi-Fi: friends join by address."
	return {
		"drive": {"line": "On your own, round the loop: %d songs across five regions." % built_in, "status": drive_status},
		"battle": {"line": "Race up to 3 friends through one song, all at once.", "status": battle_status, "new": true},
		"can_quit": Ui.can_quit(),
	}


func _on_title_action(action: String) -> void:
	_click()
	match action:
		"drive":
			_drive_from_title(true)
		"battle":
			_open_battle(_show_title)
		"how":
			_show_how_to_play()
		"settings":
			_open_settings(_show_title)
		"quit":
			get_tree().quit()


## Drive on the title: the song select, or for a player who has not picked a start yet, How to
## play (when `teach`) and then the loop map.
func _drive_from_title(teach: bool) -> void:
	if _start_index() < 0 and not _options.has("unlock-all"):
		if teach:
			_show_how_to_play()
		else:
			_show_map(_show_title)
	else:
		_show_route()


## How to play: what the notes are, the home row with each finger's colour, and gas. A new player
## sees it on their first Drive; anyone can open it from the title.
func _show_how_to_play() -> void:
	_end_session()
	_clear_ui()
	_screen = Screen.HOWTO
	_show_world(_regions[_region_index]["id"])
	_ambient.volume_db = -9.0
	_ui.add_child(Ui.dim_panel(0.62))
	var heading := Ui.heading("HOW TO PLAY", 84, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(heading, 0.0, 0.0, 1.0, 0.0, 0, 56, 0, 156, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(heading)
	var intro := Ui.shrink_to_fit(Ui.label("Notes roll down the highway to the keyboard at its foot. Press each one's key as it arrives.",
		28, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER), Ui.DESIGN_WIDTH - 80.0, 18)
	Ui.anchor(intro, 0.0, 0.0, 1.0, 0.0, 40, 170, -40, 212, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(intro)
	_ui.add_child(_home_row_guide(236.0))
	var gas := Ui.shrink_to_fit(Ui.label("Hits keep your tank full and misses drain it: run out of gas and the drive is over. Hold long notes to their end.",
		24, Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER), Ui.DESIGN_WIDTH - 80.0, 16)
	Ui.anchor(gas, 0.0, 0.0, 1.0, 0.0, 40, 512, -40, 550, HORIZONTAL_ALIGNMENT_CENTER)
	_ui.add_child(gas)
	var go := Ui.card(true)
	Ui.anchor(go, 0.5, 0.0, 0.5, 0.0, -230, 600, 230, 676)
	_on_click(go, func() -> void:
		_click()
		_drive_from_title(false))
	_ui.add_child(go)
	var go_key := Ui.caption("ENTER", 22, Ui.ACCENT)
	Ui.anchor(go_key, 0.0, 0.0, 0.0, 1.0, 26, 24, 120, -22)
	go.add_child(go_key)
	var go_text := Ui.label("Let's drive", 34, Ui.TEXT)
	Ui.anchor(go_text, 0.0, 0.0, 1.0, 1.0, 132, 10, -20, -10)
	go.add_child(go_text)
	_hint("ENTER  drive        ESC  back")


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
	var note := Ui.shrink_to_fit(Ui.label("Notes arrive in the colour of the finger that plays them. Index fingers reach for G and H; Easy never uses them.", 24, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER), 1120.0, 16)
	Ui.anchor(note, 0.0, 0.0, 1.0, 0.0, -100, 140, 100, 176, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(note)
	var sharps := Ui.shrink_to_fit(Ui.label("On Normal and Hard, sharps arrive in orange: play them on the row above, W E R T Y U I O P, between the home keys.", 24, Color(1.0, 0.62, 0.25), HORIZONTAL_ALIGNMENT_CENTER), 1200.0, 16)
	Ui.anchor(sharps, 0.0, 0.0, 1.0, 0.0, -140, 178, 140, 214, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(sharps)
	# Hard's new thing, in the power chords' own white.
	var power := Ui.shrink_to_fit(Ui.label("On Hard, power chords: notes joined by a white bar. Strike them together.", 24, Highway.COLOR_POWER, HORIZONTAL_ALIGNMENT_CENTER), 1200.0, 16)
	Ui.anchor(power, 0.0, 0.0, 1.0, 0.0, -140, 216, 140, 252, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(power)
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
	if _battle_pick and message.is_empty():
		message = "Pick a song for the battle's draw: ENTER puts it in.  %s goes back to the lobby." % Ui.back_key()
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


## The loop map (LoopMap): where a new player picks a start, and where anyone sees how far round
## the loop they have opened. `back` is where Escape goes; `focus` the region to show first.
func _show_map(back: Callable, focus: int = -1) -> void:
	_end_session()
	if focus >= 0:
		_region_index = focus
	_clear_ui()
	_screen = Screen.MAP
	_map_back = back
	# Drawn in 2D like the song select: no 3D world behind it. The region's ambience plays.
	get_viewport().disable_3d = true
	_play_ambience(_regions[_region_index]["id"])
	_ambient.volume_db = -9.0
	_map = LoopMap.new()
	_map.acted.connect(_on_map_action)
	_ui.add_child(_map)
	_map.present(_map_model())


## Everything the map draws (the model is documented in LoopMap).
func _map_model() -> Dictionary:
	var count: int = _regions.size()
	var start: int = _start_index()
	var open: Array[bool] = _open_regions()
	var clears: Array[int] = _region_clears()
	var kept: Array[int] = _kept_indexes()
	var stops: Array = []
	for i: int in count:
		var region: Dictionary = _regions[i]
		stops.append({"id": region["id"], "name": region["name"], "genres": region.get("genres", ""),
			"blurb": region.get("blurb", ""), "cleared": clears[i], "total": SongLibrary.in_region(region["id"]).size(),
			# Before a start is picked every stop is drawn open: any of them can be the start.
			"open": start < 0 or open[i] or _options.has("unlock-all"),
			"needs": RouteLoop.clears_needed(i, count, start, clears, kept),
			"prev_name": _regions[(i - 1 + count) % count]["name"], "start": i == start})
	return {"regions": stops, "focus": _region_index, "picking": _can_pick_start(), "chosen": start >= 0}


## A start can be picked, or moved, until the player clears a song.
func _can_pick_start() -> bool:
	if _options.has("unlock-all"):
		return false
	return _start_index() < 0 or not _region_clears().any(func(c: int) -> bool: return c > 0)


func _map_key(code: Key) -> void:
	match code:
		KEY_LEFT, KEY_UP:
			_map_focus(_region_index - 1)
		KEY_RIGHT, KEY_DOWN:
			_map_focus(_region_index + 1)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_map_focus(int(code) - int(KEY_1))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_map_pick(_region_index)
		KEY_ESCAPE:
			_click()
			_map_back.call()


func _on_map_action(action: String, arg: Variant) -> void:
	match action:
		"node":
			if int(arg) == _region_index:
				_map_pick(int(arg))
			else:
				_map_focus(int(arg))
		"pick":
			_map_pick(_region_index)


func _map_focus(index: int) -> void:
	var wrapped: int = wrapi(index, 0, _regions.size())
	if wrapped == _region_index or _map == null:
		return
	_region_index = wrapped
	_click()
	_play_ambience(_regions[_region_index]["id"])
	_map.present(_map_model())


## Enter on a stop: start there (while a start can be picked), drive it if open, or say why not.
func _map_pick(index: int) -> void:
	var region: Dictionary = _regions[index]
	if _can_pick_start():
		_save.route_start = str(region["id"])
		_save.route_kept.clear()
		_save.write()
		_region_index = index
		(_sfx["milestone"] as AudioStreamPlayer).play()
		var next_name: String = str(_regions[RouteLoop.next(index, _regions.size())]["name"])
		_show_route("Starting in %s. Clear 2 songs here to open %s." % [region["name"], next_name])
	elif _region_unlocked(index):
		_region_index = index
		_click()
		_show_route()
	else:
		(_sfx["wrong"] as AudioStreamPlayer).play()
		_show_toast(_locked_text(index))


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
			"grades": _grades_text(song), "level": SongLibrary.level_of(song, _level_for(song)), "selected": index == selected,
			"imported": song["source"] == "imported", "freq": _dial_frequency(index, _songs.size())})
	var detail: Dictionary = {}
	var cards: Array = []
	if not _songs.is_empty():
		var song: Dictionary = _songs[selected]
		var length: int = int(round(float(song["duration"])))
		detail = {"title": song["title"], "upper": str(song["title"]).to_upper(), "bpm": int(round(float(song["bpm"]))),
			"length": "%d:%02d" % [length / 60, length % 60], "number": selected + 1,
			"best": str(_save.best_for(song["id"], _level_for(song)).get("grade", "")), "imported": song["source"] == "imported",
			"remove_armed": _remove_armed_until > Time.get_ticks_msec(), "station": str(song.get("station", ""))}
		cards = _difficulty_cards(song)
	var practising: bool = _practice_step > 0
	return {
		"regions": tabs,
		"region": {"name": region["name"], "upper": str(region["name"]).to_upper(), "genres": region.get("genres", ""),
			"blurb": region.get("blurb", ""), "locked": not unlocked,
			"locked_text": _locked_text(_region_index)},
		"rows": rows, "count": _songs.size(), "song": detail, "cards": cards,
		"practice": {"on": practising, "text": ("%d%% speed" % int(round(PRACTICE_SPEEDS[_practice_step] * 100.0))) if practising else "off"},
		"locked": not unlocked, "message": message,
		# The battle button in the hints row (RouteSkin.BATTLE): into a battle, or while picking the
		# battle's song, back to its lobby; and while picking, Enter puts the song in the draw.
		"battle": {"text": "BACK TO LOBBY" if _battle_pick else "BATTLE", "key": "B"},
		"drive_text": "ENTER PICK SONG" if _battle_pick else "",
	}


## The level a song plays at: the chosen one, or Normal where the song has no Hard chart yet.
func _level_for(song: Dictionary) -> String:
	if SongLibrary.has_level(song, _difficulty):
		return _difficulty
	return "normal"


## The chosen level moved on by `step` (TAB: Easy, Normal, Hard, round again), skipping a level
## the song has no chart for.
func _cycle_difficulty(song: Dictionary, step: int) -> String:
	var at: int = maxi(Chart.DIFFICULTIES.find(_difficulty if song.is_empty() else _level_for(song)), 0)
	for i: int in range(1, Chart.DIFFICULTIES.size() + 1):
		var level: String = Chart.DIFFICULTIES[wrapi(at + step * i, 0, Chart.DIFFICULTIES.size())]
		if song.is_empty() or SongLibrary.has_level(song, level):
			return level
	return _difficulty


## "E– N– H–", with each difficulty's best grade in place of the dash once it has one.
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


## The Easy, Normal and Hard cards: level, notes and holds, which keys, and what makes it hard.
## A level the song has no chart for (Hard, on charts made before it) is {"available": false}.
## Three cards share the space two had, so the keys line is short ("10 keys + 12 sharps").
func _difficulty_cards(song: Dictionary) -> Array:
	var cards: Array = []
	var meta: Dictionary = Chart.read_meta(song["path"])
	var levels: Dictionary = meta.get("difficulties", {})
	var playing: String = _level_for(song)
	for level: String in Chart.DIFFICULTIES:
		if not SongLibrary.has_level(song, level):
			cards.append({"name": level.to_upper(), "key": level, "available": false, "level": 0, "notes": 0, "holds": 0,
				"counts": "", "keys": "", "sharps": 0, "power": 0, "feel": "Not charted yet", "selected": false, "best": ""})
			continue
		var notes: Array = levels.get(Chart.resolve_level(meta, level), meta.get("notes", []))
		var holds: int = 0
		var reach: bool = false
		var sharps: int = 0
		var power_times: Dictionary = {}
		for n: Dictionary in notes:
			if float(n["d"]) >= Chart.HOLD_MIN_SECONDS:
				holds += 1
			if int(n.get("s", 0)) == 1:
				sharps += 1
			elif KeyMap.REACH.has(int(n.get("l", 0))):
				reach = true
			if int(n.get("pw", 0)) == 1:
				power_times[snappedf(float(n["t"]), Chart.CHORD_SECONDS)] = true
		var keys: String = "8 resting keys"
		if sharps > 0:
			keys = "10 keys + %d sharp%s" % [sharps, "" if sharps == 1 else "s"]
		elif reach:
			keys = "10 keys, adds G and H"
		var rating: Dictionary = (song.get("ratings", {}) as Dictionary).get(level, {})
		var reasons: Array = (rating.get("reasons", []) as Array).duplicate()
		# Power chords are rare by design (the biggest hits only), so the rating never names them;
		# the card does, first, since they are the new thing to play.
		if not power_times.is_empty():
			reasons = ["power chords"] + reasons.slice(0, 1)
		var feel: String = "Steady and even"
		if not reasons.is_empty():
			feel = ", ".join(reasons)
			feel = feel.left(1).to_upper() + feel.substr(1)
		var counts: String = "%d note%s · %d hold%s" % [notes.size(), "" if notes.size() == 1 else "s", holds, "" if holds == 1 else "s"]
		cards.append({"name": level.to_upper(), "key": level, "available": true, "level": Difficulty.level_of(rating),
			"notes": notes.size(), "holds": holds, "counts": counts, "keys": keys, "sharps": sharps, "power": power_times.size(),
			"feel": feel, "selected": level == playing, "best": str(_save.best_for(song["id"], level).get("grade", ""))})
	return cards


func _on_route_action(action: String, arg: Variant) -> void:
	# Picking for a battle: driving a song puts it in the draw; the host chooses the level, and
	# practice and loading songs belong to the drive.
	if _battle_pick:
		match action:
			"drive":
				_battle_suggest_selected()
				return
			"song":
				if int(arg) == _selected_index():
					_battle_suggest_selected()
					return
			"difficulty":
				_show_toast("The host picks the level everyone races.")
				return
			"practice", "load":
				return
			"battle":
				_click()
				_show_battle()
				return
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
			var song: Dictionary = _songs[_selected_index()] if not _songs.is_empty() else {}
			if not song.is_empty() and not SongLibrary.has_level(song, str(arg)):
				_show_toast("%s is not charted for this song yet." % str(arg).capitalize())
			elif _level_for(song) != str(arg) or _difficulty != str(arg):
				_difficulty = str(arg)
				_click()
				_show_route()
		"practice":
			_step_practice()
		"drive":
			_drive_selected()
		"load":
			_open_file_picker()
		"battle":
			_click()
			_open_battle(_show_route)


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
			_difficulty = _cycle_difficulty(_songs[_selected_index()] if not _songs.is_empty() else {}, 1)
			_click()
			_show_route()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_drive_selected()
		KEY_L:
			_click()
			_open_file_picker()
		KEY_B:
			_click()
			_open_battle(_show_route)
		KEY_P:
			_click()
			_step_practice()
		KEY_S:
			_click()
			_open_settings(_show_route)
		KEY_X:
			_try_remove()
		KEY_M:
			_click()
			_show_map(_show_route, _region_index)
		KEY_ESCAPE:
			_open_menu()


## Escape on the title or route: carry on, settings, back to the title, or quit the game.
func _open_menu() -> void:
	if _menu:
		return
	_click()
	var back: Callable = _show_title if _screen == Screen.TITLE else _show_route
	var items: Array[Dictionary] = [
		{"text": "Resume", "key_text": Ui.back_key(), "action": _close_menu},
		{"text": "Battle", "key": KEY_B, "key_text": "B", "action": func() -> void:
			_close_menu()
			_open_battle(back)},
		{"text": "Settings", "key": KEY_S, "key_text": "S", "action": func() -> void:
			_close_menu()
			_open_settings(back)},
	]
	if _screen == Screen.ROUTE:
		items.append({"text": "Title screen", "key": KEY_T, "key_text": "T", "action": func() -> void:
			_close_menu()
			_show_title()})
	if Ui.can_quit():
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
		_show_toast(_locked_text(_region_index))
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
	var ready: String = "Ready: \"%s\", %d notes on Normal, %d on Easy" % [meta.get("title", ""),
		(levels.get("normal", []) as Array).size(), (levels.get("easy", []) as Array).size()]
	if Chart.has_level(meta, "hard"):
		ready += ", %d on Hard" % (levels["hard"] as Array).size()
	_show_route(ready)
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

## `battle` is a race's {"level", "zero"} (Battle.race, song time 0 on this computer's clock), or {}.
func _start_run(song: Dictionary, battle: Dictionary = {}) -> void:
	assert(not song.is_empty(), "Unknown song")
	_current_song = song
	_song_choice[song["theme"]] = song["id"]
	_end_session()
	_clear_ui()
	_screen = Screen.PLAYING
	_battle_racing = not battle.is_empty()
	var chart := Chart.load_file(song["path"], str(battle["level"]) if _battle_racing else _level_for(song))
	var highway: Highway = _stage.show_chart(chart.theme, chart)
	_play_ambience(chart.theme)
	_ambient.volume_db = -18.0
	_session = PlaySession.new()
	add_child(_session)
	_session.finished.connect(_on_run_finished)
	_session.quit_to_menu.connect(func() -> void:
		if _battle_racing:
			_leave_battle("You left the battle.")
		else:
			_show_route())
	_session.restart_requested.connect(func() -> void: _start_run(_current_song))
	var options := {"offset": _save.calibration, "stage": _stage}
	if _practice_step > 0 and not _options.has("bot") and not _battle_racing:
		options["practice"] = true
		options["speed"] = PRACTICE_SPEEDS[_practice_step]
	if _options.has("bot"):
		options["bot"] = str(_options["bot"])
	if _options.has("fast"):
		options["manual"] = true
	if _battle_racing:
		options["battle"] = true
		# However long the draw and the world took here, the song starts at the race's moment.
		options["lead_in"] = maxf(float(int(battle["zero"]) - Time.get_ticks_usec()) / 1000000.0, 0.5)
		if _options.has("battle-bot") or Battle.auto:
			options["bot"] = str(_options.get("battle-bot", "sloppy"))
	_session.begin(chart, highway, _stage.world, _sfx, options)
	if _battle_racing:
		# The rivals' mini keyboards light the lanes each racer hits and misses (RivalBar).
		_battle_hit_lanes = 0
		_battle_miss_lanes = 0
		_session.judge.note_hit.connect(func(n: Chart.Note, _verdict: String, _offset: float) -> void:
			_battle_hit_lanes |= 1 << n.lane)
		_session.judge.note_missed.connect(func(n: Chart.Note) -> void: _battle_miss_lanes |= 1 << n.lane)
		_rival_bar = RivalBar.new()
		# Under the run's own HUD layer, below the leave menu the run opens over it.
		_session.hud().add_child(_rival_bar)
		_session.hud().move_child(_rival_bar, 0)


## The next song in this region, or the first of the next region once it is open.
func _drive_next() -> void:
	var songs: Array[Dictionary] = SongLibrary.in_region(_current_song["theme"])
	var at: int = songs.map(func(s: Dictionary) -> String: return s["id"]).find(_current_song["id"])
	if at >= 0 and at + 1 < songs.size():
		_start_run(songs[at + 1])
		return
	# On round the loop: after the last region comes the first.
	var region_at: int = _region_ids().find(_current_song["theme"])
	var next_region: int = RouteLoop.next(region_at, _regions.size())
	if region_at >= 0 and next_region != region_at and _region_unlocked(next_region):
		var next_songs: Array[Dictionary] = SongLibrary.in_region(_regions[next_region]["id"])
		if not next_songs.is_empty():
			_region_index = next_region
			_start_run(next_songs[0])
			return
	_show_route("That was the last open song here. Pick another on the route.")


func _on_run_finished(result: Dictionary) -> void:
	if _options.has("fast"):
		return
	if _battle_racing:
		# A battle run is never saved: its numbers go to the others, and the standings take over.
		_report_race(0.0)
		_battle_racing = false
		Battle.finish(result)
		_stage.world.set_target_speed(0.0 if result["failed"] else 0.6)
		_ambient.volume_db = -9.0
		print("BATTLE_RESULT ", JSON.stringify({"me": Battle.me(), "score": result["score"], "failed": result["failed"]}))
		_show_battle()
		return
	var open_before: Array[bool] = _open_regions()
	var new_best: bool = false
	_last_result = result
	if not _options.has("bot") and not result.get("practice", false):
		new_best = _save.record(result)
	_stage.world.set_target_speed(0.0 if result["failed"] else 0.6)
	_ambient.volume_db = -9.0
	var opened_region: String = _newly_opened(open_before)
	# One fanfare, kept for the runs that changed something: a new best or a new road.
	if new_best or not opened_region.is_empty():
		(_sfx["clear"] as AudioStreamPlayer).play()
	_show_results(result, new_best, opened_region)
	if _options.has("bot"):
		print("RESULT ", JSON.stringify(result))
		print("TIMING ", JSON.stringify(_session.timing))
		if _options.has("shots"):
			await get_tree().create_timer(1.0).timeout
			_save_shot(str(_options["shots"]).path_join("results.png"))
		get_tree().quit()


## The name of the region this run opened, or "".
func _newly_opened(open_before: Array[bool]) -> String:
	if _options.has("unlock-all"):
		return ""
	var open_now: Array[bool] = _open_regions()
	for i: int in open_now.size():
		if open_now[i] and not open_before[i]:
			return str(_regions[i]["name"])
	return ""


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


func _show_results(result: Dictionary, new_best: bool, opened_region: String) -> void:
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
	if not opened_region.is_empty():
		news.append("NEW ROAD OPEN: %s" % opened_region.to_upper())
	if not news.is_empty():
		var banner := Ui.label("     ".join(news), 34, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(banner, 0.0, 0.0, 1.0, 0.0, 0, 656, 0, 704, HORIZONTAL_ALIGNMENT_CENTER)
		_ui.add_child(banner)
	if failed:
		_hint("SPACE  try again        P  practise it (no fail, slower)        ESC  route")
	else:
		_hint("ENTER  next song        SPACE  drive again        ESC  route")


# ---------------------------------------------------------------- battles

## The battle screens (BattleScreen) for wherever the battle is: connecting, the lobby, or the
## standings after a race. The region's world rolls on behind, as on the title.
## Opens the battle screens from the title or the song select; `back` is where Escape returns to
## before joining one, and where leaving one lands.
func _open_battle(back: Callable) -> void:
	_battle_back = back
	_show_battle()


func _battle_exit() -> void:
	if _battle_back.is_valid():
		_battle_back.call()
	else:
		_show_title()


func _show_battle() -> void:
	_end_session()
	_battle_pick = false
	_battle_racing = false
	_clear_ui()
	_screen = Screen.BATTLE
	_show_world(_regions[_region_index]["id"])
	_ambient.volume_db = -9.0
	_battle_screen = BattleScreen.new()
	_battle_screen.acted.connect(_on_battle_action)
	_ui.add_child(_battle_screen)
	_present_battle()


func _present_battle() -> void:
	# The draw's reveal covers the screen until the race starts; nothing under it needs redrawing.
	if _battle_screen == null or _battle_revealing:
		return
	match Battle.phase:
		Battle.Phase.NONE:
			_battle_screen.present({"kind": "connect", "online": Battle.online_available(), "lan": Battle.lan_available(),
				"input": _battle_input, "busy": _battle_busy, "message": _battle_message})
		Battle.Phase.LOBBY:
			_battle_screen.present(_battle_lobby_model())
		_:
			# The race has started but this player hasn't driven it yet (the draw's reveal is about to
			# cover the screen): no standings of a race nobody has started.
			if Battle.phase == Battle.Phase.RACING and not Battle.results.has(Battle.me()):
				_battle_screen.present({"kind": "blank"})
			else:
				_battle_screen.present(_battle_standings_model())


func _battle_lobby_model() -> Dictionary:
	var slots: Array = []
	var ids: Array = Battle.roster.keys()
	ids.sort()
	for id: int in ids:
		var entry: Dictionary = Battle.roster[id]
		var song: Dictionary = SongLibrary.find(str(entry.get("suggestion", ""))) if str(entry.get("suggestion", "")) != "" else {}
		slots.append({"empty": false, "name": str(entry["name"]), "host": id == 1, "me": id == Battle.me(),
			"suggestion": "" if song.is_empty() else str(song["title"])})
	var picks: int = Battle.suggestions().size()
	var note: String = "%d song%s in the draw. ENTER draws one and the race starts." % [picks, "" if picks == 1 else "s"]
	if Battle.roster.size() < 2:
		note = "Waiting for at least one more driver to join."
	elif picks == 0:
		note = "Waiting for a song pick: S to pick yours."
	return {"kind": "lobby", "code": Battle.lobby_code, "transport": Battle.transport, "slots": slots,
		"difficulty": Battle.difficulty, "is_host": Battle.is_host(), "can_draw": Battle.can_draw(), "draw_note": note,
		"ping": Battle.ping_ms(), "message": _battle_message}


func _battle_standings_model() -> Dictionary:
	var final: bool = Battle.race_over()
	var standings: Array = Battle.standings()
	var rows: Array = []
	for i: int in standings.size():
		var row: Dictionary = standings[i]
		var result: Dictionary = row["result"]
		var state: int = int(row["state"])
		var detail: String = "still driving  ·  %d%% of the song" % int(float(Battle.live.get(row["peer"], {}).get("progress", 0.0)) * 100.0)
		if state == Battle.STATE_LEFT:
			detail = "left the battle"
		elif not result.is_empty() and bool(result.get("failed", false)):
			detail = "out of gas at %d%% of the song" % int(round(float(result.get("progress", 0.0)) * 100.0))
		elif not result.is_empty():
			detail = "grade %s  ·  accuracy %d%%  ·  max combo %d" % [str(result.get("grade", "")),
				int(round(float(result.get("accuracy", 0.0)) * 100.0)), int(result.get("max_combo", 0))]
		rows.append({"place": RivalBar.ORDINALS[mini(i, 3)], "name": str(row["name"]), "score": int(row["score"]),
			"detail": detail, "me": bool(row["me"]), "dim": state == Battle.STATE_LEFT or (not final and result.is_empty())})
	var headline: String = "WAITING FOR THE OTHERS"
	if final and not standings.is_empty():
		headline = "YOU WIN" if bool(standings[0]["me"]) else "%s WINS" % str(standings[0]["name"]).to_upper()
	return {"kind": "standings", "final": final, "headline": headline, "rows": rows, "is_host": Battle.is_host()}


func _battle_key(code: Key) -> void:
	match Battle.phase:
		Battle.Phase.NONE:
			if _battle_busy:
				return
			var can: bool = Battle.online_available() or Battle.lan_available()
			if code == KEY_H and can:
				_click()
				_battle_host()
			elif code == KEY_J and can:
				_click()
				_battle_open_join()
			elif code == KEY_ESCAPE:
				_click()
				_battle_message = ""
				_battle_input = ""
				_battle_exit()
		Battle.Phase.LOBBY:
			match code:
				KEY_C:
					# The code (or address) to the clipboard, to paste to friends.
					_click()
					_battle_screen.copy_code()
				KEY_S:
					_click()
					_battle_pick = true
					_show_route()
				KEY_TAB:
					if Battle.is_host():
						_click()
						var at: int = BattleScreen.LEVELS.find(Battle.difficulty)
						Battle.set_difficulty(BattleScreen.LEVELS[wrapi(at + 1, 0, BattleScreen.LEVELS.size())])
				KEY_ENTER, KEY_KP_ENTER:
					if Battle.can_draw():
						_click()
						Battle.draw()
				KEY_ESCAPE:
					_click()
					_leave_battle("You left the battle.")
		_:
			if (code == KEY_ENTER or code == KEY_KP_ENTER) and Battle.is_host() and Battle.race_over():
				_click()
				Battle.back_to_lobby()
			elif code == KEY_ESCAPE:
				_click()
				_leave_battle("You left the battle.")


func _on_battle_action(action: String, arg: Variant) -> void:
	match action:
		"host":
			if not _battle_busy:
				_battle_host()
		"join":
			if not _battle_busy:
				_battle_open_join()
		"submit":
			if not _battle_busy:
				_battle_join(str(arg))
		"cancel_input":
			_battle_input = ""
			_present_battle()
		"difficulty":
			Battle.set_difficulty(str(arg))
		"suggest":
			_battle_pick = true
			_show_route()
		"draw":
			Battle.draw()
		"copied":
			_click()
		"back":
			# The Back / Leave button does what Escape does on that screen.
			_battle_key(KEY_ESCAPE)


## Before an online Host or Join: a player WASD said isn't signed in, and gave a sign-in page for,
## gets that page in a new tab on this press (a browser opens tabs only right after a key press or
## click). Returns true when it opened, and the press does nothing else.
func _battle_open_sign_in() -> bool:
	if not Battle.online_available() or Battle.sign_in_url.is_empty():
		return false
	OS.shell_open(Battle.sign_in_url)
	Battle.sign_in_url = ""
	_battle_message = "Sign in to WASD Engine in the new tab, then come back here and press H to host or J to join."
	_present_battle()
	return true


## J or the Join card: the box for the lobby code (online) or the host's address (LAN). Online, the
## player signs in to WASD now, from this press, so a sign-in problem shows before they type a code.
func _battle_open_join() -> void:
	if _battle_open_sign_in():
		return
	_battle_input = "code" if Battle.online_available() else "address"
	_battle_message = ""
	if not Battle.online_available():
		_present_battle()
		return
	_battle_busy = true
	_battle_message = "Signing in with WASD Engine..."
	_present_battle()
	var signed: Dictionary = await Battle.sign_in_online("J")
	_battle_busy = false
	_battle_message = "" if signed.get("ok", false) else str(signed.get("message", ""))
	if not signed.get("ok", false):
		_battle_input = ""
	if _screen == Screen.BATTLE:
		_present_battle()


func _battle_host() -> void:
	_battle_message = ""
	if _battle_open_sign_in():
		return
	if Battle.online_available():
		_battle_busy = true
		_battle_message = "Signing in with WASD Engine and opening a lobby..."
		_present_battle()
		var result: Dictionary = await Battle.host_online()
		_battle_busy = false
		_battle_message = "" if result.get("ok", false) else str(result.get("message", "Couldn't open a lobby."))
	elif Battle.lan_available():
		var err: Error = Battle.host_lan(int(_options.get("battle-port", Battle.PORT)))
		if err != OK:
			_battle_message = "Couldn't open a battle on this network (error %d). Is one already open on this computer?" % err
	if _screen == Screen.BATTLE:
		_present_battle()


func _battle_join(text: String) -> void:
	text = text.strip_edges()
	if _battle_open_sign_in():
		return
	if Battle.online_available():
		if text.length() != 6:
			_battle_message = "A lobby code has six letters."
			_present_battle()
			return
		_battle_busy = true
		_battle_message = "Joining %s..." % text.to_upper()
		_present_battle()
		var result: Dictionary = await Battle.join_online(text)
		_battle_busy = false
		_battle_message = "" if result.get("ok", false) else str(result.get("message", "Couldn't join that lobby."))
		if result.get("ok", false):
			_battle_input = ""
	else:
		var err: Error = Battle.join_lan(text if not text.is_empty() else "127.0.0.1", int(_options.get("battle-port", Battle.PORT)))
		_battle_message = "Connecting to %s..." % text if err == OK else "Couldn't reach that address (error %d)." % err
		if err == OK:
			_battle_input = ""
	if _screen == Screen.BATTLE:
		_present_battle()


## The route as the battle's song picker (_battle_pick): the drive keys put the song in the draw.
func _battle_pick_key(code: Key) -> void:
	match code:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_battle_suggest_selected()
		KEY_ESCAPE, KEY_B:
			_click()
			_show_battle()
		KEY_P, KEY_L, KEY_X, KEY_S, KEY_M, KEY_TAB:
			pass
		_:
			_route_key(code)


func _battle_suggest_selected() -> void:
	if _songs.is_empty():
		return
	var song: Dictionary = _songs[_selected_index()]
	if not _region_unlocked(_region_index):
		_show_toast(_locked_text(_region_index))
		return
	if song["source"] == "imported":
		_show_toast("Your own songs are only on your computer: pick one of the built-in songs.")
		return
	_click()
	Battle.suggest(str(song["id"]))
	_battle_message = "You put %s in the draw." % str(song["title"])
	_show_battle()


func _on_battle_changed() -> void:
	if _screen == Screen.BATTLE:
		_present_battle()
	if Battle.roster.size() != _battle_roster_size:
		_battle_roster_size = Battle.roster.size()
		_battle_roster_changed_at = Time.get_ticks_msec()


## The draw is in: the reveal plays out, then the race starts at the moment every racer shares.
func _on_race_starting(song_id: String, level: String, pool: Array, zero_usec: int) -> void:
	var song: Dictionary = SongLibrary.find(song_id)
	if song.is_empty():
		push_error("Battle: no song %s here" % song_id)
		return
	print("BATTLE_EVENT ", JSON.stringify({"event": "draw", "song": song_id, "level": level, "pool": pool}))
	if _screen != Screen.BATTLE:
		_show_battle()
	_battle_message = ""
	var titles: Array = pool.map(func(id: Variant) -> String: return str(SongLibrary.find(str(id)).get("title", id)))
	var region_at: int = _region_ids().find(song["theme"])
	var region_name: String = str(_regions[region_at]["name"]) if region_at >= 0 else ""
	var reveal_seconds: float = maxf(float(zero_usec - Time.get_ticks_usec()) / 1000000.0 - Battle.LEAD_SECONDS, 0.0)
	_battle_revealing = true
	_battle_screen.play_reveal(titles, pool.find(song_id), str(song["title"]),
		"%s  ·  %s" % [level.to_upper(), region_name.to_upper()], reveal_seconds)
	await get_tree().create_timer(reveal_seconds).timeout
	_battle_revealing = false
	if Battle.phase != Battle.Phase.RACING:
		return  # the battle closed during the reveal
	_start_run(song, {"level": level, "zero": zero_usec})


func _on_battle_standings() -> void:
	if _screen == Screen.BATTLE:
		_present_battle()
	if Battle.race_over():
		var final: Array = Battle.standings().map(func(r: Dictionary) -> Array: return [r["name"], r["score"]])
		print("BATTLE_EVENT ", JSON.stringify({"event": "standings", "rows": final}))


func _on_battle_closed(reason: String) -> void:
	_battle_racing = false
	_battle_pick = false
	_battle_busy = false
	_battle_input = ""
	_battle_revealing = false
	_battle_message = reason
	if _screen == Screen.BATTLE or _screen == Screen.PLAYING or _screen == Screen.ROUTE:
		_show_battle()


func _leave_battle(message: String) -> void:
	_battle_racing = false
	Battle.leave()
	_battle_message = ""
	_battle_exit()
	_show_toast(message)


## Every frame of a race: this run's numbers to the others, and the rivals' panels.
func _report_race(delta: float) -> void:
	var judge: Judge = _session.judge
	var progress: float = clampf(_session.clock.now() / maxf(_session.chart.last_note_end(), 0.001), 0.0, 1.0)
	Battle.report(judge.score(), judge.combo, judge.fuel, judge.hits, judge.misses, progress, _battle_hit_lanes,
		_battle_miss_lanes, judge.fuel <= 0.0, delta)
	_battle_hit_lanes = 0
	_battle_miss_lanes = 0
	if _rival_bar:
		_rival_bar.refresh(delta)


## --battle-auto and WASD test runs: suggest a song as soon as you're in the lobby, and as host,
## draw once everyone's in (AUTO_PLAYERS, or --battle-auto=N) and the roster has held still a while.
func _battle_auto_tick() -> void:
	if not Battle.auto or Battle.phase != Battle.Phase.LOBBY:
		return
	var mine: Dictionary = Battle.roster.get(Battle.me(), {})
	if not mine.is_empty() and str(mine.get("suggestion", "")).is_empty() and not _battle_auto_suggested:
		_battle_auto_suggested = true
		Battle.suggest(_battle_auto_song())
	var need: int = int(_options["battle-auto"]) if _options.get("battle-auto") is String else AUTO_PLAYERS
	if Battle.is_host() and not _battle_auto_drawn and Battle.can_draw() and Battle.roster.size() >= need \
			and Battle.suggestions().size() >= Battle.roster.size() \
			and Time.get_ticks_msec() - _battle_roster_changed_at > AUTO_SETTLE_MSEC:
		_battle_auto_drawn = true
		Battle.draw()


## The shortest built-in song, so an automatic race fits in a test run (or --battle-song).
func _battle_auto_song() -> String:
	if _options.has("battle-song"):
		return str(_options["battle-song"])
	var best: Dictionary = {}
	for region: Dictionary in _regions:
		for song: Dictionary in SongLibrary.in_region(region["id"]):
			if song["source"] != "imported" and (best.is_empty() or float(song["duration"]) < float(best["duration"])):
				best = song
	return str(best.get("id", "county_line"))


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
