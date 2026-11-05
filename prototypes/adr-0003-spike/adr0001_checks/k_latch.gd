class_name KLatch extends RefCounted
var is_set: bool
var cause: String
var _upstream: Callable
func _init(upstream: Callable = Callable()) -> void:
	_upstream = upstream
func fatal(cause: String) -> void:
	if is_set:
		return
	is_set = true
	self.cause = cause
	if _upstream.is_valid():
		_upstream.call(cause)
