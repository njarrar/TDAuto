# PROTOTYPE - NOT FOR PRODUCTION. ADR checks: numerics.
# Covers ADR-0004 V4 desktop leg (binary64, 64-bit int, typed math,
# to_ticks Validation 3 values, SimRng golden values, BattleClock
# Validation 1 with the jitter case), ADR-0004 V9 (delta_smoothing key read
# only), ADR-0009 V1, V3 and ADR-0008 V2, V3.
# SimTime, SimRng and BattleClock are copies of the ADR-0004 code, here as
# inner classes. Golden values were computed in Python for ADR-0004.
# Run: godot --headless --path . -s res://check_numerics.gd
extends SceneTree

const Report := preload("res://types/report.gd")

var _r: Report = Report.new()


class SimTime extends RefCounted:
	var ticks_per_second: int = 60
	var dt: float = 1.0 / 60.0

	func _init(p_ticks_per_second: int = 60) -> void:
		ticks_per_second = p_ticks_per_second
		dt = 1.0 / float(p_ticks_per_second)

	func to_ticks(seconds: float) -> int:
		if not is_finite(seconds):
			return 0
		var x: float = seconds * float(ticks_per_second)
		var t: int = floori(absf(x) + 0.5)
		return -t if x < 0.0 else t


class SimRng extends RefCounted:
	const M: int = 0xFFFFFFFF
	var _state: int = 0
	var _draws: int = 0

	func _init(rng_seed: int) -> void:
		_state = rng_seed & M
		if _state == 0:
			_state = 0x6D2B79F5

	func next_u32() -> int:
		var x: int = _state
		x ^= (x << 13) & M
		x ^= x >> 17
		x ^= (x << 5) & M
		_state = x
		_draws += 1
		return x

	func draw_count() -> int:
		return _draws


class BattleClock extends RefCounted:
	const MAX_TICKS_PER_FRAME: int = 3
	const STALL_SECONDS: float = 0.5
	var _ticks_per_second: int = 60
	var _dt: float = 1.0 / 60.0
	var _phase: float = 0.5
	var _acc: float = 0.0

	## p_phase is 0.5 in the ADR; 0.0 only for the jitter control case.
	func _init(p_ticks_per_second: int, p_phase: float = 0.5) -> void:
		_ticks_per_second = p_ticks_per_second
		_dt = 1.0 / float(p_ticks_per_second)
		_phase = p_phase
		_acc = _phase * _dt

	func advance(delta: float) -> int:
		if not is_finite(delta) or delta <= 0.0:
			return 0
		if delta > STALL_SECONDS:
			_acc = _phase * _dt
			return 0
		_acc += delta
		var run: int = mini(floori(_acc * float(_ticks_per_second)), MAX_TICKS_PER_FRAME)
		_acc = maxf(_acc - float(run) * _dt, 0.0)
		if run == MAX_TICKS_PER_FRAME:
			_acc = minf(_acc, 1.5 * _dt)
		return run

	func drop_backlog() -> void:
		_acc = _phase * _dt

	func acc() -> float:
		return _acc


func _initialize() -> void:
	_v4_binary64()
	_v4_int64()
	_v4_typed_math()
	_v4_to_ticks()
	_v4_sim_rng()
	_v4_clock()
	_v4_record()
	_v9_delta_smoothing()
	_vector2_and_nan()
	_r.finish(self, "check_numerics.gd")


func _f(x: float) -> String:
	return "%.17f" % x


func _v4_binary64() -> void:
	var a: float = 0.1
	var b: float = 0.2
	var s: float = a + b
	_r.check("ADR-0004-V4-0.1+0.2", s == 0.30000000000000004, _f(s), "0.30000000000000004 (binary64)")
	var big: float = 16777217.0
	var sum: float = big + 1.0
	_r.check("ADR-0004-V4-16777217+1", sum == 16777218.0, _f(sum), "16777218.0 (binary64)")


func _v4_int64() -> void:
	var minus_one: int = -1
	var m: int = minus_one & 0xFFFFFFFF
	_r.check("ADR-0004-V4-mask", m == 4294967295, m, "4294967295")
	var full: int = 0xFFFFFFFF
	var shifted: int = full << 13
	_r.check("ADR-0004-V4-shift", shifted == 35184372080640, shifted, "35184372080640 (no overflow, 64-bit int)")


