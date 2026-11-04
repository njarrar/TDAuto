extends SceneTree
## ADR-0001 validation probe 2 (godot-specialist, 2026-11-05).

class Sim extends RefCounted:
	signal hit
	var other: Sim
	var back: RefCounted
	var cb: Callable
	func on_hit() -> void: pass
	func connect_lambda(src: Sim) -> void:
		src.hit.connect(func() -> void: on_hit())

class Bag extends RefCounted:
	var a: Sim
	var b: Sim

class Statics extends RefCounted:
	static var count := 0

class Child extends Node2D:
	var battle: RefCounted
	func _process(_d: float) -> void: print("PROBE|child_process frame=", Engine.get_process_frames())
	func _input(e: InputEvent) -> void: print("PROBE|child_input ", e.get_class(), " frame=", Engine.get_process_frames())

class Parent extends Node:
	var child: Child
	var frame := 0
	var w: WeakRef
	func _process(_d: float) -> void:
		frame += 1
		if frame == 2:
			var t := InputEventScreenTouch.new(); t.pressed = true; t.index = 0
			Input.parse_input_event(t)
			var d := InputEventScreenDrag.new(); d.index = 0
			Input.parse_input_event(d)
			remove_child(child); child.free(); child = null
			print("PROBE|freed_child_in_parent_process frame=", Engine.get_process_frames(), " battle_alive=", w.get_ref() != null)
		if frame == 4:
			print("PROBE|frames_after_free_ok")
			get_tree().quit()

func out(s: String) -> void: print("PROBE|", s)

func _initialize() -> void:
	# A. Cycle via typed fields (sim holds a back-reference).
	var bag := Bag.new(); bag.a = Sim.new(); bag.b = Sim.new()
	bag.a.back = bag
	var wb: WeakRef = weakref(bag); bag = null
	out("cycle_backref_leaks=%s" % [wb.get_ref() != null])
	# B. Two sims both held, connected to each other by method Callables: no leak.
	bag = Bag.new(); bag.a = Sim.new(); bag.b = Sim.new()
	bag.a.hit.connect(bag.b.on_hit); bag.b.hit.connect(bag.a.on_hit)
	wb = weakref(bag); var wa: WeakRef = weakref(bag.a); bag = null
	out("mutual_method_connections_leak=%s sim_leak=%s" % [wb.get_ref() != null, wa.get_ref() != null])
	# C. Lambda in a RefCounted connected to a sibling's signal.
	bag = Bag.new(); bag.a = Sim.new(); bag.b = Sim.new()
	bag.b.connect_lambda(bag.a)
	wa = weakref(bag.a); var wbb: WeakRef = weakref(bag.b); bag = null
	out("lambda_self_connection_leaks a=%s b=%s" % [wa.get_ref() != null, wbb.get_ref() != null])
	# D. bind(): target and a bound RefCounted argument.
	var s := Sim.new(); var arg := Sim.new(); var holder := Sim.new()
	holder.cb = s.on_hit.bind(arg)
	var ws: WeakRef = weakref(s); var warg: WeakRef = weakref(arg); s = null; arg = null
	out("bind_keeps_target=%s bind_keeps_bound_arg=%s" % [ws.get_ref() != null, warg.get_ref() != null])
	# D2. A sim storing its own method Callable (self-reference by Callable).
	s = Sim.new(); s.cb = s.on_hit; ws = weakref(s); s = null
	out("self_method_callable_leaks=%s" % [ws.get_ref() != null])
	# E. Callable on a freed Node.
	var n := Node.new(); var nc := Callable(n, &"queue_free"); n.free()
	out("freed_node_callable_is_valid=%s is_null=%s" % [nc.is_valid(), nc.is_null()])
	# F. Static var survives instances (a 'builder holds nothing' hole).
	Statics.count += 1
	out("static_var_persists=%d" % [Statics.count])
	# G. Broken-script scene preloaded by a script that still loads.
	var broken: Script = load("res://adr0001_checks/k_app_root_broken_preload.gd")
	out("broken_preload_host_can_instantiate=%s" % [broken.can_instantiate()])
	var inst: Node = (load("res://adr0001_checks/broken_scene.tscn") as PackedScene).instantiate()
	out("broken_scene_instance=%s script=%s" % [inst.get_class(), inst.get_script()])
	inst.free()
	var miss: Script = load("res://adr0001_checks/k_missing_preload.gd")
	out("missing_preload_host_loaded=%s" % [miss != null and miss.can_instantiate()])
	# H. free() of a child during the parent's _process with input queued.
	var p := Parent.new(); p.child = Child.new()
	var battle := Sim.new(); p.child.battle = battle; p.w = weakref(battle); battle = null
	root.add_child(p); p.add_child(p.child)
