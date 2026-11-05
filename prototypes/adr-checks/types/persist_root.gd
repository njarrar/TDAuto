# PROTOTYPE - NOT FOR PRODUCTION. ADR checks stub. (ADR-0006 V3, the .tscn connection)
extends Node

var renamed_count: int = 0


func _on_child_renamed() -> void:
	renamed_count += 1
