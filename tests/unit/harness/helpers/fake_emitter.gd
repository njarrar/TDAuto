extends RefCounted
## Emitter with typed and badly typed signals, for the recording fake's own tests.

signal moved(id: StringName, count: int)
signal ticked
signal many(a: int, b: int, c: int, d: int, e: int, f: int)
signal untyped(value)
signal carries_object(thing: Object)


func emit_moved(id: StringName, count: int) -> void:
	moved.emit(id, count)


func emit_ticked() -> void:
	ticked.emit()


func emit_many() -> void:
	many.emit(1, 2, 3, 4, 5, 6)


## Emits a String where a StringName is declared (signal types are not checked at emit).
func emit_moved_with_string() -> void:
	moved.emit("a", 1)


## Emits one argument where two are declared.
func emit_moved_short() -> void:
	emit_signal(&"moved", &"a")


func emit_untyped() -> void:
	untyped.emit(1)


func emit_object() -> void:
	carries_object.emit(RefCounted.new())
