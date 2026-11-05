# PROTOTYPE - NOT FOR PRODUCTION. ADR checks stub. (ADR-0009 V6)
class_name Health
extends RefCounted

var hp: int = 0


func _init(p_max_hp: int = 1) -> void:
	hp = p_max_hp
