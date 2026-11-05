extends Node
# Review probe 2: JSON round trip of an int64 rng.state and a float; physics_jitter_fix; _process delta vs wall clock.
var _n: int = 0
var _prev: int = 0
var _sum_delta: float = 0.0
var _t0: int = 0

func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 12345
	r.randi()
	var snap := {"state": r.state, "f": 0.1 + 0.2, "pos_x": 1.0 / 3.0, "cd": 300}
	var txt := JSON.stringify(snap)
	var back: Variant = JSON.parse_string(txt)
	print("json text: ", txt)
	print("json state back: ", back["state"], " typeof: ", typeof(back["state"]), " equal to int: ", back["state"] == snap["state"])
	print("json f back equal: ", back["f"] == snap["f"], " cd typeof: ", typeof(back["cd"]), " dict equal: ", back == snap)
	var vts := var_to_str(snap)
	var back2: Variant = str_to_var(vts)
	print("var_to_str round trip equal: ", back2 == snap, " state typeof: ", typeof(back2["state"]))
	print("physics_jitter_fix: ", Engine.physics_jitter_fix, " setting: ", ProjectSettings.get_setting("physics/common/physics_jitter_fix"))
	print("randfn present: ", r.randfn(0.0, 1.0) != INF)
	_prev = Time.get_ticks_usec()
	_t0 = _prev

func _process(delta: float) -> void:
	_n += 1
	var now := Time.get_ticks_usec()
	_sum_delta += delta
	if _n <= 12:
		print("f", _n, " delta=%.6f" % delta, " wall=%.6f" % ((now - _prev) / 1e6))
	_prev = now
	if _n == 300:
		print("300 frames: sum(delta)=%.4f" % _sum_delta, " wall=%.4f" % ((now - _t0) / 1e6))
		get_tree().quit()
