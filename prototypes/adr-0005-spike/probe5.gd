extends SceneTree
# Reviewer probe (godot-specialist): weakref(null), const read-only depth, subclass _init rules, realistic read cost.
class Ctx extends RefCounted:
	var def_id: StringName
	var level: int
	var live_entity: WeakRef
	func _init(p_def_id: StringName, p_level: int = 0, p_entity: Object = null) -> void:
		def_id = p_def_id; level = p_level
		if p_entity != null:
			live_entity = weakref(p_entity)
class Rec extends RefCounted:
	var cost: int = 7
	var damage: float = 3.5
	var range_units: float = 120.0
	var tags: Array[StringName] = [&"splash"]
class Acc extends RefCounted:
	const COST := &"cost"
	const DAMAGE := &"damage"
	const RANGE := &"range"
	const SPLASH_RADIUS := &"splash_radius"
	const TYPES := {&"tower": {COST: TYPE_INT, DAMAGE: TYPE_FLOAT, RANGE: TYPE_FLOAT, SPLASH_RADIUS: TYPE_FLOAT}}
	const ROLE_TAG := {SPLASH_RADIUS: &"splash"}
	var _kind_of: Dictionary = {&"arrow": &"tower"}
	var _recs: Dictionary = {&"arrow": Rec.new()}
	var _fatal: Callable
	var _n_fatal := 0
	func _init(cb: Callable) -> void:
		_fatal = cb
	func stat_float(ctx: Ctx, key: StringName) -> float:
		var kind: StringName = _kind_of.get(ctx.def_id, &"")
		if kind == &"":
			_fatal.call("unresolved"); return 0.0
		var rec: Rec = _recs[ctx.def_id]
		if ctx.level < 1 or ctx.level > 2:
			_fatal.call("level"); return 0.0
		var t: Dictionary = TYPES[kind]
		if not t.has(key):
			_fatal.call("key"); return 0.0
		if ROLE_TAG.has(key) and not rec.tags.has(ROLE_TAG[key]):
			_fatal.call("role"); return 0.0
		if t[key] != TYPE_FLOAT:
			_fatal.call("type"); return 0.0
		match key:
			DAMAGE:
				return rec.damage
			RANGE:
				return rec.range_units
			SPLASH_RADIUS:
				return 1.0
		_fatal.call("arm"); return 0.0
func fatal(c: String) -> void:
	print("FATAL ", c)
func _init() -> void:
	# 1. weakref(null)
	var w = weakref(null)
	print("weakref(null) -> ", w, " typeof=", typeof(w), " is WeakRef? ", w is WeakRef)
	if w is WeakRef:
		print("  weakref(null).get_ref() == null: ", (w as WeakRef).get_ref() == null)
	var c0 := Ctx.new(&"arrow", 1)
	print("ctx.live_entity for preview: ", c0.live_entity, " (null field; .get_ref() here would be a null-instance error)")
	# 2. const dict read-only, nested too?
	print("const TYPES read_only: ", Acc.TYPES.is_read_only(), " nested: ", Acc.TYPES[&"tower"].is_read_only())
	# 3. realistic read cost, desktop debug
	var a := Acc.new(fatal)
	var ctx := Ctx.new(&"arrow", 1)
	var acc := 0.0
	var t0 := Time.get_ticks_usec()
	for i in 100000:
		acc += a.stat_float(ctx, Acc.RANGE)
	var dt := Time.get_ticks_usec() - t0
	print("100k realistic stat_float reads usec (desktop debug): ", dt, " -> ", dt / 100000.0 * 1000.0, " ns/read; sum=", acc)
	t0 = Time.get_ticks_usec()
	for i in 100000:
		acc += ctx.level
	print("100k loop+property baseline usec: ", Time.get_ticks_usec() - t0)
	# 4. String passed to StringName param hits match
	var s := "range"
	print("String arg into StringName param read: ", a.stat_float(ctx, s))
	quit()
