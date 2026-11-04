# PROTOTYPE - NOT FOR PRODUCTION. ADR-0004 SP14.
extends RefCounted
## Kit copy of ADR-0004's BattleClock (Decision 2). Not the real class and
## never loaded by src/. Returns how many ticks a frame of delta would run.

const MAX_TICKS_PER_FRAME := 3
const STALL_SECONDS := 0.5

var _ticks_per_second: int = 60
var _dt: float = 1.0 / 60.0
var _acc: float = 0.0


func _init(ticks_per_second: int = 60) -> void:
	_ticks_per_second = ticks_per_second
	_dt = 1.0 / float(ticks_per_second)
	_acc = 0.5 * _dt


## Ticks to run for this frame's delta.
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


## Accumulator back to half a tick.
func drop_backlog() -> void:
	_acc = 0.5 * _dt
