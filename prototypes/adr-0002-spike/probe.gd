extends SceneTree
func _init() -> void:
	var cases := {
		"int 3": "3", "float 3.0": "3.0", "exp 1e2": "1e2", "neg zero": "-0.0",
		"1e400 (overflow)": "1e400", "100000": "100000", "big 9007199254740993": "9007199254740993",
		"NaN token": "NaN", "Infinity token": "Infinity", "repeated key": "{\"a\": 1, \"a\": 2}",
		"literal null": "null", "empty": "", "trailing garbage": "1 2", "bool": "true",
		"nested": "{\"a\": [1, 2.5, {\"b\": null}]}",
	}
	for k: String in cases:
		var v: Variant = JSON.parse_string(cases[k])
		print("parse_string  %-22s -> typeof=%d (%s) value=%s" % [k, typeof(v), type_string(typeof(v)), str(v)])
	# JSON instance API for error info
	var j := JSON.new()
	var err := j.parse("{\"a\": 1,\n \"b\": }")
	print("JSON.parse err=%d line=%d msg='%s' data=%s" % [err, j.get_error_line(), j.get_error_message(), str(j.get_data())])
	err = j.parse("null")
	print("JSON.parse('null') err=%d data=%s typeof=%d" % [err, str(j.get_data()), typeof(j.get_data())])
	err = j.parse("")
	print("JSON.parse('') err=%d line=%d msg='%s'" % [err, j.get_error_line(), j.get_error_message()])
	# globals
	print("is_finite(NAN)=%s is_finite(INF)=%s is_finite(3.0)=%s" % [is_finite(NAN), is_finite(INF), is_finite(3.0)])
	var x: float = 3.0
	var y: float = 1.5
	print("floor(3.0)==3.0 -> %s typeof(floor)=%d ; floor(1.5)==1.5 -> %s ; int(3.0)=%d typeof=%d" % [floor(x) == x, typeof(floor(x)), floor(y) == y, int(x), typeof(int(x))])
	print("floor(-0.0)==-0.0 -> %s ; typeof(JSON 3)==TYPE_INT -> %s" % [floor(-0.0) == -0.0, typeof(JSON.parse_string("3")) == TYPE_INT])
	# StringName vs String keys
	var d: Dictionary = JSON.parse_string("{\"a\": 1}")
	print("String-keyed dict: has(&\"a\")=%s  d[&\"a\"]=%s  \"a\"==&\"a\" -> %s  hash eq -> %s  typeof(key)=%d" % [d.has(&"a"), str(d.get(&"a")), "a" == &"a", "a".hash() == (&"a").hash(), typeof(d.keys()[0])])
	var sn: Dictionary = {}
	sn[&"a"] = 1
	print("StringName-keyed dict: has(\"a\")=%s  sn[\"a\"]=%s  keys-typeof=%d" % [sn.has("a"), str(sn.get("a")), typeof(sn.keys()[0])])
	print("{&a:1} == {\"a\":1} -> %s" % [sn == d])
	# Dictionary equality deep?
	var d1 := {"a": [1, 2, {"b": Vector2(1, 2)}], "c": &"x"}
	var d2 := {"a": [1, 2, {"b": Vector2(1, 2)}], "c": "x"}
	var d3 := {"a": [1, 2, {"b": Vector2(1, 3)}], "c": "x"}
	print("Dictionary == deep: equal=%s  differs=%s ; 1 == 1.0 in dict: %s" % [d1 == d2, d1 == d3, {"a": 1} == {"a": 1.0}])
	# Array.make_read_only
	var arr: Array[int] = [1, 2]
	arr.make_read_only()
	print("make_read_only: is_read_only=%s" % arr.is_read_only())
	# FileAccess
	var f := FileAccess.open("res://nope.json", FileAccess.READ)
	print("FileAccess.open(missing) -> %s ; get_open_error=%d (ERR_FILE_NOT_FOUND=%d)" % [str(f), FileAccess.get_open_error(), ERR_FILE_NOT_FOUND])
	var g := FileAccess.open("res://good.json", FileAccess.READ)
	print("FileAccess.open(good) -> %s ; get_open_error=%d ; len=%d" % [str(g != null), FileAccess.get_open_error(), g.get_as_text().length() if g else -1])
	# .json as a resource?
	print("ResourceLoader.exists(good.json)=%s  recognized for JSON=%s" % [ResourceLoader.exists("res://good.json"), str(ResourceLoader.get_recognized_extensions_for_type("JSON"))])
	var r: Variant = load("res://good.json")
	print("load(good.json) -> %s  data=%s" % [str(r), str(r.data) if r else "n/a"])
	print("JSON is Resource: %s" % [ClassDB.is_parent_class("JSON", "Resource")])
	# class_name collisions
	for n: String in ["Catalogue", "CatalogueError", "CatalogueParser", "CatalogueLoadResult", "TowerRecord", "TowerLevel", "EnemyRecord", "WaveRecord", "WaveGroup", "HeroRecord", "BurstRecord", "InputRecord", "StageRecord", "PinExclusion", "Input", "Tower", "Enemy", "Wave", "Stage", "Hero", "Burst", "Battle", "Catalog"]:
		if ClassDB.class_exists(n):
			print("ClassDB collision: %s" % n)
	print("collision scan done")
	# shadowing: var range on a class
	var s: Variant = load("res://shadow_range.gd")
	print("var range script loads: %s ; instance get_range=%s" % [str(s != null), str(s.new().get_range()) if s else "n/a"])
	var ci: Variant = load("res://class_input.gd")
	print("class_name Input script loads: %s" % [str(ci != null)])
	quit()
