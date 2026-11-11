class_name PlaySession
extends Node
## One run of one song: wires input, clock, judge, audio, world and HUD together.
##
## Scored runs have no seek and no speed control. Keys are timed against the
## audio clock. A bot can stand in for the player using the same input path,
## either in real time against real audio or stepped on a manual clock.
##
## A practice run (options "practice", "speed") cannot fail, can play slower, and
## is never saved: it is where a player learns a song the scored run would end.
##
## The session also turns the run into feel: each beat of the song flares the world
## and the hit line, the combo heats the scenery up, a miss jolts the camera, and
## combo milestones are called out. And it keeps what the results screen teaches
## from: how early or late each hit was, and which keys were missed.

signal finished(result: Dictionary)
signal quit_to_menu
signal restart_requested

const LEAD_IN := 3.0
const LEAD_BOOST_DB := 6.0
const END_TAIL := 1.6
const COUNT_IN_BEATS := 3
const FAIL_WAIT := 2.8
const STEP := 1.0 / 240.0
## A full-heat world at this combo; the same number the score multiplier tops out at.
const HEAT_COMBO := 50.0
const MILESTONES: Array[int] = [25, 50, 100, 200, 300, 400, 500]

var chart: Chart
var judge: Judge
var clock: SongClock
var timing := {"samples": 0, "max_stem_gap": 0.0, "max_error": 0.0, "min_step": 1.0e9, "max_step": 0.0}

var _highway: Highway
var _world: ThemeWorld
var _backing: AudioStreamPlayer
var _lead: AudioStreamPlayer
var _sfx: Dictionary = {}
var _held_keys: Dictionary = {}
var _lead_open_until: float = -INF
## How much of the song (first note to last) the vocal was open for, for the bot checks.
var _lead_time_total: float = 0.0
var _lead_time_open: float = 0.0
var _gate: float = 0.0
var _paused: bool = false
var _counting_in: bool = false
var _count_left: float = 0.0
var _count_number: int = 0
var _ended: bool = false
var _failed_at_usec: int = -1
var _first_note_time: float = 0.0
var _bot_actions: Array = []
var _bot_index: int = 0
var _bot_name: String = ""
var _timing_start_real: int = -1
var _timing_start_song: float = 0.0
var _last_now: float = -INF

var _hud: CanvasLayer
var _score_label: Label
var _combo_label: Label
var _multiplier_label: Label
var _judgement: Label
var _judgement_tween: Tween
var _fuel_bar: ColorRect
var _progress_bar: ColorRect
var _center_label: Label
var _pause_menu: MenuOverlay
var _hands_cue: Label
var _milestone_label: Label
var _stage: Stage
var _practice: bool = false
var _speed: float = 1.0
var _last_beat: int = -1000000
var _next_milestone: int = 0
## Seconds early (negative) or late (positive) of every hit, for the results screen.
var _offsets: Array[float] = []
## Lane -> notes missed or holds dropped there.
var _trouble: Dictionary = {}
var _progress_at_end: float = 1.0

const HANDS_TEXT := "Hands on the home row:  A S D F      J K L ;"


func begin(song: Chart, highway: Highway, world: ThemeWorld, sfx: Dictionary, options: Dictionary) -> void:
	chart = song
	_highway = highway
	_world = world
	_sfx = sfx
	_bot_name = options.get("bot", "")
	_stage = options.get("stage")
	_practice = options.get("practice", false)
	_speed = float(options.get("speed", 1.0)) if _practice else 1.0
	_first_note_time = chart.notes[0].t
	judge = Judge.new(chart)
	judge.no_fail = _practice
	judge.note_hit.connect(_on_note_hit)
	judge.note_missed.connect(_on_note_missed)
	judge.wrong_key.connect(_on_wrong_key)
	judge.hold_ended.connect(_on_hold_ended)
	judge.ran_out_of_fuel.connect(_on_out_of_fuel)
	_highway.reset_run()
	if options.get("manual", false):
		clock = SongClock.new()
	else:
		_backing = _make_player(chart.backing_path, 0.0)
		_lead = _make_player(chart.lead_path, -80.0)
		_backing.pitch_scale = _speed
		_lead.pitch_scale = _speed
		Settings.set_practice_speed(_speed)
		clock = SongClock.new(_backing, _lead)
		clock.offset = options.get("offset", 0.0)
		clock.speed = _speed
	_build_hud()
	if not _bot_name.is_empty():
		_build_bot(_bot_name)
	_world.set_target_speed(1.0)
	clock.start(LEAD_IN)


