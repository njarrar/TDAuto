class_name InputResolver
extends RefCounted
## Pure gesture resolver: one active pointer, disc targets, four states. No clock, no scene.
## ADR-0008. Gesture calls are queued and drained by the outermost call; registry calls are
## immediate. Every position is a Vector2 in field units at the API; decisions use float scalars.

enum Accepts { TAP, DRAG }
enum State { IDLE, PRESSED, DRAGGING, DEAD }

## Id meaning "no target".
const NONE: int = -1
## A drain that reaches this many calls is a defect and is aborted.
const MAX_CALLS_PER_DRAIN: int = 64
## Narrowest supported width in dp (equals FieldMapping.MIN_FIELD_WIDTH_DP).
const MIN_SUPPORTED_WIDTH_DP: int = 360

const _PRESS: int = 0
const _MOVE: int = 1
const _RELEASE: int = 2
const _CANCEL_POINTER: int = 3
const _CANCEL: int = 4

## G1: a gesture began; both frozen winners are carried.
signal pressed(best_tap: int, best_drag: int, p: Vector2)
## G2: a tap completed on the tap winner.
signal tapped(best_tap: int, p: Vector2)
## G3: a tap completed with no winner of either class.
signal ground_tapped(p: Vector2)
## G4: the first move at or past slop with a drag winner.
signal drag_started(best_drag: int, press_pos: Vector2, p: Vector2)
## G5: one per move call while dragging.
signal drag_moved(best_drag: int, press_pos: Vector2, p: Vector2)
## G6: the active pointer released while dragging.
signal drag_ended(best_drag: int, press_pos: Vector2, release_pos: Vector2)
## G7: a drag was cancelled by the host.
signal drag_cancelled(best_drag: int)
## G8: back to Idle; last in every exit, exactly once per gesture.
signal became_idle()


## One disc target. Holds values only, never an owner, node or Callable.
class Target extends RefCounted:
	var id: int = -1
	var cx: float = 0.0
	var cy: float = 0.0
	var radius: float = 0.0
	var accepts: int = 0
	var priority: int = 0
	var enabled: bool = true
	var sink: bool = false


var _drag_slop: float = 0.0
var _tap_slop: float = 0.0
var _drag_slop_sq: float = 0.0
var _tap_slop_sq: float = 0.0
var _dev_error: Callable = Callable()

var _targets: Array[Target] = []
var _next_id: int = 1

var _state: State = State.IDLE
var _pointer: int = -1
var _press_x: float = 0.0
var _press_y: float = 0.0
var _press_pos: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO
var _slop_sq: float = 0.0
var _max_travel_sq: float = 0.0
var _tap_id: int = NONE
var _tap_cx: float = 0.0
var _tap_cy: float = 0.0
var _tap_r: float = 0.0
var _tap_sink: bool = false
var _drag_id: int = NONE
var _serial: int = 0
var _record: GestureRecord = null

var _q_kind: PackedInt64Array = PackedInt64Array()
var _q_pointer: PackedInt64Array = PackedInt64Array()
var _q_pos: PackedVector2Array = PackedVector2Array()
var _draining: bool = false
var _aborting: bool = false


## Slops are squared once here. Use create() to get validation.
func _init(drag_slop: float, tap_slop: float, dev_error: Callable = Callable()) -> void:
	_drag_slop = drag_slop
	_tap_slop = tap_slop
	_drag_slop_sq = drag_slop * drag_slop
	_tap_slop_sq = tap_slop * tap_slop
	_dev_error = dev_error


## True when both slops are finite, in range, and tap_slop > drag_slop (Input Rule 9).
static func validate(drag_slop: float, tap_slop: float) -> bool:
	if not (is_finite(drag_slop) and is_finite(tap_slop)):
		return false
	if drag_slop < 8.0 or drag_slop > 30.0:
		return false
	if tap_slop < 16.0 or tap_slop > 34.0:
		return false
	return tap_slop > drag_slop


