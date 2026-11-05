extends SceneTree
class P extends RefCounted:
	var a: int
	var f: Callable
	func _init(x: int, cb: Callable) -> void:
		a = x; f = cb
	func g() -> float:
		return 1.0
class S1 extends P:
	func _init(x: int, cb: Callable) -> void:
		super(x, cb)
	func g() -> float:
		return 2.0
class S2 extends P:
	func g() -> float:
		return 3.0
func _init() -> void:
	var s1 := S1.new(4, Callable())
	print("S1 a=", s1.a, " g=", s1.g())
	var s2 := S2.new(5, Callable())
	print("S2 a=", s2.a, " g=", s2.g())
	quit()
