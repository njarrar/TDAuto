extends SceneTree
# 4.7 typed-return inheritance: override declared without a return type and without a return on one path.
class P extends RefCounted:
	func f(x: int) -> float:
		return 1.0
class S extends P:
	func f(x):
		if x > 0:
			return 2.0
func _init() -> void:
	print("S.f(1)=", S.new().f(1), " S.f(0)=", S.new().f(0))
	quit()