## Returns null when validate() fails (reports nothing), else a new resolver.
static func create(drag_slop: float, tap_slop: float, dev_error: Callable = Callable()) -> InputResolver:
	if not validate(drag_slop, tap_slop):
		return null
	return InputResolver.new(drag_slop, tap_slop, dev_error)


## True when a disc of this radius is at least 48 dp across at this width.
## Integers only: both floored first, compared without division (Input Formulas).
static func target_ok(radius: float, width_dp: float) -> bool:
	if not (is_finite(radius) and is_finite(width_dp)):
		return false
	return 2 * floori(radius) * floori(width_dp) >= 25920 # 48 * 540


## Gesture call (queued): a pointer went down.
func press(pointer: int, pos: Vector2) -> void:
	if not (is_finite(pos.x) and is_finite(pos.y)):
		_report("InputResolver.press: non-finite position")
		return
	_enqueue(_PRESS, pointer, pos)


## Gesture call (queued): a pointer moved.
func move(pointer: int, pos: Vector2) -> void:
	if not (is_finite(pos.x) and is_finite(pos.y)):
		_report("InputResolver.move: non-finite position")
		return
	_enqueue(_MOVE, pointer, pos)


## Gesture call (queued): a pointer went up.
func release(pointer: int, pos: Vector2) -> void:
	if not (is_finite(pos.x) and is_finite(pos.y)):
		_report("InputResolver.release: non-finite position")
		return
	_enqueue(_RELEASE, pointer, pos)


## Gesture call (queued): the OS cancelled one touch. Acts only for the active pointer.
func cancel_pointer(pointer: int) -> void:
	_enqueue(_CANCEL_POINTER, pointer, Vector2.ZERO)


## Gesture call (queued): the host ends any live gesture as a cancel.
func cancel() -> void:
	_enqueue(_CANCEL, 0, Vector2.ZERO)


## InputAdapter.flush() only, first. If a drain was left set by a script error, reports,
## clears the queue and flags, ends any live gesture as a cancel and returns true.
func recover_if_stuck() -> bool:
	if not _draining:
		return false
	_report("InputResolver.recover_if_stuck: drain flag was left set; recovered")
	_clear_queue()
	_aborting = true
	_end_as_cancel(GestureRecord.Outcome.CANCELLED)
	_aborting = false
	_clear_queue()
	_draining = false
	return true


## Registry: add a disc target. Returns its id, or NONE (and reports) when rejected.
## Effective at the next press; never queued.
func register(centre: Vector2, radius: float, accepts: Accepts, priority: int, sink: bool = false) -> int:
	if not (is_finite(centre.x) and is_finite(centre.y)):
		_report("InputResolver.register: non-finite centre")
		return NONE
	if not is_finite(radius) or radius <= 0.0:
		_report("InputResolver.register: radius must be finite and above 0")
		return NONE
	if accepts != Accepts.TAP and accepts != Accepts.DRAG:
		_report("InputResolver.register: accepts must be TAP or DRAG")
		return NONE
	if sink and accepts == Accepts.DRAG:
		_report("InputResolver.register: a sink must accept TAP")
		return NONE
	var t: Target = Target.new()
	t.id = _next_id
	_next_id += 1
	t.cx = centre.x
	t.cy = centre.y
	t.radius = radius
	t.accepts = accepts
	t.priority = priority
	t.enabled = true
	t.sink = sink
	_targets.append(t)
	if not target_ok(radius, float(MIN_SUPPORTED_WIDTH_DP)):
		_report("InputResolver.register: radius below 48 dp at the minimum width")
	return t.id


## Registry: remove a target. Unknown id is a reported no-op.
func unregister(id: int) -> void:
	for i: int in range(_targets.size()):
		if _targets[i].id == id:
			_targets.remove_at(i)
			return
	_report("InputResolver.unregister: unknown id")


