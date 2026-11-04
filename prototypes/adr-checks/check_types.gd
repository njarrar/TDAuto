# PROTOTYPE - NOT FOR PRODUCTION. ADR checks: class and type parse.
# Covers ADR-0009 V2, V6, V7; ADR-0006 V6; ADR-0008 V4, V5, V6;
# ADR-0010 V4; ADR-0011 V6.
# This driver names no stub class itself. Every stub and probe is loaded
# with load(), so a script that does not parse is recorded, not fatal.
# Run: godot --headless --path . -s res://check_types.gd (after --import).
extends SceneTree

const Report := preload("res://types/report.gd")
const T: String = "res://types/"
const P: String = "res://types/probes/"

var _r: Report = Report.new()


func _initialize() -> void:
	# Stubs: does each class_name script load (cyclic references included)?
	for f in ["health.gd", "status.gd", "targetable.gd", "enemy.gd", "combat.gd", "damage_event.gd"]:
		_parse("ADR-0009-V6-load-" + f.get_basename(), T + f, true, "loads, no cyclic-reference error")
	for f in ["flow.gd", "stage_result.gd"]:
		_parse("ADR-0006-V6-load-" + f.get_basename(), T + f, true, "loads, no cyclic-reference error")
	for f in ["hero_sim.gd", "pin_geometry.gd"]:
		_parse("ADR-0010-V4-load-" + f.get_basename(), T + f, true, "loads, no cyclic-reference error")
	_parse("ADR-0008-V5-load-input_resolver", T + "input_resolver.gd", true, "loads (Callable() defaults on _init and create)")
	_parse("ADR-0008-V6-load-fake_resolver", T + "fake_resolver.gd", true, "loads (FakeResolver extends InputResolver)")
	_parse("ADR-0009-V2g-load-read_context", T + "read_context.gd", true, "loads")

	# ADR-0009 V6 and ADR-0006 V6: run the cycles.
	_probe("ADR-0009-V6", P + "combat_cycle.gd")
	_probe("ADR-0006-V6", P + "flow_cycle.gd")
	_probe("ADR-0006-V6-EMITTER_KEYS", P + "const_emitter_keys.gd")
	_warn_pair("ADR-0009-V6-int-to-enum-var", P + "source_kind_int.gd", P + "source_kind_int_ignored.gd", "record whether a bare int to Combat.SourceKind warns")

	# ADR-0009 V2.
	var static_loads: bool = _try_load(P + "variance_static.gd") != null
	_r.record("ADR-0009-V2a-static", "loads" if static_loads else "does not load (analyzer rejects)", "record; V2a-runtime decides if it loads")
	if static_loads:
		_probe("ADR-0009-V2a-static", P + "variance_static.gd")
	_probe("ADR-0009-V2", P + "typed_arrays.gd")
	_probe("ADR-0009-V2g", P + "typed_dict.gd")

	# ADR-0009 V7: constructor chaining.
	_ctor("ADR-0009-V7-no-super", P + "enemy_no_super.gd", [1, &"x"], true)
	_ctor("ADR-0009-V7-no-init-noargs", P + "enemy_no_init.gd", [], true)
	_ctor("ADR-0009-V7-no-init-onearg", P + "enemy_no_init.gd", [5], false)
	_ctor("ADR-0009-V7-combat-no-forward", P + "combat_fake_no_forward.gd", [], true)
	_ctor("ADR-0009-V7-combat-forward", P + "combat_fake_forward.gd", [Callable()], false)

	# ADR-0010 V4: enum values, find_key, overrides.
	_probe("ADR-0010-V4", P + "enum_base.gd")
	_override("ADR-0010-V4-override-explicit", P + "enum_override_explicit.gd", true, "loads; pick() returns 2 (B)")
	_override("ADR-0010-V4-override-inferred", P + "enum_override_inferred.gd", null, "record (untyped override returning E.B)")
	_override("ADR-0010-V4-override-no-return", P + "enum_override_no_return.gd", false, "does not load (4.7: typed return inherited, return needed)")
	_override("ADR-0010-V4-override-null", P + "enum_override_null.gd", false, "does not load (return null fails for an enum return)")
	_probe("ADR-0010-V4-cycle", P + "hero_cycle.gd")

	# ADR-0008 V4, V5, V6.
	_warn_pair("ADR-0008-V4-int-literal", P + "enum_arg_literal.gd", P + "enum_arg_literal_ignored.gd", "possibly INT_AS_ENUM_WITHOUT_CAST")
	_warn_pair("ADR-0008-V4-cast-nomatch", P + "enum_arg_cast_nomatch.gd", P + "enum_arg_cast_nomatch_ignored.gd", "possibly INT_AS_ENUM_WITHOUT_MATCH")
	_warn_pair("ADR-0008-V4-other-enum", P + "enum_arg_other.gd", P + "enum_arg_other_ignored.gd", "record (another enum's value)")
	_probe("ADR-0008-V4-runtime", P + "enum_arg_runtime.gd")
	_probe("ADR-0008-V5", P + "callable_default.gd")
	_probe("ADR-0008-V5-V6", P + "resolver_probe.gd")
	_probe("ADR-0008-V6-fake", P + "fake_probe.gd")
	_override("ADR-0008-V6-override-no-return", P + "fake_resolver_no_return.gd", false, "does not load (4.7: typed int return inherited)")

	# ADR-0011 V6.
	_probe("ADR-0011-V6", P + "const_packed.gd")
	_probe("ADR-0011-V6-fallback", P + "const_array_int.gd")

	_r.finish(self, "check_types.gd")


