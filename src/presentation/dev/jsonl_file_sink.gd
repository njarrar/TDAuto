class_name JsonlFileSink extends RefCounted
## Append-only JSON Lines file for development logs (ADR-0008 V8, ADR-0010
## Decision 10). One handle, flushed after every line, every store checked.
## Open returns null in release builds or on failure.

var _file: FileAccess = null


## Opens `path` for appending: READ_WRITE if the file exists, else WRITE, then
## seek_end. Null in release builds or on failure; the caller reports a failed
## open once through dev_error with FileAccess.get_open_error().
static func open(path: String) -> JsonlFileSink:
	if not OS.is_debug_build():
		return null
	var mode: FileAccess.ModeFlags = FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var file: FileAccess = FileAccess.open(path, mode)
	if file == null:
		return null
	file.seek_end()
	var sink: JsonlFileSink = JsonlFileSink.new()
	sink._file = file
	return sink


## Stores `text` and a newline, then flushes. False if the sink is closed or a store failed.
func write_line(text: String) -> bool:
	if _file == null:
		return false
	var stored: bool = _file.store_string(text + "\n")
	if not stored:
		return false
	_file.flush()
	return true


## True while the file handle is open.
func is_open() -> bool:
	return _file != null


## Closes the handle. Safe to call twice.
func close() -> void:
	if _file == null:
		return
	_file.flush()
	_file.close()
	_file = null
