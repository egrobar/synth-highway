extends SceneTree
## Headless rules tests for Judge and the manual SongClock.
## Run: godot --headless --path game -s res://tests/test_judge.gd

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	test_tap_windows()
	test_miss_after_window()
	test_full_hold()
	test_early_release_drops_but_keeps_combo()
	test_tail_grace_boundary()
	test_tapping_a_hold_scores_less_than_holding_it()
	test_hold_belongs_to_the_key_that_started_it()
	test_repeated_pitch_after_a_hold()
	test_two_holds_at_once()
	test_hold_completes_if_key_stays_down()
	test_wrong_key_breaks_combo()
	test_a_note_cannot_be_scored_twice()
	test_fuel_empties_once()
	test_perfect_run_grades_s()
	test_grade_reflects_dropped_holds()
	test_manual_clock()
	test_key_map()
	test_power_chord_both_hit()
	test_power_chord_one_missed()
	test_power_chord_keys_a_little_apart()
	test_three_note_power_chord()
	test_power_chord_with_a_hold()
	test_chart_levels_and_power_flags()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("FAIL: ", label)


func near(a: float, b: float, label: String) -> void:
	check(absf(a - b) < 0.001, "%s (got %.4f, want %.4f)" % [label, a, b])


func judge_for(triples: Array) -> Judge:
	return Judge.new(Chart.from_triples(triples))


func test_tap_windows() -> void:
	var j := judge_for([[1.0, 0.2, 60], [2.0, 0.2, 60], [3.0, 0.2, 60], [4.0, 0.2, 60]])
	j.press(60, "a", 1.06)
	check(j.notes[0].verdict == "perfect", "inside the perfect window is perfect")
	j.press(60, "a", 1.9)
	check(j.notes[1].verdict == "good", "early, inside the good window, is good")
	j.press(60, "a", 3.15)
	check(j.notes[2].verdict == "good", "late, inside the good window, is good")
	j.press(60, "a", 3.7)
	check(j.notes[3].state == Chart.NoteState.PENDING and j.wrong_presses == 1, "outside any window is a wrong press")


func test_miss_after_window() -> void:
	var j := judge_for([[1.0, 0.2, 60]])
	j.advance(1.0 + Judge.GOOD_WINDOW - 0.01)
	check(j.misses == 0, "not missed while still inside the window")
	j.advance(1.0 + Judge.GOOD_WINDOW + 0.01)
	check(j.misses == 1 and j.notes[0].state == Chart.NoteState.MISSED, "missed after the window closes")


func test_full_hold() -> void:
	var j := judge_for([[1.0, 2.0, 60]])
	j.press(60, "a", 1.0)
	check(j.notes[0].hold_state == Chart.HoldState.HOLDING, "a long note starts holding")
	j.advance(2.0)
	near(j.notes[0].sustained, 1.0, "sustain builds while held")
	j.release("a", 3.0)
	check(j.notes[0].hold_state == Chart.HoldState.COMPLETE, "held to the end completes")
	near(j.notes[0].sustained, 2.0, "complete hold is fully sustained")
	check(j.holds_completed == 1, "complete hold is counted")


func test_early_release_drops_but_keeps_combo() -> void:
	var j := judge_for([[1.0, 2.0, 60]])
	j.press(60, "a", 1.0)
	j.release("a", 1.5)
	check(j.notes[0].hold_state == Chart.HoldState.DROPPED, "early release drops the hold")
	near(j.notes[0].sustained, 0.5, "dropped hold keeps only the part held")
	check(j.combo == 1, "dropping a hold does not break the combo")
	check(not j.is_holding(), "nothing is held after a drop")


func test_tail_grace_boundary() -> void:
	var inside := judge_for([[1.0, 2.0, 60]])
	inside.press(60, "a", 1.0)
	inside.release("a", 3.0 - Judge.HOLD_TAIL_GRACE + 0.01)
	check(inside.notes[0].hold_state == Chart.HoldState.COMPLETE, "release inside the grace counts as complete")
	near(inside.notes[0].sustained, 2.0, "grace credits the full length")
	var outside := judge_for([[1.0, 2.0, 60]])
	outside.press(60, "a", 1.0)
	outside.release("a", 3.0 - Judge.HOLD_TAIL_GRACE - 0.01)
	check(outside.notes[0].hold_state == Chart.HoldState.DROPPED, "release before the grace is a drop")


