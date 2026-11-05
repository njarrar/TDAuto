# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0009 V2 (a) run-time leg, (b) to (f).
extends "res://types/probes/probe_base.gd"


class FakeWave extends RefCounted:
	var _list: Array[Targetable] = []

	func targets() -> Array[Targetable]:
		return _list


func _take(list: Array[Targetable]) -> int:
	return list.size()


func _step_a(state: Dictionary) -> void:
	var enemies: Array[Enemy] = [Enemy.new(1, &"a")]
	var loose: Variant = enemies
	state["called"] = true
	state["size"] = _take(loose)
	state["after"] = true


func run() -> void:
	var state: Dictionary = {"called": false, "after": false, "size": -1}
	var e0: int = errs()
	_step_a(state)
	var e1: int = errs()
	var errored: bool = not state["after"] or (e0 >= 0 and e1 > e0)
	add("ADR-0009-V2a-runtime", "PASS" if errored else "FAIL", "finished=%s size=%s errors=+%s" % [state["after"], state["size"], "n/a" if e0 < 0 else str(e1 - e0)], "an error")

	var ts: Array[Targetable] = []
	ts.append(Enemy.new(2, &"b"))
	check("ADR-0009-V2b", ts.size() == 1, "size=%d" % ts.size(), "append of Enemy to Array[Targetable] succeeds")

	var e: Enemy = ts[0] as Enemy
	check("ADR-0009-V2c", e != null and e.def_id == &"b", "as Enemy -> %s" % ("instance def_id=" + str(e.def_id) if e != null else "null"), "the instance")

	var wave: FakeWave = FakeWave.new()
	wave._list.append(Enemy.new(3, &"c"))
	var targets: Callable = wave.targets
	var list: Array[Targetable] = targets.call()
	var ok_d: bool = list.size() == 1 and list.is_typed() and list.get_typed_script() == Targetable
	check("ADR-0009-V2d", ok_d, "size=%d typed=%s script_is_Targetable=%s same_buffer=%s" % [list.size(), list.is_typed(), list.get_typed_script() == Targetable, is_same(list, wave._list)], "assigns without error, keeps the element type")

	var arr: Array[int] = [10, 20, 30, 40]
	arr.remove_at(1)
	var after_remove: String = str(arr)
	arr.erase(30)
	check("ADR-0009-V2e", after_remove == "[10, 30, 40]" and str(arr) == "[10, 40]", "remove_at(1) -> %s; erase(30) -> %s" % [after_remove, arr], "[10, 30, 40] then [10, 40]")

	record("ADR-0009-V2f", "not observable from GDScript (no capacity read)", "recorded, not required")
	done = true
