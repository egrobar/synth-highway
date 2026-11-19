class_name SaveData
extends RefCounted
## Everything that survives between sessions: timing calibration, the player's
## settings (see Settings) and best runs, kept per song and difficulty
## ("county_line:normal"), and where the player started on the route's loop (RouteLoop).
## Practice runs are never recorded.

## main.gd's --save=NAME points this at another file in user://, so a test run can pick a start
## or finish songs without touching the player's own save.
static var path: String = "user://save.json"

var calibration: float = 0.0
var best: Dictionary = {}
var settings: Dictionary = Settings.DEFAULTS.duplicate()
## The region id the player started the loop on, or "" before they pick one on the loop map.
var route_start: String = ""
## Region ids a save from before the loop had open (RouteLoop.old_chain_open): they stay open.
var route_kept: Array[String] = []


static func load_or_new() -> SaveData:
	var save := SaveData.new()
	if not FileAccess.file_exists(path):
		return save
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		save.calibration = float(parsed.get("calibration", 0.0))
		for key: String in Settings.DEFAULTS:
			save.settings[key] = (parsed.get("settings", {}) as Dictionary).get(key, Settings.DEFAULTS[key])
		var stored: Dictionary = parsed.get("best", {})
		for key: String in stored:
			# The first build kept one best per song; those were Normal runs.
			save.best[key if key.contains(":") else key + ":normal"] = stored[key]
		var route: Dictionary = parsed.get("route", {})
		save.route_start = str(route.get("start", ""))
		for id: Variant in route.get("kept", []):
			save.route_kept.append(str(id))
	return save


func write() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"calibration": calibration, "settings": settings, "best": best,
		"route": {"start": route_start, "kept": route_kept}}, " "))


func best_for(song_id: String, difficulty: String) -> Dictionary:
	return best.get("%s:%s" % [song_id, difficulty], {})


## A song counts as cleared once it has been finished without running out of gas.
func cleared(song_id: String) -> bool:
	for level: String in Chart.DIFFICULTIES:
		if not best_for(song_id, level).is_empty():
			return true
	return false


## Records a finished run and returns true if it beat the previous best.
func record(result: Dictionary) -> bool:
	if result["failed"]:
		return false
	var key: String = "%s:%s" % [result["song_id"], result.get("difficulty", "normal")]
	var previous: Dictionary = best.get(key, {})
	if int(result["score"]) <= int(previous.get("score", -1)):
		return false
	best[key] = {"score": result["score"], "grade": result["grade"], "accuracy": result["accuracy"]}
	write()
	return true
