class_name Targetable extends RefCounted
var spawn_id: int = 0
var distance: float = 0.0
var position: Vector2 = Vector2.ZERO
var removed: bool = false
var health: Health = null
func is_dead() -> bool: return health != null and health.hp <= 0.0
