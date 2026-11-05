# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0006 V6: Flow and StageResult cycle, enum signal parameter.
extends "res://types/probes/probe_base.gd"


func run() -> void:
	var flow: Flow = Flow.new()
	var got: Array = []
	flow.phase_changed.connect(func(v: Flow.Phase) -> void: got.append(v))
	flow.set_phase(Flow.Phase.WON)
	var ok_sig: bool = got.size() == 1 and typeof(got[0]) == TYPE_INT and got[0] == 4
	check("ADR-0006-V6-phase_changed", ok_sig, "received %s" % [got], "one value 4 (WON), TYPE_INT")
	var res: StageResult = flow.result()
	check("ADR-0006-V6-StageResult", res.outcome == Flow.Phase.WON, "outcome=%d" % res.outcome, "4 (WON); Flow returns StageResult typed Flow.Phase")
	done = true
