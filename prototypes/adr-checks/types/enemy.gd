# PROTOTYPE - NOT FOR PRODUCTION. ADR checks stub. (ADR-0009 V2, V6, V7)
class_name Enemy
extends Targetable

var def_id: StringName = &""


func _init(p_spawn_id: int, p_def_id: StringName) -> void:
	super(p_spawn_id)
	def_id = p_def_id