## Registry: move a target. Unknown id or non-finite centre is a reported no-op.
func set_centre(id: int, centre: Vector2) -> void:
	var t: Target = _find(id)
	if t == null:
		_report("InputResolver.set_centre: unknown id")
		return
	if not (is_finite(centre.x) and is_finite(centre.y)):
		_report("InputResolver.set_centre: non-finite centre")
		return
	t.cx = centre.x
	t.cy = centre.y


## Registry: enable or disable a target for hit tests. Unknown id is a reported no-op.
func set_enabled(id: int, enabled: bool) -> void:
	var t: Target = _find(id)
	if t == null:
		_report("InputResolver.set_enabled: unknown id")
		return
	t.enabled = enabled


## Current state.
func state() -> State:
	return _state


## Centre of a target; Vector2(NAN, NAN) if unknown. For logs and tests only.
func centre_of(id: int) -> Vector2:
	var t: Target = _find(id)
	if t == null:
		return Vector2(NAN, NAN)
	return Vector2(t.cx, t.cy)


## Null before the first gesture, else a new copy of the latest record.
func last_gesture() -> GestureRecord:
	if _record == null:
		return null
	return _record.copy()


func _report(msg: String) -> void:
	if _dev_error.is_valid():
		_dev_error.call(msg)
	else:
		push_error(msg)


func _find(id: int) -> Target:
	for t: Target in _targets:
		if t.id == id:
			return t
	return null


func _clear_queue() -> void:
	_q_kind.clear()
	_q_pointer.clear()
	_q_pos.clear()


func _enqueue(kind: int, pointer: int, pos: Vector2) -> void:
	var _hold: InputResolver = self # keeps this object alive until return
	if _aborting:
		return # calls made while an abort ends the gesture are discarded
	_q_kind.append(kind)
	_q_pointer.append(pointer)
	_q_pos.append(pos)
	if _draining:
		return # a handler's call: runs after the current batch
	_draining = true
	var i: int = 0
	while i < _q_kind.size(): # size re-read: handlers append mid-loop
		if i == MAX_CALLS_PER_DRAIN:
			_abort_drain()
			break
		_run(_q_kind[i], _q_pointer[i], _q_pos[i])
		i += 1
	_clear_queue()
	_draining = false


func _abort_drain() -> void:
	_aborting = true
	_report("InputResolver: %d calls in one drain, gesture aborted" % MAX_CALLS_PER_DRAIN)
	_end_as_cancel(GestureRecord.Outcome.CANCELLED)
	_aborting = false


func _run(kind: int, pointer: int, pos: Vector2) -> void:
	if kind == _PRESS:
		_do_press(pointer, pos)
	elif kind == _MOVE:
		_do_move(pointer, pos)
	elif kind == _RELEASE:
		_do_release(pointer, pos)
	elif kind == _CANCEL_POINTER:
		if _state != State.IDLE and pointer == _pointer:
			_end_as_cancel(GestureRecord.Outcome.CANCELLED)
	elif kind == _CANCEL:
		_end_as_cancel(GestureRecord.Outcome.CANCELLED)


func _has_real_tap_winner() -> bool:
	return _tap_id != NONE and not _tap_sink


func _do_press(pointer: int, p: Vector2) -> void:
	if _state == State.IDLE:
		_begin(pointer, p)
		return
	if pointer == _pointer:
		_end_as_cancel(GestureRecord.Outcome.REPRESSED)
		_begin(pointer, p)
		return
	if (_state == State.PRESSED or _state == State.DEAD) and not _has_real_tap_winner():
		_end_as_cancel(GestureRecord.Outcome.REPLACED)
		_begin(pointer, p)
		return
	# otherwise dropped


