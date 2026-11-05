extends SceneTree
func _init():
	for p in ["res://bad.gd","res://good.gd"]:
		var s: GDScript = load(p)
		print("PROBE2 ", p, " can_instantiate=", s.can_instantiate(), " reload=", s.reload() if p.ends_with("bad.gd") else "-")
	quit(0)
