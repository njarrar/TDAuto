# PROTOTYPE - NOT FOR PRODUCTION. ADR checks: ADR-0008 V1 (d), no self-hold.
# A listener drops the emitter's last strong reference while the emitter's
# own method is still emitting, and that method has no `var _hold := self`.
# This may crash the engine (use after free), so it runs alone. A crash
# shows in run_all.sh as an exit code and no END line; that is the result.
# Run: godot --headless --path . -s res://check_signals_nohold.gd
extends SceneTree

const Report := preload("res://types/report.gd")

var _r: Report = Report.new()


class Holder extends RefCounted:
	var emitter: Variant = null


class NoHoldEmitter extends RefCounted:
	signal fired

	func fire(state: Dictionary) -> void:
		fired.emit()
		state["after_emit"] = true


class Dropper extends RefCounted:
	var holder: Holder

	func on_fired() -> void:
		holder.emitter = null


class Trigger extends RefCounted:
	signal go


func _initialize() -> void:
	var holder: Holder = Holder.new()
	var em: NoHoldEmitter = NoHoldEmitter.new()
	var w: WeakRef = weakref(em)
	var dropper: Dropper = Dropper.new()
	dropper.holder = holder
	em.fired.connect(dropper.on_fired)
	var state: Dictionary = {"after_emit": false}
	var trig: Trigger = Trigger.new()
	trig.go.connect(Callable(em, "fire").bind(state))
	holder.emitter = em
	em = null
	print("NOTE ADR-0008-V1d-nohold starting; a crash here is the result")
	var e0: int = _r.errors()
	trig.go.emit()
	var errs: String = "n/a" if e0 < 0 else "+" + str(_r.errors() - e0)
	_r.record("ADR-0008-V1d-nohold", "no crash; finished after emit=%s freed after=%s errors=%s %s" % [state["after_emit"], w.get_ref() == null, errs, _r.last_error()], "record (ADR asks what happens; a crash is also a result)")
	_r.finish(self, "check_signals_nohold.gd")
