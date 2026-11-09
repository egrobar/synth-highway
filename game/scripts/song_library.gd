class_name SongLibrary
extends RefCounted
## Every playable song: built-in charts in res://data/songs/ and the player's own
## imports in user://songs/<id>/chart.json. Entries are chart metadata plus "path".

const USER_DIR := "user://songs"


static func all() -> Array[Dictionary]:
	var songs: Array[Dictionary] = []
	for file: String in DirAccess.get_files_at("res://data/songs"):
		if file.ends_with(".json"):
			_add(songs, "res://data/songs/" + file)
	if DirAccess.dir_exists_absolute(USER_DIR):
		for folder: String in DirAccess.get_directories_at(USER_DIR):
			_add(songs, "%s/%s/chart.json" % [USER_DIR, folder])
	songs.sort_custom(_before)
	return songs


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
	}
	songs.append(entry)


## Built-in songs first, easiest first; then the player's own, newest last.
static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["source"] != b["source"]:
		return a["source"] == "builtin"
	var rate_a: float = float(a["notes"]) / maxf(float(a["duration"]), 1.0)
	var rate_b: float = float(b["notes"]) / maxf(float(b["duration"]), 1.0)
	if a["source"] == "builtin":
		return rate_a < rate_b
	return str(a["path"]) < str(b["path"])
