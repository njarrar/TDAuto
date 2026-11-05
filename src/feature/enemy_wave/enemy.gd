class_name Enemy extends Targetable
## One enemy on the roster (ADR-0009 Decision 1). Holds no ReadContext, no
## reference to EnemyWave, Combat or Battle, and no Callable.

## The enemy record's id.
var def_id: StringName = &""
## Path segment hint for `PathTrack.place`.
var segment: int = 0


func _init(p_spawn_id: int, p_def_id: StringName) -> void:
	super(p_spawn_id)
	def_id = p_def_id
