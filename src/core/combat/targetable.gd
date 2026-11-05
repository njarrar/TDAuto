class_name Targetable extends RefCounted
## The one type Combat sees (ADR-0009 Decision 1). Pure data: no references to
## EnemyWave, Combat or Battle. Combat writes `health` and `status` (through
## `Combat.attach`); EnemyWave writes `distance`, `pos_x`, `pos_y` and `removed`.

## Battle-wide id, never reused. Every tie-break uses it.
var spawn_id: int
## Distance along the path, cached once per tick.
var distance: float = 0.0
## Centre in field units (y down), cached once per tick.
var pos_x: float = 0.0
var pos_y: float = 0.0
## True once the enemy has left the roster by leak or reap.
var removed: bool = false
## Set once by `Combat.attach`.
var health: Health = null
var status: Status = null


func _init(p_spawn_id: int) -> void:
	spawn_id = p_spawn_id


## For views, and for building view-signal payloads. Sim code must never use
## the result for a decision, a comparison or stored state.
func view_position() -> Vector2:
	return Vector2(pos_x, pos_y)
