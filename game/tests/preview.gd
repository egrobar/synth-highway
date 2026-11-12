extends SceneTree
## Renders one region, optionally with a song played by the perfect bot, and
## saves a frame. Independent of the menus, so a region can be checked alone.
##
##   godot --always-on-top --path game -s res://tests/preview.gd -- --theme=<id> --out=/abs/frame.png
##         [--song=<song id> --at=<song seconds> --difficulty=easy|normal|hard]
## Without --song it captures the empty road after 3 s. Audio is muted.
## Windowed runs need --always-on-top on macOS, or an occluded window renders black.

var _stage: Stage
var _session: PlaySession
var _options: Dictionary = {}
var _elapsed: float = 0.0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		_options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	AudioServer.set_bus_mute(0, true)
	_stage = Stage.new()
	root.add_child(_stage)
	var theme: String = _options.get("theme", "backroads")
	if not _options.has("song"):
		_stage.show_region(theme)
		return
	var chart := Chart.load_file("res://data/songs/%s.json" % _options["song"], _options.get("difficulty", "normal"))
	var highway: Highway = _stage.show_chart(theme, chart)
	_session = PlaySession.new()
	root.add_child(_session)
	_session.begin(chart, highway, _stage.world, {}, {"bot": "perfect"})


func _process(delta: float) -> bool:
	_elapsed += delta
	var due: bool = _elapsed > 3.0
	if _session:
		due = _session.clock.now() >= float(_options.get("at", "12"))
	if due:
		var out: String = _options.get("out", "user://preview.png")
		root.get_viewport().get_texture().get_image().save_png(out)
		print("PREVIEW ", out)
		return true
	return _elapsed > 240.0