## Plays the whole song on the manual clock in one go. Used by the headless test.
func run_to_end_headless() -> Dictionary:
	var result: Dictionary = {}
	# Lambdas capture locals by value, so fill the shared dictionary rather than reassign it.
	finished.connect(func(r: Dictionary) -> void: result.merge(r))
	var guard: int = 0
	while result.is_empty() and guard < 240 * 600:
		clock.advance(STEP)
		_step(STEP)
		guard += 1
	return result


func _exit_tree() -> void:
	# The pitch correction is on a shared bus; never leave it on for the next run.
	if clock != null and not clock.manual:
		Settings.set_practice_speed(1.0)


func _process(delta: float) -> void:
	if clock == null or clock.manual:
		return
	if _failed_at_usec >= 0:
		if Time.get_ticks_usec() - _failed_at_usec > int(FAIL_WAIT * 1000000.0):
			_finish(true)
		return
	if _counting_in:
		_tick_count_in(delta)
		_highway.update_view(clock.now(), delta, judge.is_holding())
		return
	if _paused:
		return
	clock.update()
	_record_timing()
	_step(delta)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo or _ended or not is_instance_valid(clock):
		return
	var key: InputEventKey = event
	if key.pressed and _handle_control_key(key.physical_keycode):
		get_viewport().set_input_as_handled()
		return
	if _paused or _counting_in or _failed_at_usec >= 0:
		return
	var lane: int = KeyMap.lane_for(key.physical_keycode)
	if lane < 0:
		return
	_key_event(lane, key.physical_keycode, key.pressed)
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Tabbing away must never cost the player a run.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and clock != null and not _paused and not _ended and _bot_name.is_empty():
		_pause()


func _handle_control_key(code: Key) -> bool:
	if _failed_at_usec >= 0:
		return false
	if _counting_in:
		return code == KEY_ESCAPE or code == KEY_SPACE
	if _paused and _pause_menu:
		return _pause_menu.handle_key(code)
	if code == KEY_ESCAPE or code == KEY_SPACE:
		_pause()
		return true
	return false


func _key_event(lane: int, source: Variant, pressed: bool) -> void:
	var t: float = clock.now()
	if pressed:
		if _held_keys.has(source):
			return
		_held_keys[source] = lane
		_highway.set_key_pressed(lane, true)
		# Noodling during the intro is free. Only presses near the first note are judged.
		if t >= _first_note_time - Judge.GOOD_WINDOW:
			judge.press(lane, source, t)
	else:
		if not _held_keys.has(source):
			return
		_highway.set_key_pressed(int(_held_keys[source]), false)
		_held_keys.erase(source)
		judge.release(source, t)


func _step(delta: float) -> void:
	var now: float = clock.now()
	_run_bot(now)
	judge.advance(now)
	_update_lead_gate(now, delta)
	if now >= _first_note_time and now <= chart.last_note_end():
		_lead_time_total += delta
		if _lead_should_open(now):
			_lead_time_open += delta
	_highway.update_view(now, delta, judge.is_holding())
	_world.set_target_speed(0.74 + 0.26 * clampf(judge.fuel / 0.5, 0.0, 1.0))
	_world.set_headlight_level(judge.fuel / 0.4)
	_world.set_heat(float(judge.combo) / HEAT_COMBO)
	_tick_beat(now)
	_tick_milestone()
	_update_hud(now)
	if not _ended and _failed_at_usec < 0 and now >= chart.last_note_end() + END_TAIL:
		_finish(false)


## Flares the world and the hit line on each beat of the song, harder on bar lines.
func _tick_beat(now: float) -> void:
	var index: int = int(floor((now - chart.beat_offset) / chart.beat_seconds()))
	if index == _last_beat:
		return
	_last_beat = index
	if index < 0 or now > chart.last_note_end() + 0.5:
		return
	var strength: float = 1.0 if index % chart.beats_per_bar == 0 else 0.5
	_world.beat(strength)
	if Settings.motion:
		_highway.pulse(strength)


