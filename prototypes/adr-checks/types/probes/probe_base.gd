# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe.
extends RefCounted
## Base for probes that check_types.gd loads at run time. Rows are kept as
## the probe runs, so an abort keeps the rows written before it.

var rows: Array = []
var done: bool = false
## Set by the driver: returns the error count, or -1.
var error_count: Callable = Callable()


func run() -> void:
	done = true


func errs() -> int:
	if not error_count.is_valid():
		return -1
	return int(error_count.call())


func add(id: String, status: String, observed: Variant, expected: String) -> void:
	rows.append([id, status, str(observed), expected])


func check(id: String, ok: bool, observed: Variant, expected: String) -> void:
	add(id, "PASS" if ok else "FAIL", observed, expected)


func record(id: String, observed: Variant, expected: String) -> void:
	add(id, "RECORD", observed, expected)
