# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0008 V4 / ADR-0009 V6 warning probe.
extends RefCounted

enum Other { X = 7 }


func f(r: InputResolver) -> int:
	var got: int = r.register(1, 5)
	if got < 0:
		return got
	return 0
