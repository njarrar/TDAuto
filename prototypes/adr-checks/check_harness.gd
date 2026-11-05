# PROTOTYPE - NOT FOR PRODUCTION. ADR checks: harness facts.
# Covers the headless parts of ADR-0007 V6: PCRE2 lookbehind with
# show_error, DirAccess over a nested res:// tree, ClassDB.class_exists for
# every class_name found in docs/architecture/adr-*.md at run time, and the
# `[connection signal=` token (saved by ResourceSaver, not by the editor).
# The ADR files are read from the repo: this folder must sit at
# <repo>/prototypes/adr-checks/ for the scan to find them.
# Not covered: ADR-0007 V2 (needs gdUnit4); the editor save and the
# main-project .godot/ scan of V6 (need the editor and the main project).
# Run: godot --headless --path . -s res://check_harness.gd
extends SceneTree

const Report := preload("res://types/report.gd")

var _r: Report = Report.new()


func _initialize() -> void:
	_regex()
	_dir_access()
	_class_names()
	_connection_token()
	_r.finish(self, "check_harness.gd")


func _regex() -> void:
	var re: RegEx = RegEx.create_from_string("(?<![\\w.])floor\\s*\\(", true)
	var valid: bool = re != null and re.is_valid()
	var hits: Array = []
	for text in ["floor(x)", "math.floor(x)", ".floor(", "floorf(x)", "a = floor (x)"]:
		hits.append(valid and re.search(text) != null)
	_r.check("ADR-0007-V6-regex", valid and hits == [true, false, false, false, true], "valid=%s matches for floor(x), math.floor(x), .floor(, floorf(x), floor (x): %s" % [valid, hits], "[true, false, false, false, true]")


func _walk(path: String, out: PackedStringArray) -> void:
	var d: DirAccess = DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		out.append(path.path_join(f))
	for sub in d.get_directories():
		_walk(path.path_join(sub), out)


func _dir_access() -> void:
	var files: PackedStringArray = PackedStringArray()
	_walk("res://types", files)
	var ok: bool = files.has("res://types/probes/probe_base.gd") and files.has("res://types/report.gd")
	_r.check("ADR-0007-V6-dir-access", ok, "%d files under res://types, nested probe found=%s" % [files.size(), files.has("res://types/probes/probe_base.gd")], "nested res:// tree listed headless")


func _class_names() -> void:
	var docs: String = ProjectSettings.globalize_path("res://").path_join("../../docs/architecture").simplify_path()
	if not DirAccess.dir_exists_absolute(docs):
		_r.check("ADR-0007-V6-classdb-scan", false, "ADR folder not found at %s" % docs, "docs/architecture found two levels up")
		return
	var re: RegEx = RegEx.create_from_string("class_name\\s+([A-Z][A-Za-z0-9_]*)")
	var names: Array = []
	var files: int = 0
	for f in DirAccess.get_files_at(docs):
		if not (f.begins_with("adr-") and f.ends_with(".md")):
			continue
		files += 1
		var text: String = FileAccess.get_file_as_string(docs.path_join(f))
		for m in re.search_all(text):
			var n: String = m.get_string(1)
			if not names.has(n):
				names.append(n)
	names.sort()
	_r.record("ADR-0007-V6-classdb-scan", "%d names from %d ADR files" % [names.size(), files], "record")
	for n in names:
		var exists: bool = ClassDB.class_exists(n)
		_r.check("ADR-0007-V6-classdb-" + str(n), not exists, "class_exists=%s" % exists, "false (no engine class of that name)")
	for n in ["Node", "Input", "Engine"]:
		var exists2: bool = ClassDB.class_exists(n)
		_r.check("ADR-0007-V6-classdb-control-" + n, exists2, "class_exists=%s" % exists2, "true (control)")


func _connection_token() -> void:
	var root: Node = Node.new()
	root.name = "R"
	var child: Node = Node.new()
	child.name = "C"
	root.add_child(child)
	child.owner = root
	child.renamed.connect(root.update_configuration_warnings, CONNECT_PERSIST)
	var ps: PackedScene = PackedScene.new()
	var perr: int = ps.pack(root)
	DirAccess.make_dir_recursive_absolute("user://adr_checks")
	var path: String = "user://adr_checks/conn.tscn"
	var serr: int = ResourceSaver.save(ps, path)
	var text: String = FileAccess.get_file_as_string(path)
	var found: bool = text.contains("[connection signal=")
	_r.check("ADR-0007-V6-connection-token", found, "pack=%s save=%s token found=%s" % [error_string(perr), error_string(serr), found], "a line starting [connection signal= (ResourceSaver headless; editor save not run)")
	root.free()
	DirAccess.remove_absolute(path)