func test_tapping_a_hold_scores_less_than_holding_it() -> void:
	# The bug this replaces: on the web build a one-frame tap scored the same as a full hold.
	var held := judge_for([[1.0, 2.0, 60]])
	held.press(60, "a", 1.0)
	held.release("a", 3.0)
	var tapped := judge_for([[1.0, 2.0, 60]])
	tapped.press(60, "a", 1.0)
	tapped.release("a", 1.016)
	check(held.score() > tapped.score() * 2, "holding is worth far more than tapping (%d vs %d)" % [held.score(), tapped.score()])
	check(held.accuracy() > tapped.accuracy(), "holding is more accurate than tapping")


func test_hold_belongs_to_the_key_that_started_it() -> void:
	var j := judge_for([[1.0, 2.0, 60]])
	j.press(60, "z-row", 1.0)
	j.release("q-row", 1.5)
	check(j.notes[0].hold_state == Chart.HoldState.HOLDING, "releasing a different key leaves the hold alone")


func test_repeated_pitch_after_a_hold() -> void:
	var j := judge_for([[1.0, 1.0, 60], [2.0, 0.3, 60]])
	j.press(60, "a", 1.0)
	j.release("a", 1.9)
	j.press(60, "a", 2.0)
	check(j.notes[0].hold_state == Chart.HoldState.COMPLETE, "the grace leaves time to re-press")
	check(j.notes[1].verdict == "perfect", "the repeated note is hit")
	check(j.combo == 2 and j.wrong_presses == 0, "a repeated pitch is not punished")


func test_two_holds_at_once() -> void:
	var j := judge_for([[1.0, 2.0, 60], [1.0, 2.0, 64]])
	j.press(60, "a", 1.0)
	j.press(64, "b", 1.0)
	j.release("a", 1.5)
	check(j.notes[0].hold_state == Chart.HoldState.DROPPED, "first hold dropped")
	check(j.notes[1].hold_state == Chart.HoldState.HOLDING, "second hold unaffected")


func test_hold_completes_if_key_stays_down() -> void:
	var j := judge_for([[1.0, 1.0, 60]])
	j.press(60, "a", 1.0)
	j.advance(2.01)
	check(j.notes[0].hold_state == Chart.HoldState.COMPLETE, "hold completes at its end with the key still down")
	var before: int = j.score()
	j.release("a", 2.5)
	check(j.score() == before and j.holds_dropped == 0, "the late release changes nothing")


func test_wrong_key_breaks_combo() -> void:
	var j := judge_for([[1.0, 0.2, 60], [2.0, 0.2, 60]])
	j.press(60, "a", 1.0)
	j.press(62, "b", 1.5)
	check(j.combo == 0 and j.wrong_presses == 1, "a wrong key breaks the combo")


func test_a_note_cannot_be_scored_twice() -> void:
	var j := judge_for([[1.0, 0.2, 60]])
	j.press(60, "a", 1.0)
	var after_first: int = j.score()
	j.press(60, "a", 1.01)
	check(j.hits == 1 and j.score() == after_first, "the same note cannot be hit twice")


func test_fuel_empties_once() -> void:
	var triples: Array = []
	for i: int in 30:
		triples.append([float(i), 0.2, 60])
	var j := judge_for(triples)
	var fired: Array[int] = [0]
	j.ran_out_of_fuel.connect(func() -> void: fired[0] += 1)
	j.advance(40.0)
	check(j.fuel == 0.0, "fuel empties after enough misses")
	check(fired[0] == 1, "the out-of-fuel signal fires exactly once")


