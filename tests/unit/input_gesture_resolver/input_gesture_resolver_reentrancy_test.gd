extends GdUnitTestSuite
## Input criterion 27 and ADR-0008 Validation Criteria 2 and 4: queue, cap, recovery, copies, dev_error.

const Rig := preload("res://tests/unit/input_gesture_resolver/helpers/rig.gd")
const Listener := preload("res://tests/unit/input_gesture_resolver/helpers/recording_listener.gd")


class Canceller extends RefCounted:
	var r: InputResolver = null
	func on_pressed(_best_tap: int, _best_drag: int, _p: Vector2) -> void:
		r.cancel()


class PressOnTap extends RefCounted:
	var r: InputResolver = null
	var at: Vector2 = Vector2.ZERO
	func on_tapped(_best_tap: int, _p: Vector2) -> void:
		r.press(0, at)


class RegisterOnTap extends RefCounted:
	var r: InputResolver = null
	var new_id: int = -1
	func on_tapped(_best_tap: int, _p: Vector2) -> void:
		new_id = r.register(Vector2(100.0, 700.0), 36.0, InputResolver.Accepts.TAP, 200)


class RegisterOnIdle extends RefCounted:
	var r: InputResolver = null
	var names: Dictionary = {}
	var done: bool = false
	var new_id: int = -1
	func on_became_idle() -> void:
		if done:
			return
		done = true
		new_id = r.register(Vector2(500.0, 100.0), 36.0, InputResolver.Accepts.TAP, 200)
		names[new_id] = "N"


class PressOnPressed extends RefCounted:
	var r: InputResolver = null
	func on_pressed(_best_tap: int, _best_drag: int, p: Vector2) -> void:
		r.press(0, p)


func _check(g: Rig, expected: Array[String]) -> void:
	assert_str(g.joined()).is_equal(" | ".join(PackedStringArray(expected)))


func test_c27_cancel_in_pressed_handler_runs_after_batch() -> void:
	var g: Rig = Rig.new(15.0, 28.0, false)
	g.add_tower()
	var c: Canceller = Canceller.new()
	c.r = g.r
	g.r.pressed.connect(c.on_pressed)
	var l2: Listener = Listener.new()
	l2.names = g.l.names
	g.connect_listener(g.l)
	g.connect_listener(l2)
	g.r.press(0, Rig.T_POS)
	g.r.release(0, Rig.T_POS)
	c.r = null
	var want: Array[String] = ["pressed(T,NONE)", "became_idle"]
	_check(g, want)
	assert_str(l2.joined()).is_equal(" | ".join(PackedStringArray(want)))


func test_c27_press_in_tapped_handler_starts_after_became_idle() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.add_slot()
	var p: PressOnTap = PressOnTap.new()
	p.r = g.r
	p.at = Rig.S_POS
	g.r.tapped.connect(p.on_tapped)
	g.tap_at(Rig.T_POS)
	p.r = null
	_check(g, ["pressed(T,NONE)", "tapped(T)", "became_idle", "pressed(S,NONE)"])


func test_c27_register_in_tapped_handler_returns_at_once() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	var reg: RegisterOnTap = RegisterOnTap.new()
	reg.r = g.r
	g.r.tapped.connect(reg.on_tapped)
	g.tap_at(Rig.T_POS)
	assert_bool(reg.new_id > 0).is_true()
	_check(g, ["pressed(T,NONE)", "tapped(T)", "became_idle"])
	g.l.names[reg.new_id] = "N"
	g.r.press(0, Vector2(100.0, 700.0))
	reg.r = null
	assert_str(g.joined()).is_equal(" | ".join(PackedStringArray([
		"pressed(T,NONE)", "tapped(T)", "became_idle", "pressed(N,NONE)"])))


func test_register_in_became_idle_of_cancel_then_press_reaches_new_press() -> void:
	var g: Rig = Rig.new()
	var reg: RegisterOnIdle = RegisterOnIdle.new()
	reg.r = g.r
	reg.names = g.l.names
	g.r.became_idle.connect(reg.on_became_idle)
	g.r.press(0, Rig.GROUND)
	g.r.press(0, Rig.GROUND)
	reg.r = null
	_check(g, ["pressed(NONE,NONE)", "became_idle", "pressed(N,NONE)"])


func test_runaway_listener_stops_at_cap_with_one_report() -> void:
	var g: Rig = Rig.new()
	var pp: PressOnPressed = PressOnPressed.new()
	pp.r = g.r
	g.r.pressed.connect(pp.on_pressed)
	g.r.press(0, Rig.GROUND)
	pp.r = null
	assert_int(g.r.reports.size()).is_equal(1)
	assert_int(g.r.state()).is_equal(InputResolver.State.IDLE)
	assert_int(g.l.count_of("pressed(")).is_equal(InputResolver.MAX_CALLS_PER_DRAIN)
	assert_str(g.l.log[g.l.log.size() - 1]).is_equal("became_idle")
	assert_int(g.r.queue_size()).is_equal(0)
	assert_bool(g.r.is_draining()).is_false()


func test_forced_stuck_flag_recovers_once() -> void:
	var g: Rig = Rig.new()
	assert_bool(g.r.recover_if_stuck()).is_false()
	g.r.press(0, Rig.GROUND)
	g.r.force_stuck()
	assert_bool(g.r.recover_if_stuck()).is_true()
	assert_int(g.r.state()).is_equal(InputResolver.State.IDLE)
	assert_bool(g.r.is_draining()).is_false()
	assert_int(g.r.reports.size()).is_equal(1)
	_check(g, ["pressed(NONE,NONE)", "became_idle"])
	assert_bool(g.r.recover_if_stuck()).is_false()
	g.r.press(0, Rig.GROUND)
	assert_int(g.l.count_of("pressed(")).is_equal(2)


func test_cancel_outside_a_drain_emits_at_once() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.move(0, Vector2(120.0, 100.0))
	g.r.cancel()
	assert_str(g.l.log[g.l.log.size() - 2]).is_equal("drag_cancelled(H)")
	assert_str(g.l.log[g.l.log.size() - 1]).is_equal("became_idle")


func test_last_gesture_null_when_fresh_then_equal_new_copy() -> void:
	var g: Rig = Rig.new()
	assert_object(g.r.last_gesture()).is_null()
	g.add_tower()
	g.tap_at(Rig.T_POS)
	var a: GestureRecord = g.r.last_gesture()
	var b: GestureRecord = g.r.last_gesture()
	assert_object(a).is_not_null()
	assert_bool(a == b).is_false()
	assert_int(a.serial).is_equal(b.serial)
	assert_int(a.outcome).is_equal(b.outcome)
	assert_int(a.best_tap).is_equal(b.best_tap)
	assert_int(a.serial).is_equal(1)
	a.serial = 99
	assert_int(g.r.last_gesture().serial).is_equal(1)


func test_dev_error_callable_receives_reports() -> void:
	var rec: Listener = Listener.new()
	var r: InputResolver = InputResolver.create(15.0, 28.0, rec.on_error)
	r.press(0, Vector2(NAN, 0.0))
	r.unregister(5)
	assert_int(rec.errors.size()).is_equal(2)


func test_dropped_battle_resolver_is_freed() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.add_hero()
	g.tap_at(Rig.T_POS)
	var wr: WeakRef = weakref(g.r)
	g.r = null
	assert_object(wr.get_ref()).is_null()
