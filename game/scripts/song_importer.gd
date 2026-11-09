class_name SongImporter
extends Node
## Runs tools/importer/import_song.py as a child process and reports its progress.
##
## The pipeline (Demucs, Basic Pitch, librosa) lives in the repo's .venv-pipeline,
## built by tools/setup_pipeline.sh. It prints "PROGRESS <0..1> <message>",
## "DONE <chart path>" or "ERROR <message>" lines; stdout and stderr are each read
## on their own thread so neither pipe can fill up and stall the separation.

signal progressed(fraction: float, message: String)
signal finished(chart_path: String)
signal failed(message: String)

var _pid: int = -1
var _stdout_thread: Thread
var _stderr_thread: Thread
var _stderr_tail: String = ""
var _done: bool = false


static func repo_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()


static func python_path() -> String:
	return repo_root().path_join(".venv-pipeline/bin/python")


## Empty when importing can run, otherwise what the player needs to do first.
static func setup_problem() -> String:
	if FileAccess.file_exists(python_path()):
		return ""
	return "Song import needs its tools installed once. In a terminal, run:\n%s/tools/setup_pipeline.sh" % repo_root()


func start(source_file: String, title: String, theme: String) -> String:
	var out_dir: String = SongLibrary.new_import_dir(title)
	var args := PackedStringArray([
		repo_root().path_join("tools/importer/import_song.py"), source_file,
		ProjectSettings.globalize_path(out_dir), "--theme", theme, "--title", title,
	])
	var pipes: Dictionary = OS.execute_with_pipe(python_path(), args)
	if pipes.is_empty():
		failed.emit("Could not start the importer.")
		return ""
	_pid = int(pipes["pid"])
	_done = false
	_stdout_thread = Thread.new()
	_stdout_thread.start(_read_stdout.bind(pipes["stdio"]))
	_stderr_thread = Thread.new()
	_stderr_thread.start(_read_stderr.bind(pipes["stderr"]))
	return out_dir


func cancel() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1


func is_running() -> bool:
	return _pid > 0 and not _done


func _read_stdout(pipe: FileAccess) -> void:
	while pipe.is_open() and pipe.get_error() == OK:
		var line: String = pipe.get_line().strip_edges()
		if not line.is_empty():
			_handle_line.call_deferred(line)
	_on_process_ended.call_deferred()


func _read_stderr(pipe: FileAccess) -> void:
	while pipe.is_open() and pipe.get_error() == OK:
		var line: String = pipe.get_line()
		_append_stderr.call_deferred(line)


func _append_stderr(line: String) -> void:
	_stderr_tail = (_stderr_tail + "\n" + line).right(1500)


func _handle_line(line: String) -> void:
	if line.begins_with("PROGRESS "):
		var parts: PackedStringArray = line.split(" ", true, 2)
		progressed.emit(float(parts[1]), parts[2] if parts.size() > 2 else "")
	elif line.begins_with("DONE "):
		_done = true
		finished.emit(ProjectSettings.localize_path(line.substr(5)))
	elif line.begins_with("ERROR "):
		_done = true
		failed.emit(line.substr(6))


func _on_process_ended() -> void:
	if not _done and _pid > 0:
		_done = true
		failed.emit("The importer stopped unexpectedly.\n" + _stderr_tail.right(400))
	_pid = -1
	for thread: Thread in [_stdout_thread, _stderr_thread]:
		if thread and thread.is_started():
			thread.wait_to_finish()


func _exit_tree() -> void:
	cancel()
