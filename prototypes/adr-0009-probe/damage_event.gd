class_name DamageEvent extends RefCounted
var target: Targetable
var amount: float
var source_kind: Combat.SourceKind
var source_id: StringName
func _init(p_target: Targetable, p_amount: float, p_kind: Combat.SourceKind, p_source_id: StringName) -> void:
	target = p_target; amount = p_amount; source_kind = p_kind; source_id = p_source_id
