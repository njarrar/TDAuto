class_name CommandStep extends RefCounted
## One scripted command (ADR-0010 Decision 9). Values only.

var at_tick: int = 0
## &"build", &"upgrade", &"pin", &"burst", &"start_wave" or &"call_early".
var command: StringName = &""
var slot_index: int = -1
var tower_id: StringName = &""
var x: float = 0.0
var y: float = 0.0


func _init(p_at_tick: int = 0, p_command: StringName = &"", p_slot_index: int = -1,
		p_tower_id: StringName = &"", p_x: float = 0.0, p_y: float = 0.0) -> void:
	at_tick = p_at_tick
	command = p_command
	slot_index = p_slot_index
	tower_id = p_tower_id
	x = p_x
	y = p_y
