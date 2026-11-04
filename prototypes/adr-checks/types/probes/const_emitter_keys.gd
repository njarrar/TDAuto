# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0006 V6: const typed array of StringName.
extends "res://types/probes/probe_base.gd"

const EMITTER_KEYS: Array[StringName] = [&"flow", &"combat", &"tower_sim"]


func run() -> void:
	var ok: bool = EMITTER_KEYS.size() == 3 and typeof(EMITTER_KEYS[0]) == TYPE_STRING_NAME
	check("ADR-0006-V6-EMITTER_KEYS", ok, "size=%d typeof0=%s typed=%s read_only=%s" % [EMITTER_KEYS.size(), type_string(typeof(EMITTER_KEYS[0])), EMITTER_KEYS.is_typed(), EMITTER_KEYS.is_read_only()], "parses; 3 StringName values")
	done = true
