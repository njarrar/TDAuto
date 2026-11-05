# PROTOTYPE - NOT FOR PRODUCTION. ADR checks: signals.
# Covers ADR-0006 V1 to V5, ADR-0008 V1 (a) to (e) with (d) only the
# self-hold case, and ADR-0007 V3 (variadic lambda as a recording listener).
# ADR-0006 V6 is in check_types.gd. ADR-0008 V1 (d) without the self-hold may
# crash, so it is alone in check_signals_nohold.gd.
# Run: godot --headless --path . -s res://check_signals.gd
extends SceneTree

const Report := preload("res://types/report.gd")

var _r: Report = Report.new()


class V1Emitter extends RefCounted:
	signal s(a: int, b: StringName)


class V1Listener extends RefCounted:
	var seen: Array = []

	func on_s(a: int, b: StringName) -> void:
		seen.append([type_string(typeof(a)), type_string(typeof(b)), a, b])


class BaseEm extends RefCounted:
	signal base_sig


class DerivedEm extends BaseEm:
	signal own_sig(x: int)


class Rec extends RefCounted:
	signal zero
	signal one(a: int)
	signal six(a: int, b: float, c: String, d: StringName, e: Vector2, f: bool)


class V3Em extends RefCounted:
	signal ping


class V3Target extends RefCounted:
	var hits: int = 0

	func on_ping() -> void:
		hits += 1


class Plain extends RefCounted:
	signal s0
	signal t0


class Named extends RefCounted:
	var tag: String
	var out: Array

	func _init(p_tag: String, p_out: Array) -> void:
		tag = p_tag
		out = p_out

	func on_s() -> void:
		out.append(tag)


## Listener that connects or disconnects another listener during the emit.
class Mutator extends RefCounted:
	var out: Array
	var em: Plain
	var other: Named
	var connect_other: bool

	func _init(p_out: Array, p_em: Plain, p_other: Named, p_connect: bool) -> void:
		out = p_out
		em = p_em
		other = p_other
		connect_other = p_connect

	func on_s() -> void:
		out.append("M")
		if connect_other:
			em.s0.connect(other.on_s)
		else:
			em.s0.disconnect(other.on_s)


## A of s emits t (nested emit).
class Nester extends RefCounted:
	var out: Array
	var em: Plain

	func _init(p_out: Array, p_em: Plain) -> void:
		out = p_out
		em = p_em

	func on_s() -> void:
		out.append("A")
		em.t0.emit()


## Re-emits s once from its own listener.
class ReEmitter extends RefCounted:
	var out: Array
	var em: Plain
	var depth: int = 0

	func _init(p_out: Array, p_em: Plain) -> void:
		out = p_out
		em = p_em

	func on_s() -> void:
		depth += 1
		out.append("R%d" % depth)
		if depth == 1:
			em.s0.emit()


class PokeEm extends RefCounted:
	signal s(v: int)
	var out: Array

	func _init(p_out: Array) -> void:
		out = p_out

	func poke(n: int) -> void:
		out.append("poke%d" % n)


class PokeA extends RefCounted:
	var em: PokeEm

	func _init(p_em: PokeEm) -> void:
		em = p_em

	func on_s(v: int) -> void:
		em.out.append("A%d" % v)
		em.poke(1)


class PokeB extends RefCounted:
	var out: Array

	func _init(p_out: Array) -> void:
		out = p_out

	func on_s(v: int) -> void:
		out.append("B%d" % v)


class Holder extends RefCounted:
	var emitter: Variant = null


class SelfHoldEmitter extends RefCounted:
	signal fired

	func fire(state: Dictionary) -> void:
		var _hold: RefCounted = self
		fired.emit()
		state["after_emit"] = true


class Dropper extends RefCounted:
	var holder: Holder

	func on_fired() -> void:
		holder.emitter = null


class Trigger extends RefCounted:
	signal go


func _initialize() -> void:
	_adr0006_v1()
	_adr0006_v2()
	_adr0007_v3()
	_adr0006_v3()
	_adr0006_v4_and_0008_v1c()
	_adr0006_v5()
	_adr0008_v1a()
	_adr0008_v1b()
	_adr0008_v1d_hold()
	_adr0008_v1e()
	_r.finish(self, "check_signals.gd")


func _parses(src: String) -> int:
	var g: GDScript = GDScript.new()
	g.source_code = src
	return g.reload()


func _errs_delta(before: int) -> String:
	if before < 0:
		return "n/a"
	return "+" + str(_r.errors() - before)


