extends Node
## Test stand-in for BattleWrapper: attach and detach only.

@export var attach_ok: bool = true
var battle: Battle = null
var attach_calls: int = 0
var detach_calls: int = 0


func attach(p_battle: Battle, _reduce_motion: bool, _dev_logs: Object = null) -> bool:
	attach_calls += 1
	if not attach_ok:
		return false
	battle = p_battle
	return true


func detach() -> void:
	detach_calls += 1
	battle = null
