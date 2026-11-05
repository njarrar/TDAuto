extends SceneTree
class Base extends RefCounted:
	func pick() -> Targetable: return null
class Sub extends Base:
	func pick():
		pass
func _init() -> void:
	print("override without explicit return compiled; result=", Sub.new().pick())
	quit()
