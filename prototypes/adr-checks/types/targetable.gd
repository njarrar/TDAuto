# PROTOTYPE - NOT FOR PRODUCTION. ADR checks stub. (ADR-0009 V2, V6, V7)
class_name Targetable
extends RefCounted
## Base class with a required constructor argument. Types fields Health, Status.

var spawn_id: int = 0
var health: Health = null
var status: Status = null


func _init(p_spawn_id: int) -> void:
	spawn_id = p_spawn_id
	health = Health.new(10)
	status = Status.new()
