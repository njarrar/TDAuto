# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0010 V4: HeroSim and PinGeometry cycle.
extends "res://types/probes/probe_base.gd"


func run() -> void:
	var h: HeroSim = HeroSim.new()
	var off: int = h.try_pin(-1.0)
	var on: int = h.try_pin(1.0)
	check("ADR-0010-V4-cycle", off == 1 and on == 0, "try_pin(-1)=%d try_pin(1)=%d" % [off, on], "1 (OFF_PATH) and 0 (OK); cyclic class_name reference parses and runs")
	done = true
