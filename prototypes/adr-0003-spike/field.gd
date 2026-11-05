extends Node2D
## The stand-in for the input adapter: reads presses, moves and releases
## in _unhandled_input, as the Input GDD's ADR note proposes.

func _unhandled_input(event: InputEvent) -> void:
	get_parent().log_event("field._unhandled_input", event)

func _process(_delta: float) -> void:
	get_parent().mark("field._process")
