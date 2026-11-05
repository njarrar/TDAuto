extends SceneTree
func _init() -> void:
	var r: Variant = load("res://rec.tres")
	print("tres loaded: %s" % [str(r != null)])
	if r:
		print("count (1.5 in file) -> %s typeof=%d ; damage (\"oops\" in file) -> %s ; name_id (missing) -> '%s' ; unknown prop get -> %s ; property list has atack_interval: %s" % [str(r.count), typeof(r.count), str(r.damage), r.name_id, str(r.get("atack_interval")), str(r.get_property_list().any(func(p): return p.name == "atack_interval"))])
	print("Vector2(0.1,0).x == 0.1 -> %s ; x=%.17f ; Vector2(173.99,0).x=%.10f" % [Vector2(0.1, 0).x == 0.1, Vector2(0.1, 0).x, Vector2(173.99, 0).x])
	var d1 := {"a": 1}
	var d2 := {"a": 1}
	print("Dictionary ==: %s ; recursive_equal: %s ; same ref: %s" % [d1 == d2, d1.recursive_equal(d2, 10), d1 == d1])
	quit()
