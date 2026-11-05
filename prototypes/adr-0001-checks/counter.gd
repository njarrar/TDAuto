# PROTOTYPE - NOT FOR PRODUCTION. ADR-0001 V2.
extends RefCounted
## Shared event counts. Owned by v2_main.gd, never by the fake battle.

var n: Dictionary = {}


## Adds one to the count for key.
func bump(key: String) -> void:
	n[key] = int(n.get(key, 0)) + 1
