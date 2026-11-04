class_name Bot extends RefCounted
## Base of every bot (ADR-0010 Decision 9). A bot is passed to the battle
## runner as `bot.between`. It calls only the gameplay commands and read
## queries; it never writes a field, connects a signal or calls a tick entry.

var battle: Battle = null


func _init(p_battle: Battle) -> void:
	battle = p_battle


## Called before tick i. Override.
func between(_i: int) -> void:
	pass
