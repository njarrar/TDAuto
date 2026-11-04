class_name SimTime extends RefCounted
## Tick rate and the one seconds-to-ticks conversion (ADR-0004 Decision 6).

const TICKS_PER_SECOND := 60

## Ticks per second, at least 1. Read-only by contract.
var ticks_per_second: int = TICKS_PER_SECOND
## Seconds per tick, 1.0 / ticks_per_second. Read-only by contract.
var dt: float = 1.0 / float(TICKS_PER_SECOND)


func _init(p_ticks_per_second: int = TICKS_PER_SECOND) -> void:
	ticks_per_second = maxi(p_ticks_per_second, 1)
	dt = 1.0 / float(ticks_per_second)


## Converts seconds to whole ticks, halves away from zero. Non-finite gives 0.
func to_ticks(seconds: float) -> int:
	if not is_finite(seconds):
		return 0
	var x: float = seconds * float(ticks_per_second)
	var t: int = floori(absf(x) + 0.5)
	return -t if x < 0.0 else t
