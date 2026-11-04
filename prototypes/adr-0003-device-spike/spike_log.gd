# PROTOTYPE - NOT FOR PRODUCTION. ADR-0003 device spike.
# Collects log lines and groups them by frame. Each line carries the engine
# clock (t, microseconds) and the wall clock (u, Unix seconds), so the order
# across a suspension is certain (SP10). A group ends at each PROC marker
# (the root node's _process). A group that holds only frame markers is dropped,
# so quiet frames leave no lines. Committed lines go to the screen view, to
# user://spike_log.txt and to stdout (print), so Xcode and adb logcat show them too.
extends RefCounted

const LOG_PATH: String = "user://spike_log.txt"
const PREV_PATH: String = "user://spike_log_prev.txt"
const SCREEN_LINES: int = 32
const MAX_KEPT_LINES: int = 20000

## The last frame marker written: "START", "PHYS" or "PROC".
var last_marker: String = "START"
## Input events first seen by _input while the last marker was PROC or START.
var events_after_proc: int = 0
## Input events first seen by _input while the last marker was PHYS.
var events_after_phys: int = 0
## When true, mouse motion with no button held is kept out of the screen view
## (it is still written to the file).
var hide_hover_on_screen: bool = true
## Set when the screen view has new lines.
var screen_dirty: bool = true

var _file: FileAccess = null
var _seq: int = 0
var _staged: PackedStringArray = PackedStringArray()
var _staged_screen: PackedStringArray = PackedStringArray()
var _staged_has_entry: bool = false
var _last_proc_line: String = ""
var _last_group_committed: bool = true
var _screen: PackedStringArray = PackedStringArray()
var _kept: PackedStringArray = PackedStringArray()


## Opens user://spike_log.txt for writing. The previous run's log is kept as
## user://spike_log_prev.txt.
func open_file() -> void:
	var log_abs: String = ProjectSettings.globalize_path(LOG_PATH)
	var prev_abs: String = ProjectSettings.globalize_path(PREV_PATH)
	if FileAccess.file_exists(PREV_PATH):
		DirAccess.remove_absolute(prev_abs)
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.rename_absolute(log_abs, prev_abs)
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if _file == null:
		push_error("spike: cannot open %s (error %d)" % [LOG_PATH, FileAccess.get_open_error()])


## Adds one line to the current frame group.
## on_screen false keeps the line out of the screen view only.
func entry(tag: String, text: String, on_screen: bool = true) -> void:
	_seq += 1
	var frame: int = Engine.get_process_frames()
	var file_line: String = "%06d f%d pf%d t%d u%.3f after=%s %s %s" % [
		_seq, frame, Engine.get_physics_frames(), Time.get_ticks_usec(),
		Time.get_unix_time_from_system(), last_marker, tag, text]
	_staged.append(file_line)
	if on_screen:
		_staged_screen.append("f%d %s %s" % [frame, tag, text])
	else:
		_staged_screen.append("")
	_staged_has_entry = true


## Writes a frame marker ("PHYS" or "PROC"). At PROC the group since the last
## PROC is committed if it holds any entry, and dropped otherwise.
func marker(kind: String, text: String) -> void:
	_seq += 1
	var frame: int = Engine.get_process_frames()
	var file_line: String = "%06d f%d pf%d t%d u%.3f %s %s" % [
		_seq, frame, Engine.get_physics_frames(), Time.get_ticks_usec(),
		Time.get_unix_time_from_system(), kind, text]
	_staged.append(file_line)
	_staged_screen.append("f%d %s %s" % [frame, kind, text])
	last_marker = kind
	if kind != "PROC":
		return
	if _staged_has_entry:
		_write_context()
		_commit()
		_last_group_committed = true
	else:
		_staged.clear()
		_staged_screen.clear()
		_last_group_committed = false
	_last_proc_line = file_line


## Commits the current group at once, without waiting for the next PROC. Used
## after lifecycle notifications, because the app may be suspended or killed
## before another frame runs.
func flush_now() -> void:
	if not _staged_has_entry:
		return
	_write_context()
	_commit()
	_last_group_committed = true


## Sequence number of the last line added (entries and markers).
func seq() -> int:
	return _seq


## All committed lines of the on-screen view, oldest first.
func screen_text() -> String:
	return "\n".join(_screen)


## Every committed line of this run (up to MAX_KEPT_LINES), for the Copy button.
func all_text() -> String:
	return "\n".join(_kept)


## Number of committed lines kept in memory.
func kept_count() -> int:
	return _kept.size()


## Empties the screen view. The file and the kept lines are not touched.
func clear_screen() -> void:
	_screen.clear()
	screen_dirty = true


## Commits what is staged and closes the file.
func close() -> void:
	flush_now()
	if _file != null:
		_file.flush()
		_file.close()
		_file = null


# When the previous group was dropped as quiet, its PROC line is written first,
# so the reader can see which frame this group follows.
func _write_context() -> void:
	if not _last_group_committed and _last_proc_line != "":
		_write("ctx " + _last_proc_line, "")


func _commit() -> void:
	for i: int in _staged.size():
		_write(_staged[i], _staged_screen[i])
	_staged.clear()
	_staged_screen.clear()
	_staged_has_entry = false
	if _file != null:
		_file.flush()


func _write(file_line: String, screen_line: String) -> void:
	if _file != null:
		_file.store_line(file_line)
	print(file_line)
	if _kept.size() < MAX_KEPT_LINES:
		_kept.append(file_line)
	if screen_line != "":
		_screen.append(screen_line)
		while _screen.size() > SCREEN_LINES:
			_screen.remove_at(0)
		screen_dirty = true