## Returns the script, or null if it does not load or cannot be instantiated.
func _try_load(path: String) -> GDScript:
	var s: GDScript = ResourceLoader.load(path) as GDScript
	if s == null or not s.can_instantiate():
		return null
	return s


## expect: true (must load), false (must not load) or null (record only).
func _parse(id: String, path: String, expect: Variant, expected: String) -> void:
	var loads: bool = _try_load(path) != null
	var observed: String = "loads" if loads else "does not load"
	if expect == null:
		_r.record(id, observed, expected)
	else:
		_r.check(id, loads == bool(expect), observed, expected)


## Loads a probe, sets its error counter, runs it and prints its rows.
func _probe(id: String, path: String) -> void:
	var s: GDScript = _try_load(path)
	if s == null:
		_r.check(id, false, "probe %s does not load" % path.get_file(), "probe loads and runs")
		return
	var inst: Object = s.new()
	inst.set("error_count", Callable(_r, "errors"))
	inst.call("run")
	var rows: Variant = inst.get("rows")
	if rows is Array:
		for row in rows:
			_r.result(str(row[0]), str(row[1]), row[2], str(row[3]))
	if not bool(inst.get("done")):
		_r.check(id + "-complete", false, "probe %s stopped before its end (script error)" % path.get_file(), "probe runs to the end")


## Plain probe and its @warning_ignore twin. project.godot raises the two
## int-as-enum warnings to errors, so "plain fails, twin loads" means a warning.
func _warn_pair(id: String, plain: String, ignored: String, expected: String) -> void:
	var a: bool = _try_load(plain) != null
	var b: bool = _try_load(ignored) != null
	var observed: String
	if a and b:
		observed = "no warning, no error"
	elif b:
		observed = "warning (int_as_enum, raised to error)"
	elif a:
		observed = "odd: plain loads, ignored twin does not"
	else:
		observed = "hard error (fails with the warning ignored too)"
	_r.record(id, observed, expected)


## Constructor case. expect_error true: PASS if it does not load, new()
## gives null, or an error is logged. false: PASS if an instance is made with
## no error.
func _ctor(id: String, path: String, args: Array, expect_error: bool) -> void:
	var s: GDScript = _try_load(path)
	if s == null:
		_r.check(id, expect_error, "parse error (script does not load)", "an error (parse or run time), not a silent default" if expect_error else "loads and builds")
		return
	var e0: int = _r.errors()
	var inst: Variant = s.callv("new", args)
	var e1: int = _r.errors()
	var errored: bool = inst == null or (e0 >= 0 and e1 > e0)
	var detail: String = "null" if inst == null else "instance spawn_id=%s" % str(inst.get("spawn_id"))
	var observed: String = "loads; new(%s) -> %s; errors=+%s %s" % [args, detail, "n/a" if e0 < 0 else str(e1 - e0), _r.last_error() if errored else ""]
	if expect_error:
		if errored:
			_r.check(id, true, observed, "an error (parse or run time), not a silent default")
		elif e0 < 0:
			_r.record(id, observed + " (no error counter)", "an error (parse or run time)")
		else:
			_r.check(id, false, observed + " (silent)", "an error (parse or run time), not a silent default")
	else:
		_r.check(id, not errored, observed, "loads and builds with no error")


## Override probe: checks loading, and for a loading one, what pick() returns.
func _override(id: String, path: String, expect_load: Variant, expected: String) -> void:
	var s: GDScript = _try_load(path)
	var observed: String = "does not load"
	if s != null:
		var inst: Object = s.new()
		observed = "loads"
		if inst.has_method("pick"):
			observed += "; pick() -> %s" % str(inst.call("pick"))
	if expect_load == null:
		_r.record(id, observed, expected)
	else:
		_r.check(id, (s != null) == bool(expect_load), observed, expected)
