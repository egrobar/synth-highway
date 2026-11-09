extends SceneTree
## Plays a whole song with a bot on the manual clock, headless, and prints the result.
##   godot --headless --path game -s res://tests/bot_song.gd -- --song=<id> [--theme=<id>]
##         [--bot=perfect|tapper|sloppy|afk] [--difficulty=easy|normal] [--chart=/abs/chart.json]
## Exits non-zero if the perfect bot fails to get an S, which would mean an unplayable chart.


var _started: bool = false


## Runs on the first frame rather than in _initialize, once the nodes are inside the tree.
func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	var options: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var path: String = options.get("chart", "res://data/songs/%s.json" % options.get("song", "county_line"))
	var chart := Chart.load_file(path, options.get("difficulty", "normal"))
	var stage := Stage.new()
	root.add_child(stage)
	var highway: Highway = stage.show_chart(options.get("theme", chart.theme), chart)
	var session := PlaySession.new()
	root.add_child(session)
	var bot: String = options.get("bot", "perfect")
	session.begin(chart, highway, stage.world, {}, {"bot": bot, "manual": true})
	var result: Dictionary = session.run_to_end_headless()
	result["difficulty"] = chart.difficulty
	result["notes_per_second"] = snappedf(float(chart.notes.size()) / maxf(chart.last_note_end(), 1.0), 0.01)
	print("RESULT ", JSON.stringify(result))
	quit(1 if bot == "perfect" and result.get("grade", "") != "S" else 0)
