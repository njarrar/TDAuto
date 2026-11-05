class_name GestureLog extends Node
## Development gesture log (ADR-0008 Decision 8). Debug builds only; made by
## BattleWrapper.attach. A view listener: reads only, no command, no sim write.
## One JSON line per finished gesture and one per tower upgrade. Time stamps
## are Time.get_ticks_msec(), frame-quantised, which is enough for Pillar 4.

var _resolver: InputResolver = null
var _adapter: InputAdapter = null
var _sink: Callable = Callable()
var _chip_open: Callable = Callable()
var _dev_error: Callable = Callable()
var _device: String = ""
var _press_ms: int = 0
var _press_chip_open: bool = false
var _press_best_tap: int = -1
var _press_best_drag: int = -1
var _error_reported: bool = false


## `sink` is `write_line(text: String) -> bool`. `chip_open` is
## `tower_input.is_chip_open`. `dev_error` is called once on a failed write.
func attach(resolver: InputResolver, adapter: InputAdapter, sink: Callable, chip_open: Callable = Callable(), dev_error: Callable = Callable()) -> void:
	_resolver = resolver
	_adapter = adapter
	_sink = sink
	_chip_open = chip_open
	_dev_error = dev_error
	_device = OS.get_model_name()
	_error_reported = false


## Drops every reference.
func detach() -> void:
	_resolver = null
	_adapter = null
	_sink = Callable()
	_chip_open = Callable()
	_dev_error = Callable()


## G1. Remembers the press time, the chip state and the frozen winners.
func _on_pressed(best_tap: int, best_drag: int, _p: Vector2) -> void:
	_press_ms = Time.get_ticks_msec()
	_press_best_tap = best_tap
	_press_best_drag = best_drag
	_press_chip_open = false
	if _chip_open.is_valid():
		_press_chip_open = bool(_chip_open.call())


## G8. Writes the finished gesture.
func _on_became_idle() -> void:
	if _resolver == null:
		return
	var end_ms: int = Time.get_ticks_msec()
	var gesture: GestureRecord = _resolver.last_gesture()
	if gesture == null:
		return
	var record: Dictionary = {
		"kind": "gesture",
		"device": _device,
		"press_ms": _press_ms,
		"end_ms": end_ms,
		"serial": gesture.serial,
		"pointer": gesture.pointer,
		"press_x": gesture.press_pos.x,
		"press_y": gesture.press_pos.y,
		"end_x": gesture.end_pos.x,
		"end_y": gesture.end_pos.y,
		"moves": gesture.moves,
		"max_travel": gesture.max_travel,
		"best_tap": _press_best_tap,
		"best_drag": _press_best_drag,
		"outcome": String(GestureRecord.Outcome.find_key(gesture.outcome)),
		"slop": gesture.slop,
		"chip_open": _press_chip_open,
	}
	if _adapter != null:
		var insets: FieldInsets = _adapter.field_insets()
		record["inset_top"] = insets.top
		record["inset_bottom"] = insets.bottom
		record["inset_left"] = insets.left
		record["inset_right"] = insets.right
		record["field_width_dp"] = _adapter.field_width_dp()
	_write(record)


## P5. Writes one upgrade line.
func _on_tower_upgraded(slot_index: int, level: int) -> void:
	_write({
		"kind": "upgrade",
		"t_ms": Time.get_ticks_msec(),
		"slot_index": slot_index,
		"level": level,
	})


func _write(record: Dictionary) -> void:
	var line: String = JSON.stringify(record, "", true, true)
	var ok: bool = false
	if _sink.is_valid():
		ok = bool(_sink.call(line))
	if ok or _error_reported:
		return
	_error_reported = true
	if _dev_error.is_valid():
		_dev_error.call("gesture_log: write failed")
