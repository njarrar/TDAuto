extends SceneTree
# Review probe for ADR-0008 (godot-specialist, 2026-11-05). Throwaway.

class Res extends RefCounted:
	enum Kind { TAP, SINK, DRAG }
	const NONE := 0
	signal pressed(best_tap: int, best_drag: int, p: Vector2)
	signal became_idle()
	var _ids: PackedInt32Array = PackedInt32Array()
	var _next_id: int = 1
	var _queue: Array = []
	var _head: int = 0
	var _draining: bool = false
	var state: int = 0
	var winner: int = 0
	var log: Array = []
	var dev_error: Callable
	static func validate(d: float, t: float) -> bool:
		return is_finite(d) and is_finite(t) and d > 0.0 and t > d
	static func create(d: float, t: float, cb: Callable = Callable()) -> Res:
		if not validate(d, t):
			return null
		var r := Res.new()
		r.dev_error = cb
		return r
	func register(kind: Kind, priority: int, centre: Vector2, radius: float, enabled: bool = true) -> int:
		var id := _next_id
		_next_id += 1
		_ids.append(id)
		return id
	func unregister(id: int) -> void:
		var i := _ids.find(id)
		if i >= 0:
			_ids.remove_at(i)
	func press(pointer: int, pos: Vector2) -> void:
		_queue.append([0, pointer, pos])
		if _draining:
			return
		_draining = true
		while _head < _queue.size():
			var e: Array = _queue[_head]
			_head += 1
			# replacement: cancel batch then press
			if state != 0:
				state = 0
				log.append("commit idle")
				became_idle.emit()
			state = 1
			winner = _ids[0] if _ids.size() > 0 else NONE
			var w := winner
			log.append("commit pressed w=%d" % w)
			pressed.emit(w, NONE, e[2])
		_queue.clear()
		_head = 0
		_draining = false

class Listener extends RefCounted:
	var name: String
	var res: Res
	var reenter: bool = false
	func on_pressed(bt, bd, p) -> void:
		res.log.append("%s pressed bt=%d state=%d ids=%s" % [name, bt, res.state, str(res._ids)])
		if reenter:
			reenter = false
			res.unregister(bt)
			var nid := res.register(Res.Kind.TAP, 1, Vector2.ZERO, 5.0)
			res.log.append("%s unregistered %d registered %d" % [name, bt, nid])
			res.press(0, Vector2(1, 1))
			res.log.append("%s press() returned, state=%d w=%d" % [name, res.state, res.winner])
	func on_idle() -> void:
		res.log.append("%s became_idle state=%d" % [name, res.state])

func _init() -> void:
	# R1 static factory, null return, Callable() default, enum param
	var bad := Res.create(0.0, 1.0)
	var ok := Res.create(15.0, 28.0)
	print("R1|create null=", bad == null, " ok=", ok != null, " nan=", Res.create(NAN, 28.0) == null, " default cb valid=", ok.dev_error.is_valid())
	# R2 Callable().is_valid
	print("R2|Callable().is_valid=", Callable().is_valid())
	# R3 PackedInt32Array find/remove_at keeps order
	var ids := PackedInt32Array([1, 2, 3, 4])
	ids.remove_at(ids.find(2))
	print("R3|after remove 2: ", ids, " find(missing)=", ids.find(9))
	# R4 float32 edge with fractional radius / fractional positions
	var c := Vector2(270.0, 480.0)
	var r := 36.4
	var edge := Vector2(270.0 + r, 480.0)
	print("R4|float32 x=", edge.x, " eq 306.4? ", edge.x == 306.4, " d2=", edge.distance_squared_to(c), " r*r=", r * r, " edge hit=", edge.distance_squared_to(c) <= r * r)
	var c2 := Vector2(270.3, 480.7)
	var e2 := Vector2(270.3 + 36.0, 480.7)
	print("R4|frac centre r=36: d2=", e2.distance_squared_to(c2), " hit=", e2.distance_squared_to(c2) <= 1296.0)
	var e3 := Vector2(270.0 + 27.5, 480.0)
	print("R4|r=27.5 edge hit=", e3.distance_squared_to(c) <= 27.5 * 27.5, " d2=", e3.distance_squared_to(c))
	# R5 packed in-place writes vs Array append: static memory delta
	var ring := PackedInt32Array()
	ring.resize(224)
	var m0 := Performance.get_monitor(Performance.MEMORY_STATIC)
	for i in 200000:
		ring[i % 224] = i
	var m1 := Performance.get_monitor(Performance.MEMORY_STATIC)
	var q: Array = []
	for i in 2000:
		q.append([0, i, Vector2(i, i)])
	var m2 := Performance.get_monitor(Performance.MEMORY_STATIC)
	q.clear()
	var m3 := Performance.get_monitor(Performance.MEMORY_STATIC)
	print("R5|ring 200k writes delta=", m1 - m0, " queue 2000 appends delta=", m2 - m1, " after clear delta=", m3 - m2)
	# R6 re-entrancy: handler A unregisters winner, registers, calls press() during pressed
	var a := Listener.new(); a.name = "A"; a.res = ok; a.reenter = true
	var b := Listener.new(); b.name = "B"; b.res = ok
	ok.pressed.connect(a.on_pressed)
	ok.pressed.connect(b.on_pressed)
	ok.became_idle.connect(a.on_idle)
	ok.register(Res.Kind.TAP, 1, Vector2.ZERO, 5.0)
	ok.press(0, Vector2(0, 0))
	for line in ok.log:
		print("R6|", line)
	print("R6|queue after drain size=", ok._queue.size(), " head=", ok._head, " draining=", ok._draining)
	quit()