func _v4_typed_math() -> void:
	var neg_half: float = -0.5
	var obs: Array = [floori(neg_half), floori(2.5), ceili(neg_half), ceili(2.1), absf(-2.5), _f(sqrt(2.0)), is_nan(sqrt(-1.0)), is_finite(1.0e308 * 10.0)]
	var ok: bool = floori(neg_half) == -1 and floori(2.5) == 2 and ceili(neg_half) == 0 and ceili(2.1) == 3 and absf(-2.5) == 2.5 and sqrt(2.0) == 1.4142135623730951 and is_nan(sqrt(-1.0)) and not is_finite(1.0e308 * 10.0)
	_r.check("ADR-0004-V4-typed-math", ok, "floori(-0.5), floori(2.5), ceili(-0.5), ceili(2.1), absf(-2.5), sqrt(2), isnan(sqrt(-1)), is_finite(1e308*10) = %s" % [obs], "[-1, 2, 0, 3, 2.5, 1.41421356237309515, true, false] (IEEE)")


func _v4_to_ticks() -> void:
	var t60: SimTime = SimTime.new(60)
	var t4: SimTime = SimTime.new(4)
	var tenth: float = 0.1
	var acc3: float = tenth + tenth + tenth
	var got: Array = [
		t60.to_ticks(0.9), t60.to_ticks(5.0), t60.to_ticks(1.0 / 60.0), t60.to_ticks(0.0),
		t60.to_ticks(0.125 * 0.0), t60.to_ticks(0.125 * 1.0), t60.to_ticks(0.125 * 2.0), t60.to_ticks(0.125 * 3.0),
		t60.to_ticks(tenth * 3.0), t60.to_ticks(acc3), t60.to_ticks(0.025), t60.to_ticks(-0.025),
		t4.to_ticks(0.125), t60.to_ticks(NAN), t60.to_ticks(INF), t60.to_ticks(-INF),
	]
	var want: Array = [54, 300, 1, 0, 0, 8, 15, 23, 18, 18, 2, -2, 1, 0, 0, 0]
	_r.check("ADR-0004-V4-to_ticks", got == want, got, "%s (0.9, 5.0, 1/60, 0; 0.125 steps; 0.1*3 and 0.1+0.1+0.1; 0.025, -0.025; at 4: 0.125; NAN, INF, -INF)" % [want])
	var left: float = 5.0
	var n: int = 0
	while left > 0.0 and n < 1000:
		left -= t60.dt
		n += 1
	_r.check("ADR-0004-V4-float-countdown", n == 301, n, "301 ticks (5.0 s by repeated subtraction of dt)")


func _v4_sim_rng() -> void:
	var cases: Array = [[1, [270369, 67634689, 2647435461]], [0, [1085196063, 2447379481, 2618286376]], [-1, [253983, 4228382207, 1958451267]]]
	for c in cases:
		var rng: SimRng = SimRng.new(int(c[0]))
		var got: Array = [rng.next_u32(), rng.next_u32(), rng.next_u32()]
		_r.check("ADR-0004-V4-SimRng(%d)" % int(c[0]), got == c[1], "%s draws=%d" % [got, rng.draw_count()], "%s, draw_count 3" % [c[1]])


func _v4_clock() -> void:
	var c: BattleClock = BattleClock.new(60)
	var dt: float = 1.0 / 60.0
	var r1: int = c.advance(1.0 / 60.0)
	var c2: BattleClock = BattleClock.new(60)
	var r2: int = c2.advance(1.0 / 30.0)
	var c3: BattleClock = BattleClock.new(60)
	var r3: int = c3.advance(0.2)
	var carry_ok: bool = c3.acc() == 1.5 * dt
	var c4: BattleClock = BattleClock.new(60)
	c4.advance(0.1)
	var r4: int = c4.advance(0.6)
	var reset_ok: bool = c4.acc() == 0.5 * dt
	_r.check("ADR-0004-V4-clock-basic", r1 == 1 and r2 == 2 and r3 == 3 and carry_ok and r4 == 0 and reset_ok, "1/60->%d 1/30->%d 0.2->%d carry=%s ticks 0.6->%d reset=%s" % [r1, r2, r3, c3.acc() / dt, r4, c4.acc() / dt], "1, 2, 3 with 1.5 ticks carry, 0 with reset to 0.5 tick")

	var c5: BattleClock = BattleClock.new(60)
	c5.advance(0.01)
	var before: float = c5.acc()
	var bad: Array = [c5.advance(0.0), c5.advance(-1.0), c5.advance(NAN), c5.advance(INF)]
	_r.check("ADR-0004-V4-clock-bad-delta", bad == [0, 0, 0, 0] and c5.acc() == before, "%s acc unchanged=%s" % [bad, c5.acc() == before], "[0, 0, 0, 0], nothing changed")

	var c6: BattleClock = BattleClock.new(60)
	var total: int = 0
	for i in 1800:
		total += c6.advance(1.0 / 30.0)
	_r.check("ADR-0004-V4-clock-1800", total == 3600, total, "3600 ticks from 1800 calls of 1/30")

	var c7: BattleClock = BattleClock.new(60)
	c7.advance(0.2)
	c7.drop_backlog()
	var r7: int = c7.advance(0.01)
	_r.check("ADR-0004-V4-clock-drop_backlog", r7 == 1, r7, "1 (drop_backlog then advance(0.01))")

	var counts: Array = _jitter(0.5)
	_r.check("ADR-0004-V4-jitter-half-phase", counts[1] == 600, "frames with 0/1/2/3 ticks: %s" % [counts], "600 one-tick frames of 600")
	var zero: Array = _jitter(0.0)
	_r.check("ADR-0004-V4-jitter-zero-phase", zero[0] > 0 or zero[2] > 0, "frames with 0/1/2/3 ticks: %s" % [zero], "some 0- and 2-tick frames (control: clock started at 0)")


