extends RefCounted
## Runs every lint rule on one .gd or .tscn file. One instance per file; pure.
##
## Findings are dictionaries: {rule: StringName, path: String, line: int, message: String}.

const Rules := preload("res://tools/lint/lint_rules.gd")
const Lexer := preload("res://tools/lint/lint_lexer.gd")
const Scope := preload("res://tools/lint/lint_scope.gd")

const MEMBER_PATTERN: String = r"^(?:@\w+(?:\([^)]*\))?\s+)*"
const REF_CLASS_PATTERN: String = r"\b[A-Z][A-Za-z0-9_]*\b"

var path: String = ""
var text: String = ""
var index: Dictionary = {}
var include_pending: bool = false
var findings: Array[Dictionary] = []

var _is_gd: bool = false
var _masked: String = ""
var _strings: Array[Dictionary] = []
var _lines: Array[Dictionary] = []
var _own_class: String = ""
var _own_class_line: int = 1
var _layer: int = -2
var _regex_cache: Dictionary = {}


func _init(p_path: String, p_text: String, p_index: Dictionary, p_include_pending: bool = false) -> void:
	path = p_path
	text = p_text
	index = p_index
	include_pending = p_include_pending


## Runs every active rule whose scope admits this file and returns the findings.
func run() -> Array[Dictionary]:
	_is_gd = path.get_extension() == "gd"
	_layer = Scope.layer_of(path)
	if _is_gd:
		var lexed: Dictionary = Lexer.lex(text)
		_masked = lexed["masked"]
		_strings = lexed["strings"]
		_lines = Lexer.logical_lines(_masked)
		var decl: RegExMatch = null
		for ln: Dictionary in _lines:
			decl = _re(r"^class_name\s+(\w+)").search(ln["text"])
			if decl != null:
				_own_class = decl.get_string(1)
				_own_class_line = ln["line"]
				break
	else:
		var phys: PackedStringArray = text.split("\n")
		for i in phys.size():
			_lines.append({"line": i + 1, "text": phys[i].rstrip("\r"), "indent": 0, "func": "", "is_def": false})
	for key in Rules.RULES:
		var id: String = key
		var spec: Dictionary = Rules.RULES[id]
		if str(spec["pending"]) != "" and not include_pending:
			continue
		if not Scope.in_scope(id, path, index):
			continue
		_run_rule(id, spec)
	return findings


func _run_rule(id: String, spec: Dictionary) -> void:
	match id:
		"LAYER-1", "LAYER-2", "LAYER-4":
			_layer_refs(id)
		"LAYER-3":
			_layer_three(id)
		"LAYER-5":
			_layer_five(id)
		"NAME-1":
			_name_one(id)
		"NAME-2":
			_name_two(id)
		"NAME-3":
			_name_three(id)
		"NAME-4":
			_name_four(id)
		"NAME-5":
			_name_five(id)
		"WIRE-4":
			_wire_four(id)
		"WIRE-5":
			_wire_five(id)
		"WIRE-6":
			_wire_six(id)
		"WIRE-7":
			_wire_seven(id)
		"WIRE-8":
			_wire_eight(id)
		"WIRE-9":
			_wire_nine(id)
		"WIRE-10":
			_wire_ten(id)
		"STATE-8":
			_state_eight(id)
		"STATE-9":
			_state_nine(id)
		"STAT-1":
			_stat_one(id)
		"REND-2":
			_rend_two(id)
		"REND-3":
			_rend_three(id)
		"INIT-1":
			_init_one(id)
		"TEST-2":
			_generic(id, spec)
			_test_two_paths(id)
		"TEST-4":
			_test_four(id)
		"TEST-6":
			_test_six(id)
		_:
			_generic(id, spec)


# ---------------------------------------------------------------------------
# Generic pattern rules
# ---------------------------------------------------------------------------

