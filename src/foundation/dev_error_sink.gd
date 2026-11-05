class_name DevErrorSink extends RefCounted
## Default development-error sink (ADR-0001 Decision 4). Injected as
## `sink.report`. Always calls push_error and records the message in memory.
## It never changes game state. Tests inject a recording fake instead.

var _messages: PackedStringArray = PackedStringArray()


## Reports one development error: push_error, then record it.
func report(msg: String) -> void:
	push_error(msg)
	_messages.append(msg)


## Every message reported so far, in order.
func messages() -> PackedStringArray:
	return _messages


## Number of messages reported so far.
func count() -> int:
	return _messages.size()
