extends Node
# Review probe: architecture name, first frames' _process delta (windowed), usec resolution, int(unix) typing,
# whether a notification/input callback can run inside a _process loop, and the drop-remainder slowdown.
var _frames: int = 0
var _in_loop: bool = false
var _reentry: int = 0
var _t_prev: int = 0

func _ready() -> void:
	print("arch: ", Engine.get_architecture_name(), " version: ", Engine.get_version_info().string)
	print("int(unix): ", int(Time.get_unix_time_from_system()), " typeof: ", typeof(int(Time.get_unix_time_from_system())))
	var t: Array[int] = []
	for i in 5:
		t.append(Time.get_ticks_usec())
	print("usec 5 reads: ", t)
	print("roundi exists: ", roundi(2.5), " ceili: ", ceili(2.1))
	# drop-remainder model at an exact 60 fps with +-1 % jitter vs keep-remainder
	var dt := 1.0 / 60.0
	var acc_drop := 0.0
	var acc_keep := 0.0
	var n_drop := 0
	var n_keep := 0
	var n_cap := 0
	var frames := 6000
	for f in frames:
		var d := dt * (0.99 if f % 2 == 0 else 1.01)
		acc_drop += d
		var owed := floori(acc_drop / dt)
		if owed > 2:
			n_drop += 2
			acc_drop = 0.0
		else:
			n_drop += owed
			acc_drop -= owed * dt
		acc_keep += d
		owed = floori(acc_keep / dt)
		if owed > 2:
			n_keep += 2
			n_cap += 1
			acc_keep -= 2 * dt
		else:
			n_keep += owed
			acc_keep -= owed * dt
	print("jitter 1pct over ", frames, " frames: drop=", n_drop, " keep=", n_keep)
	# one 100 ms stall every 60 frames: per-stall loss under drop vs keep
	acc_drop = 0.0; acc_keep = 0.0; n_drop = 0; n_keep = 0
	var owed_total := 0.0
	for f in 600:
		var d := 0.1 if f % 60 == 59 else dt
		owed_total += d
		acc_drop += d
		var owed := floori(acc_drop / dt)
		if owed > 2:
			n_drop += 2; acc_drop = 0.0
		else:
			n_drop += owed; acc_drop -= owed * dt
		acc_keep += d
		owed = floori(acc_keep / dt)
		if owed > 2:
			n_keep += 2; acc_keep -= 2 * dt
		else:
			n_keep += owed; acc_keep -= owed * dt
	print("stall 100ms every 60 frames, 600 frames, real ticks owed=", roundi(owed_total / dt), " drop=", n_drop, " keep(no bank cap)=", n_keep)
	_t_prev = Time.get_ticks_usec()

func _notification(what: int) -> void:
	if _in_loop and what >= 1000:
		_reentry += 1
		print("REENTRY notification ", what, " inside _process loop")

func _input(_e: InputEvent) -> void:
	if _in_loop:
		_reentry += 1
		print("REENTRY input inside _process loop")

func _process(delta: float) -> void:
	_frames += 1
	var now := Time.get_ticks_usec()
	if _frames <= 4:
		print("frame ", _frames, " delta=%.6f" % delta, " usec since prev=", now - _t_prev)
	_t_prev = now
	_in_loop = true
	# busy loop ~30 ms so any queued notification/input would have a window to be dispatched if the engine ever did that
	var end := Time.get_ticks_usec() + 30000
	while Time.get_ticks_usec() < end:
		pass
	_in_loop = false
	if _frames == 4:
		print("usec resolution during busy loop: sub-ms increments observed (loop exited at ", Time.get_ticks_usec() - end, " usec past target)")
	if _frames == 90:
		print("reentry count over 90 frames: ", _reentry)
		get_tree().quit()
