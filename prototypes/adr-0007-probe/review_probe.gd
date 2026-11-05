extends SceneTree
func _init():
	for p in ["res://missing_type.gd", "res://child_typed.gd", "res://named.gd", "res://good.gd"]:
		var s = load(p)
		if s == null:
			print("REVIEW ", p, " load=null")
		else:
			print("REVIEW ", p, " can_instantiate=", s.can_instantiate(), " reload=", s.reload(), " global_name=", s.get_global_name())
	var sc = load("res://broken.tscn")
	print("REVIEW broken.tscn load=", sc, " can_inst=", sc.can_instantiate() if sc else "n/a")
	print("REVIEW os=", OS.get_name(), " arch=", Engine.get_architecture_name(), " ver=", Engine.get_version_info())
	print("REVIEW env=", OS.get_environment("HOME") != "")
	print("REVIEW classlist=", ProjectSettings.get_global_class_list())
	quit(0)
