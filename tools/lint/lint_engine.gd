extends RefCounted
## Public API of the layer lint (pure: no file access).
##
## A finding is {rule: StringName, path: String, line: int, message: String}.
## Rules and scopes: lint_rules.gd, mirroring docs/architecture/adr-0007-lint-rules.md.

const Rules := preload("res://tools/lint/lint_rules.gd")
const Scope := preload("res://tools/lint/lint_scope.gd")
const Check := preload("res://tools/lint/lint_check.gd")


## Builds the class index from every source: a Dictionary of res path to text. Keys:
##   files          path -> true, every path given
##   classes        class_name -> Array of {path, line}
##   class_area     class_name -> "src" | "tests" | "tools" | "addons"
##   class_layer    class_name -> layer number (src only)
##   class_module   class_name -> feature module folder ("" when none)
##   class_of_file  path -> its class_name
##   enums          enum name -> true (src only)
##   init_required  class_name -> true when its _init has a parameter without a default
##   emitter_files  path -> true for the files of the battle emitter classes
##   battle_signals signal name -> true, read from the wiring contract file when present
static func build_index(sources: Dictionary) -> Dictionary:
	var files: Dictionary = {}
	var classes: Dictionary = {}
	var class_area: Dictionary = {}
	var class_layer: Dictionary = {}
	var class_module: Dictionary = {}
	var class_of_file: Dictionary = {}
	var enums: Dictionary = {}
	var init_required: Dictionary = {}
	var class_re: RegEx = RegEx.create_from_string(r"(?m)^class_name\s+(\w+)", true)
	var enum_re: RegEx = RegEx.create_from_string(r"(?m)^\s*enum\s+(\w+)", true)
	var init_re: RegEx = RegEx.create_from_string(r"(?m)^func\s+_init\s*\(([^)]*)\)", true)
	for key in sources:
		var path: String = key
		files[path] = true
		if path.get_extension() != "gd":
			continue
		var text: String = sources[path]
		var area: String = _area_of(path)
		var cm: RegExMatch = class_re.search(text)
		var cls: String = ""
		if cm != null:
			cls = cm.get_string(1)
			var line_no: int = text.substr(0, cm.get_start()).count("\n") + 1
			if not classes.has(cls):
				classes[cls] = []
			classes[cls].append({"path": path, "line": line_no})
			if not class_area.has(cls):
				class_area[cls] = area
				class_layer[cls] = Scope.layer_of(path)
				class_module[cls] = Scope.module_of(path)
			class_of_file[path] = cls
		if area == "src":
			for em: RegExMatch in enum_re.search_all(text):
				enums[em.get_string(1)] = true
		if cls != "" and (area == "src" or area == "tests"):
			var im: RegExMatch = init_re.search(text)
			if im != null and _has_required_param(im.get_string(1)):
				init_required[cls] = true
	var emitter_files: Dictionary = {}
	for emitter_class in Rules.EMITTER_CLASSES:
		if classes.has(emitter_class):
			for entry in classes[emitter_class]:
				emitter_files[entry["path"]] = true
	var battle_signals: Dictionary = {}
	if sources.has(Rules.CONTRACT_PATH):
		var contract: String = sources[Rules.CONTRACT_PATH]
		var key_re: RegEx = RegEx.create_from_string(r"[\x22\x27]([a-z_0-9]+)\.([a-z_0-9]+)[\x22\x27]\s*:", true)
		for km: RegExMatch in key_re.search_all(contract):
			battle_signals[km.get_string(2)] = true
	return {
		"files": files,
		"classes": classes,
		"class_area": class_area,
		"class_layer": class_layer,
		"class_module": class_module,
		"class_of_file": class_of_file,
		"enums": enums,
		"init_required": init_required,
		"emitter_files": emitter_files,
		"battle_signals": battle_signals,
	}


## Runs every active rule on one file. options: {"include_pending": bool} switches on
## the rules that wait on another ADR (the self-tests use it).
static func check_source(res_path: String, text: String, index: Dictionary, options: Dictionary = {}) -> Array[Dictionary]:
	var checker: RefCounted = Check.new(res_path, text, index, bool(options.get("include_pending", false)))
	return checker.run()


