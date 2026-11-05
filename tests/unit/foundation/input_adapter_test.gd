extends GdUnitTestSuite
## ADR-0003 Validation: the adapter fed synthetic events. A queued release then
## cancel_all() reaches the resolver as nothing; a canceled touch becomes
## cancel_pointer; flush() keeps arrival order; rejected presses are not forwarded.

const MARGIN: float = 10.0


## Records resolver calls in order. Subclass of the real resolver.
class RecordingResolver extends InputResolver:
	var calls: Array[String] = []
	var recovered: int = 0

	func _init() -> void:
		super(15.0, 28.0)

	func press(pointer: int, _pos: Vector2) -> void:
		calls.append("press%d" % pointer)

	func move(pointer: int, _pos: Vector2) -> void:
		calls.append("move%d" % pointer)

	func release(pointer: int, _pos: Vector2) -> void:
		calls.append("release%d" % pointer)

	func cancel_pointer(pointer: int) -> void:
		calls.append("cancel_pointer%d" % pointer)

	func cancel() -> void:
		calls.append("cancel")

	func recover_if_stuck() -> bool:
		recovered += 1
		calls.append("recover")
		return false


func _make(resolver: RecordingResolver) -> InputAdapter:
	var adapter: InputAdapter = InputAdapter.new()
	adapter.attach(resolver, MARGIN)
	return adapter


func _touch(index: int, pressed: bool, pos: Vector2, canceled: bool = false) -> InputEventScreenTouch:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	e.canceled = canceled
	return e


func _drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var e: InputEventScreenDrag = InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	return e


func test_flush_calls_recover_first_then_keeps_arrival_order() -> void:
	var resolver: RecordingResolver = RecordingResolver.new()
	var adapter: InputAdapter = _make(resolver)
	adapter._unhandled_input(_touch(0, true, Vector2(270.0, 480.0)))
	adapter._input(_drag(0, Vector2(280.0, 490.0)))
	adapter._input(_touch(0, false, Vector2(280.0, 490.0)))

	adapter.flush()

	assert_array(resolver.calls).is_equal(["recover", "press0", "move0", "release0"])
	assert_int(adapter.queued_count()).is_equal(0)
	assert_bool(adapter.is_forwarded(0)).is_false()
	adapter.free()


func test_release_then_cancel_all_reaches_resolver_as_cancel_only() -> void:
	var resolver: RecordingResolver = RecordingResolver.new()
	var adapter: InputAdapter = _make(resolver)
	adapter._unhandled_input(_touch(0, true, Vector2(270.0, 480.0)))
	adapter._input(_touch(0, false, Vector2(270.0, 480.0)))

	adapter.cancel_all()
	adapter.flush()

	assert_array(resolver.calls).is_equal(["cancel", "recover"])
	assert_bool(adapter.is_forwarded(0)).is_false()
	adapter.free()


func test_canceled_touch_becomes_cancel_pointer_never_release() -> void:
	var resolver: RecordingResolver = RecordingResolver.new()
	var adapter: InputAdapter = _make(resolver)
	adapter._unhandled_input(_touch(0, true, Vector2(270.0, 480.0)))
	adapter._input(_touch(0, false, Vector2(270.0, 480.0), true))

	adapter.flush()

	assert_array(resolver.calls).is_equal(["recover", "press0", "cancel_pointer0"])
	adapter.free()


func test_rejected_press_is_not_forwarded_and_its_moves_are_ignored() -> void:
	var resolver: RecordingResolver = RecordingResolver.new()
	var adapter: InputAdapter = _make(resolver)
	adapter._unhandled_input(_touch(0, true, Vector2(5.0, 480.0)))
	adapter._input(_drag(0, Vector2(100.0, 480.0)))
	adapter._input(_touch(0, false, Vector2(100.0, 480.0)))

	assert_int(adapter.queued_count()).is_equal(0)
	assert_bool(adapter.is_forwarded(0)).is_false()
	adapter.free()


func test_off_field_press_is_rejected() -> void:
	var resolver: RecordingResolver = RecordingResolver.new()
	var adapter: InputAdapter = _make(resolver)

	adapter._unhandled_input(_touch(0, true, Vector2(270.0, 1000.0)))

	assert_int(adapter.queued_count()).is_equal(0)
	adapter.free()


