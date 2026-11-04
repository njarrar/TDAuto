# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0008 V4 / ADR-0009 V6 warning probe, warnings ignored.
extends RefCounted

enum Other { X = 7 }


func f(r: InputResolver) -> int:
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	var k: Combat.SourceKind = 1
	if r == null:
		return k
	return 0