## Checks project.godot and export_presets.cfg. files: res path -> text. The keys also
## say which other files exist (PROJ-2 looks for the main scene).
static func check_project(files: Dictionary, options: Dictionary = {}) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if files.has("res://project.godot"):
		var ini: Dictionary = parse_ini(str(files["res://project.godot"]))
		_check_project_godot(ini, files, findings)
		if _active("PROJ-8", options):
			_check_renderer(ini, findings)
	if files.has("res://export_presets.cfg"):
		_check_presets(parse_ini(str(files["res://export_presets.cfg"])), findings)
	return findings


## Parses Godot ini text. Returns {section: {key: {"value": String, "line": int}}}.
## Each section also holds "__line__" (the header line) as {"value": "", "line": n}.
static func parse_ini(text: String) -> Dictionary:
	var result: Dictionary = {}
	var section: String = ""
	var phys: PackedStringArray = text.split("\n")
	for i in phys.size():
		var raw: String = phys[i].strip_edges()
		if raw == "" or raw.begins_with(";"):
			continue
		if raw.begins_with("[") and raw.ends_with("]"):
			section = raw.substr(1, raw.length() - 2)
			if not result.has(section):
				result[section] = {"__line__": {"value": "", "line": i + 1}}
			continue
		var eq: int = raw.find("=")
		if eq < 0 or section == "":
			continue
		var key: String = raw.substr(0, eq).strip_edges()
		var value: String = raw.substr(eq + 1).strip_edges()
		var table: Dictionary = result[section]
		table[key] = {"value": value, "line": i + 1}
	return result


static func _check_project_godot(ini: Dictionary, files: Dictionary, findings: Array[Dictionary]) -> void:
	var path: String = "res://project.godot"
	if ini.has("autoload"):
		_pfind(findings, "PROJ-1", path, _section_line(ini, "autoload"), "project.godot has an [autoload] section")
	if files.has(Rules.PROJ2_SCENE):
		var main: String = _value(ini, "application", "run/main_scene")
		if main != "\"%s\"" % Rules.PROJ2_SCENE:
			_pfind(findings, "PROJ-2", path, _key_line(ini, "application", "run/main_scene"), "[application] run/main_scene must be \"%s\" (found %s)" % [Rules.PROJ2_SCENE, main if main != "" else "nothing"])
	for row in Rules.PROJ3_KEYS:
		var found: String = _value(ini, str(row[0]), str(row[1]))
		if found != str(row[2]):
			_pfind(findings, "PROJ-3", path, _key_line(ini, str(row[0]), str(row[1])), "[%s] %s must be %s (found %s)" % [row[0], row[1], row[2], found if found != "" else "nothing"])
	if _value(ini, "application", "run/delta_smoothing") != "false":
		_pfind(findings, "PROJ-4", path, _key_line(ini, "application", "run/delta_smoothing"), "[application] run/delta_smoothing must be false")
	if _value(ini, "application", "run/low_processor_mode") == "true":
		_pfind(findings, "PROJ-4", path, _key_line(ini, "application", "run/low_processor_mode"), "[application] run/low_processor_mode must not be true")
	for key in ["report/godot/push_error", "report/verbose_orphans"]:
		if _value(ini, "gdunit4", key) != "true":
			_pfind(findings, "PROJ-5", path, _key_line(ini, "gdunit4", key), "[gdunit4] %s must be true" % key)
	if _value(ini, "gdunit4", "report/godot/script_error") == "false":
		_pfind(findings, "PROJ-5", path, _key_line(ini, "gdunit4", "report/godot/script_error"), "[gdunit4] report/godot/script_error must not be false")


## True if the rule runs: it is not pending, or options asks for pending rules too.
static func _active(rule: String, options: Dictionary) -> bool:
	return str(Rules.RULES[rule]["pending"]) == "" or bool(options.get("include_pending", false))


