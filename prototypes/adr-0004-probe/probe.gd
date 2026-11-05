extends SceneTree
# ADR-0004 probe: RNG repeatability, float width, rounding, engine defaults. Observation only.
func _init() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 12345
	var b := RandomNumberGenerator.new()
	b.seed = 12345
	var sa: Array = []
	var sb: Array = []
	for i in 10:
		sa.append(a.randi())
		sb.append(b.randi())
	print("randi seed 12345: ", sa)
	print("two instances equal: ", sa == sb)
	var z := RandomNumberGenerator.new()
	z.seed = 0
	print("seed 0 first randf: %.17f" % z.randf(), " then randi: ", z.randi())
	var third := 1.0 / 3.0
	print("float 1/3: %.17f" % third)
	var v := Vector2(third, 0.0)
	print("Vector2.x 1/3: %.17f" % v.x)
	print("roundi 0.5 -0.5 2.5 -2.5: ", roundi(0.5), " ", roundi(-0.5), " ", roundi(2.5), " ", roundi(-2.5))
	var dt := 1.0 / 60.0
	print("to_ticks round 0.9 5.0 1/60 0.0: ", roundi(0.9 / dt), " ", roundi(5.0 / dt), " ", roundi(dt / dt), " ", roundi(0.0 / dt))
	var s := 3 * 0.1
	print("3*0.1/dt raw: %.17f" % (s / dt), " round: ", roundi(s / dt), " ceil: ", ceili(s / dt), " floor: ", floori(s / dt))
	print("Engine physics_ticks_per_second: ", Engine.physics_ticks_per_second, " max_physics_steps_per_frame: ", Engine.max_physics_steps_per_frame, " time_scale: ", Engine.time_scale)
	print("version: ", Engine.get_version_info().string)
	var t0 := Time.get_ticks_usec()
	var t1 := Time.get_ticks_usec()
	print("TIME usec pair: ", t0, " ", t1, " unix: %.3f" % Time.get_unix_time_from_system(), " typeof: ", typeof(Time.get_unix_time_from_system()))
	quit()
