extends SceneTree
func _init() -> void:
	var live: Array[Enemy] = [Enemy.new()]
	var base: Array[Targetable] = live
	print("static assign compiled?! size=", base.size())
	quit()
