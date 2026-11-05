extends RefCounted
## Scope helpers for the layer lint (pure, no file access).

const Rules := preload("res://tools/lint/lint_rules.gd")


## True when path matches an entry: a folder prefix ending in "/", a full res:// path,
## or a bare file name.
static func path_matches(path: String, entry: String) -> bool:
	if entry.ends_with("/"):
		return path.begins_with(entry)
	if entry.begins_with("res://"):
		return path == entry
	return path.get_file() == entry


static func matches_any(path: String, entries: Array) -> bool:
	for entry in entries:
		if path_matches(path, str(entry)):
			return true
	return false


## Layer number of a src path: 0 to 4, -1 when under src/ but outside the five
## layer folders, -2 when not under src/.
static func layer_of(path: String) -> int:
	var prefix: String = "res://src/"
	if not path.begins_with(prefix):
		return -2
	var rest: String = path.substr(prefix.length())
	if not rest.contains("/"):
		return -1
	var seg: String = rest.get_slice("/", 0)
	if Rules.LAYERS.has(seg):
		return int(Rules.LAYERS[seg])
	return -1


## Feature module folder of a src/feature path, "" otherwise.
static func module_of(path: String) -> String:
	var prefix: String = "res://src/feature/"
	if not path.begins_with(prefix):
		return ""
	var rest: String = path.substr(prefix.length())
	if not rest.contains("/"):
		return ""
	return rest.get_slice("/", 0)


static func is_sim(path: String) -> bool:
	if Rules.SIM_FILES.has(path):
		return true
	for prefix in Rules.SIM_PREFIXES:
		if path.begins_with(prefix):
			return true
	return false


static func is_battle(path: String) -> bool:
	if not path.begins_with("res://src/"):
		return false
	if Rules.NON_BATTLE_FILES.has(path):
		return false
	for prefix in Rules.NON_BATTLE_PREFIXES:
		if path.begins_with(prefix):
			return false
	return true


## True when the rule's scope, extension, only and exclude fields all admit the file.
## Project-file rules are not file scoped and always return false here.
static func in_scope(id: String, path: String, index: Dictionary) -> bool:
	var spec: Dictionary = Rules.RULES[id]
	var exts: PackedStringArray = str(spec["ext"]).split(",")
	if exts.has("project"):
		return false
	if not exts.has(path.get_extension()):
		return false
	var admitted: bool = _scope_ok(str(spec["scope"]), spec, path, index)
	if not admitted:
		var also: Array = spec.get("also", [])
		admitted = matches_any(path, also)
	if not admitted:
		return false
	var only: Array = spec.get("only", [])
	if not only.is_empty() and not matches_any(path, only):
		return false
	var exclude: Array = spec.get("exclude", [])
	if matches_any(path, exclude):
		return false
	return true


## Names a rule needs that the scan did not find ("<file> absent" or "class <X> absent").
static func missing_names(id: String, index: Dictionary) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	var spec: Dictionary = Rules.RULES[id]
	var files: Dictionary = index.get("files", {})
	var classes: Dictionary = index.get("classes", {})
	var named: Array = spec.get("named", [])
	for entry in named:
		var found: bool = false
		for file_path in files:
			if path_matches(str(file_path), str(entry)):
				found = true
				break
		if not found:
			missing.append("%s absent" % str(entry))
	var named_classes: Array = spec.get("named_classes", [])
	for cls in named_classes:
		if not classes.has(str(cls)):
			missing.append("class %s absent" % str(cls))
	return missing


static func _scope_ok(scope: String, spec: Dictionary, path: String, index: Dictionary) -> bool:
	match scope:
		"src":
			return path.begins_with("res://src/")
		"src_presentation":
			return path.begins_with("res://src/presentation/")
		"sim":
			return is_sim(path)
		"battle":
			return is_battle(path)
		"tests":
			return path.begins_with("res://tests/")
		"tests_unit":
			return path.begins_with("res://tests/unit/")
		"tests_tools":
			return path.begins_with("res://tests/") or path.begins_with("res://tools/")
		"src_tests":
			return path.begins_with("res://src/") or path.begins_with("res://tests/")
		"scan":
			return path.begins_with("res://src/") or path.begins_with("res://tests/") or path.begins_with("res://tools/")
		"emitters":
			return _emitter_files(index).has(path)
		"emitter_or_sim":
			return is_sim(path) or _emitter_files(index).has(path)
		"classes":
			var of_file: Dictionary = index.get("class_of_file", {})
			var wanted: Array = spec.get("classes", [])
			return of_file.has(path) and wanted.has(of_file[path])
	return false


static func _emitter_files(index: Dictionary) -> Dictionary:
	return index.get("emitter_files", {})
