# PROTOTYPE - NOT FOR PRODUCTION. ADR checks.
extends RefCounted
## Prints one RESULT line per item and counts FAIL lines.
## Also owns an optional error counter: a Logger loaded at run time from
## error_counter.gd. If that file does not load (wrong Logger API), errors()
## returns -1 and the checks still run.

const COUNTER_PATH: String = "res://types/error_counter.gd"

var fails: int = 0
var _counter: Variant = null


func _init() -> void:
	var script: GDScript = load(COUNTER_PATH) as GDScript
	if script == null or not script.can_instantiate():
		print("NOTE error counter not loaded; error counts read -1")
		return
	if not OS.has_method("add_logger"):
		print("NOTE OS.add_logger missing; error counts read -1")
		return
	_counter = script.new()
	OS.call("add_logger", _counter)


## Engine and script errors logged since start, or -1 if no counter.
func errors() -> int:
	if _counter == null:
		return -1
	return int(_counter.get("errors"))


## Warnings logged since start, or -1 if no counter.
func warnings() -> int:
	if _counter == null:
		return -1
	return int(_counter.get("warnings"))


## The text of the last error seen, or "".
func last_error() -> String:
	if _counter == null:
		return ""
	return str(_counter.get("last"))


## Prints one RESULT line. status is PASS, FAIL or RECORD.
func result(id: String, status: String, observed: Variant, expected: String) -> void:
	if status == "FAIL":
		fails += 1
	var text: String = str(observed).replace("\n", " ").replace("\r", " ")
	print("RESULT %s %s %s | expected: %s" % [id, status, text, expected])


## PASS when ok, else FAIL.
func check(id: String, ok: bool, observed: Variant, expected: String) -> void:
	result(id, "PASS" if ok else "FAIL", observed, expected)


## Records a value with no pass or fail.
func record(id: String, observed: Variant, expected: String) -> void:
	result(id, "RECORD", observed, expected)


## Prints the END marker, removes the logger and quits (1 if any FAIL).
func finish(tree: SceneTree, script_name: String) -> void:
	print("END %s fails=%d" % [script_name, fails])
	if _counter != null and OS.has_method("remove_logger"):
		OS.call("remove_logger", _counter)
	tree.quit(1 if fails > 0 else 0)
