extends GdUnitTestSuite
## Runs the layer lint over src/, tests/ and tools/ plus project.godot and
## export_presets.cfg, and proves the gate itself (ADR-0007 Decision 8).

const Rules := preload("res://tools/lint/lint_rules.gd")
const Runner := preload("res://tools/lint/lint_runner.gd")
const Samples := preload("res://tests/helpers/lint_samples.gd")

const CATALOGUE_PATH: String = "res://docs/architecture/adr-0007-lint-rules.md"

var _runner: RefCounted = null
var _report: Dictionary = {}


func before() -> void:
	_runner = Runner.new()
	_report = _runner.run()
	for line in _report["coverage"]:
		print(line)


func test_repo_scan_finds_src_scripts() -> void:
	assert_int(_report["scanned_src_gd"]).is_greater(0)


func test_repo_has_no_structural_errors() -> void:
	assert_array(Array(_report["errors"])).is_empty()


func test_repo_has_no_lint_findings() -> void:
	var findings: Array[Dictionary] = _report["findings"]
	var lines: PackedStringArray = _runner.format_findings(findings)
	assert_array(Array(lines)).is_empty()


func test_empty_scan_fails() -> void:
	var report: Dictionary = _runner.run_on({}, {})
	assert_int((report["errors"] as PackedStringArray).size()).is_greater(0)


func test_seeded_uid_path_is_reported_as_layer_5() -> void:
	var sources: Dictionary = {"res://src/core/_lint_probe.gd": 'extends RefCounted\nconst H := preload("uid://abc")\n'}
	var report: Dictionary = _runner.run_on(sources, {})
	var findings: Array[Dictionary] = report["findings"]
	var rules_hit: Array = []
	for f in findings:
		rules_hit.append(str(f["rule"]))
	assert_array(rules_hit).contains(["LAYER-5"])


func test_coverage_lists_pending_and_not_assessed_rules() -> void:
	var report: Dictionary = _runner.run_on({"res://src/core/a.gd": "extends RefCounted\n"}, {})
	var coverage: Array = Array(report["coverage"])
	assert_array(coverage).contains(["pending: WIRE-5 (ADR-0006)"])
	assert_array(coverage).contains(["pending: INPUT-9 (ADR-0008)"])
	assert_array(coverage).contains(["not assessed: ERR-5 res://src/root/app_root.gd absent"])
	assert_array(coverage).contains(["not assessed: PROJ-1 res://project.godot absent"])


func test_every_rule_has_a_bad_sample_and_a_near_miss() -> void:
	var samples: Dictionary = Samples.all()
	var failures: Array = []
	for rule in Rules.RULES:
		if not samples.has(rule):
			failures.append("%s: no sample" % rule)
			continue
		failures.append_array(Array(Samples.check_bad(str(rule), samples[rule])))
		failures.append_array(Array(Samples.check_near(str(rule), samples[rule])))
	assert_array(failures).is_empty()


func test_rule_ids_match_the_catalogue() -> void:
	var diff: PackedStringArray = _id_diff(Rules.RULES.keys(), _catalogue_ids())
	assert_array(Array(diff)).is_empty()


func test_id_check_notices_a_rule_without_a_catalogue_row() -> void:
	var ids: Array = Rules.RULES.keys()
	ids.append("ZZZ-99")
	var diff: PackedStringArray = _id_diff(ids, _catalogue_ids())
	assert_array(Array(diff)).contains(["in lint_rules.gd but not in the catalogue: ZZZ-99"])


func _catalogue_ids() -> Array:
	var text: String = FileAccess.get_file_as_string(CATALOGUE_PATH)
	var id_re: RegEx = RegEx.create_from_string(r"(?m)^\| ([A-Z]+-\d+) \|", true)
	var ids: Array = []
	for m: RegExMatch in id_re.search_all(text):
		ids.append(m.get_string(1))
	return ids


func _id_diff(rule_ids: Array, catalogue_ids: Array) -> PackedStringArray:
	var diff: PackedStringArray = PackedStringArray()
	if catalogue_ids.is_empty():
		diff.append("no rule rows found in %s" % CATALOGUE_PATH)
	for id in rule_ids:
		if not catalogue_ids.has(id):
			diff.append("in lint_rules.gd but not in the catalogue: %s" % id)
	for id in catalogue_ids:
		if not rule_ids.has(id):
			diff.append("in the catalogue but not in lint_rules.gd: %s" % id)
	return diff