func _generic(id: String, spec: Dictionary) -> void:
	var msg: String = str(spec.get("msg", id))
	var skip_def: bool = bool(spec.get("skip_def", false))
	if _is_gd:
		var any_patterns: Array = spec.get("re", [])
		var member_patterns: Array = spec.get("re_member", [])
		for ln: Dictionary in _lines:
			var t: String = ln["text"]
			var line_no: int = ln["line"]
			for pattern in any_patterns:
				_scan_line(id, msg, line_no, t, str(pattern), skip_def)
			if int(ln["indent"]) == 0:
				for pattern in member_patterns:
					_scan_line(id, msg, line_no, t, str(pattern), skip_def)
		var string_patterns: Array = spec.get("string_re", [])
		for tok: Dictionary in _strings:
			for pattern in string_patterns:
				var sm: RegExMatch = _re(str(pattern)).search(str(tok["content"]))
				if sm != null:
					_add(id, tok["line"], "%s: %s" % [msg, sm.get_string()])
	else:
		var scene_patterns: Array = spec.get("tscn_re", [])
		for ln: Dictionary in _lines:
			for pattern in scene_patterns:
				_scan_line(id, msg, ln["line"], ln["text"], str(pattern), false)


func _scan_line(id: String, msg: String, line_no: int, t: String, pattern: String, skip_def: bool) -> void:
	for m: RegExMatch in _re(pattern).search_all(t):
		var hit: String = m.get_string()
		if skip_def and _preceded_by_func(t, m.get_start()):
			continue
		if _excepted(id, hit):
			continue
		_add(id, line_no, "%s: %s" % [msg, hit.strip_edges()])


# ---------------------------------------------------------------------------
# LAYER
# ---------------------------------------------------------------------------

func _layer_refs(id: String) -> void:
	for ref: Dictionary in _collect_refs():
		var area: String = ref["area"]
		var what: String = ref["what"]
		if id == "LAYER-1":
			if _layer >= 0 and area == "src" and int(ref["layer"]) > _layer:
				_add(id, ref["line"], "references %s in a higher layer" % what)
		elif id == "LAYER-2":
			var other: String = ref["module"]
			var mine: String = Scope.module_of(path)
			if _layer == 2 and area == "src" and int(ref["layer"]) == 2 and other != "" and mine != "" and other != mine:
				_add(id, ref["line"], "references %s in feature module %s" % [what, other])
		elif id == "LAYER-4":
			if area == "addons" or area == "tests" or area == "tools" or area == "prototypes":
				_add(id, ref["line"], "references %s under %s/" % [what, area])


## Collects references to project classes and res:// paths. Each entry:
## line, what, area (src, tests, tools, addons, prototypes), layer, module.
func _collect_refs() -> Array[Dictionary]:
	var refs: Array[Dictionary] = []
	var class_area: Dictionary = index.get("class_area", {})
	var class_layer: Dictionary = index.get("class_layer", {})
	var class_module: Dictionary = index.get("class_module", {})
	if _is_gd:
		var locals: Dictionary = _local_names()
		for ln: Dictionary in _lines:
			for m: RegExMatch in _re(REF_CLASS_PATTERN).search_all(ln["text"]):
				var name: String = m.get_string()
				if name == _own_class or locals.has(name) or not class_area.has(name):
					continue
				refs.append({
					"line": ln["line"],
					"what": name,
					"area": class_area[name],
					"layer": int(class_layer.get(name, -2)),
					"module": str(class_module.get(name, "")),
				})
		for tok: Dictionary in _strings:
			var content: String = tok["content"]
			if not content.begins_with("res://"):
				continue
			var ctx: String = _masked.substr(maxi(0, int(tok["start"]) - 40), mini(40, int(tok["start"]))).strip_edges()
			if ctx.ends_with("preload(") or ctx.ends_with("load(") or ctx.ends_with("extends"):
				refs.append(_path_ref(tok["line"], content))
	else:
		for ln: Dictionary in _lines:
			var pm: RegExMatch = _re(r"^\[ext_resource [^\]]*\bpath=\x22(res://[^\x22]+)\x22").search(ln["text"])
			if pm != null:
				refs.append(_path_ref(ln["line"], pm.get_string(1)))
	return refs


func _path_ref(line_no: int, ref_path: String) -> Dictionary:
	var area: String = ""
	for candidate in ["src", "tests", "tools", "addons", "prototypes"]:
		if ref_path.begins_with("res://%s/" % candidate):
			area = candidate
	return {
		"line": line_no,
		"what": ref_path,
		"area": area,
		"layer": Scope.layer_of(ref_path),
		"module": Scope.module_of(ref_path),
	}


func _local_names() -> Dictionary:
	var names: Dictionary = {}
	for ln: Dictionary in _lines:
		var m: RegExMatch = _re(r"^(?:class|enum)\s+(\w+)").search(ln["text"])
		if m != null:
			names[m.get_string(1)] = true
	return names


