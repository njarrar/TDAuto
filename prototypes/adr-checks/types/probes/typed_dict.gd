# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0009 V2 (g): typed Dictionary[int, ReadContext].
extends "res://types/probes/probe_base.gd"

var d: Dictionary[int, ReadContext] = {}


func _put(key: int, value: Variant, state: Dictionary) -> void:
	d[key] = value
	state["after"] = true


func run() -> void:
	d[1] = ReadContext.new()
	var state: Dictionary = {"after": false}
	var e0: int = errs()
	_put(2, Health.new(1), state)
	var e1: int = errs()
	var rejected: bool = not d.has(2)
	check("ADR-0009-V2g", rejected and d.size() == 1, "parses; wrong value stored=%s finished=%s errors=+%s" % [d.has(2), state["after"], "n/a" if e0 < 0 else str(e1 - e0)], "parses and rejects a wrong value type")
	done = true