## Calls out a combo milestone once, the first time the combo reaches it.
func _tick_milestone() -> void:
	if _next_milestone >= MILESTONES.size() or judge.combo < MILESTONES[_next_milestone]:
		return
	var reached: int = MILESTONES[_next_milestone]
	_next_milestone += 1
	_world.beat(1.6)
	_play(_sfx, "milestone")
	if clock.manual:
		return
	_milestone_label.text = "%d COMBO" % reached
	_milestone_label.pivot_offset = _milestone_label.size * 0.5
	_milestone_label.scale = Vector2.ONE * 1.5
	var tween := create_tween()
	tween.set_parallel(true)
	_milestone_label.modulate.a = 1.0
	tween.tween_property(_milestone_label, "scale", Vector2.ONE, 0.18)
	tween.tween_property(_milestone_label, "modulate:a", 0.0, 0.5).set_delay(0.9)


## The melody stem is the player's to keep alive. A hit opens it, and it stays open
## through the gap until the next note is due, so a real vocal keeps singing between
## the charted notes (breaths, short words, notes Easy leaves out). A miss cuts it
## when that note's window closes; letting go of a hold cuts it at once.
func _lead_should_open(now: float) -> bool:
	return judge.is_holding() or now < _lead_open_until


## How long a hit on note n keeps the melody playing: until the next note's hit
## window closes, or a few seconds past the end of the last note.
func _carry_until(n: Chart.Note) -> float:
	var i: int = chart.notes.find(n)
	if i >= 0 and i + 1 < chart.notes.size():
		return chart.notes[i + 1].t + Judge.GOOD_WINDOW
	return n.end_time() + 3.0


func _update_lead_gate(now: float, delta: float) -> void:
	if clock.manual:
		return
	var open: bool = _lead_should_open(now)
	# Opens almost instantly so a hit feels immediate; closes a touch slower so it cannot click.
	_gate = move_toward(_gate, 1.0 if open else 0.0, delta / (0.012 if open else 0.06))
	_lead.volume_db = linear_to_db(maxf(_gate, 0.0001)) + LEAD_BOOST_DB


func _pause() -> void:
	_paused = true
	clock.pause()
	# The lead-in cue would sit right under the menu's own reminder: one is enough.
	if _hands_cue:
		_hands_cue.visible = false
	var items: Array[Dictionary] = [
		{"text": "Resume", "key": KEY_SPACE, "key_text": "SPACE", "action": _start_count_in},
		{"text": "Restart", "key": KEY_R, "key_text": "R", "action": func() -> void: restart_requested.emit()},
		{"text": "Back to the route", "key": KEY_BACKSPACE, "key_text": "BACKSPACE", "action": func() -> void: quit_to_menu.emit()},
		{"text": "Quit game", "key": KEY_Q, "key_text": "Q", "action": func() -> void: get_tree().quit()},
	]
	_pause_menu = MenuOverlay.new().setup("PAUSED", items, _start_count_in, Ui.ACCENT, HANDS_TEXT,
		func() -> void: _play(_sfx, "ui"))
	_hud.add_child(_pause_menu)


func _start_count_in() -> void:
	if _pause_menu:
		_pause_menu.queue_free()
		_pause_menu = null
	if _hands_cue:
		_hands_cue.visible = true
	_paused = false
	_counting_in = true
	_count_number = COUNT_IN_BEATS
	_count_left = chart.beat_seconds()
	_show_count()


func _tick_count_in(delta: float) -> void:
	_count_left -= delta
	if _count_left > 0.0:
		return
	_count_number -= 1
	if _count_number > 0:
		_count_left += chart.beat_seconds()
		_show_count()
		return
	_counting_in = false
	_center_label.visible = false
	# A key let go during the pause ends its hold now, not retroactively.
	for source: Variant in _held_keys.keys():
		if not Input.is_physical_key_pressed(source):
			_key_event(int(_held_keys[source]), source, false)
	clock.resume()


func _show_count() -> void:
	_center_label.text = str(_count_number)
	_center_label.visible = true
	_play(_sfx, "click")


