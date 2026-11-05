extends SceneTree
func _init() -> void:
	var nan_v := Vector2(NAN, 1.0)
	var inf_v := Vector2(INF, 1.0)
	var ninf_v := Vector2(1.0, -INF)
	var ok_v := Vector2(3.0, 4.0)
	print("PROBE|is_finite nan=", nan_v.is_finite(), " inf=", inf_v.is_finite(), " -inf=", ninf_v.is_finite(), " ok=", ok_v.is_finite())
	print("PROBE|is_nan float: ", is_nan(NAN), " ", is_nan(1.0), " is_inf: ", is_inf(INF), " is_finite float: ", is_finite(INF), " ", is_finite(2.0))
	print("PROBE|nan compare nan<=r2: ", NAN <= 36.0, " nan>=s2: ", NAN >= 15.0)
	print("PROBE|dist exact edge: ", Vector2(306.0, 480.0).distance_squared_to(Vector2(270.0, 480.0)) <= 36.0 * 36.0, " ", Vector2(307.0, 480.0).distance_squared_to(Vector2(270.0, 480.0)) <= 36.0 * 36.0)
	var c := Vector2(270.0, 480.0)
	var t0 := Time.get_ticks_usec()
	var a := 0
	for i in 10000:
		if Vector2(float(i % 540), 480.0).distance_squared_to(c) <= 1296.0: a += 1
	var t1 := Time.get_ticks_usec()
	for i in 10000:
		if Vector2(float(i % 540), 480.0).distance_to(c) <= 36.0: a += 1
	var t2 := Time.get_ticks_usec()
	print("PROBE|10k squared usec=", t1 - t0, " distance_to usec=", t2 - t1, " hits=", a)
	quit()
