extends SceneTree
func _init() -> void:
	var c := Color("0B1020")
	print("T0 base=", c, " h=", c.h, " s=", c.s, " v=", c.v)
	print("T1 won=", Color.from_hsv(c.h, c.s, c.v + 0.04), " lost=", Color.from_hsv(c.h, c.s * 0.4, c.v - 0.04))
	print("T2 half-ramp lost=", Color.from_hsv(c.h, c.s * (1.0 - 0.6 * 0.5), c.v - 0.04 * 0.5))
	quit()