## Result codes: 0 incumbent by priority, 1 challenger by priority, 2 incumbent by distance,
## 3 challenger by distance, 4 incumbent by id.
func _compare(best: Target, best_d: float, t: Target, d: float) -> int:
	if t.priority > best.priority:
		return 1
	if t.priority < best.priority:
		return 0
	if d < best_d:
		return 3
	if d > best_d:
		return 2
	return 4


func _rule_of(code: int) -> GestureRecord.WinRule:
	if code <= 1:
		return GestureRecord.WinRule.PRIORITY
	if code <= 3:
		return GestureRecord.WinRule.DISTANCE
	return GestureRecord.WinRule.ID


func _begin(pointer: int, p: Vector2) -> void:
	var px: float = p.x
	var py: float = p.y
	var tap_best: Target = null
	var tap_d: float = 0.0
	var tap_n: int = 0
	var tap_rule: GestureRecord.WinRule = GestureRecord.WinRule.NO_CANDIDATE
	var drag_best: Target = null
	var drag_d: float = 0.0
	var drag_n: int = 0
	var drag_rule: GestureRecord.WinRule = GestureRecord.WinRule.NO_CANDIDATE
	for t: Target in _targets:
		if not t.enabled:
			continue
		var dx: float = px - t.cx
		var dy: float = py - t.cy
		var d: float = dx * dx + dy * dy
		if d > t.radius * t.radius:
			continue
		if t.accepts == Accepts.TAP:
			tap_n += 1
			if tap_best == null:
				tap_best = t
				tap_d = d
				tap_rule = GestureRecord.WinRule.ONLY
			else:
				var code: int = _compare(tap_best, tap_d, t, d)
				tap_rule = _rule_of(code)
				if code == 1 or code == 3:
					tap_best = t
					tap_d = d
		else:
			drag_n += 1
			if drag_best == null:
				drag_best = t
				drag_d = d
				drag_rule = GestureRecord.WinRule.ONLY
			else:
				var code2: int = _compare(drag_best, drag_d, t, d)
				drag_rule = _rule_of(code2)
				if code2 == 1 or code2 == 3:
					drag_best = t
					drag_d = d

	# Commit the gesture before any emit.
	_state = State.PRESSED
	_pointer = pointer
	_press_x = px
	_press_y = py
	_press_pos = p
	_last_pos = p
	_max_travel_sq = 0.0
	_tap_id = NONE
	_tap_cx = 0.0
	_tap_cy = 0.0
	_tap_r = 0.0
	_tap_sink = false
	_drag_id = NONE
	var tap_centre: Vector2 = Vector2.ZERO
	var drag_centre: Vector2 = Vector2.ZERO
	if tap_best != null:
		_tap_id = tap_best.id
		_tap_cx = tap_best.cx
		_tap_cy = tap_best.cy
		_tap_r = tap_best.radius
		_tap_sink = tap_best.sink
		tap_centre = Vector2(tap_best.cx, tap_best.cy)
	if drag_best != null:
		_drag_id = drag_best.id
		drag_centre = Vector2(drag_best.cx, drag_best.cy)
	var use_tap_slop: bool = _has_real_tap_winner() or (_tap_id == NONE and _drag_id == NONE)
	_slop_sq = _tap_slop_sq if use_tap_slop else _drag_slop_sq
	_serial += 1
	var rec: GestureRecord = GestureRecord.new()
	rec.serial = _serial
	rec.pointer = pointer
	rec.press_pos = p
	rec.end_pos = p
	rec.best_tap = _tap_id
	rec.best_drag = _drag_id
	rec.tap_sink = _tap_sink
	rec.tap_centre = tap_centre
	rec.drag_centre = drag_centre
	rec.tap_candidates = tap_n
	rec.drag_candidates = drag_n
	rec.tap_rule = tap_rule
	rec.drag_rule = drag_rule
	rec.slop = _tap_slop if use_tap_slop else _drag_slop
	rec.outcome = GestureRecord.Outcome.OPEN
	_record = rec
	var emit_tap: int = _tap_id
	var emit_drag: int = _drag_id
	pressed.emit(emit_tap, emit_drag, p)


