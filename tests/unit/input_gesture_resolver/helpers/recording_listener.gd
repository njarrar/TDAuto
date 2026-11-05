extends RefCounted
## Recording fake listener: appends "name(args)" to `log` for every signal.
## Ids print as names from `names`, -1 as NONE. `pos_log` holds the Vector2 payloads per entry.

var log: Array[String] = []
var pos_log: Array[PackedVector2Array] = []
var names: Dictionary = {}
var captured: Array[GestureRecord] = []
var capture_on_idle: InputResolver = null ## a resolver; when set, became_idle copies last_gesture()
var errors: Array[String] = []


func label(id: int) -> String:
	if id == -1:
		return "NONE"
	return str(names.get(id, "#" + str(id)))


func on_pressed(best_tap: int, best_drag: int, p: Vector2) -> void:
	_add("pressed(%s,%s)" % [label(best_tap), label(best_drag)], [p])


func on_tapped(best_tap: int, p: Vector2) -> void:
	_add("tapped(%s)" % label(best_tap), [p])


func on_ground_tapped(p: Vector2) -> void:
	_add("ground_tapped", [p])


func on_drag_started(best_drag: int, press_pos: Vector2, p: Vector2) -> void:
	_add("drag_started(%s)" % label(best_drag), [press_pos, p])


func on_drag_moved(best_drag: int, press_pos: Vector2, p: Vector2) -> void:
	_add("drag_moved(%s)" % label(best_drag), [press_pos, p])


func on_drag_ended(best_drag: int, press_pos: Vector2, release_pos: Vector2) -> void:
	_add("drag_ended(%s)" % label(best_drag), [press_pos, release_pos])


func on_drag_cancelled(best_drag: int) -> void:
	_add("drag_cancelled(%s)" % label(best_drag), [])


func on_became_idle() -> void:
	_add("became_idle", [])
	if capture_on_idle != null:
		var rec: GestureRecord = capture_on_idle.last_gesture()
		captured.append(rec)


## dev_error sink for tests that use a real InputResolver.
func on_error(msg: String) -> void:
	errors.append(msg)


func joined() -> String:
	return " | ".join(PackedStringArray(log))


func count_of(prefix: String) -> int:
	var n: int = 0
	for s: String in log:
		if s.begins_with(prefix):
			n += 1
	return n


func _add(text: String, ps: Array) -> void:
	log.append(text)
	pos_log.append(PackedVector2Array(ps))