func _on_note_hit(n: Chart.Note, verdict: String, offset: float) -> void:
	_offsets.append(offset)
	_highway.celebrate(n.lane, verdict == "perfect")
	_flash_judgement(verdict.to_upper(), Color(1.0, 0.93, 0.7) if verdict == "perfect" else Color(0.55, 0.95, 0.65))
	if not n.is_hold:
		_lead_open_until = maxf(_lead_open_until, _carry_until(n))


func _on_note_missed(n: Chart.Note) -> void:
	_trouble[n.lane] = int(_trouble.get(n.lane, 0)) + 1
	if _stage:
		_stage.jolt(0.7)
	_lead_open_until = minf(_lead_open_until, clock.now())
	_flash_judgement("MISS", Color(1.0, 0.34, 0.46))


func _on_wrong_key(lane: int) -> void:
	_highway.flash_wrong(lane)
	_play(_sfx, "wrong")


func _on_hold_ended(n: Chart.Note, completed: bool) -> void:
	if completed:
		_lead_open_until = maxf(_lead_open_until, _carry_until(n))
		_highway.celebrate(n.lane, true)
		_flash_judgement("HELD", Color(0.75, 0.97, 1.0))
		_play(_sfx, "held")
	else:
		_trouble[n.lane] = int(_trouble.get(n.lane, 0)) + 1
		_lead_open_until = minf(_lead_open_until, clock.now())
		_flash_judgement("LET GO", Color(0.65, 0.68, 0.8))


func _on_out_of_fuel() -> void:
	_failed_at_usec = Time.get_ticks_usec()
	_progress_at_end = clampf(clock.now() / maxf(chart.last_note_end(), 0.001), 0.0, 1.0)
	_world.set_heat(0.0)
	_world.set_target_speed(0.0)
	_world.set_headlight_level(0.0)
	if clock.manual:
		_finish(true)
		return
	clock.stop()
	_center_label.text = "OUT OF GAS"
	_center_label.visible = true
	_play(_sfx, "out_of_gas")


func _finish(failed: bool) -> void:
	if _ended:
		return
	_ended = true
	var holds_total: int = 0
	for n: Chart.Note in chart.notes:
		if n.is_hold:
			holds_total += 1
	if not clock.manual:
		clock.stop()
	for source: Variant in _held_keys.keys():
		_highway.set_key_pressed(int(_held_keys[source]), false)
	_held_keys.clear()
	_hud.visible = false
	_world.set_heat(0.0)
	var sorted_offsets: Array[float] = _offsets.duplicate()
	sorted_offsets.sort()
	var trouble: Array = []
	for lane: int in _trouble:
		trouble.append([lane, int(_trouble[lane])])
	trouble.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]) or (int(a[1]) == int(b[1]) and int(a[0]) < int(b[0])))
	finished.emit({
		"practice": _practice, "speed": _speed, "progress": _progress_at_end if failed else 1.0,
		# The median, so a few wild presses do not hide a steady habit of rushing or dragging.
		"typical_offset": sorted_offsets[sorted_offsets.size() / 2] if sorted_offsets.size() >= 8 else 0.0,
		"offsets_counted": sorted_offsets.size(), "trouble": trouble,
		"lead_open_share": snappedf(_lead_time_open / maxf(_lead_time_total, 0.001), 0.001),
		"song_id": chart.id, "title": chart.title, "failed": failed, "difficulty": chart.difficulty, "theme": chart.theme,
		"score": judge.score(), "grade": "" if failed else judge.grade(), "accuracy": judge.accuracy(),
		"hits": judge.hits, "total": chart.notes.size(), "perfects": judge.perfects, "goods": judge.goods,
		"misses": judge.misses, "wrong": judge.wrong_presses, "max_combo": judge.max_combo,
		"holds_completed": judge.holds_completed, "holds_dropped": judge.holds_dropped, "holds_total": holds_total,
	})


