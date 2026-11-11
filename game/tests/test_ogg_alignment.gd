extends SceneTree
## Song stems are stored as Ogg Vorbis, and the song clock assumes they start on exactly
## the sample a WAV would. This decodes a click track both ways with Godot's own decoders
## (AudioStreamPlayback.mix_audio, so no audio device is needed) and compares where the
## clicks land.
##   godot --headless --path game -s res://tests/test_ogg_alignment.gd -- --wav=/abs/clicks.wav --ogg=/abs/clicks.ogg
## Fixtures come from the importer's own write_stem (see tools/importer/import_song.py).
## Exits non-zero if any click is more than 1 ms (44 samples) off.

const LIMIT_SAMPLES := 44


func _initialize() -> void:
	var options: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else ""
	var wav: Array[int] = _onsets(_decode(AudioStreamWAV.load_from_file(options["wav"])))
	var ogg: Array[int] = _onsets(_decode(AudioStreamOggVorbis.load_from_file(options["ogg"])))
	var worst: int = 0
	for i: int in mini(wav.size(), ogg.size()):
		var gap: int = ogg[i] - wav[i]
		worst = maxi(worst, absi(gap))
		print("click %d: wav at %d, ogg at %d, OGG offset %+d samples (%+.2f ms)" % [i, wav[i], ogg[i], gap, gap / 44.1])
	var ok: bool = wav.size() >= 3 and wav.size() == ogg.size() and worst <= LIMIT_SAMPLES
	print("OGG ALIGNMENT %s (%d clicks, worst %d samples)" % ["OK" if ok else "FAIL", wav.size(), worst])
	quit(0 if ok else 1)


func _decode(stream: AudioStream) -> PackedVector2Array:
	var playback: AudioStreamPlayback = stream.instantiate_playback()
	playback.start(0.0)
	var frames := PackedVector2Array()
	for i: int in 200:
		frames.append_array(playback.mix_audio(1.0, 1024))
	return frames


func _onsets(frames: PackedVector2Array) -> Array[int]:
	var found: Array[int] = []
	var quiet_since: int = 0
	for i: int in frames.size():
		if absf(frames[i].x) > 0.3:
			if i - quiet_since > 2000:
				found.append(i)
			quiet_since = i
	return found