## PROJ-8 (ADR-0012 Decisions 1, 5): Mobile renderer with no other override, the
## auto-fallback off, and the 60 fps cap. The fallback key is ADR-0012's believed name
## (NEEDS VERIFICATION, R2). The export-preset leg waits for R5 to name the baker key.
static func _check_renderer(ini: Dictionary, findings: Array[Dictionary]) -> void:
	var path: String = "res://project.godot"
	if _value(ini, "rendering", "renderer/rendering_method") != "\"mobile\"":
		_pfind(findings, "PROJ-8", path, _key_line(ini, "rendering", "renderer/rendering_method"), "[rendering] renderer/rendering_method must be \"mobile\"")
	if ini.has("rendering"):
		var table: Dictionary = ini["rendering"]
		for key in table:
			if str(key).begins_with("renderer/rendering_method.") and str(table[key]["value"]) != "\"mobile\"":
				_pfind(findings, "PROJ-8", path, int(table[key]["line"]), "[rendering] %s must be \"mobile\" (found %s)" % [key, table[key]["value"]])
	if _value(ini, "rendering", "rendering_device/fallback_to_opengl3") != "false":
		_pfind(findings, "PROJ-8", path, _key_line(ini, "rendering", "rendering_device/fallback_to_opengl3"), "[rendering] rendering_device/fallback_to_opengl3 must be false")
	if _value(ini, "application", "run/max_fps") != "60":
		_pfind(findings, "PROJ-8", path, _key_line(ini, "application", "run/max_fps"), "[application] run/max_fps must be 60")


static func _check_presets(ini: Dictionary, findings: Array[Dictionary]) -> void:
	var path: String = "res://export_presets.cfg"
	var preset_re: RegEx = RegEx.create_from_string(r"^preset\.\d+$", true)
	for section in ini:
		if preset_re.search(str(section)) == null:
			continue
		var include_filter: String = _value(ini, str(section), "include_filter")
		if not include_filter.contains("*.json"):
			_pfind(findings, "PROJ-6", path, _key_line(ini, str(section), "include_filter"), "[%s] include_filter must contain *.json" % section)
		var exclude_filter: String = _value(ini, str(section), "exclude_filter")
		for needed in Rules.PROJ7_EXCLUDES:
			if not exclude_filter.contains(needed):
				_pfind(findings, "PROJ-7", path, _key_line(ini, str(section), "exclude_filter"), "[%s] exclude_filter must contain %s" % [section, needed])


static func _value(ini: Dictionary, section: String, key: String) -> String:
	if not ini.has(section):
		return ""
	var table: Dictionary = ini[section]
	if not table.has(key):
		return ""
	return str(table[key]["value"])


static func _key_line(ini: Dictionary, section: String, key: String) -> int:
	if not ini.has(section):
		return 1
	var table: Dictionary = ini[section]
	if table.has(key):
		return int(table[key]["line"])
	return _section_line(ini, section)


static func _section_line(ini: Dictionary, section: String) -> int:
	if not ini.has(section):
		return 1
	var table: Dictionary = ini[section]
	return int(table["__line__"]["line"])


static func _pfind(findings: Array[Dictionary], rule: String, path: String, line_no: int, message: String) -> void:
	findings.append({"rule": StringName(rule), "path": path, "line": line_no, "message": message})


static func _area_of(path: String) -> String:
	for area in ["src", "tests", "tools", "addons", "prototypes"]:
		if path.begins_with("res://%s/" % area):
			return area
	return ""


static func _has_required_param(raw_params: String) -> bool:
	var params: String = ""
	for physical in raw_params.split("\n"):
		params += physical.get_slice("#", 0) + " "
	var depth: int = 0
	var current: String = ""
	var parts: PackedStringArray = PackedStringArray()
	for i in params.length():
		var c: String = params[i]
		if c == "(" or c == "[" or c == "{":
			depth += 1
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
		if c == "," and depth == 0:
			parts.append(current)
			current = ""
		else:
			current += c
	parts.append(current)
	for part in parts:
		var stripped: String = part.strip_edges()
		if stripped == "":
			continue
		if not stripped.contains("="):
			return true
	return false
