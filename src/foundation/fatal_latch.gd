class_name FatalLatch extends RefCounted
## Records the first fatal cause. Pure: no scene, no catalogue, no engine call.
## The error report itself (push_error) is made by FatalRelay, once per battle.

var _is_fatal: bool = false
var _cause: String = ""


## Records the first fatal cause. Later calls change nothing.
func fatal(p_cause: String) -> void:
	if _is_fatal:
		return
	_is_fatal = true
	_cause = p_cause


## True once fatal() has been called.
func is_fatal() -> bool:
	return _is_fatal


## The first cause, or "" if not fatal.
func cause() -> String:
	return _cause
