class_name InputAdapter extends Node
## The one code path that reads pointer input (ADR-0003). Presses come from
## _unhandled_input, forwarded moves and releases from _input. Everything is
## queued and handed to the resolver by flush() at frame step 0. Touch events
## only (the mouse reaches it as emulated touch). The wrapper sets
## process_mode to PROCESS_MODE_ALWAYS.

## Pointer index used for touches emulated from the mouse (SP5).
const MOUSE_POINTER := 1000

## A loss trigger fired (focus out, pause, window focus out, go back). Emitted
## after cancel_all(). Listeners are idempotent.
signal lifecycle_paused()
## The window size or the insets changed.
signal display_changed()

enum CallKind { PRESS, MOVE, RELEASE, CANCEL_POINTER }

var _resolver: InputResolver = null
var _edge_reject_margin: float = 0.0
var _insets: FieldInsets = FieldInsets.new()
var _window_size: Vector2 = Vector2.ZERO
var _size_known: bool = false
var _field_width_dp: float = -1.0
var _presses_blocked: bool = false
var _forwarded: Dictionary[int, bool] = {}
var _queue_kind: PackedInt32Array = PackedInt32Array()
var _queue_pointer: PackedInt32Array = PackedInt32Array()
var _queue_pos: PackedVector2Array = PackedVector2Array()
var _epoch: int = 0
var _viewport: Viewport = null


## Starts reading for one battle. `edge_reject_margin` is in field units.
func attach(resolver: InputResolver, edge_reject_margin: float) -> void:
	detach()
	_resolver = resolver
	_edge_reject_margin = maxf(edge_reject_margin, 0.0)
	if is_inside_tree():
		_viewport = get_viewport()
		if _viewport != null:
			_viewport.size_changed.connect(_on_viewport_size_changed)
	_read_display()
	_check_width_dp()


## Disconnects, empties the queue and the forwarded set, drops the resolver.
func detach() -> void:
	if _viewport != null:
		if _viewport.size_changed.is_connected(_on_viewport_size_changed):
			_viewport.size_changed.disconnect(_on_viewport_size_changed)
		_viewport = null
	_clear_queue()
	_forwarded.clear()
	_resolver = null
	_size_known = false
	_presses_blocked = false


## Frame step 0: recover a stuck resolver, then deliver the queued calls in
## arrival order. Stops at once if cancel_all() runs during delivery.
func flush() -> void:
	if _resolver == null:
		return
	_resolver.recover_if_stuck()
	var epoch: int = _epoch
	var count: int = _queue_kind.size()
	var i: int = 0
	while i < count:
		var kind: int = _queue_kind[i]
		var pointer: int = _queue_pointer[i]
		var pos: Vector2 = _queue_pos[i]
		match kind:
			CallKind.PRESS:
				_resolver.press(pointer, pos)
			CallKind.MOVE:
				_resolver.move(pointer, pos)
			CallKind.RELEASE:
				_forwarded.erase(pointer)
				_resolver.release(pointer, pos)
			CallKind.CANCEL_POINTER:
				_forwarded.erase(pointer)
				_resolver.cancel_pointer(pointer)
		if epoch != _epoch or _resolver == null:
			return
		i += 1
	_clear_queue()


## Empties the queue, clears the forwarded set and cancels the resolver.
func cancel_all() -> void:
	_epoch += 1
	_clear_queue()
	_forwarded.clear()
	if _resolver != null:
		_resolver.cancel()


## SP3 Branches B and C only: while blocked, presses are not forwarded.
func set_presses_blocked(blocked: bool) -> void:
	_presses_blocked = blocked


## Current insets in field units. All 0 on desktop.
func field_insets() -> FieldInsets:
	return _insets


## Field width in dp, or -1.0 on desktop or when the density is unknown.
func field_width_dp() -> float:
	return _field_width_dp


## Number of queued calls (tests and logs).
func queued_count() -> int:
	return _queue_kind.size()


## True while the pointer index belongs to a forwarded press.
func is_forwarded(pointer: int) -> bool:
	return _forwarded.has(pointer)


