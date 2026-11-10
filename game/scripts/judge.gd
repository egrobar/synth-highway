class_name Judge
extends RefCounted
## All scoring rules, with no scene or audio dependencies so they can be tested headless.
##
## Fed key presses, key releases and the current song time, it decides what was
## hit, missed or held. Windows are in real seconds. Scored runs are always at
## full speed with no seeking, which closes the score farming the web build allows.

const PERFECT_WINDOW := 0.07
const GOOD_WINDOW := 0.16
## Letting go this close to a hold's end counts as a full hold. Without it,
## notes that butt up against the next one would be impossible to complete.
const HOLD_TAIL_GRACE := 0.15

const POINTS_PERFECT := 100.0
const POINTS_GOOD := 60.0
const HOLD_POINTS_PER_SECOND := 100.0
const HOLD_COMPLETE_BONUS := 50.0
const COMBO_FOR_MAX_MULTIPLIER := 50

const FUEL_ON_HIT := 0.012
const FUEL_ON_HOLD_COMPLETE := 0.02
const FUEL_ON_MISS := -0.07
const FUEL_ON_WRONG := -0.02
const FUEL_ON_HOLD_DROP := -0.03
## Easy is where a new player learns the layout: mistakes there cost about half the fuel,
## so a rough first minute does not end the song (14 straight misses did, on Normal's numbers).
const EASY_FUEL_COST := 0.55

signal note_hit(note: Chart.Note, verdict: String, offset: float)
signal note_missed(note: Chart.Note)
signal wrong_key(lane: int)
signal hold_ended(note: Chart.Note, completed: bool)
signal ran_out_of_fuel

var notes: Array[Chart.Note]
var combo: int = 0
var max_combo: int = 0
var hits: int = 0
var perfects: int = 0
var goods: int = 0
var misses: int = 0
var wrong_presses: int = 0
var holds_completed: int = 0
var holds_dropped: int = 0
var fuel: float = 1.0
## Practice runs: the tank never drains, so the song always plays to the end.
var no_fail: bool = false
var _fuel_cost: float = 1.0

var _points: float = 0.0
var _first_open: int = 0
var _active_holds: Dictionary = {}
var _fuel_spent: bool = false


func _init(chart: Chart) -> void:
	notes = chart.notes
	chart.reset()
	if chart.difficulty == "easy":
		_fuel_cost = EASY_FUEL_COST


func score() -> int:
	return int(round(_points))


func multiplier() -> float:
	return 1.0 + float(mini(combo, COMBO_FOR_MAX_MULTIPLIER)) / 25.0


func is_holding() -> bool:
	return not _active_holds.is_empty()


func press(lane: int, source: Variant, t: float) -> void:
	var best: Chart.Note = null
	var best_offset: float = INF
	for i: int in range(_first_open, notes.size()):
		var n: Chart.Note = notes[i]
		if n.t > t + GOOD_WINDOW:
			break
		if n.lane != lane or n.state != Chart.NoteState.PENDING:
			continue
		var offset: float = t - n.t
		if absf(offset) <= GOOD_WINDOW and absf(offset) < absf(best_offset):
			best = n
			best_offset = offset
	if best == null:
		wrong_presses += 1
		combo = 0
		_add_fuel(FUEL_ON_WRONG)
		wrong_key.emit(lane)
		return
	_register_hit(best, source, best_offset)


func release(source: Variant, t: float) -> void:
	if not _active_holds.has(source):
		return
	var n: Chart.Note = _active_holds[source]
	if t >= n.end_time() - HOLD_TAIL_GRACE:
		_finish_hold(source, n, true)
	else:
		_accrue(n, t)
		_finish_hold(source, n, false)


## Call every frame, after any presses and releases for that frame.
func advance(t: float) -> void:
	for source: Variant in _active_holds.keys():
		var n: Chart.Note = _active_holds[source]
		if t >= n.end_time():
			_finish_hold(source, n, true)
		else:
			_accrue(n, t)
	# _first_open only ever moves forward, so a frame's cost stays flat for the whole song.
	while _first_open < notes.size():
		var n: Chart.Note = notes[_first_open]
		if n.state != Chart.NoteState.PENDING:
			_first_open += 1
		elif n.t + GOOD_WINDOW < t:
			_register_miss(n)
			_first_open += 1
		else:
			break


## Share of everything available in the song that was earned, 0 to 1.
func accuracy() -> float:
	if notes.is_empty():
		return 0.0
	var earned: float = 0.0
	for n: Chart.Note in notes:
		var head: float = 1.0 if n.verdict == "perfect" else (0.6 if n.verdict == "good" else 0.0)
		if n.is_hold:
			earned += 0.5 * head + 0.5 * clampf(n.sustained / n.d, 0.0, 1.0)
		else:
			earned += head
	return earned / float(notes.size())


func grade() -> String:
	var a: float = accuracy()
	if a >= 0.95:
		return "S"
	if a >= 0.88:
		return "A"
	if a >= 0.75:
		return "B"
	if a >= 0.6:
		return "C"
	return "D"


func _register_hit(n: Chart.Note, source: Variant, offset: float) -> void:
	var verdict: String = "perfect" if absf(offset) <= PERFECT_WINDOW else "good"
	n.state = Chart.NoteState.HIT
	n.verdict = verdict
	hits += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	if verdict == "perfect":
		perfects += 1
	else:
		goods += 1
	_points += (POINTS_PERFECT if verdict == "perfect" else POINTS_GOOD) * multiplier()
	_add_fuel(FUEL_ON_HIT)
	if n.is_hold:
		n.hold_state = Chart.HoldState.HOLDING
		_active_holds[source] = n
	note_hit.emit(n, verdict, offset)


func _register_miss(n: Chart.Note) -> void:
	n.state = Chart.NoteState.MISSED
	misses += 1
	combo = 0
	_add_fuel(FUEL_ON_MISS)
	note_missed.emit(n)


func _accrue(n: Chart.Note, until: float) -> void:
	var reached: float = clampf(until, n.t, n.end_time())
	var gained: float = reached - (n.t + n.sustained)
	if gained > 0.0:
		n.sustained += gained
		_points += gained * HOLD_POINTS_PER_SECOND * multiplier()


func _finish_hold(source: Variant, n: Chart.Note, completed: bool) -> void:
	_active_holds.erase(source)
	if completed:
		_accrue(n, n.end_time())
		n.hold_state = Chart.HoldState.COMPLETE
		holds_completed += 1
		_points += HOLD_COMPLETE_BONUS * multiplier()
		_add_fuel(FUEL_ON_HOLD_COMPLETE)
	else:
		# Dropping a hold costs the rest of the note and some fuel, but not the
		# combo: the press was good, and the sound cutting out is already the penalty.
		n.hold_state = Chart.HoldState.DROPPED
		holds_dropped += 1
		_add_fuel(FUEL_ON_HOLD_DROP)
	hold_ended.emit(n, completed)


func _add_fuel(amount: float) -> void:
	if no_fail:
		return
	fuel = clampf(fuel + (amount * _fuel_cost if amount < 0.0 else amount), 0.0, 1.0)
	if fuel <= 0.0 and not _fuel_spent:
		_fuel_spent = true
		ran_out_of_fuel.emit()
