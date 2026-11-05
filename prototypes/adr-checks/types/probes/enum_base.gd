# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0010 V4: enum with declaration order unlike values.
extends "res://types/probes/probe_base.gd"

enum E { OK = 0, A = 1, C = 3, B = 2 }


func pick() -> E:
	return E.A


func run() -> void:
	var v: Variant = pick()
	check("ADR-0010-V4-typeof", typeof(v) == TYPE_INT, type_string(typeof(v)), "TYPE_INT")
	var k: Variant = E.find_key(2)
	check("ADR-0010-V4-find_key", str(k) == "B", "%s (%s)" % [k, type_string(typeof(k))], "\"B\"")
	record("ADR-0010-V4-keys", "%s values %s" % [E.keys(), E.values()], "record only")
	done = true
