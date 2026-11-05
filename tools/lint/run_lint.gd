extends SceneTree
## Local entry point for the layer lint:
##   godot --headless --path . -s res://tools/lint/run_lint.gd
## Prints every finding as "<res path>:<line>: <RULE> <message>", then the coverage
## lines. Exits 1 on any finding or structural error, 0 otherwise.

const Runner := preload("res://tools/lint/lint_runner.gd")


func _initialize() -> void:
	var runner: RefCounted = Runner.new()
	var report: Dictionary = runner.run()
	var findings: Array[Dictionary] = report["findings"]
	var finding_lines: PackedStringArray = runner.format_findings(findings)
	var errors: PackedStringArray = report["errors"]
	for line in finding_lines:
		print(line)
	for line in errors:
		print("error: ", line)
	for line in report["coverage"]:
		print(line)
	print("lint: scanned %d files (%d .gd under src/), %d findings, %d errors" % [report["scanned"], report["scanned_src_gd"], findings.size(), errors.size()])
	quit(1 if (not findings.is_empty() or not errors.is_empty()) else 0)