func _layer_three(id: String) -> void:
	if _layer == -1:
		_add(id, 1, "file is outside the five layer folders")


func _layer_five(id: String) -> void:
	for tok: Dictionary in _strings:
		if str(tok["content"]).contains("uid://"):
			_add(id, tok["line"], "uid:// path in src")


# ---------------------------------------------------------------------------
# NAME
# ---------------------------------------------------------------------------

func _name_one(id: String) -> void:
	if _own_class == "":
		return
	var classes: Dictionary = index.get("classes", {})
	var entries: Array = classes.get(_own_class, [])
	if entries.size() < 2:
		return
	for entry in entries:
		var other: Dictionary = entry
		if other["path"] != path:
			_add(id, _own_class_line, "class_name %s is also declared in %s" % [_own_class, other["path"]])


func _name_two(id: String) -> void:
	if _own_class == "":
		return
	if ClassDB.class_exists(_own_class) or Engine.has_singleton(_own_class) or Rules.VARIANT_NAMES.has(_own_class):
		_add(id, _own_class_line, "class_name %s is an engine name" % _own_class)


func _name_three(id: String) -> void:
	if _own_class != "":
		_add(id, _own_class_line, "class_name %s declared outside src" % _own_class)


func _name_four(id: String) -> void:
	if _own_class == "":
		return
	var expected: String = pascal_case(path.get_file().get_basename())
	if expected != _own_class:
		_add(id, _own_class_line, "class_name %s should be %s for file %s" % [_own_class, expected, path.get_file()])


func _name_five(id: String) -> void:
	for ln: Dictionary in _lines:
		var t: String = ln["text"]
		var m: RegExMatch = _re(r"\b(?:func|var|const|for)\s+(?:load|seed)\b").search(t)
		if m != null:
			_add(id, ln["line"], "name shadows a global function: %s" % m.get_string())
		if t.begins_with("func") or t.begins_with("static func"):
			var pm: RegExMatch = _re(r"[(,]\s*(?:load|seed)\s*(?::|,|\)|=)").search(t)
			if pm != null:
				_add(id, ln["line"], "parameter shadows a global function: %s" % pm.get_string().strip_edges())


## PascalCase of a snake_case file name.
static func pascal_case(snake: String) -> String:
	var out: String = ""
	for part in snake.split("_"):
		if part.is_empty():
			continue
		out += part.substr(0, 1).to_upper() + part.substr(1)
	return out


# ---------------------------------------------------------------------------
# WIRE
# ---------------------------------------------------------------------------

func _wire_four(id: String) -> void:
	var whole_file: bool = Scope.matches_any(path, ["battle_builder.gd", "battle_wrapper.gd"])
	var bind_re: RegEx = _re(r"\.(?:bind|unbind)\s*\(")
	for ln: Dictionary in _lines:
		var t: String = ln["text"]
		if whole_file:
			for m: RegExMatch in bind_re.search_all(t):
				_add(id, ln["line"], "bind or unbind: %s" % m.get_string())
			continue
		for cm: RegExMatch in _re(r"\.connect\s*\(").search_all(t):
			var args: String = _balanced_args(t, cm.get_end() - 1)
			var bm: RegExMatch = bind_re.search(args)
			if bm != null:
				_add(id, ln["line"], "bind or unbind inside connect: %s" % bm.get_string())


func _battle_signals() -> Dictionary:
	return index.get("battle_signals", {})


func _wire_five(id: String) -> void:
	var signals: Dictionary = _battle_signals()
	var whole_file: bool = Scope.matches_any(path, ["battle_builder.gd", "battle_wrapper.gd"])
	for ln: Dictionary in _lines:
		var t: String = ln["text"]
		if whole_file:
			for m: RegExMatch in _re(r"\bCONNECT_\w+").search_all(t):
				_add(id, ln["line"], "%s: %s" % [Rules.RULES[id]["msg"], m.get_string()])
			continue
		for cm: RegExMatch in _re(r"\.(\w+)\.connect\s*\(").search_all(t):
			if not signals.has(cm.get_string(1)):
				continue
			var args: String = _balanced_args(t, cm.get_end() - 1)
			var fm: RegExMatch = _re(r"\bCONNECT_\w+").search(args)
			if fm != null:
				_add(id, ln["line"], "%s on %s: %s" % [Rules.RULES[id]["msg"], cm.get_string(1), fm.get_string()])


