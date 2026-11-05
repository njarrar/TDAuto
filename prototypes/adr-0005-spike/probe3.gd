extends SceneTree
const COST := &"cost"
const DAMAGE := &"damage"
const KT := {&"tower": {COST: TYPE_INT, DAMAGE: TYPE_FLOAT}}
func pick(k: StringName) -> int:
	match k:
		COST:
			return 1
		DAMAGE:
			return 2
		_:
			return -1
func _init() -> void:
	var s := "damage"
	print(pick(&"cost"), pick(&"damage"), pick(&"x"), " string-derived key: ", pick(StringName(s)), " raw String: ", pick(s))
	print("const dict by const key: ", KT[&"tower"][COST] == TYPE_INT, " ", KT[&"tower"].has(&"nope"))
	quit()
