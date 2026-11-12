class_name SongClock
extends RefCounted
## The one place song time comes from.
##
## The web version summed frame times, which drifts away from real audio. Here,
## during playback, time is read from what the audio hardware has actually
## played. There is also a manual mode, advanced by hand, so a bot can run a
## whole song deterministically in a headless test.

enum Mode { STOPPED, LEAD_IN, PLAYING, PAUSED }

var mode: Mode = Mode.STOPPED
var manual: bool = false
## Player-calibrated seconds, added on top of the driver's reported latency.
var offset: float = 0.0
## Practice runs play slower: the stems' pitch scale. Song time then passes at this
## fraction of real time, so everything measured in real seconds is scaled by it.
var speed: float = 1.0

var _manual_now: float = 0.0
var _backing: AudioStreamPlayer
var _lead: AudioStreamPlayer
var _lead_in_end_usec: int = 0
var _lead_in_remaining: float = 0.0
var _paused_during_lead_in: bool = false
var _frozen: float = 0.0
var _last: float = -INF
## When now() last ran while playing, so time can run on after the audio ends.
var _wall_usec: int = 0


func _init(backing: AudioStreamPlayer = null, lead: AudioStreamPlayer = null) -> void:
	_backing = backing
	_lead = lead
	manual = backing == null


func start(lead_in: float) -> void:
	_last = -INF
	if manual:
		_manual_now = -lead_in
		mode = Mode.PLAYING
		return
	_lead_in_end_usec = Time.get_ticks_usec() + int(lead_in * 1000000.0)
	mode = Mode.LEAD_IN


## Call once per frame. Hands over from the silent lead-in to the audio.
func update() -> void:
	if not manual and mode == Mode.LEAD_IN and Time.get_ticks_usec() >= _lead_in_end_usec:
		_start_audio()


func advance(dt: float) -> void:
	assert(manual, "advance() is only for the manual test clock")
	if mode == Mode.PLAYING:
		_manual_now += dt


func now() -> float:
	if manual:
		return _manual_now
	var t: float = _last
	match mode:
		Mode.LEAD_IN:
			# Ends on exactly the value playback starts from, so nothing jumps at the handover.
			t = -float(_lead_in_end_usec - Time.get_ticks_usec()) / 1000000.0 * speed - _total_latency()
		Mode.PLAYING:
			var wall: int = Time.get_ticks_usec()
			if _backing.playing:
				t = _backing.get_playback_position() + AudioServer.get_time_since_last_mix() * speed - _total_latency()
			elif _last > -INF:
				# The audio has run out, but the run ends PlaySession.END_TAIL after the last note,
				# which can be later: with time stuck at the audio's end the run never finished
				# (Vox Ex Profundis, last note ending 1.4 s before its audio did; 2026-11-11).
				# Time runs on with the wall clock.
				t = _last + float(wall - _wall_usec) / 1000000.0 * speed
			_wall_usec = wall
		Mode.PAUSED:
			return _frozen
	# Position updates arrive in mix-sized chunks. Time must never run backwards.
	_last = maxf(_last, t)
	return _last


func pause() -> void:
	if mode == Mode.PAUSED or mode == Mode.STOPPED:
		return
	_frozen = now()
	if not manual:
		_paused_during_lead_in = mode == Mode.LEAD_IN
		if _paused_during_lead_in:
			_lead_in_remaining = float(_lead_in_end_usec - Time.get_ticks_usec()) / 1000000.0
		else:
			_set_stream_paused(true)
	mode = Mode.PAUSED


func resume() -> void:
	if mode != Mode.PAUSED:
		return
	if manual:
		mode = Mode.PLAYING
	elif _paused_during_lead_in:
		_lead_in_end_usec = Time.get_ticks_usec() + int(_lead_in_remaining * 1000000.0)
		mode = Mode.LEAD_IN
	else:
		_set_stream_paused(false)
		_wall_usec = Time.get_ticks_usec()  # a pause after the audio ended must not jump time on
		mode = Mode.PLAYING


func stop() -> void:
	if not manual:
		_backing.stop()
		_lead.stop()
	mode = Mode.STOPPED


## How far apart the two stems are, in seconds. Used by the timing check.
func stem_gap() -> float:
	if manual or mode != Mode.PLAYING:
		return 0.0
	return absf(_backing.get_playback_position() - _lead.get_playback_position())


func _total_latency() -> float:
	return (AudioServer.get_output_latency() + offset) * speed


func _start_audio() -> void:
	# Locking the mixer guarantees both stems begin in the same mix, sample-aligned.
	AudioServer.lock()
	_backing.play()
	_lead.play()
	AudioServer.unlock()
	mode = Mode.PLAYING


func _set_stream_paused(paused: bool) -> void:
	AudioServer.lock()
	_backing.stream_paused = paused
	_lead.stream_paused = paused
	AudioServer.unlock()