func _adr0006_v1() -> void:
	var em: V1Emitter = V1Emitter.new()
	var a: V1Listener = V1Listener.new()
	var b_seen: Array = []
	em.s.connect(a.on_s)
	em.s.connect(func(...args: Array) -> void: b_seen.append(args.size()))
	var sig: Signal = em.s
	var cases: Array = [["x", "y"], [1.5, &"y"], [1, "y"], [1]]
	var continued: bool = true
	var parts: Array = []
	for args in cases:
		a.seen.clear()
		b_seen.clear()
		var e0: int = _r.errors()
		_emit_args(sig, args)
		var a_got: String = str(a.seen) if not a.seen.is_empty() else "not called"
		parts.append("emit%s: A %s, B got %s, errors %s" % [args, a_got, b_seen, _errs_delta(e0)])
		if b_seen.size() != 1:
			continued = false
	_r.check("ADR-0006-V1-emit-continues", continued, "; ".join(PackedStringArray(parts)), "no type check at emit; a listener error is logged and the emit goes on to the next listener")
	var head: String = "extends RefCounted\nsignal s(a: int, b: StringName)\nfunc f() -> void:\n\t"
	var arity: int = _parses(head + "s.emit(1)\n")
	var types: int = _parses(head + "s.emit(\"x\", \"y\")\n")
	_r.record("ADR-0006-V1-parse-time", "s.emit(1) reload=%s; s.emit(\"x\", \"y\") reload=%s" % [error_string(arity), error_string(types)], "record (OK means the analyzer does not check emit())")


## Emits a Signal with an argument list of any length.
func _emit_args(sig: Signal, args: Array) -> void:
	match args.size():
		1:
			sig.emit(args[0])
		2:
			sig.emit(args[0], args[1])
		_:
			sig.emit()


func _adr0006_v2() -> void:
	var d: DerivedEm = DerivedEm.new()
	var list: Array = d.get_script().get_script_signal_list()
	var names: Array = []
	var dict_ok: bool = true
	for entry in list:
		if not (entry is Dictionary) or not entry.has("name"):
			dict_ok = false
			continue
		names.append(str(entry["name"]))
	names.sort()
	var ok: bool = dict_ok and names == ["base_sig", "own_sig"]
	_r.check("ADR-0006-V2", ok, "names=%s dict_with_name=%s" % [names, dict_ok], "[base_sig, own_sig] only, Dictionary entries with a name key")
	var base_names: Array = []
	for entry in RefCounted.new().get_signal_list():
		base_names.append(str(entry["name"]))
	var branch: Array = []
	for entry in d.get_signal_list():
		var n: String = str(entry["name"])
		if not base_names.has(n):
			branch.append(n)
	branch.sort()
	_r.record("ADR-0006-V2-branch", "get_signal_list minus RefCounted: %s" % [branch], "record (fallback form)")


func _adr0007_v3() -> void:
	var rec: Rec = Rec.new()
	var got: Array = []
	var listener: Callable = func(...args: Array) -> void: got.append(args)
	rec.zero.connect(listener)
	rec.one.connect(listener)
	rec.six.connect(listener)
	rec.zero.emit()
	rec.one.emit(1)
	rec.six.emit(1, 2.0, "c", &"a", Vector2(1.0, 2.0), true)
	rec.six.emit(1, 2.0, "c", "a", Vector2(1.0, 2.0), true)
	var counts: Array = []
	for g in got:
		counts.append(g.size())
	_r.check("ADR-0007-V3-counts", counts == [0, 1, 6, 6], "argument counts %s" % [counts], "[0, 1, 6, 6]")
	var t_sn: int = typeof(got[2][3]) if got.size() > 2 else -1
	var t_s: int = typeof(got[3][3]) if got.size() > 3 else -1
	_r.check("ADR-0007-V3-stringname", t_sn == TYPE_STRING_NAME, type_string(t_sn), "TYPE_STRING_NAME for &\"a\"")
	_r.check("ADR-0007-V3-string-into-stringname", t_s == TYPE_STRING, type_string(t_s), "TYPE_STRING for \"a\" into a StringName parameter (no conversion)")
	var declared: Array = []
	for entry in rec.get_script().get_script_signal_list():
		if str(entry["name"]) == "six":
			for arg in entry["args"]:
				declared.append(int(arg["type"]))
	var want: Array = [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_BOOL]
	_r.check("ADR-0007-V3-declared-types", declared == want, "args[i].type %s" % [declared], "%s (int, float, String, StringName, Vector2, bool)" % [want])


