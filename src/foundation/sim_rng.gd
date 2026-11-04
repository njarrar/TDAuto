class_name SimRng extends RefCounted
## The sim's only random generator (ADR-0004 Decision 7): 32-bit xorshift in
## integers, masked after each left shift. No float, no multiplication.

const _MASK: int = 0xFFFFFFFF
const _ZERO_STATE: int = 0x6D2B79F5

var _state: int = 0
var _draws: int = 0


## State is rng_seed & 0xFFFFFFFF; a zero state becomes 0x6D2B79F5.
func _init(rng_seed: int) -> void:
	_state = rng_seed & _MASK
	if _state == 0:
		_state = _ZERO_STATE


## Next value, 0 .. 4294967295 (xorshift32 with 13, 17, 5).
func next_u32() -> int:
	var x: int = _state
	x ^= (x << 13) & _MASK
	x ^= x >> 17
	x ^= (x << 5) & _MASK
	_state = x
	_draws += 1
	return x


## Next value in 0 .. n - 1, n at least 1 (modulo bias accepted). A bad n
## returns 0 without drawing.
func next_below(n: int) -> int:
	if n < 1:
		return 0
	return next_u32() % n


## Number of draws made so far.
func draw_count() -> int:
	return _draws