func _note_travel(p: Vector2) -> void:
	var dx: float = p.x - _press_x
	var dy: float = p.y - _press_y
	var d: float = dx * dx + dy * dy
	if d > _max_travel_sq:
		_max_travel_sq = d
	_last_pos = p


func _do_move(pointer: int, p: Vector2) -> void:
	if _state == State.IDLE or pointer != _pointer:
		return
	_note_travel(p)
	_record.moves += 1
	var dx: float = p.x - _press_x
	var dy: float = p.y - _press_y
	var crossed: bool = dx * dx + dy * dy >= _slop_sq
	var drag: int = _drag_id
	var press_pos: Vector2 = _press_pos
	if _state == State.PRESSED:
		if not crossed:
			return
		if drag != NONE:
			_state = State.DRAGGING
			drag_started.emit(drag, press_pos, p)
		else:
			_state = State.DEAD
	elif _state == State.DRAGGING:
		drag_moved.emit(drag, press_pos, p)


func _do_release(pointer: int, p: Vector2) -> void:
	if _state == State.IDLE or pointer != _pointer:
		return
	_note_travel(p)
	var was: State = _state
	var tap: int = _tap_id
	var drag: int = _drag_id
	var press_pos: Vector2 = _press_pos
	var outcome: GestureRecord.Outcome = GestureRecord.Outcome.DEAD
	var ex: float = p.x - _press_x
	var ey: float = p.y - _press_y
	if was == State.DRAGGING:
		outcome = GestureRecord.Outcome.DRAGGED
	elif was == State.PRESSED:
		if ex * ex + ey * ey >= _slop_sq:
			if drag != NONE:
				outcome = GestureRecord.Outcome.DRAGGED_LOST_MOVES
			else:
				outcome = GestureRecord.Outcome.DEAD
		elif tap != NONE:
			var tx: float = p.x - _tap_cx
			var ty: float = p.y - _tap_cy
			if tx * tx + ty * ty <= _tap_r * _tap_r:
				outcome = GestureRecord.Outcome.TAPPED
			else:
				outcome = GestureRecord.Outcome.ROLLED_OFF
		elif drag != NONE:
			outcome = GestureRecord.Outcome.DRAG_WINNER_ONLY
		else:
			outcome = GestureRecord.Outcome.GROUND_TAPPED
	_finish_record(outcome, p)
	_to_idle()
	if outcome == GestureRecord.Outcome.DRAGGED_LOST_MOVES:
		drag_started.emit(drag, press_pos, p)
		drag_ended.emit(drag, press_pos, p)
	elif outcome == GestureRecord.Outcome.DRAGGED:
		drag_ended.emit(drag, press_pos, p)
	elif outcome == GestureRecord.Outcome.TAPPED:
		tapped.emit(tap, p)
	elif outcome == GestureRecord.Outcome.GROUND_TAPPED:
		ground_tapped.emit(p)
	became_idle.emit()


func _end_as_cancel(outcome: GestureRecord.Outcome) -> void:
	if _state == State.IDLE:
		return
	var was_dragging: bool = _state == State.DRAGGING
	var drag: int = _drag_id
	_finish_record(outcome, _last_pos)
	_to_idle()
	if was_dragging:
		drag_cancelled.emit(drag)
	became_idle.emit()


func _finish_record(outcome: GestureRecord.Outcome, end_pos: Vector2) -> void:
	if _record == null:
		return
	_record.outcome = outcome
	_record.end_pos = end_pos
	_record.max_travel = sqrt(_max_travel_sq)


func _to_idle() -> void:
	_state = State.IDLE
	_pointer = -1
	_tap_id = NONE
	_tap_cx = 0.0
	_tap_cy = 0.0
	_tap_r = 0.0
	_tap_sink = false
	_drag_id = NONE
