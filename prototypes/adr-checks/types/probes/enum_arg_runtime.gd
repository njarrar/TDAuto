# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0008 V4: out-of-range values reach an Accepts parameter at run time.
extends "res://types/probes/probe_base.gd"

enum Other { X = 7 }


func run() -> void:
	var r: InputResolver = InputResolver.create(15.0, 28.0)
	var five: int = 5
	var minus: int = -1
	var other: int = Other.X
	var loose: Variant = 5
	var e0: int = errs()
	var g5: int = r.register(1, five as InputResolver.Accepts)
	var gm: int = r.register(2, minus as InputResolver.Accepts)
	var go: int = r.register(3, other as InputResolver.Accepts)
	var gl: int = r.register(4, loose)
	var e1: int = errs()
	var delta: String = "n/a" if e0 < 0 else str(e1 - e0)
	var ok: bool = g5 == 5 and gm == -1 and go == 7 and gl == 5 and (e0 < 0 or e1 == e0)
	check("ADR-0008-V4-runtime", ok, "received 5->%d -1->%d other(7)->%d Variant 5->%d errors=+%s" % [g5, gm, go, gl, delta], "no runtime check: values arrive unchanged, no error")
	done = true