func _wire_six(id: String) -> void:
	var signals: Dictionary = _battle_signals()
	for ln: Dictionary in _lines:
		for m: RegExMatch in _re(r"\.(\w+)\.(?:connect|disconnect)\s*\(").search_all(ln["text"]):
			if signals.has(m.get_string(1)):
				_add(id, ln["line"], "battle signal %s connected here" % m.get_string(1))


func _wire_seven(id: String) -> void:
	var signals: Dictionary = _battle_signals()
	for ln: Dictionary in _lines:
		var m: RegExMatch = _re(r"^\[connection\s+signal=\x22(\w+)\x22").search(ln["text"])
		if m != null and signals.has(m.get_string(1)):
			_add(id, ln["line"], "scene connection of battle signal %s" % m.get_string(1))


func _wire_eight(id: String) -> void:
	var signals: Dictionary = _battle_signals()
	var re: RegEx = _re(r"\.(\w+)\.connect\s*\(\s*(?:[A-Za-z_]\w*\.)*([A-Za-z_]\w*)\s*[,)]")
	for ln: Dictionary in _lines:
		for m: RegExMatch in re.search_all(ln["text"]):
			var sig: String = m.get_string(1)
			var method: String = m.get_string(2)
			if signals.has(sig) and method != "on_" + sig and method != "_on_" + sig:
				_add(id, ln["line"], "listener %s for %s should be on_%s or _on_%s" % [method, sig, sig, sig])


func _wire_nine(id: String) -> void:
	var signals: Dictionary = _battle_signals()
	var in_view: bool = path.begins_with("res://src/presentation/") or path.get_file() == "battle_wrapper.gd"
	var commands: String = "|".join(PackedStringArray(Rules.COMMANDS))
	var banned_all: Array[String] = [r"\.tick\s*\(", r"\.deliver\s*\(", r"\.apply_slow\s*\(", r"(?<!\w)(?:" + commands + r")\s*\("]
	var banned_view: Array[String] = [r"\.emit\s*\(", r"\.connect\s*\(", r"\.disconnect\s*\(", r"\brequest_retry\s*\("]
	var banned_stat: Array[String] = [r"\bstat_int\s*\(", r"\bstat_float\s*\("]
	for ln: Dictionary in _lines:
		if bool(ln["is_def"]):
			continue
		var fn: String = ln["func"]
		var sig: String = ""
		if fn.begins_with("on_"):
			sig = fn.substr(3)
		elif fn.begins_with("_on_"):
			sig = fn.substr(4)
		if sig == "" or not signals.has(sig):
			continue
		var checks: Array[String] = []
		if not Rules.GESTURE_SIGNALS.has(sig):
			checks.append_array(banned_all)
		if in_view:
			checks.append_array(banned_view)
		if sig == "attack_fired" or sig == "damage_applied":
			checks.append_array(banned_stat)
		for pattern in checks:
			var m: RegExMatch = _re(pattern).search(ln["text"])
			if m != null:
				_add(id, ln["line"], "listener %s calls %s" % [fn, m.get_string().strip_edges()])


func _wire_ten(id: String) -> void:
	var enums: Dictionary = index.get("enums", {})
	for ln: Dictionary in _lines:
		var m: RegExMatch = _re(r"^signal\s+(\w+)\s*\(").search(ln["text"])
		if m == null:
			continue
		var args: String = _balanced_args(ln["text"], m.get_end() - 1)
		for part in _split_args(args):
			if part.strip_edges() == "":
				continue
			var tm: RegExMatch = _re(r"^\s*\w+\s*:\s*([A-Za-z_][\w.]*)").search(part)
			if tm == null:
				_add(id, ln["line"], "signal %s: parameter '%s' is untyped" % [m.get_string(1), part.strip_edges()])
				continue
			var type_name: String = tm.get_string(1)
			var short_name: String = type_name.get_slice(".", type_name.get_slice_count(".") - 1)
			if not Rules.WIRE10_TYPES.has(type_name) and not enums.has(short_name):
				_add(id, ln["line"], "signal %s: parameter type %s is not allowed" % [m.get_string(1), type_name])


