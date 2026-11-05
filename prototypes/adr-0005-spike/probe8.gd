extends SceneTree
# Cross-class const as a match pattern (the accessor matches on StatKeys.COST, a constant on another class).
func pick(k: StringName) -> int:
	match k:
		KeysX.COST:
			return 1
		KeysX.DAMAGE:
			return 2
		_:
			return -1
func _init() -> void:
	print("cross-class const match: ", pick(&"cost"), pick(&"damage"), pick(&"x"), " raw String: ", pick("damage"))
	quit()
