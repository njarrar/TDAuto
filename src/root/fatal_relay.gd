class_name FatalRelay extends RefCounted
## The injected `fatal(cause)` of one battle (ADR-0001 Decision 3). Owned by
## Battle. Commit, then emit: latches are set before any listener runs.

var _latch: FatalLatch = null
var _app_handler: Callable = Callable()
var _flow_hook: Callable = Callable()


## p_latch is the battle latch. p_app_handler is the Builder's fatal_handler
## (AppRoot.on_fatal); it may be an empty Callable.
func _init(p_latch: FatalLatch, p_app_handler: Callable = Callable()) -> void:
	_latch = p_latch
	_app_handler = p_app_handler


## Sets the Flow hook (flow.enter_fatal), called with no arguments. The Builder
## sets it right after Flow is built.
func set_flow_hook(hook: Callable) -> void:
	_flow_hook = hook


## The battle latch this relay sets.
func latch() -> FatalLatch:
	return _latch


## Reports a fatal cause. Steps in order: return if already fatal; set the
## battle latch and push_error; call the app handler; call the Flow hook.
func fatal(cause: String) -> void:
	if _latch.is_fatal():
		return
	_latch.fatal(cause)
	push_error(cause)
	if _app_handler.is_valid():
		_app_handler.call(cause)
	if _flow_hook.is_valid():
		_flow_hook.call()
