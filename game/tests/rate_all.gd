extends SceneTree
## Prints every song's difficulty (Difficulty.rate) for both levels, hardest first, plus the
## score spread: used to calibrate Difficulty.SCORE_AT_1 / SCORE_AT_10 and to check the model.
##   tools/godot.sh --headless -s res://tests/rate_all.gd


func _init() -> void:
	var rows: Array = []
	for song: Dictionary in SongLibrary.all():
		var meta: Dictionary = Chart.read_meta(str(song["path"]))
		var levels: Dictionary = meta.get("difficulties", {})
		for level: String in Chart.DIFFICULTIES:
			var raw: Array = levels.get(level, meta.get("notes", []))
			var r: Dictionary = Difficulty.rate(raw)
			rows.append([float(r["score"]), level, str(song["id"]), float(r["level"]), float(r["peak_nps"]),
				", ".join(r["reasons"]), str(song["theme"]), raw.size()])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for row: Array in rows:
		print("%6.2f  Lv%4.1f  %-6s %-40s %-9s n=%4d peak %.1f/s  %s" % [row[0], row[3], row[1], str(row[2]).left(40), row[6], row[7], row[4], row[5]])
	var scores: Array[float] = []
	for row: Array in rows:
		scores.append(float(row[0]))
	scores.sort()
	var at := func(q: float) -> float: return scores[int(floor(q * float(scores.size() - 1)))]
	print("SPREAD min %.2f  p5 %.2f  p25 %.2f  p50 %.2f  p75 %.2f  p95 %.2f  max %.2f  (%d charts)" % [
		scores[0], at.call(0.05), at.call(0.25), at.call(0.5), at.call(0.75), at.call(0.95), scores[-1], scores.size()])
	quit()