## Compares the audio-derived clock against real elapsed time, for the timing check.
func _record_timing() -> void:
	if clock.mode != SongClock.Mode.PLAYING:
		return
	var now: float = clock.now()
	var real: int = Time.get_ticks_usec()
	if _timing_start_real < 0:
		if now > 0.5:
			_timing_start_real = real
			_timing_start_song = now
			_last_now = now
		return
	var elapsed_real: float = float(real - _timing_start_real) / 1000000.0
	timing["samples"] = int(timing["samples"]) + 1
	timing["max_error"] = maxf(float(timing["max_error"]), absf((now - _timing_start_song) - elapsed_real))
	timing["max_stem_gap"] = maxf(float(timing["max_stem_gap"]), clock.stem_gap())
	timing["min_step"] = minf(float(timing["min_step"]), now - _last_now)
	timing["max_step"] = maxf(float(timing["max_step"]), now - _last_now)
	_last_now = now
	var trace: Array = timing.get_or_add("trace", [])
	if trace.size() < int(elapsed_real / 5.0) + 1:
		trace.append([snappedf(elapsed_real, 0.001), snappedf(now - _timing_start_song, 0.001),
			snappedf(_backing.get_playback_position(), 0.001), snappedf(AudioServer.get_time_since_last_mix(), 0.0001),
			snappedf(AudioServer.get_output_latency(), 0.0001), AudioServer.get_mix_rate()])


## Built-in songs are imported resources; the player's own are plain files in user://,
## Ogg Vorbis since 2026-11-10 and WAV before that, so both load.
static func _load_stem(path: String) -> AudioStream:
	if path.begins_with("res://"):
		return load(path)
	if path.get_extension().to_lower() == "ogg":
		return AudioStreamOggVorbis.load_from_file(path)
	return AudioStreamWAV.load_from_file(path)