## Applies display metrics. Cancels all input if the window size changed since
## the last call, then recomputes the insets and emits display_changed if the
## size or the insets changed. `use_safe_area` is true on phones only.
func apply_display_metrics(window_size: Vector2, window_pos: Vector2, safe: Rect2, use_safe_area: bool) -> void:
	var was_known: bool = _size_known
	var size_changed: bool = (not was_known) or window_size != _window_size
	if size_changed and was_known:
		cancel_all()
	_size_known = true
	_window_size = window_size
	var new_insets: FieldInsets = FieldInsets.new()
	if use_safe_area:
		new_insets = FieldMapping.insets_from_safe_area(safe, window_pos, window_size)
	var insets_changed: bool = not new_insets.is_equal_to(_insets)
	_insets = new_insets
	if was_known and (size_changed or insets_changed):
		display_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _resolver == null:
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null or not touch.pressed or touch.canceled:
		return
	if _presses_blocked:
		return
	var pointer: int = _pointer_of(touch)
	var pos: Vector2 = _to_field(touch.position)
	if not FieldMapping.press_allowed(pos, _insets, _edge_reject_margin):
		return
	_forwarded[pointer] = true
	_enqueue(CallKind.PRESS, pointer, pos)
	_mark_handled()


func _input(event: InputEvent) -> void:
	if _resolver == null:
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null:
		var drag_pointer: int = _pointer_of(drag)
		if not _forwarded.has(drag_pointer):
			return
		_enqueue(CallKind.MOVE, drag_pointer, _to_field(drag.position))
		_mark_handled()
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed and not touch.canceled:
		return
	var pointer: int = _pointer_of(touch)
	if not _forwarded.has(pointer):
		return
	if touch.canceled:
		_enqueue(CallKind.CANCEL_POINTER, pointer, _to_field(touch.position))
	else:
		_enqueue(CallKind.RELEASE, pointer, _to_field(touch.position))
	_mark_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_loss()


## The one position conversion point. The identity while SP6 holds.
func _to_field(pos: Vector2) -> Vector2:
	return pos


func _pointer_of(event: InputEvent) -> int:
	var index: int = 0
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		index = touch.index
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null:
		index = drag.index
	if event.device == InputEvent.DEVICE_ID_EMULATION or event.device == InputEvent.DEVICE_ID_MOUSE:
		return MOUSE_POINTER
	return index


func _enqueue(kind: int, pointer: int, pos: Vector2) -> void:
	_queue_kind.append(kind)
	_queue_pointer.append(pointer)
	_queue_pos.append(pos)


func _clear_queue() -> void:
	_queue_kind.clear()
	_queue_pointer.clear()
	_queue_pos.clear()


func _mark_handled() -> void:
	if not is_inside_tree():
		return
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _on_loss() -> void:
	if _resolver == null:
		return
	cancel_all()
	lifecycle_paused.emit()


func _read_display() -> void:
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var mobile: bool = OS.has_feature("mobile")
	var safe: Rect2 = Rect2()
	var window_pos: Vector2 = Vector2.ZERO
	if mobile:
		safe = Rect2(DisplayServer.get_display_safe_area())
		window_pos = Vector2(DisplayServer.window_get_position())
	apply_display_metrics(window_size, window_pos, safe, mobile)


func _check_width_dp() -> void:
	_field_width_dp = -1.0
	if not OS.has_feature("mobile"):
		return
	var px_per_dp: float = 0.0
	var os_name: String = OS.get_name()
	if os_name == "Android":
		px_per_dp = float(DisplayServer.screen_get_dpi()) / 160.0
	elif os_name == "iOS":
		px_per_dp = DisplayServer.screen_get_scale()
	_field_width_dp = FieldMapping.field_width_dp(_window_size, px_per_dp)
	if _field_width_dp < 0.0:
		return
	var width: int = floori(_field_width_dp)
	if not FieldMapping.width_supported(width):
		push_error("input_adapter: field width %d dp is below the %d dp floor" % [width, FieldMapping.MIN_FIELD_WIDTH_DP])


func _on_viewport_size_changed() -> void:
	if _resolver == null:
		return
	_read_display()