func _adr0006_v3() -> void:
	var em: V3Em = V3Em.new()
	var t: V3Target = V3Target.new()
	var err1: int = em.ping.connect(t.on_ping)
	var list: Array = em.get_signal_connection_list("ping")
	var shape: String = "none"
	var ok: bool = false
	if list.size() == 1:
		var c: Dictionary = list[0]
		var cb: Callable = c.get("callable", Callable())
		ok = c.has("signal") and c.has("callable") and c.has("flags") and cb.get_object() == t and typeof(cb.get_method()) == TYPE_STRING_NAME and int(c["flags"]) == 0
		shape = "keys=%s object_is_target=%s method_type=%s flags=%s" % [c.keys(), cb.get_object() == t, type_string(typeof(cb.get_method())), c.get("flags")]
	_r.check("ADR-0006-V3-connection-list", ok, "connect=%s %s" % [error_string(err1), shape], "signal, callable, flags keys; object is the target; method StringName; flags 0")

	var list2: Array = em.ping.get_connections()
	var same: bool = list2.size() == 1 and (list2[0] as Dictionary).has("signal") and (list2[0] as Dictionary).has("callable") and (list2[0] as Dictionary).has("flags")
	_r.check("ADR-0006-V3-get_connections", same, "size=%d keys=%s" % [list2.size(), (list2[0] as Dictionary).keys() if list2.size() > 0 else []], "same shape as get_signal_connection_list")

	var e0: int = _r.errors()
	var err2: int = em.ping.connect(t.on_ping)
	var count: int = em.ping.get_connections().size()
	_r.check("ADR-0006-V3-double-connect", err2 == ERR_INVALID_PARAMETER and count == 1, "second connect=%s connections=%d errors=%s" % [error_string(err2), count, _errs_delta(e0)], "ERR_INVALID_PARAMETER, an error pushed, nothing added")

	var t2: V3Target = V3Target.new()
	em.ping.connect(t2.on_ping, CONNECT_DEFERRED)
	var dflags: int = -1
	for c in em.get_signal_connection_list("ping"):
		if (c["callable"] as Callable).get_object() == t2:
			dflags = int(c["flags"])
	_r.check("ADR-0006-V3-deferred-flag", dflags > 0, "flags=%d (CONNECT_DEFERRED=%d)" % [dflags, CONNECT_DEFERRED], "non-zero")

	var ps: PackedScene = load("res://types/persist_scene.tscn") as PackedScene
	if ps == null:
		_r.check("ADR-0006-V3-tscn-persist", false, "persist_scene.tscn did not load", "flags include CONNECT_PERSIST (2)")
	else:
		var root: Node = ps.instantiate()
		var child: Node = root.get_node("Child")
		var pflags: int = -1
		for c in child.get_signal_connection_list("renamed"):
			pflags = int(c["flags"])
		_r.check("ADR-0006-V3-tscn-persist", pflags >= 0 and (pflags & CONNECT_PERSIST) != 0, "flags=%d" % pflags, "includes CONNECT_PERSIST (2)")
		root.free()

	var em2: V3Em = V3Em.new()
	var n: Node = Node.new()
	em2.ping.connect(n.update_configuration_warnings)
	var before: int = em2.ping.get_connections().size()
	n.free()
	var after: int = em2.ping.get_connections().size()
	_r.check("ADR-0006-V3-freed-listener", before == 1 and after == 0, "connections before free=%d after=%d" % [before, after], "dropped automatically (0 after free)")
	em2.ping.emit()


func _adr0006_v4_and_0008_v1c() -> void:
	var out: Array = []
	var em: Plain = Plain.new()
	var a: Named = Named.new("A", out)
	var b: Named = Named.new("B", out)
	var c: Named = Named.new("C", out)
	em.s0.connect(a.on_s)
	em.s0.connect(b.on_s)
	em.s0.connect(c.on_s)
	em.s0.emit()
	var first: String = "".join(PackedStringArray(out))
	out.clear()
	em.s0.disconnect(b.on_s)
	em.s0.connect(b.on_s)
	em.s0.emit()
	var second: String = "".join(PackedStringArray(out))
	_r.check("ADR-0006-V4-order", first == "ABC" and second == "ACB", "first %s, after disconnect(B)+connect(B) %s" % [first, second], "ABC then ACB")

	var out2: Array = []
	var em2: Plain = Plain.new()
	var d: Named = Named.new("D", out2)
	var m: Mutator = Mutator.new(out2, em2, d, true)
	em2.s0.connect(m.on_s)
	var b2: Named = Named.new("B", out2)
	em2.s0.connect(b2.on_s)
	em2.s0.emit()
	var during: String = "".join(PackedStringArray(out2))
	out2.clear()
	m.connect_other = false
	m.out = out2
	em2.s0.disconnect(m.on_s)
	em2.s0.emit()
	var next: String = "".join(PackedStringArray(out2))
	_r.record("ADR-0006-V4-connect-during-emit", "emit with M connecting D: %s; next emit: %s" % [during, next], "record (\"MB\" means the running emit used a snapshot)")

	var out3: Array = []
	var em3: Plain = Plain.new()
	var c3: Named = Named.new("C", out3)
	var m3: Mutator = Mutator.new(out3, em3, c3, false)
	var b3: Named = Named.new("B", out3)
	em3.s0.connect(m3.on_s)
	em3.s0.connect(b3.on_s)
	em3.s0.connect(c3.on_s)
	em3.s0.emit()
	var log3: String = "".join(PackedStringArray(out3))
	_r.record("ADR-0006-V4-disconnect-during-emit", "emit with M disconnecting C: %s" % log3, "record (\"MBC\" means a snapshot)")
	_r.check("ADR-0008-V1c", log3 == "MBC", "listener disconnected during the emit: log %s" % log3, "yes, it still receives that emit (MBC)")