func _make_player(path: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	# Built-in songs are imported resources; imported songs are plain WAV files in user://.
	player.stream = _load_stem(path)
	player.volume_db = volume_db
	player.bus = Settings.BUS_STEMS
	add_child(player)
	return player


func _play(bank: Dictionary, name: String) -> void:
	if clock != null and clock.manual:
		return
	var player: AudioStreamPlayer = bank.get(name)
	if player:
		player.play()


func _build_bot(profile: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for n: Chart.Note in chart.notes:
		var press: float = n.t
		var release: float = n.t + 0.06
		match profile:
			"perfect":
				release = n.end_time() if n.is_hold else n.t + 0.06
			"tapper":
				release = n.t + STEP * 2.0
			"sloppy":
				if rng.randf() < 0.1:
					continue
				press = n.t + rng.randf_range(-0.12, 0.12)
				if n.is_hold:
					release = n.t + n.d * rng.randf_range(0.55, 1.0)
				else:
					release = press + 0.08
			"afk":
				continue
		_bot_actions.append([press, true, n.lane])
		_bot_actions.append([release, false, n.lane])
	_bot_actions.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


func _run_bot(now: float) -> void:
	while _bot_index < _bot_actions.size() and float(_bot_actions[_bot_index][0]) <= now:
		var action: Array = _bot_actions[_bot_index]
		_bot_index += 1
		_key_event(int(action[2]), KeyMap.key_for(int(action[2])), bool(action[1]))


func _flash_judgement(text: String, color: Color) -> void:
	_judgement.text = text
	_judgement.modulate = color
	_judgement.pivot_offset = _judgement.size * 0.5
	if clock.manual:
		return
	if _judgement_tween:
		_judgement_tween.kill()
	_judgement.scale = Vector2.ONE * 1.25
	_judgement_tween = create_tween()
	_judgement_tween.set_parallel(true)
	_judgement_tween.tween_property(_judgement, "scale", Vector2.ONE, 0.09)
	_judgement_tween.tween_property(_judgement, "modulate:a", 0.0, 0.3).set_delay(0.28)


func _update_hud(now: float) -> void:
	_score_label.text = str(judge.score())
	_combo_label.text = str(judge.combo)
	_multiplier_label.text = "x%.1f" % judge.multiplier()
	_fuel_bar.anchor_right = judge.fuel
	_fuel_bar.color = Color(1.0, 0.3, 0.3) if judge.fuel < 0.3 else Color(1.0, 0.76, 0.32)
	_progress_bar.anchor_right = clampf(now / chart.last_note_end(), 0.0, 1.0)
	# The cue fades out just before the first note arrives.
	if _hands_cue:
		_hands_cue.modulate.a = clampf((_first_note_time - 0.6 - now) / 0.8, 0.0, 1.0)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var score_caption := Ui.label("SCORE", 18, Ui.MUTED)
	Ui.anchor(score_caption, 1.0, 0.0, 1.0, 0.0, -260, 22, -32, 46, HORIZONTAL_ALIGNMENT_RIGHT)
	_hud.add_child(score_caption)
	_score_label = Ui.heading("0", 46, Ui.TEXT)
	Ui.anchor(_score_label, 1.0, 0.0, 1.0, 0.0, -360, 42, -32, 104, HORIZONTAL_ALIGNMENT_RIGHT)
	_hud.add_child(_score_label)

	var combo_caption := Ui.label("COMBO", 18, Ui.MUTED)
	Ui.anchor(combo_caption, 0.0, 0.0, 0.0, 0.0, 32, 22, 260, 46)
	_hud.add_child(combo_caption)
	_combo_label = Ui.heading("0", 46, Ui.ACCENT)
	Ui.anchor(_combo_label, 0.0, 0.0, 0.0, 0.0, 32, 42, 180, 104)
	_hud.add_child(_combo_label)
	_multiplier_label = Ui.label("x1.0", 24, Ui.MUTED)
	Ui.anchor(_multiplier_label, 0.0, 0.0, 0.0, 0.0, 150, 60, 280, 100)
	_hud.add_child(_multiplier_label)

	var gas_caption := Ui.label("GAS", 18, Ui.MUTED)
	Ui.anchor(gas_caption, 0.0, 0.0, 0.0, 0.0, 32, 112, 90, 136)
	_hud.add_child(gas_caption)
	var gas_track := ColorRect.new()
	gas_track.color = Color(1, 1, 1, 0.14)
	Ui.anchor(gas_track, 0.0, 0.0, 0.0, 0.0, 84, 119, 284, 131)
	_hud.add_child(gas_track)
	_fuel_bar = ColorRect.new()
	_fuel_bar.anchor_bottom = 1.0
	_fuel_bar.anchor_right = 1.0
	gas_track.add_child(_fuel_bar)

	_judgement = Ui.heading("", 58, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(_judgement, 0.5, 0.26, 0.5, 0.26, -300, -40, 300, 40, HORIZONTAL_ALIGNMENT_CENTER)
	_judgement.modulate.a = 0.0
	_hud.add_child(_judgement)
	_milestone_label = Ui.heading("", 44, Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(_milestone_label, 0.5, 0.15, 0.5, 0.15, -300, -30, 300, 30, HORIZONTAL_ALIGNMENT_CENTER)
	_milestone_label.modulate.a = 0.0
	_hud.add_child(_milestone_label)
	if _practice:
		var tag_text: String = "PRACTICE   ·   no fail, not scored"
		if _speed < 0.999:
			tag_text = "PRACTICE   ·   %d%% speed   ·   no fail, not scored" % int(round(_speed * 100.0))
		var tag := Ui.label(tag_text, 22, Ui.WARM, HORIZONTAL_ALIGNMENT_CENTER)
		Ui.anchor(tag, 0.0, 0.0, 1.0, 0.0, 0, 22, 0, 52, HORIZONTAL_ALIGNMENT_CENTER)
		_hud.add_child(tag)

	_center_label = Ui.heading("", 120, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(_center_label, 0.5, 0.42, 0.5, 0.42, -500, -90, 500, 90, HORIZONTAL_ALIGNMENT_CENTER)
	_center_label.visible = false
	_hud.add_child(_center_label)

	var progress_track := ColorRect.new()
	progress_track.color = Color(1, 1, 1, 0.12)
	Ui.anchor(progress_track, 0.0, 1.0, 1.0, 1.0, 0, -5, 0, 0)
	_hud.add_child(progress_track)
	_progress_bar = ColorRect.new()
	_progress_bar.color = Ui.ACCENT
	_progress_bar.anchor_bottom = 1.0
	_progress_bar.anchor_right = 0.0
	progress_track.add_child(_progress_bar)

	# Shown through the lead-in, so every song starts from the same hand position.
	_hands_cue = Ui.label(HANDS_TEXT, 30, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.anchor(_hands_cue, 0.0, 0.62, 1.0, 0.62, 0, 0, 0, 50, HORIZONTAL_ALIGNMENT_CENTER)
	_hud.add_child(_hands_cue)