## 600 frames alternating 1/60 - 0.0001 and 1/60 + 0.0001, minus first.
func _jitter(phase: float) -> Array:
	var c: BattleClock = BattleClock.new(60, phase)
	var counts: Array = [0, 0, 0, 0]
	for i in 600:
		var d: float = (1.0 / 60.0 - 0.0001) if i % 2 == 0 else (1.0 / 60.0 + 0.0001)
		counts[c.advance(d)] += 1
	return counts


func _callee_error(state: Dictionary) -> void:
	var o: Variant = null
	o.missing_method()
	state["callee_after"] = true


func _v4_record() -> void:
	_r.record("ADR-0004-V4-round", "round(0.5)=%s round(2.5)=%s round(-0.5)=%s" % [round(0.5), round(2.5), round(-0.5)], "record only")
	var arch: String = str(Engine.call("get_architecture_name")) if Engine.has_method("get_architecture_name") else "n/a"
	_r.record("ADR-0004-V4-arch", "x86_64=%s arm64=%s x86_32=%s arm32=%s 64=%s get_architecture_name=%s" % [OS.has_feature("x86_64"), OS.has_feature("arm64"), OS.has_feature("x86_32"), OS.has_feature("arm32"), OS.has_feature("64"), arch], "record the call naming the CPU architecture")
	var state: Dictionary = {"callee_after": false, "caller_after": false}
	_callee_error(state)
	state["caller_after"] = true
	_r.record("ADR-0004-V4-unwind-debug", "caller continued=%s callee continued=%s (debug run; release leg is SP15)" % [state["caller_after"], state["callee_after"]], "record (release export leg on the phone)")


func _v9_delta_smoothing() -> void:
	var key: String = "application/run/delta_smoothing"
	var has: bool = ProjectSettings.has_setting(key)
	var value: Variant = ProjectSettings.get_setting(key, null)
	_r.check("ADR-0004-V9", has, "has_setting=%s value=%s" % [has, value], "key exists (believed default true)")


func _vector2_and_nan() -> void:
	var tenth: float = 0.1
	var odd: float = 16777217.0
	var v1: Vector2 = Vector2(tenth, 0.0)
	var v2: Vector2 = Vector2(odd, 0.0)
	var eq1: bool = v1.x == tenth
	var eq2: bool = v2.x == odd
	_r.check("ADR-0009-V1", not eq1 and not eq2, "Vector2(0.1,0).x==0.1 %s (%s); Vector2(16777217,0).x==16777217 %s (%s); single=%s double=%s" % [eq1, _f(v1.x), eq2, _f(v2.x), OS.has_feature("single"), OS.has_feature("double")], "both false (32-bit components)")
	var v3: Vector2 = Vector2(299.0, 500.0)
	var diff: float = v3.x - 270.0
	_r.check("ADR-0008-V2", diff == 29.0, _f(diff), "29.0 (Vector2(299, 500).x - 270 == 29)")

	var nan_v: float = NAN
	var inf_v: float = INF
	var ninf_v: float = -INF
	var fin: Array = [is_finite(nan_v), is_finite(inf_v), is_finite(ninf_v)]
	var cmp: Array = [nan_v > 0.0, nan_v < 1.0, nan_v >= 0.0]
	_r.check("ADR-0009-V3", fin == [false, false, false] and cmp == [false, false, false], "is_finite NAN/INF/-INF %s; NAN > 0, < 1, >= 0 %s" % [fin, cmp], "all false (IEEE)")
	var vn: Vector2 = Vector2(nan_v, 0.0)
	var vi: Vector2 = Vector2(inf_v, 0.0)
	var vf: Array = [is_finite(vn.x), is_finite(vi.x)]
	_r.check("ADR-0008-V3", vf == [false, false], "is_finite(Vector2(NAN,0).x), is_finite(Vector2(INF,0).x) = %s" % [vf], "both false")
