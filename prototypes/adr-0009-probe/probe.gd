extends SceneTree
var _seen: Array[String] = []
func _handler(event: DamageEvent, applied: float, killed: bool) -> void:
	_seen.append("handler ran: applied=%s killed=%s kind=%d" % [applied, killed, event.source_kind])
func _by_id(a: Targetable, b: Targetable) -> bool: return a.spawn_id < b.spawn_id
func _init() -> void:
	print("== 1 cyclic typed reference Combat<->DamageEvent")
	var c := Combat.new()
	var e := Enemy.new(); e.spawn_id = 1; e.health = Health.new(); e.health.hp = 12.0
	var ev := DamageEvent.new(e, 30.0, Combat.SourceKind.HERO, &"hero")
	print("  parsed+ran; source_kind=", ev.source_kind, " name=", c.kind_name(ev.source_kind))
	print("== 4 signal dispatch synchronous")
	c.damage_applied.connect(_handler)
	var r: float = c.deliver(ev)
	print("  deliver returned ", r, "; handler entries at return: ", _seen.size(), " -> ", _seen)
	print("== 3 is_finite")
	print("  is_finite(NAN)=", is_finite(NAN), " is_finite(INF)=", is_finite(INF), " is_finite(-INF)=", is_finite(-INF), " is_finite(0.0)=", is_finite(0.0))
	print("  min(30.0, 12.0) type=", typeof(min(30.0, 12.0)) == TYPE_FLOAT, " minf=", minf(30.0, 12.0))
	print("== 2 typed-array invariance (runtime, via Variant)")
	var live: Array[Enemy] = [e]
	var v: Variant = live
	var ok := true
	var buf: Array[Targetable] = []
	buf.assign(live)
	print("  Array[Targetable].assign(Array[Enemy]) -> size=", buf.size(), " typed=", buf.get_typed_class_name(), " is_same_typed(live)=", buf.is_same_typed(live))
	var buf2: Array[Targetable] = []
	buf2.append(e)
	print("  append(Enemy) into Array[Targetable] ok, size=", buf2.size())
	print("  pass Array[Enemy] as Array[Targetable] param (via Variant):")
	print("  (runtime result recorded in first run: error, call aborted)")
	print("== reused buffer handed out")
	var held: Array[Targetable] = _buf_ref(buf2)
	buf2.clear(); buf2.append(Enemy.new())
	print("  caller's held ref sees rebuild: size=", held.size(), " same object=", held[0] == buf2[0])
	print("== sort_custom with method Callable")
	var arr: Array[Targetable] = [Enemy.new(), Enemy.new()]
	arr[0].spawn_id = 5; arr[1].spawn_id = 2
	arr.sort_custom(_by_id)
	print("  sorted ids: ", arr[0].spawn_id, ",", arr[1].spawn_id)
	print("== typed Dictionary[StringName, float]")
	print("  by_id=", c._by_id, " by_kind=", c._by_kind)
	print("== weakref / cycle check")
	var w: WeakRef = weakref(e)
	e = null; ev = null; live.clear(); buf.clear(); buf2.clear(); held = []; v = null; arr.clear()
	print("  weakref after drop: ", w.get_ref())
	print("== remove-during-iteration")
	var l: Array[int] = [1, 2, 3, 4]
	var visited: Array[int] = []
	for x in l:
		visited.append(x)
		if x == 2: l.erase(2)
	print("  for-in with erase visited ", visited, " (expected 1,2,3,4 if safe)")
	quit()
func _take(a: Array[Targetable]) -> void:
	print("  accepted; size=", a.size())
func _buf_ref(b: Array[Targetable]) -> Array[Targetable]: return b
