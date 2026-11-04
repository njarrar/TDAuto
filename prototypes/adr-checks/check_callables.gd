# PROTOTYPE - NOT FOR PRODUCTION. ADR checks: Callable and lifetime.
# Covers ADR-0001 V1 (method Callable, signal connection, lambda, bind,
# lambda binding self) and ADR-0009 V5 (reaped enemy and its Health, Status
# and ReadContext freed; all freed on retry). Proof by weakref().get_ref().
# Run: godot --headless --path . -s res://check_callables.gd
extends SceneTree

const Report := preload("res://types/report.gd")

var _r: Report = Report.new()


class Target extends RefCounted:
	var value: int = 1

	func ping() -> int:
		return value

	func on_signal() -> void:
		value += 1

	func make_plain_lambda() -> Callable:
		return func() -> int: return 1

	func make_self_lambda() -> Callable:
		return func() -> int: return value


class Emitter extends RefCounted:
	signal fired


class Peer extends RefCounted:
	signal poked
	var other: Callable

	func ping() -> int:
		return 0

	func on_poked() -> void:
		pass


# ADR-0009 V5 stand-ins: one-way ownership, back-pointers as method Callables.
class V5Health extends RefCounted:
	signal died(spawn_id: int)
	var hp: int = 0
	var spawn_id: int = 0
	var _on_zero: Callable

	func _init(p_spawn_id: int, p_hp: int, p_on_zero: Callable) -> void:
		spawn_id = p_spawn_id
		hp = p_hp
		_on_zero = p_on_zero

	func hit(n: int) -> void:
		hp -= n
		if hp <= 0:
			_on_zero.call()
			died.emit(spawn_id)


class V5Status extends RefCounted:
	var ticks_left: int = 0


class V5ReadContext extends RefCounted:
	var _base: Callable

	func _init(p_base: Callable) -> void:
		_base = p_base

	func read() -> float:
		return float(_base.call())


class V5Enemy extends RefCounted:
	var spawn_id: int = 0
	var removed: bool = false
	var health: V5Health
	var status: V5Status
	var context: V5ReadContext

	func _init(p_id: int) -> void:
		spawn_id = p_id
		health = V5Health.new(p_id, 3, _on_zero)
		status = V5Status.new()
		context = V5ReadContext.new(base_speed)

	func base_speed() -> float:
		return 1.0

	func _on_zero() -> void:
		removed = true


class V5Wave extends RefCounted:
	var roster: Array[V5Enemy] = []
	var died_count: int = 0

	func spawn(p_id: int) -> V5Enemy:
		var e: V5Enemy = V5Enemy.new(p_id)
		e.health.died.connect(_on_died)
		roster.append(e)
		return e

	func targets() -> Array[V5Enemy]:
		return roster

	func reap() -> void:
		var i: int = 0
		while i < roster.size():
			if roster[i].removed:
				roster.remove_at(i)
			else:
				i += 1

	func _on_died(_spawn_id: int) -> void:
		died_count += 1


class V5Combat extends RefCounted:
	var _targets: Callable

	func _init(p_targets: Callable) -> void:
		_targets = p_targets

	func hit_one(index: int, n: int) -> void:
		var list: Array = _targets.call()
		list[index].health.hit(n)


func _initialize() -> void:
	_v1_method_callable()
	_v1_connection()
	_v1_lambda_capture()
	_v1_bind()
	_v1_lambda_self()
	_v1_cycles()
	_v5_reap_and_retry()
	_r.finish(self, "check_callables.gd")


func _v1_method_callable() -> void:
	var t: Target = Target.new()
	var w: WeakRef = weakref(t)
	var c: Callable = t.ping
	t = null
	var freed: bool = w.get_ref() == null
	_r.check("ADR-0001-V1-method-callable", freed, "target freed=%s; callable still valid=%s" % [freed, c.is_valid()], "freed (a method Callable holds the object ID only)")


func _v1_connection() -> void:
	var e: Emitter = Emitter.new()
	var t: Target = Target.new()
	var w: WeakRef = weakref(t)
	e.fired.connect(t.on_signal)
	t = null
	var freed: bool = w.get_ref() == null
	_r.check("ADR-0001-V1-connection-target", freed, "target freed=%s; connections left=%d" % [freed, e.fired.get_connections().size()], "freed (a connection does not keep its target)")
	e.fired.emit()

	var e2: Emitter = Emitter.new()
	var we: WeakRef = weakref(e2)
	var t2: Target = Target.new()
	e2.fired.connect(t2.on_signal)
	e2 = null
	_r.record("ADR-0001-V1-connection-emitter", "emitter freed=%s while its target lives" % (we.get_ref() == null), "record (expected freed)")

	var e3: Emitter = Emitter.new()
	var o: Target = Target.new()
	var wo: WeakRef = weakref(o)
	e3.fired.connect(func() -> void: o.on_signal())
	o = null
	_r.record("ADR-0001-V1-connected-lambda", "captured object alive=%s while the lambda is connected" % (wo.get_ref() != null), "record (expected alive: the lambda holds it)")


