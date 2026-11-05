extends SceneTree
func _init():
	var s = load("res://bad.gd")
	print("PROBE load bad.gd -> ", s)
	var g = load("res://good.gd")
	print("PROBE load good.gd -> ", g)
	quit(0)
