# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0008 V6: FakeResolver extends InputResolver.
extends "res://types/probes/probe_base.gd"


func run() -> void:
	var f: FakeResolver = FakeResolver.new(15.0, 28.0)
	check("ADR-0008-V6-fake-super", f.min_radius == 15.0 and f.max_radius == 28.0, "min=%s max=%s" % [f.min_radius, f.max_radius], "15.0 and 28.0 (super(a, b) forwarded)")
	var hit: int = f.hit_test(0.0, 0.0)
	check("ADR-0008-V6-fake-override", hit == 7 and f.calls == 1, "hit_test=%d calls=%d" % [hit, f.calls], "7 and 1 (typed override with explicit return)")
	var as_base: InputResolver = f
	check("ADR-0008-V6-fake-as-base", as_base.hit_test(0.0, 0.0) == 7, "through base type: %d" % as_base.hit_test(0.0, 0.0), "7 (override called through the base type)")
	var m: InputResolver = FakeResolver.create(1.0, 2.0)
	var plain: bool = not (m is FakeResolver) and m.get_script() == InputResolver
	check("ADR-0008-V6-fake-create", plain, "is FakeResolver=%s script is InputResolver=%s" % [m is FakeResolver, m.get_script() == InputResolver], "plain InputResolver (statics are not virtual)")
	done = true
