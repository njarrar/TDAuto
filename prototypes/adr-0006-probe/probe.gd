extends SceneTree
const Emitter = preload("res://emitter.gd")
const Listener = preload("res://listener.gd")

func _init() -> void:
	var em = Emitter.new()
	var log: Array[String] = em.log
	var a = Listener.new("A", log)
	var b = Listener.new("B", log)
	var c = Listener.new("C", log)
	# (1)+(2)+(3): A connected first, nests an emit of inner; B second.
	a.em = em
	print("connect A:", em.fired.connect(a.on_fired))
	print("connect B:", em.fired.connect(b.on_fired))
	print("connect C.inner:", em.inner.connect(c.on_inner))
	log.append("before emit")
	em.fired.emit(1)
	log.append("after emit")
	print("P1-3 log: ", log)
	log.clear()
	# (4) connection introspection
	print("P4 get_signal_connection_list(fired): ", em.get_signal_connection_list("fired"))
	var conns: Array = em.fired.get_connections()
	print("P4 Signal.get_connections() count: ", conns.size())
	for d in conns:
		print("P4 keys: ", d.keys())
		var cb: Callable = d["callable"]
		print("P4 target obj==a: ", cb.get_object() == a, " obj==b: ", cb.get_object() == b, " method: ", cb.get_method(), " flags: ", d["flags"], " signal: ", d["signal"], " is_connected: ", em.fired.is_connected(cb))
	# (5) emit with no connections
	print("P5 nobody connections: ", em.nobody.get_connections().size())
	em.nobody.emit(5)
	print("P5 emit with no listener returned, no output above this line expected")
	# (6) typed parameter not checked at emit
	var t = Listener.new("T", log)
	em.nobody.connect(t.on_typed)
	em.nobody.emit("not an int")
	print("P6 handler saw: ", type_string(t.seen_type), " = ", t.seen_value, " log=", log)
	log.clear()
	# (7) duplicate connect
	var err: int = em.fired.connect(a.on_fired)
	print("P7 duplicate connect returned: ", err, " (ERR_INVALID_PARAMETER=", ERR_INVALID_PARAMETER, ") count now: ", em.fired.get_connections().size())
	# (8) released RefCounted listener
	var em2 = Emitter.new()
	var d = Listener.new("D", log)
	em2.fired.connect(d.on_fired)
	print("P8 before release count: ", em2.fired.get_connections().size())
	d = null
	print("P8 after release count: ", em2.fired.get_connections().size())
	em2.fired.emit(8)
	print("P8 emit after release: log=", log, " count: ", em2.fired.get_connections().size())
	# (6b) emit to a typed handler with a wrong type
	var em3 = Emitter.new()
	var e = Listener.new("E", log)
	em3.fired.connect(e.on_inner)  # on_inner(n: int)
	em3.fired.emit("str into int param")
	print("P6b typed handler got: ", log)
	# (extra) a Signal held as a field: does it keep the emitter alive / cycle?
	var holder = Listener.new("H", log)
	var em4 = Emitter.new()
	holder.em = em4.fired
	var wr = weakref(em4)
	em4 = null
	print("PX Signal-as-field keeps emitter alive: ", wr.get_ref() != null)
	holder = null
	print("PX after holder released: ", wr.get_ref() != null)
	# (extra) StringName payload equality
	var sn: StringName = &"tower_a"
	print("PX StringName == String: ", sn == "tower_a", " String == StringName: ", "tower_a" == sn, " typeof: ", type_string(typeof(sn)), " dict key hit: ", {&"tower_a": 1}.has("tower_a"))
	quit(0)
