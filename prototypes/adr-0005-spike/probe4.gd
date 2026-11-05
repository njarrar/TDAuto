extends SceneTree
func _init() -> void:
	print("cross-class const key: ", KeysX.T[&"tower"], " ", KeysX.T.has(&"tower"))
	quit()
