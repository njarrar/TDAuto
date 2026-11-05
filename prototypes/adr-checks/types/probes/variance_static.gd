# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0009 V2 (a), static leg: Array[Enemy] passed to Array[Targetable].
# If the analyzer rejects this, the file does not load (the driver records it).
extends "res://types/probes/probe_base.gd"


func take(list: Array[Targetable]) -> int:
	return list.size()


func run() -> void:
	var enemies: Array[Enemy] = [Enemy.new(1, &"a")]
	var e0: int = errs()
	var state: Dictionary = {"after": false}
	_step(enemies, state)
	var e1: int = errs()
	record("ADR-0009-V2a-static-run", "loads; call finished=%s errors=+%s" % [state["after"], "n/a" if e0 < 0 else str(e1 - e0)], "record: what happens when it loads")
	done = true


func _step(enemies: Array[Enemy], state: Dictionary) -> void:
	var n: int = take(enemies)
	state["after"] = n >= 0
