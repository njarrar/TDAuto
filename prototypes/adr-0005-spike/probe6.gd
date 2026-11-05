extends SceneTree
# Does a subclass _init() with no super() call compile when the parent _init has required args?
class P extends RefCounted:
	var a: int
	func _init(x: int) -> void:
		a = x
class S extends P:
	var reads := []
	func _init() -> void:
		reads.append(1)
func _init() -> void:
	var s := S.new()
	print("S.new() without super: a=", s.a, " reads=", s.reads)
	quit()
