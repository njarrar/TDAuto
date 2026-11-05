# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0010 V4: override with explicit enum return.
extends "res://types/probes/enum_base.gd"


func pick() -> E:
	return E.B