# ---------------------------------------------------------------------------
# STATE and STAT
# ---------------------------------------------------------------------------

func _state_eight(id: String) -> void:
	var markers: Array[String] = [".erase(", ".remove_at(", ".clear(", ".pop_"]
	for i in _lines.size():
		var m: RegExMatch = _re(r"^for\s+\w+(?:\s*:\s*[\w.\[\]]+)?\s+in\s+([A-Za-z_][\w.]*)\s*:").search(_lines[i]["text"])
		if m == null:
			continue
		var coll: String = m.get_string(1)
		var stop: int = Lexer.body_end(_lines, i)
		for j in range(i + 1, stop):
			var body_text: String = _lines[j]["text"]
			for marker in markers:
				if _has_token(body_text, coll + marker):
					_add(id, _lines[j]["line"], "%s changed inside 'for' over it (%s)" % [coll, marker])


func _state_nine(id: String) -> void:
	var names: Array[String] = []
	var decl_re: RegEx = _re(MEMBER_PATTERN + r"var\s+(\w+)\s*:\s*Packed[A-Za-z0-9]*Array\b(.*)$")
	for ln: Dictionary in _lines:
		var m: RegExMatch = decl_re.search(ln["text"])
		if m == null:
			continue
		var tail: String = m.get_string(2).strip_edges()
		if tail.ends_with(":") or _re(r"\bset\s*=").search(tail) != null:
			names.append(m.get_string(1))
	if names.is_empty():
		return
	for member in names:
		var write_re: RegEx = _re(r"(?<![\w.])(?:self\.)?" + member + r"\s*\[[^\]]*\]\s*(?:=(?!=)|[+\-*/]=)")
		for ln: Dictionary in _lines:
			if write_re.search(ln["text"]) != null:
				_add(id, ln["line"], "element write to %s skips its setter" % member)


func _stat_one(id: String) -> void:
	for ln: Dictionary in _lines:
		var t: String = ln["text"]
		for m: RegExMatch in _re(r"\bstat_(?:int|float)\s*\(").search_all(t):
			if _preceded_by_func(t, m.get_start()):
				continue
			var args: PackedStringArray = _split_args(_balanced_args(t, m.get_end() - 1))
			if args.size() >= 2 and not args[1].strip_edges().begins_with("StatKeys."):
				_add(id, ln["line"], "stat key '%s' must start with StatKeys." % args[1].strip_edges())


# ---------------------------------------------------------------------------
# REND
# ---------------------------------------------------------------------------

func _rend_two(id: String) -> void:
	var patterns: Array[String] = [
		r"\bCanvasLayer\b", r"\bz_as_relative\b", r"\btop_level\s*=\s*true\b", r"\bLine2D\b", r"\bPolygon2D\b",
	]
	if not Scope.matches_any(path, Rules.MODAL_SCREEN_PREFIXES):
		patterns.append(r"\bSprite2D\b")
	for ln: Dictionary in _lines:
		var t: String = ln["text"]
		for pattern in patterns:
			var m: RegExMatch = _re(pattern).search(t)
			if m != null:
				_add(id, ln["line"], "layering or drawing node: %s" % m.get_string())
		var zm: RegExMatch = _re(r"\bz_index\s*=(?!=)\s*([^\s#]+)").search(t)
		if zm != null and zm.get_string(1) != "0":
			_add(id, ln["line"], "z_index set to %s" % zm.get_string(1))


func _rend_three(id: String) -> void:
	for ln: Dictionary in _lines:
		if str(ln["func"]) == "attach":
			continue
		var m: RegExMatch = _re(r"\binstantiate\s*\(").search(ln["text"])
		if m != null:
			_add(id, ln["line"], "instantiate outside an attach method")


# ---------------------------------------------------------------------------
# INIT and TEST
# ---------------------------------------------------------------------------

func _init_one(id: String) -> void:
	var required: Dictionary = index.get("init_required", {})
	var base: String = ""
	for ln: Dictionary in _lines:
		if int(ln["indent"]) != 0:
			continue
		var m: RegExMatch = _re(r"(?:^|\s)extends\s+([A-Za-z_]\w*)").search(ln["text"])
		if m != null:
			base = m.get_string(1)
			break
	if base == "" or not bool(required.get(base, false)):
		return
	for i in _lines.size():
		var ln: Dictionary = _lines[i]
		if int(ln["indent"]) != 0 or not str(ln["text"]).begins_with("func _init"):
			continue
		var whole: String = str(ln["text"])
		for j in range(i + 1, Lexer.body_end(_lines, i)):
			whole += " " + str(_lines[j]["text"])
		if _re(r"\bsuper\s*\(").search(whole) == null:
			_add(id, ln["line"], "_init of a subclass of %s must call super(...)" % base)


