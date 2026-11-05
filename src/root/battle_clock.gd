class_name BattleClock extends RefCounted
## Pure tick accumulator (ADR-0004 Decision 2). Owned by BattleWrapper; it
## only aligns ticks with frames and never affects a sim result.

## Provisional until ADR-0004 V6 sets it (2 to 4).
const MAX_TICKS_PER_FRAME := 3
## A delta above this runs no ticks and resets the accumulator.
const STALL_SECONDS := 0.5

var _ticks_per_second: int = 60
var _dt: float = 1.0 / 60.0
var _acc: float = 0.0


## The accumulator starts at half a tick.
func _init(ticks_per_second: int) -> void:
	_ticks_per_second = maxi(ticks_per_second, 1)
	_dt = 1.0 / float(_ticks_per_second)
	_acc = 0.5 * _dt


## Adds one frame's delta (seconds) and returns the ticks to run this frame.
func advance(delta: float) -> int:
	if not is_finite(delta) or delta <= 0.0:
		return 0
	if delta > STALL_SECONDS:
		_acc = 0.5 * _dt
		return 0
	_acc += delta
	var run: int = mini(floori(_acc * float(_ticks_per_second)), MAX_TICKS_PER_FRAME)
	_acc = maxf(_acc - float(run) * _dt, 0.0)
	if run == MAX_TICKS_PER_FRAME:
		_acc = minf(_acc, 1.5 * _dt)
	return run


## Puts the accumulator back to half a tick.
func drop_backlog() -> void:
	_acc = 0.5 * _dt


## The accumulator in seconds (read-only; for tests and dev display).
func accumulated() -> float:
	return _acc
