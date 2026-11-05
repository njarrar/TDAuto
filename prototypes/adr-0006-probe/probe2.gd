extends SceneTree
const FlowLike = preload("res://flow_like.gd")
const L = preload("res://listener2.gd")
func _init() -> void:
	var log: Array[String] = []
	var f = FlowLike.new()
	var l = L.new(log)
	# P9: does a conversion failure on listener 1 abort listener 2?
	f.gold_changed.connect(l.on_int)
	f.gold_changed.connect(l.on_untyped)
	f.gold_changed.emit("bad")
	print("P9 after String into int (typed first, untyped second): ", log); log.clear()
	# P10: float into int parameter
	f.gold_changed.emit(2.75)
	print("P10 float 2.75 into int param: ", log); log.clear()
	# P11: out-of-range int into enum-typed handler
	f.phase_changed.connect(l.on_phase)
	f.phase_changed.emit(FlowLike.Phase.FATAL)
	f.phase_changed.emit(99)
	print("P11 enum-typed handler, FATAL then 99: ", log); log.clear()
	# P12: argument count mismatch at emit
	var g = FlowLike.new()
	g.gold_changed.connect(l.on_two)
	g.gold_changed.emit(1)
	print("P12 one arg into two-param handler: ", log); log.clear()
	# P13: emit with too many args vs declaration
	f.gold_changed.disconnect(l.on_int)
	f.gold_changed.emit(1, 2)
	print("P13 two args into one-param signal (untyped handler): ", log); log.clear()
	quit(0)