func _adr0006_v5() -> void:
	var out: Array = []
	var em: Plain = Plain.new()
	var a: Nester = Nester.new(out, em)
	var b: Named = Named.new("B", out)
	var t1: Named = Named.new("T1", out)
	var t2: Named = Named.new("T2", out)
	em.s0.connect(a.on_s)
	em.s0.connect(b.on_s)
	em.t0.connect(t1.on_s)
	em.t0.connect(t2.on_s)
	em.s0.emit()
	var got: String = ",".join(PackedStringArray(out))
	_r.check("ADR-0006-V5-nested", got == "A,T1,T2,B", got, "A,T1,T2,B (depth-first)")

	var out2: Array = []
	var em2: Plain = Plain.new()
	var r: ReEmitter = ReEmitter.new(out2, em2)
	var b2: Named = Named.new("B", out2)
	em2.s0.connect(r.on_s)
	em2.s0.connect(b2.on_s)
	em2.s0.emit()
	_r.record("ADR-0006-V5-re-emit", ",".join(PackedStringArray(out2)), "record (R1,R2,B,B means the re-emit is delivered in full)")


func _adr0008_v1a() -> void:
	var out: Array = []
	var em: PokeEm = PokeEm.new(out)
	var a: PokeA = PokeA.new(em)
	var b: PokeB = PokeB.new(out)
	em.s.connect(a.on_s)
	em.s.connect(b.on_s)
	var e0: int = _r.errors()
	em.s.emit(7)
	out.append("returned")
	var got: String = ",".join(PackedStringArray(out))
	var errs: String = _errs_delta(e0)
	_r.check("ADR-0008-V1a", got == "A7,poke1,B7,returned" and (errs == "n/a" or errs == "+0"), "%s errors=%s" % [got, errs], "A7,poke1,B7,returned with no error")


func _adr0008_v1b() -> void:
	var arr: Array = [0]
	var em: PokeEm = PokeEm.new([])
	var appender: Callable = func(_v: int) -> void:
		if arr.size() < 3:
			arr.append(arr.size())
	em.s.connect(appender)
	var visited: int = 0
	var i: int = 0
	while i < arr.size():
		em.s.emit(i)
		visited += 1
		i += 1
	_r.check("ADR-0008-V1b", visited == 3 and arr.size() == 3, "visited=%d size=%d" % [visited, arr.size()], "the loop sees the appended elements (3 and 3)")


func _adr0008_v1d_hold() -> void:
	var holder: Holder = Holder.new()
	var em: SelfHoldEmitter = SelfHoldEmitter.new()
	var w: WeakRef = weakref(em)
	var dropper: Dropper = Dropper.new()
	dropper.holder = holder
	em.fired.connect(dropper.on_fired)
	var state: Dictionary = {"after_emit": false}
	var trig: Trigger = Trigger.new()
	trig.go.connect(Callable(em, "fire").bind(state))
	holder.emitter = em
	em = null
	trig.go.emit()
	var freed: bool = w.get_ref() == null
	_r.check("ADR-0008-V1d-hold", state["after_emit"] and freed, "finished after emit=%s freed after=%s" % [state["after_emit"], freed], "finishes, then frees")


func _v1e_callee(o: Variant, state: Dictionary) -> void:
	state["callee_entered"] += 1
	o.missing_method()
	state["callee_after"] += 1


func _adr0008_v1e() -> void:
	var state: Dictionary = {"caller_started": 0, "caller_after": 0, "callee_entered": 0, "callee_after": 0}
	var e0: int = _r.errors()
	_v1e_caller(state)
	_r.record("ADR-0008-V1e", "%s errors=%s" % [state, _errs_delta(e0)], "ADR expects the caller to abort with its flags left set (debug run). caller_after 0 = caller aborted; 3 = only the callee stopped")


func _v1e_caller(state: Dictionary) -> void:
	for i in 3:
		state["caller_started"] += 1
		_v1e_callee(null, state)
		state["caller_after"] += 1
