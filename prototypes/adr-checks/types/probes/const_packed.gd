# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0011 V6: packed-array constant.
extends "res://types/probes/probe_base.gd"

const TEXT_SIZES: PackedInt32Array = [21, 24, 36]


func run() -> void:
	var ok: bool = typeof(TEXT_SIZES) == TYPE_PACKED_INT32_ARRAY and TEXT_SIZES.size() == 3 and TEXT_SIZES[0] == 21 and TEXT_SIZES[2] == 36
	check("ADR-0011-V6", ok, "%s (%s)" % [TEXT_SIZES, type_string(typeof(TEXT_SIZES))], "parses and reads [21, 24, 36] as PackedInt32Array")
	done = true
