extends RefCounted
## Error-capture helpers (ADR-0007 Decision 7).
##
## With [gdunit4] report/godot/push_error=true, every push_error, push_warning and engine
## error a test does not assert fails it. Expected errors are asserted by message:
##
##   await assert_error(pusher.push_error_once).is_push_error(MESSAGE)
##
## The asserted callable must push its error ONCE: a callable that pushes the same message
## twice cannot be asserted twice without running it again. Pusher.push_error_once
## pushes exactly once per call.
##
## Never assert engine error text (Decision 7 item 3).


## Pushes one error per call. Message is set at construction.
class Pusher extends RefCounted:
	var message: String = ""

	func _init(p_message: String = "pusher") -> void:
		message = p_message

	func push_error_once() -> void:
		push_error(message)


## Pushes one warning per call. Used to prove an unasserted warning fails a test (V2).
class Warner extends RefCounted:
	var message: String = ""

	func _init(p_message: String = "warner") -> void:
		message = p_message

	func push_warning_once() -> void:
		push_warning(message)


## Returns a node nobody frees: with report/verbose_orphans=true it makes the run exit 101.
## Seeded proof only (ADR-0007 Validation 4); never call it in a normal test.
static func leak_node() -> Node:
	return Node.new()