func _v1_lambda_capture() -> void:
	var o: Target = Target.new()
	var w: WeakRef = weakref(o)
	var f: Callable = func() -> int: return o.value
	o = null
	var alive: bool = w.get_ref() != null
	_r.check("ADR-0001-V1-lambda-capture", alive, "captured object alive=%s" % alive, "alive (a lambda holds a captured RefCounted strongly)")
	f = Callable()
	_r.record("ADR-0001-V1-lambda-release", "freed after the lambda is dropped=%s" % (w.get_ref() == null), "record (expected freed)")


func _v1_bind() -> void:
	var holder: Target = Target.new()
	var o: Target = Target.new()
	var wo: WeakRef = weakref(o)
	var wh: WeakRef = weakref(holder)
	var b: Callable = holder.ping.bind(o)
	o = null
	var alive: bool = wo.get_ref() != null
	_r.check("ADR-0001-V1-bind-arg", alive, "bound argument alive=%s" % alive, "alive (bind() holds its arguments strongly)")
	holder = null
	_r.record("ADR-0001-V1-bind-target", "method target freed while the bound Callable lives=%s (valid=%s)" % [wh.get_ref() == null, b.is_valid()], "record (expected freed: the inner method Callable holds an ID)")


func _v1_lambda_self() -> void:
	var t: Target = Target.new()
	var w: WeakRef = weakref(t)
	var f: Callable = t.make_plain_lambda()
	t = null
	_r.record("ADR-0001-V1-lambda-self-nocapture", "object alive=%s after a lambda made in its method (no self use) outlives it" % (w.get_ref() != null), "record (the question: does it bind self strongly)")
	f = Callable()

	var t2: Target = Target.new()
	var w2: WeakRef = weakref(t2)
	var g: Callable = t2.make_self_lambda()
	t2 = null
	var alive: bool = w2.get_ref() != null
	_r.check("ADR-0001-V1-lambda-self-use", alive, "object alive=%s after a lambda that reads a member outlives it" % alive, "alive (lambdas hold strong references)")
	g = Callable()


func _v1_cycles() -> void:
	# Builder-style wiring: two objects point at each other through method
	# Callables and signal connections. Dropping both must free both.
	var a: Peer = Peer.new()
	var b: Peer = Peer.new()
	var wa: WeakRef = weakref(a)
	var wb: WeakRef = weakref(b)
	a.other = b.ping
	b.other = a.ping
	a.poked.connect(b.on_poked)
	b.poked.connect(a.on_poked)
	a = null
	b = null
	var both: bool = wa.get_ref() == null and wb.get_ref() == null
	_r.check("ADR-0001-V1-cycle-method", both, "both freed=%s" % both, "both freed (method Callables and connections hold IDs)")

	# Counter-case: the same cycle through lambdas leaks.
	var c: Peer = Peer.new()
	var d: Peer = Peer.new()
	var wc: WeakRef = weakref(c)
	var wd: WeakRef = weakref(d)
	c.other = func() -> int: return d.ping()
	d.other = func() -> int: return c.ping()
	c = null
	d = null
	var leaked: bool = wc.get_ref() != null and wd.get_ref() != null
	_r.record("ADR-0001-V1-cycle-lambda", "lambda cycle leaked=%s" % leaked, "record (expected leaked; reason for the lambda ban)")
	var c2: Variant = wc.get_ref()
	if c2 != null:
		c2.set("other", Callable())
	var d2: Variant = wd.get_ref()
	if d2 != null:
		d2.set("other", Callable())


func _v5_reap_and_retry() -> void:
	var wave: V5Wave = V5Wave.new()
	var combat: V5Combat = V5Combat.new(wave.targets)
	for i in 3:
		wave.spawn(i)
	var e: V5Enemy = wave.roster[1]
	var refs: Array[WeakRef] = [weakref(e), weakref(e.health), weakref(e.status), weakref(e.context)]
	var speed: float = e.context.read()
	e = null
	combat.hit_one(1, 5)
	wave.reap()
	var freed: Array[bool] = []
	for w in refs:
		freed.append(w.get_ref() == null)
	var all_freed: bool = not freed.has(false)
	_r.check("ADR-0009-V5-reap", all_freed, "enemy, Health, Status, ReadContext freed=%s; roster=%d died=%d read=%s" % [freed, wave.roster.size(), wave.died_count, speed], "all four freed after reap() and the test drops its references")

	var rest: Array[WeakRef] = []
	for en in wave.roster:
		rest.append(weakref(en))
		rest.append(weakref(en.health))
		rest.append(weakref(en.status))
		rest.append(weakref(en.context))
	var ww: WeakRef = weakref(wave)
	var wcb: WeakRef = weakref(combat)
	wave = null
	combat = null
	var left: int = 0
	for w in rest:
		if w.get_ref() != null:
			left += 1
	var ok: bool = left == 0 and ww.get_ref() == null and wcb.get_ref() == null
	_r.check("ADR-0009-V5-retry", ok, "objects left=%d of %d; wave freed=%s combat freed=%s" % [left, rest.size(), ww.get_ref() == null, wcb.get_ref() == null], "all freed when the battle is dropped (retry)")
