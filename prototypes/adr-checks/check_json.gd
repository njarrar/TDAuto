# PROTOTYPE - NOT FOR PRODUCTION. ADR checks: JSON.
# Covers ADR-0002 W1 (number typing, NaN and Infinity tokens, duplicate
# keys, UTF-8 BOM, plus the optional make_read_only guard) and W3 (stringify
# with sort_keys and full_precision as the canonical form).
# Writes one file under user://adr_checks/ for the BOM case and removes it.
# Run: godot --headless --path . -s res://check_json.gd
extends SceneTree

const Report := preload("res://types/report.gd")
const DIR: String = "user://adr_checks"

var _r: Report = Report.new()


func _initialize() -> void:
	_w1_numbers()
	_w1_tokens()
	_w1_duplicate_key()
	_w1_bom()
	_w1_null_document()
	_w1_read_only()
	_w3_sort_keys()
	_w3_precision()
	_r.finish(self, "check_json.gd")


## Returns [error, data, message].
func _parse(text: String) -> Array:
	var j: JSON = JSON.new()
	var err: int = j.parse(text)
	return [err, j.data, j.get_error_message()]


func _w1_numbers() -> void:
	var p: Array = _parse("[3, 3.0, 160]")
	var types: Array = []
	if p[0] == OK:
		for v in p[1]:
			types.append(type_string(typeof(v)))
	var ok: bool = types == ["float", "float", "float"]
	_r.check("ADR-0002-W1-numbers", ok, "parse=%s types of 3, 3.0, 160: %s" % [error_string(p[0]), types], "float for all three")


func _w1_tokens() -> void:
	for tok in ["NaN", "Infinity", "-Infinity"]:
		var p: Array = _parse("[%s]" % tok)
		_r.record("ADR-0002-W1-token-" + tok, "parse=%s data=%s msg=%s" % [error_string(p[0]), p[1], p[2]], "record whether it parses or fails (strict JSON fails)")


func _w1_duplicate_key() -> void:
	var p: Array = _parse("{\"a\": 1, \"a\": 2}")
	_r.record("ADR-0002-W1-duplicate-key", "parse=%s data=%s msg=%s" % [error_string(p[0]), p[1], p[2]], "record which value survives, or whether it fails")


func _w1_bom() -> void:
	var text: String = String.chr(0xFEFF) + "{\"a\": 1}"
	var p: Array = _parse(text)
	_r.record("ADR-0002-W1-bom-string", "parse=%s data=%s msg=%s" % [error_string(p[0]), p[1], p[2]], "record whether a leading U+FEFF is a parse error")

	DirAccess.make_dir_recursive_absolute(DIR)
	var path: String = DIR.path_join("bom.json")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_r.check("ADR-0002-W1-bom-file", false, "could not write %s: %s" % [path, error_string(FileAccess.get_open_error())], "file written")
		return
	var bytes: PackedByteArray = PackedByteArray([0xEF, 0xBB, 0xBF])
	bytes.append_array("{\"a\": 1}".to_utf8_buffer())
	f.store_buffer(bytes)
	f.close()
	var read: String = FileAccess.get_file_as_string(path)
	var first: int = read.unicode_at(0) if read.length() > 0 else -1
	var q: Array = _parse(read)
	_r.record("ADR-0002-W1-bom-file", "get_file_as_string keeps BOM=%s; parse=%s data=%s" % [first == 0xFEFF, error_string(q[0]), q[1]], "record (Decision reads with get_file_as_string)")
	DirAccess.remove_absolute(path)


func _w1_null_document() -> void:
	var p: Array = _parse("null")
	_r.check("ADR-0002-W1-null-document", p[0] == OK and p[1] == null, "parse=%s data=%s" % [error_string(p[0]), p[1]], "OK with data null (the Error code decides)")


func _write_first(arr: Array, state: Dictionary) -> void:
	arr[0] = 9
	state["after"] = true


func _w1_read_only() -> void:
	var arr: Array = [1, 2]
	arr.make_read_only()
	var state: Dictionary = {"after": false}
	var e0: int = _r.errors()
	_write_first(arr, state)
	var errs: String = "n/a" if e0 < 0 else "+" + str(_r.errors() - e0)
	_r.record("ADR-0002-W1-make_read_only", "is_read_only=%s value after write=%s write finished=%s errors=%s" % [arr.is_read_only(), arr[0], state["after"], errs], "record (optional guard: an in-place write is an error, value stays 1)")


func _w3_sort_keys() -> void:
	var data: Dictionary = {}
	data["b"] = 1
	var inner: Dictionary = {}
	inner["d"] = 2
	var deep: Dictionary = {}
	deep["z"] = 1
	deep["y"] = 2
	inner["c"] = [deep]
	data["a"] = inner
	var s: String = JSON.stringify(data, "", true, true)
	var want: String = "{\"a\":{\"c\":[{\"y\":2,\"z\":1}],\"d\":2},\"b\":1}"
	_r.check("ADR-0002-W3-sort-every-level", s == want, s, want)

	var other: Dictionary = {"a": {"c": [{"y": 2, "z": 1}], "d": 2}, "b": 1}
	var s2: String = JSON.stringify(other, "", true, true)
	_r.check("ADR-0002-W3-equal-snapshots", s == s2, "insertion orders differ; strings equal=%s" % (s == s2), "equal strings")


## The next double above x (one ulp), through its bit pattern.
func _next_up(x: float) -> float:
	var b: PackedByteArray = PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	var bits: int = b.decode_s64(0)
	b.encode_s64(0, bits + 1)
	return b.decode_double(0)


func _w3_precision() -> void:
	var values: Array = [0.1, 1.0 / 3.0, 2.5, 1.0e-7, 123456.789, 3.0, 16777217.0]
	var all_round_trip: bool = true
	var all_differ: bool = true
	var shown: Array = []
	for v in values:
		var x: float = v
		var y: float = _next_up(x)
		var sx: String = JSON.stringify(x, "", true, true)
		var sy: String = JSON.stringify(y, "", true, true)
		var back: Variant = JSON.parse_string(sx)
		if not (back is float and back == x):
			all_round_trip = false
		if sx == sy or x == y:
			all_differ = false
		shown.append("%s/%s" % [sx, sy])
	_r.check("ADR-0002-W3-full-precision", all_round_trip and all_differ, "value/next-ulp: %s; round trip=%s one-ulp differs=%s" % [", ".join(PackedStringArray(shown)), all_round_trip, all_differ], "every value parses back equal; a one-ulp change gives a different string")
