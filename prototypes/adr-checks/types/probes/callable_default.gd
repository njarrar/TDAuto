# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0008 V5: Callable() as a default argument.
extends "res://types/probes/probe_base.gd"


class Sink extends RefCounted:
	var cb: Callable

	func _init(p_a: float, p_cb: Callable = Callable()) -> void:
		cb = p_cb

	static func create(p_a: float, p_cb: Callable = Callable()) -> Sink:
		return Sink.new(p_a, p_cb)


func run() -> void:
	var s: Sink = Sink.create(1.0)
	var t: Sink = Sink.new(1.0)
	var ok: bool = not s.cb.is_valid() and not t.cb.is_valid() and not Callable().is_valid()
	check("ADR-0008-V5", ok, "create().cb valid=%s new().cb valid=%s Callable().is_valid()=%s" % [s.cb.is_valid(), t.cb.is_valid(), Callable().is_valid()], "defaults parse; is_valid() false")
	done = true
