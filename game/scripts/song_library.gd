class_name SongLibrary
extends RefCounted
## Every playable song: built-in charts in res://data/songs/ and the player's own
## imports in user://songs/<id>/chart.json. Entries are chart metadata plus "path".

const USER_DIR := "user://songs"

## Difficulty.rate results by chart path, kept while the file is unchanged: the route screen
## rebuilds its song list on every key press, and rating ~90 songs each time would stall it.
static var _rating_cache: Dictionary = {}


## The library is read once and kept: the route screen asks for it several times on every key
## press, and reading ~95 chart files each time stalled it. invalidate() after an import or a
## removal.
static var _cached: Array[Dictionary] = []
static var _cached_ok: bool = false


static func all() -> Array[Dictionary]:
	if _cached_ok:
		return _cached
	var songs: Array[Dictionary] = []
	for file: String in DirAccess.get_files_at("res://data/songs"):
		if file.ends_with(".json"):
			_add(songs, "res://data/songs/" + file)
	if DirAccess.dir_exists_absolute(USER_DIR):
		for folder: String in DirAccess.get_directories_at(USER_DIR):
			_add(songs, "%s/%s/chart.json" % [USER_DIR, folder])
	songs.sort_custom(_before)
	_cached = songs
	_cached_ok = true
	return songs


## Forgets the library, so the next all() reads the chart files again.
static func invalidate() -> void:
	_cached_ok = false


static func in_region(region: String) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	for song: Dictionary in all():
		if song["theme"] == region:
			picked.append(song)
	return picked


static func find(song_id: String) -> Dictionary:
	for song: Dictionary in all():
		if song["id"] == song_id:
			return song
	return {}


## A fresh folder for an import, named from the title so it is findable on disk.
static func new_import_dir(title: String) -> String:
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var base: String = title.to_lower().validate_filename().replace(" ", "_").left(32)
	return "%s/%s_%d" % [USER_DIR, base if not base.is_empty() else "song", Time.get_unix_time_from_system()]


## Moves an imported song to the OS trash rather than deleting it outright.
static func remove_import(song: Dictionary) -> Error:
	if song.get("source", "") != "imported":
		return ERR_UNAUTHORIZED
	return OS.move_to_trash(ProjectSettings.globalize_path(str(song["path"]).get_base_dir()))


static func _add(songs: Array[Dictionary], path: String) -> void:
	var meta: Dictionary = Chart.read_meta(path)
	if meta.is_empty() or not meta.has("id"):
		return
	var entry: Dictionary = {
		"id": meta["id"], "title": meta.get("title", meta["id"]), "theme": meta.get("theme", "backroads"),
		"source": meta.get("source", "builtin"), "bpm": meta.get("bpm", 120.0), "duration": meta.get("duration", 0.0),
		"path": path, "notes": (meta.get("notes", []) as Array).size(),
		# The space game radio station a song came from, if any (tools/importer/import_radio.sh).
		"station": meta.get("station", ""),
		# Per difficulty: Difficulty.rate's {"level", "score", "reasons", "peak_nps"}.
		"ratings": _ratings_for(path, meta),
	}
	songs.append(entry)


static func _ratings_for(path: String, meta: Dictionary) -> Dictionary:
	var stamp: int = FileAccess.get_modified_time(path)
	var cached: Dictionary = _rating_cache.get(path, {})
	if not cached.is_empty() and int(cached["stamp"]) == stamp:
		return cached["ratings"]
	var levels: Dictionary = meta.get("difficulties", {})
	var ratings: Dictionary = {}
	for level: String in Chart.DIFFICULTIES:
		ratings[level] = Difficulty.rate(levels.get(level, meta.get("notes", [])))
	_rating_cache[path] = {"stamp": stamp, "ratings": ratings}
	return ratings


## A song's level (1-10) at one difficulty, as a whole number for menus.
static func level_of(song: Dictionary, difficulty: String) -> int:
	return Difficulty.level_of((song.get("ratings", {}) as Dictionary).get(difficulty, {}))


## Built-in songs first, easiest first (by their Normal chart's difficulty), so a region's list
## reads as a climb; then the player's own, newest last.
static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["source"] != b["source"]:
		return a["source"] == "builtin"
	if a["source"] == "builtin":
		var level_a: float = float((a["ratings"] as Dictionary)["normal"]["level"])
		var level_b: float = float((b["ratings"] as Dictionary)["normal"]["level"])
		if not is_equal_approx(level_a, level_b):
			return level_a < level_b
		return str(a["title"]) < str(b["title"])
	return str(a["path"]) < str(b["path"])