func test_perfect_run_grades_s() -> void:
	var j := judge_for([[1.0, 0.2, 60], [2.0, 2.0, 62], [5.0, 0.2, 64]])
	j.press(60, "a", 1.0)
	j.press(62, "a", 2.0)
	j.release("a", 4.0)
	j.press(64, "a", 5.0)
	near(j.accuracy(), 1.0, "a flawless run is 100%")
	check(j.grade() == "S", "a flawless run is an S")


func test_grade_reflects_dropped_holds() -> void:
	var j := judge_for([[1.0, 2.0, 60], [4.0, 2.0, 62]])
	j.press(60, "a", 1.0)
	j.release("a", 1.02)
	j.press(62, "a", 4.0)
	j.release("a", 4.02)
	near(j.accuracy(), 0.505, "tapped holds earn only the head and a sliver of sustain")
	check(j.grade() == "D", "only tapping holds cannot earn a good grade")


func test_manual_clock() -> void:
	var clock := SongClock.new()
	clock.start(2.0)
	near(clock.now(), -2.0, "lead-in starts negative")
	clock.advance(0.5)
	near(clock.now(), -1.5, "manual clock advances")
	clock.pause()
	clock.advance(1.0)
	near(clock.now(), -1.5, "a paused clock does not move")
	clock.resume()
	clock.advance(0.5)
	near(clock.now(), -1.0, "a resumed clock continues")


func test_key_map() -> void:
	check(KeyMap.lane_for(KEY_A) == 0 and KeyMap.lane_for(KEY_SEMICOLON) == 9, "home row is lanes 0-9")
	check(KeyMap.lane_for(KEY_W) == 10 and KeyMap.lane_for(KEY_P) == 18, "top row W-P are the sharps 10-18")
	check(KeyMap.lane_for(KEY_Q) == -1 and KeyMap.lane_for(KEY_Z) == -1, "keys outside the instrument play nothing")
	check(KeyMap.key_for(12) == KEY_R and KeyMap.label_for(9) == ";", "lanes map back to their keys")
	near(Highway.lane_x(10), (Highway.lane_x(0) + Highway.lane_x(1)) * 0.5, "a sharp sits between its two home lanes")
	var j := judge_for([[1.0, 0.2, 12]])
	j.press(2, "d", 1.0)
	check(j.wrong_presses == 1 and j.hits == 0, "the home key under a sharp does not play the sharp")
	j.press(12, "r", 1.0)
	check(j.hits == 1, "the sharp's own key plays it")


# ---------------------------------------------------------------- power chords (Hard)

func test_power_chord_both_hit() -> void:
	var j := judge_for([[1.0, 0.2, 3, 1], [1.0, 0.2, 6, 1], [2.0, 0.2, 4]])
	j.press(3, KEY_F, 1.0)
	check(j.notes[1].state == Chart.NoteState.PENDING, "one key of a chord leaves the other note waiting")
	j.press(6, KEY_J, 1.0)
	check(j.notes[0].verdict == "perfect" and j.notes[1].verdict == "perfect", "both notes of a chord are hit")
	check(j.hits == 2 and j.combo == 2 and j.wrong_presses == 0, "a chord is two hits, no wrong press")


func test_power_chord_one_missed() -> void:
	var j := judge_for([[1.0, 0.2, 3, 1], [1.0, 0.2, 6, 1]])
	j.press(6, KEY_J, 1.02)
	j.advance(1.0 + Judge.GOOD_WINDOW + 0.01)
	var f: Chart.Note = j.notes[0] if j.notes[0].lane == 3 else j.notes[1]
	var jn: Chart.Note = j.notes[1] if j.notes[0].lane == 3 else j.notes[0]
	check(jn.state == Chart.NoteState.HIT, "the pressed half of the chord is hit")
	check(f.state == Chart.NoteState.MISSED and j.misses == 1, "the unpressed half is missed on its own")
	check(j.hits == 1 and j.combo == 0, "missing half a chord breaks the combo")
	# Pressing the same key twice cannot take both halves.
	var twice := judge_for([[1.0, 0.2, 3, 1], [1.0, 0.2, 6, 1]])
	twice.press(3, KEY_F, 1.0)
	twice.press(3, KEY_F, 1.01)
	check(twice.hits == 1 and twice.wrong_presses == 1, "one key cannot play both notes of a chord")


