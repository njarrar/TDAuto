class_name KAppRootBroken extends Node
const FATAL_SCENE: PackedScene = preload("res://adr0001_checks/broken_scene.tscn")
func show_fatal() -> void:
	var n := FATAL_SCENE.instantiate()
	print("PROBE|broken_instantiated=", n, " script=", n.get_script())