func _test_two_paths(id: String) -> void:
	for tok: Dictionary in _strings:
		var ctx: String = _masked.substr(maxi(0, int(tok["start"]) - 20), mini(20, int(tok["start"]))).strip_edges()
		if (ctx.ends_with("preload(") or ctx.ends_with("load(")) and not str(tok["content"]).ends_with(".gd"):
			_add(id, tok["line"], "load of a path that is not a script: %s" % tok["content"])


func _test_four(id: String) -> void:
	if not text.contains("baselines"):
		return
	for ln: Dictionary in _lines:
		var m: RegExMatch = _re(r"\bFileAccess\.(?:WRITE|READ_WRITE)\b").search(ln["text"])
		if m != null:
			_add(id, ln["line"], "a file that names baselines writes files: %s" % m.get_string())


func _test_six(id: String) -> void:
	var allowed: Array[String] = ["timeout", "fuzzer_iterations", "fuzzer_seed", "test_parameters"]
	for ln: Dictionary in _lines:
		var m: RegExMatch = _re(r"^(?:static\s+)?func\s+(\w+)\s*\(").search(ln["text"])
		if m == null:
			continue
		var fname: String = m.get_string(1)
		var params: PackedStringArray = _split_args(_balanced_args(ln["text"], m.get_end() - 1))
		var names: Array[String] = []
		for part in params:
			var nm: RegExMatch = _re(r"^\s*(\w+)").search(part)
			names.append(nm.get_string(1) if nm != null else "")
		var has_set: bool = names.has("test_parameters")
		for k in params.size():
			var pname: String = names[k]
			if pname == "":
				continue
			if pname == "do_skip" or pname == "skip_reason":
				_add(id, ln["line"], "%s has the skip parameter %s" % [fname, pname])
			elif fname.begins_with("test_"):
				if allowed.has(pname) or has_set or params[k].contains("Fuzzer"):
					continue
				_add(id, ln["line"], "%s has the unknown parameter %s (gdUnit4 skips it silently)" % [fname, pname])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _add(id: String, line_no: int, message: String) -> void:
	findings.append({"rule": StringName(id), "path": path, "line": line_no, "message": message})


func _re(pattern: String) -> RegEx:
	if _regex_cache.has(pattern):
		return _regex_cache[pattern]
	var compiled: RegEx = RegEx.create_from_string(pattern, true)
	_regex_cache[pattern] = compiled
	return compiled


func _preceded_by_func(t: String, pos: int) -> bool:
	return t.substr(0, pos).strip_edges().ends_with("func")


func _excepted(id: String, hit: String) -> bool:
	for row: Dictionary in Rules.FILE_EXCEPTIONS:
		if str(row["rule"]) != id or not Scope.path_matches(path, str(row["file"])):
			continue
		var allow: Array = row.get("allow", [])
		if allow.is_empty():
			return true
		for prefix in allow:
			if hit.begins_with(str(prefix)):
				return true
	return false


## The text inside the bracket that opens at open_pos (balanced), without the brackets.
func _balanced_args(t: String, open_pos: int) -> String:
	var depth: int = 0
	for i in range(open_pos, t.length()):
		var c: String = t[i]
		if c == "(" or c == "[" or c == "{":
			depth += 1
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
			if depth == 0:
				return t.substr(open_pos + 1, i - open_pos - 1)
	return t.substr(open_pos + 1)


## Splits on commas that are not inside brackets.
func _split_args(s: String) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var current: String = ""
	for i in s.length():
		var c: String = s[i]
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
	return parts


## True when needle occurs in hay and is not the tail of a longer name or member path.
func _has_token(hay: String, needle: String) -> bool:
	var from: int = 0
	while from <= hay.length():
		var p: int = hay.find(needle, from)
		if p < 0:
			return false
		if p == 0 or not (Lexer.is_ident_char(hay[p - 1]) or hay[p - 1] == "."):
			return true
		from = p + 1
	return false