func test_power_chord_keys_a_little_apart() -> void:
	# Two fingers never land on the same frame: 40 ms apart is still a clean chord.
	var j := judge_for([[1.0, 0.2, 2, 1], [1.0, 0.2, 7, 1]])
	j.press(7, KEY_K, 0.98)
	j.advance(0.99)
	j.press(2, KEY_D, 1.02)
	j.advance(1.03)
	check(j.notes[0].verdict == "perfect" and j.notes[1].verdict == "perfect", "both halves perfect when 40 ms apart")


func test_three_note_power_chord() -> void:
	var j := judge_for([[1.0, 0.2, 0, 1], [1.0, 0.2, 4, 1], [1.0, 0.2, 9, 1]])
	j.press(0, KEY_A, 1.0)
	j.press(9, KEY_SEMICOLON, 1.0)
	j.press(4, KEY_G, 1.01)
	check(j.hits == 3 and j.misses == 0 and j.wrong_presses == 0, "a three-note chord is three hits")


func test_power_chord_with_a_hold() -> void:
	var j := judge_for([[1.0, 2.0, 3, 1], [1.0, 0.2, 6, 1]])
	j.press(3, KEY_F, 1.0)
	j.press(6, KEY_J, 1.0)
	j.release(KEY_J, 1.1)
	j.advance(2.0)
	check(j.notes[0].hold_state == Chart.HoldState.HOLDING, "letting go of the tap half leaves the held half holding")
	j.release(KEY_F, 3.0)
	check(j.notes[0].hold_state == Chart.HoldState.COMPLETE and j.holds_completed == 1, "the held half completes")


func test_chart_levels_and_power_flags() -> void:
	var base := {"id": "t", "title": "T", "theme": "backroads", "bpm": 120.0, "beats_per_bar": 4, "duration": 4.0,
		"backing": "b.ogg", "lead": "l.ogg"}
	var two: Dictionary = base.duplicate()
	two["difficulties"] = {"easy": [{"t": 1.0, "d": 0.2, "p": 60, "l": 0}],
		"normal": [{"t": 1.0, "d": 0.2, "p": 60, "l": 0}, {"t": 1.5, "d": 0.2, "p": 62, "l": 1}]}
	var path_two := "user://test_levels_two.json"
	_write_json(path_two, two)
	var fallback := Chart.load_file(path_two, "hard")
	check(fallback.difficulty == "normal" and fallback.notes.size() == 2, "a chart without Hard plays Normal when Hard is asked for")
	check(not Chart.has_level(two, "hard") and Chart.playable_levels(two) == ["easy", "normal"], "Hard is not offered where it is not charted")
	var three: Dictionary = two.duplicate(true)
	three["difficulties"]["hard"] = [{"t": 1.0, "d": 0.2, "p": 60, "l": 6, "pw": 1}, {"t": 1.0, "d": 0.2, "p": 55, "l": 3, "pw": 1},
		{"t": 1.5, "d": 0.2, "p": 62, "l": 13, "s": 1}]
	var path_three := "user://test_levels_three.json"
	_write_json(path_three, three)
	var hard := Chart.load_file(path_three, "hard")
	check(hard.difficulty == "hard" and Chart.playable_levels(three).has("hard"), "a charted Hard loads as Hard")
	check(hard.notes[0].power and hard.notes[1].power and not hard.notes[2].power, "pw marks power notes")
	check(hard.notes[0].lane == 3 and hard.notes[1].lane == 6, "a chord's notes come in lane order")
	var chords: Array = hard.power_chords()
	check(chords.size() == 1 and (chords[0] as Array).size() == 2, "the two power notes make one chord")
	var old := base.duplicate()
	old["notes"] = [{"t": 1.0, "d": 0.2, "p": 60}]
	check(Chart.resolve_level(old, "hard") == "normal" and Chart.resolve_level(old, "easy") == "normal", "a one-list chart plays its list for every level")
	DirAccess.remove_absolute(path_two)
	DirAccess.remove_absolute(path_three)


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
