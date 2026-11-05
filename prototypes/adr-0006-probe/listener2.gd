extends RefCounted
const FlowLike = preload("res://flow_like.gd")
var log: Array[String]
func _init(l: Array[String]) -> void:
	log = l
func on_int(n: int) -> void:
	log.append("int:" + str(n))
func on_untyped(n) -> void:
	log.append("untyped:" + type_string(typeof(n)) + ":" + str(n))
func on_phase(value: FlowLike.Phase) -> void:
	log.append("phase:" + str(value))
func on_two(a: int, b: int) -> void:
	log.append("two")
