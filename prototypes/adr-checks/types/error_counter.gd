# PROTOTYPE - NOT FOR PRODUCTION. ADR checks.
extends Logger
## Counts errors and warnings the engine reports (4.5+ Logger API).
## Loaded at run time by report.gd, so a wrong signature here only turns the
## counts off. Signature from memory: NOT in the pinned engine reference.

var errors: int = 0
var warnings: int = 0
var last: String = ""


func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == 1:
		warnings += 1
	else:
		errors += 1
	last = rationale if not rationale.is_empty() else code
