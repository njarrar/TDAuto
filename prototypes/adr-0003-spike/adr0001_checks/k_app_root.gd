class_name KAppRoot extends Node
enum State { BOOT, IN_STAGE, FATAL }
const FATAL_SCENE: PackedScene = preload("res://adr0001_checks/ok_scene.tscn")
var _state: State = State.BOOT
func state() -> State:
	return _state
func fatal(cause: String) -> void:
	print("PROBE|app_fatal=", cause)
