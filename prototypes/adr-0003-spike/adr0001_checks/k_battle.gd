class_name KBattle extends RefCounted
var fatal_latch: KLatch
var _cancel: Callable
func set_input_cancel(cancel: Callable) -> void:
	_cancel = cancel
func cancel_input() -> void:
	if _cancel.is_valid():
		_cancel.call()
