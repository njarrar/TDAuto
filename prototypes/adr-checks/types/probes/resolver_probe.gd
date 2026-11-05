# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0008 V5, V6: the InputResolver stub itself.
extends "res://types/probes/probe_base.gd"


func run() -> void:
	var r: InputResolver = InputResolver.create(15.0, 28.0)
	check("ADR-0008-V5-resolver", r != null and not r.has_dev_error(), "create() ok=%s dev_error valid=%s" % [r != null, r.has_dev_error()], "create() through InputResolver.new(a, b, c); default Callable() invalid")
	for i in 4:
		r.register(i + 1, InputResolver.Accepts.TAP)
	r.remove_target_at(1)
	var ids: Array[int] = r.target_ids()
	check("ADR-0008-V6-remove_at", str(ids) == "[1, 3, 4]", "ids after remove_at(1): %s" % [ids], "[1, 3, 4] (order kept)")
	var typed_ok: bool = r._targets.is_typed() and r._targets.get_typed_script() == InputResolver.Target
	check("ADR-0008-V6-inner-typed", typed_ok, "is_typed=%s typed_script_is_Target=%s" % [r._targets.is_typed(), r._targets.get_typed_script() == InputResolver.Target], "Array[Target] with inner class element type")
	done = true
