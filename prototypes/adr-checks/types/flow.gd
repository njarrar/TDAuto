# PROTOTYPE - NOT FOR PRODUCTION. ADR checks stub. (ADR-0006 V6)
class_name Flow
extends RefCounted
## Returns StageResult, while StageResult types a field Flow.Phase.

enum Phase { BUILD = 0, WAVE = 1, INTERMISSION = 2, PAUSED = 3, WON = 4, LOST = 5, FATAL = 6 }

signal phase_changed(value: Phase)

var _phase: Phase = Phase.BUILD


func set_phase(p_phase: Phase) -> void:
	_phase = p_phase
	phase_changed.emit(p_phase)


func result() -> StageResult:
	var r: StageResult = StageResult.new()
	r.outcome = _phase
	return r
