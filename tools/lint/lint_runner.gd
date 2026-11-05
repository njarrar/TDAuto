extends RefCounted
## Walks the repo, runs the lint and builds the report. Used by run_lint.gd and by
## tests/integration/lint/repo_lint_test.gd.
##
## Report keys:
##   findings   Array[Dictionary]  sorted by path, line, rule
##   coverage   PackedStringArray  per rule: "<RULE>: N files", "pending: ...", "not assessed: ..."
##   errors     PackedStringArray  structural failures (empty scan, too many exceptions)
##   scanned    int                .gd and .tscn files checked under src/, tests/, tools/
##   scanned_src_gd  int           .gd files checked under src/

const Rules := preload("res://tools/lint/lint_rules.gd")
const LintEngine := preload("res://tools/lint/lint_engine.gd")
const Scope := preload("res://tools/lint/lint_scope.gd")

const CHECKED_ROOTS: Array[String] = ["res://src", "res://tests", "res://tools"]
const INDEX_ONLY_ROOTS: Array[String] = ["res://addons"]
const PROJECT_FILES: Array[String] = ["res://project.godot", "res://export_presets.cfg"]


## Reads the repo and lints it.
func run() -> Dictionary:
	var sources: Dictionary = {}
	for root in CHECKED_ROOTS:
		_walk(root, sources, true)
	for root in INDEX_ONLY_ROOTS:
		_walk(root, sources, false)
	var project_files: Dictionary = {}
	for project_file in PROJECT_FILES:
		if FileAccess.file_exists(project_file):
			project_files[project_file] = FileAccess.get_file_as_string(project_file)
	return run_on(sources, project_files)


## Lints in-memory sources. sources: res path to text for .gd and .tscn files (files under
## addons/ are used for the class index only). project_files: project.godot and
## export_presets.cfg text.
func run_on(sources: Dictionary, project_files: Dictionary, options: Dictionary = {}) -> Dictionary:
	var everything: Dictionary = sources.duplicate()
	everything.merge(project_files)
	var index: Dictionary = LintEngine.build_index(everything)
	var findings: Array[Dictionary] = []
	var checked: Array[String] = []
	for key in sources:
		var path: String = key
		if not _is_checked(path):
			continue
		checked.append(path)
		findings.append_array(LintEngine.check_source(path, str(sources[path]), index, options))
	findings.append_array(LintEngine.check_project(everything, options))
	findings.sort_custom(_before)
	var scanned_src_gd: int = 0
	for path in checked:
		if path.begins_with("res://src/") and path.get_extension() == "gd":
			scanned_src_gd += 1
	var errors: PackedStringArray = PackedStringArray()
	if scanned_src_gd == 0:
		errors.append("scanned no .gd file under res://src/ (an empty scan is a failure, never a pass)")
	if Rules.FILE_EXCEPTIONS.size() > Rules.MAX_FILE_EXCEPTIONS:
		errors.append("FILE_EXCEPTIONS has %d rows; the budget is %d (reopen ADR-0007)" % [Rules.FILE_EXCEPTIONS.size(), Rules.MAX_FILE_EXCEPTIONS])
	for row: Dictionary in Rules.FILE_EXCEPTIONS:
		if not Rules.RULES.has(row.get("rule", "")) or str(row.get("adr", "")) == "" or str(row.get("file", "")) == "":
			errors.append("FILE_EXCEPTIONS row is missing its rule, file or ADR: %s" % str(row))
	return {
		"findings": findings,
		"coverage": _coverage(checked, index, project_files, options),
		"errors": errors,
		"scanned": checked.size(),
		"scanned_src_gd": scanned_src_gd,
	}


## One line per finding: "<res path>:<line>: <RULE> <message>".
func format_findings(findings: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f in findings:
		out.append("%s:%d: %s %s" % [f["path"], f["line"], f["rule"], f["message"]])
	return out


func _coverage(checked: Array[String], index: Dictionary, project_files: Dictionary, options: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var include_pending: bool = bool(options.get("include_pending", false))
	for key in Rules.RULES:
		var id: String = key
		var spec: Dictionary = Rules.RULES[id]
		var pending: String = str(spec["pending"])
		if pending != "" and not include_pending:
			lines.append("pending: %s (%s)" % [id, pending])
			continue
		var missing: PackedStringArray = Scope.missing_names(id, index)
		for gap in missing:
			lines.append("not assessed: %s %s" % [id, gap])
		var count: int = 0
		if str(spec["ext"]) == "project":
			if id.begins_with("PROJ-6") or id.begins_with("PROJ-7"):
				count = 1 if project_files.has("res://export_presets.cfg") else 0
			else:
				count = 1 if project_files.has("res://project.godot") else 0
				if count == 0:
					lines.append("not assessed: %s res://project.godot absent" % id)
					continue
		else:
			for path in checked:
				if Scope.in_scope(id, path, index):
					count += 1
		if missing.is_empty() or count > 0:
			lines.append("%s: %d in-scope files" % [id, count])
	return lines


func _walk(dir_path: String, sources: Dictionary, with_scenes: bool) -> void:
	for file_name in DirAccess.get_files_at(dir_path):
		var ext: String = file_name.get_extension()
		if ext == "gd" or (with_scenes and ext == "tscn"):
			var full: String = dir_path + "/" + file_name
			sources[full] = FileAccess.get_file_as_string(full)
	for sub in DirAccess.get_directories_at(dir_path):
		if sub.begins_with("."):
			continue
		_walk(dir_path + "/" + sub, sources, with_scenes)


func _is_checked(path: String) -> bool:
	for root in CHECKED_ROOTS:
		if path.begins_with(root + "/"):
			return true
	return false


func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["path"] != b["path"]:
		return str(a["path"]) < str(b["path"])
	if a["line"] != b["line"]:
		return int(a["line"]) < int(b["line"])
	return str(a["rule"]) < str(b["rule"])
