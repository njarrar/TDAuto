extends SceneTree
## ADR-0001 probe: Callable and signal lifetime of RefCounted targets, free() vs
## queue_free() timing, is_valid() on an unset Callable, push_error survival.

class Helper extends RefCounted:
	signal fired
	var name := "helper"
	func hello() -> String: return "hi"

class Holder extends RefCounted:
	var cb: Callable
	var unset: Callable

func _init() -> void:
	var out := func(s: String) -> void: print("PROBE|%s" % s)
	# 1. A method Callable does not keep its RefCounted target alive.
	var h := Helper.new()
	var holder := Holder.new()
	holder.cb = h.hello
	var w: WeakRef = weakref(h)
	h = null
	out.call("callable_keeps_target_alive=%s is_valid=%s" % [w.get_ref() != null, holder.cb.is_valid()])
	# 2. A signal connection does not keep the emitter's listener alive either.
	var emitter := Helper.new()
	var listener := Helper.new()
	emitter.fired.connect(listener.hello)
	var wl: WeakRef = weakref(listener)
	listener = null
	out.call("signal_connection_keeps_listener_alive=%s connections=%d" % [wl.get_ref() != null, emitter.fired.get_connections().size()])
	emitter.fired.emit()
	out.call("emit_to_dead_listener_survived=true")
	# 3. is_valid() guard on an unset Callable; call_deferred-free guard.
	out.call("unset_callable_is_valid=%s is_null=%s" % [holder.unset.is_valid(), holder.unset.is_null()])
	# 4. free() vs queue_free(): is the node gone before the frame ends?
	var n := Node.new()
	root.add_child(n)
	var wn: WeakRef = weakref(n)
	n.queue_free()
	out.call("queue_free_gone_immediately=%s" % [not is_instance_valid(wn.get_ref())])
	var n2 := Node.new()
	root.add_child(n2)
	var wn2: WeakRef = weakref(n2)
	root.remove_child(n2)
	n2.free()
	out.call("remove_child_free_gone_immediately=%s" % [not is_instance_valid(wn2.get_ref())])
	# 5. A RefCounted held only by a Node's script var is released with the node.
	var holder2 := Holder.new()
	var wh: WeakRef = weakref(holder2)
	var n3 := Node.new()
	n3.set_meta("battle", holder2)
	holder2 = null
	out.call("meta_holds_refcounted=%s" % [wh.get_ref() != null])
	n3.free()
	out.call("released_with_node_free=%s" % [wh.get_ref() == null])
	# 6. push_error in a release-like run prints and continues.
	push_error("PROBE|push_error_continues")
	out.call("after_push_error=true")
	# 7. Calling a method Callable whose target died: the GDD says it aborts the caller.
	_call_dead(holder)
	out.call("reached_after_dead_call_in_same_function=UNREACHED_IF_ABORTED")
	quit()

func _call_dead(holder: Holder) -> void:
	var r: Variant = holder.cb.call()
	print("PROBE|dead_call_returned=%s" % [r])
	print("PROBE|line_after_dead_call_ran=true")
