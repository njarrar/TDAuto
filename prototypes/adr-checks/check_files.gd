# PROTOTYPE - NOT FOR PRODUCTION. ADR checks: file append and debug flag.
# Covers ADR-0008 V7, V8 and ADR-0010 V1, V2 (one run closes both ADRs).
# Release half of the debug flag is ADR-0001 V4 (phone export), not here.
# Works in user://adr_checks/ and removes its files at the end.
# Run: godot --headless --path . -s res://check_files.gd
extends SceneTree

const Report := preload("res://types/report.gd")
const DIR: String = "user://adr_checks"

var _r: Report = Report.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_debug_flags()
	_write_truncates()
	_read_write_missing()
	_append()
	_flush()
	_store_returns_bool()
	_r.record("ADR-0010-V3-info", "user data dir: %s" % OS.get_user_data_dir(), "record only (V3 itself is a windowed run)")
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))
	DirAccess.remove_absolute(DIR)
	_r.finish(self, "check_files.gd")


func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _debug_flags() -> void:
	var dbg: bool = OS.is_debug_build()
	_r.check("ADR-0008-V7a", dbg, "is_debug_build=%s" % dbg, "true in an editor run")
	_r.check("ADR-0010-V2", dbg, "is_debug_build=%s (headless editor binary)" % dbg, "true in an editor run; release half from ADR-0001 V4")
	var model: String = OS.get_model_name()
	_r.check("ADR-0008-V7b", not model.is_empty(), "get_model_name=\"%s\" os=%s" % [model, OS.get_name()], "non-empty")


func _write_truncates() -> void:
	var p: String = DIR.path_join("truncate.txt")
	_write(p, "abc")
	_write(p, "x")
	var got: String = FileAccess.get_file_as_string(p)
	_r.check("ADR-0008-V8-write-truncates", got == "x", "\"%s\"" % got, "\"x\" (WRITE truncates)")
	_r.check("ADR-0010-V1-write-truncates", got == "x", "\"%s\"" % got, "\"x\"")


func _read_write_missing() -> void:
	var p: String = DIR.path_join("missing.txt")
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	var f: FileAccess = FileAccess.open(p, FileAccess.READ_WRITE)
	var err: int = FileAccess.get_open_error()
	var created: bool = FileAccess.file_exists(p)
	var failed: bool = f == null
	if f != null:
		f.close()
	_r.check("ADR-0008-V8-read-write-missing", failed and not created, "open null=%s file created=%s" % [failed, created], "fails on a missing file")
	_r.check("ADR-0010-V1-read-write-missing", failed and not created, "open null=%s file created=%s" % [failed, created], "fails on a missing file")
	_r.record("ADR-0010-V1-get_open_error", "%d (%s)" % [err, error_string(err)], "record (likely ERR_FILE_NOT_FOUND)")


func _append() -> void:
	var p: String = DIR.path_join("append.txt")
	_write(p, "abc")
	var f: FileAccess = FileAccess.open(p, FileAccess.READ_WRITE)
	f.close()
	var untouched: String = FileAccess.get_file_as_string(p)
	f = FileAccess.open(p, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string("def")
	f.close()
	var got: String = FileAccess.get_file_as_string(p)
	var ok: bool = untouched == "abc" and got == "abcdef"
	_r.check("ADR-0008-V8-append", ok, "READ_WRITE open and close: \"%s\"; after seek_end + store_string: \"%s\"" % [untouched, got], "\"abc\" (no truncate) then \"abcdef\"")
	_r.check("ADR-0010-V1-append", ok, "\"%s\" then \"%s\"" % [untouched, got], "\"abc\" then \"abcdef\"")


func _flush() -> void:
	var p: String = DIR.path_join("flush.txt")
	_write(p, "abc")
	var f: FileAccess = FileAccess.open(p, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string("ghi")
	f.flush()
	var while_open: String = FileAccess.get_file_as_string(p)
	f.close()
	_r.check("ADR-0008-V8-flush", while_open == "abcghi", "read while open after flush: \"%s\"" % while_open, "\"abcghi\" (flush writes through)")
	_r.check("ADR-0010-V1-flush", while_open == "abcghi", "\"%s\"" % while_open, "\"abcghi\"")


func _store_returns_bool() -> void:
	# Called by name so a void return cannot stop this script from parsing.
	var p: String = DIR.path_join("store.bin")
	var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
	var calls: Array = [
		["store_string", ["x"]], ["store_line", ["y"]], ["store_8", [1]],
		["store_32", [2]], ["store_double", [1.5]], ["store_buffer", [PackedByteArray([1, 2])]],
	]
	var types: Array = []
	var all_bool: bool = true
	for c in calls:
		var rv: Variant = f.callv(c[0], c[1])
		types.append("%s:%s=%s" % [c[0], type_string(typeof(rv)), rv])
		if typeof(rv) != TYPE_BOOL:
			all_bool = false
	f.close()
	_r.check("ADR-0008-V8-store-bool", all_bool, ", ".join(PackedStringArray(types)), "bool from every store_*")
	_r.check("ADR-0010-V1-store-bool", all_bool, "store_string returns %s" % str(types[0]), "bool")
