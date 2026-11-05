# PROTOTYPE - NOT FOR PRODUCTION. ADR-0001 V3 (editor leg).
extends Node
## Loads each broken scene with ResourceLoader.load(), instantiates it if it
## is a PackedScene, and logs what came back and how many engine errors each
## step raised. Errors in the Output panel are expected.

const LOG_PATH := "user://adr0001_v3_log.txt"
const CASES: PackedStringArray = [
	"res://broken/does_not_exist.tscn",
	"res://broken/broken_script.tscn",
	"res://broken/missing_ext.tscn",
	"res://broken/missing_sub.tscn",
	"res://broken/good.tscn",
]

var _counter: Object = null
var _file: FileAccess


func _ready() -> void:
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_install_counter()
	_log("INFO godot=%s debug=%s display=%s log=%s" % [Engine.get_version_info().get("string", "?"), OS.is_debug_build(), DisplayServer.get_name(), ProjectSettings.globalize_path(LOG_PATH)])
	for path: String in CASES:
		_run_case(path)
	_log("END v3")
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0)


func _install_counter() -> void:
	var script: Script = load("res://error_counter.gd") as Script
	if script == null or not OS.has_method("add_logger"):
		_log("INFO error counter off, error counts read n/a")
		return
	_counter = script.new()
	OS.call("add_logger", _counter)


func _run_case(path: String) -> void:
	var e0: int = _errors()
	var exists: bool = ResourceLoader.exists(path)
	var res: Resource = ResourceLoader.load(path)
	var e1: int = _errors()
	var desc: String = "null" if res == null else res.get_class()
	_log("LOAD %s exists=%s result=%s packed_scene=%s errors=%s last=%s" % [path, exists, desc, res is PackedScene, _diff(e0, e1), _last()])
	if not (res is PackedScene):
		return
	var inst: Node = (res as PackedScene).instantiate()
	var e2: int = _errors()
	if inst == null:
		_log("INSTANTIATE %s result=null errors=%s last=%s" % [path, _diff(e1, e2), _last()])
		return
	var scr: Variant = inst.get_script()
	var scr_text: String = "none" if scr == null else str(scr)
	_log("INSTANTIATE %s result=%s children=%d script=%s errors=%s last=%s" % [path, inst.get_class(), inst.get_child_count(), scr_text, _diff(e1, e2), _last()])
	inst.free()


func _errors() -> int:
	if _counter == null:
		return -1
	return int(_counter.get("errors"))


func _last() -> String:
	if _counter == null:
		return "n/a"
	return "\"%s\"" % str(_counter.get("last"))


func _diff(before: int, after: int) -> String:
	if before < 0:
		return "n/a"
	return str(after - before)


func _log(text: String) -> void:
	print(text)
	if _file != null:
		_file.store_line(text)
		_file.flush()