func test_moves_of_other_indices_are_ignored() -> void:
	var resolver: RecordingResolver = RecordingResolver.new()
	var adapter: InputAdapter = _make(resolver)
	adapter._unhandled_input(_touch(0, true, Vector2(270.0, 480.0)))
	adapter._input(_drag(1, Vector2(280.0, 490.0)))

	assert_int(adapter.queued_count()).is_equal(1)
	adapter.free()


func test_emulated_mouse_touch_uses_the_mouse_pointer() -> void:
	var resolver: RecordingResolver = RecordingResolver.new()
	var adapter: InputAdapter = _make(resolver)
	var e: InputEventScreenTouch = _touch(0, true, Vector2(270.0, 480.0))
	e.device = InputEvent.DEVICE_ID_EMULATION

	adapter._unhandled_input(e)

	assert_bool(adapter.is_forwarded(InputAdapter.MOUSE_POINTER)).is_true()
	assert_bool(adapter.is_forwarded(0)).is_false()
	adapter.free()


func test_mouse_events_are_ignored() -> void:
	var resolver: RecordingResolver = RecordingResolver.new()
	var adapter: InputAdapter = _make(resolver)
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.pressed = true
	e.position = Vector2(270.0, 480.0)

	adapter._unhandled_input(e)

	assert_int(adapter.queued_count()).is_equal(0)
	adapter.free()


func test_each_loss_notification_cancels_then_emits_lifecycle_paused() -> void:
	var losses: Array[int] = [
		Node.NOTIFICATION_APPLICATION_FOCUS_OUT,
		Node.NOTIFICATION_APPLICATION_PAUSED,
		Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,
		Node.NOTIFICATION_WM_GO_BACK_REQUEST,
	]
	for what: int in losses:
		var resolver: RecordingResolver = RecordingResolver.new()
		var adapter: InputAdapter = _make(resolver)
		var seen: Array[int] = [0]
		adapter.lifecycle_paused.connect(func() -> void: seen[0] += 1)
		adapter._unhandled_input(_touch(0, true, Vector2(270.0, 480.0)))

		adapter._notification(what)

		assert_array(resolver.calls).is_equal(["cancel"])
		assert_int(seen[0]).is_equal(1)
		assert_int(adapter.queued_count()).is_equal(0)
		adapter.free()


func test_real_size_change_cancels_all_and_emits_display_changed() -> void:
	var resolver: RecordingResolver = RecordingResolver.new()
	var adapter: InputAdapter = _make(resolver)
	adapter.apply_display_metrics(Vector2(540.0, 960.0), Vector2.ZERO, Rect2(), false)
	var seen: Array[int] = [0]
	adapter.display_changed.connect(func() -> void: seen[0] += 1)
	adapter._unhandled_input(_touch(0, true, Vector2(270.0, 480.0)))
	resolver.calls.clear()

	adapter.apply_display_metrics(Vector2(1080.0, 1920.0), Vector2.ZERO, Rect2(), false)

	assert_array(resolver.calls).is_equal(["cancel"])
	assert_int(seen[0]).is_equal(1)
	assert_int(adapter.queued_count()).is_equal(0)
	adapter.free()


func test_same_size_does_not_cancel() -> void:
	var resolver: RecordingResolver = RecordingResolver.new()
	var adapter: InputAdapter = _make(resolver)
	adapter.apply_display_metrics(Vector2(540.0, 960.0), Vector2.ZERO, Rect2(), false)
	resolver.calls.clear()

	adapter.apply_display_metrics(Vector2(540.0, 960.0), Vector2.ZERO, Rect2(), false)

	assert_array(resolver.calls).is_empty()
	adapter.free()


func test_detach_clears_queue_and_forwarded_set() -> void:
	var resolver: RecordingResolver = RecordingResolver.new()
	var adapter: InputAdapter = _make(resolver)
	adapter._unhandled_input(_touch(0, true, Vector2(270.0, 480.0)))

	adapter.detach()
	adapter.flush()

	assert_int(adapter.queued_count()).is_equal(0)
	assert_bool(adapter.is_forwarded(0)).is_false()
	assert_array(resolver.calls).is_empty()
	adapter.free()
