# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0011 V6 fallback: Array[int] constant.
extends "res://types/probes/probe_base.gd"

const TEXT_SIZES: Array[int] = [21, 24, 36]


func run() -> void:
	record("ADR-0011-V6-fallback", "%s typed=%s" % [TEXT_SIZES, TEXT_SIZES.is_typed()], "fallback form also parses (record only)")
	done = true
