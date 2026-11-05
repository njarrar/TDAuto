# PROTOTYPE - NOT FOR PRODUCTION. ADR checks probe. ADR-0009 V6 and ADR-0006 V6: Combat and DamageEvent cycle.
extends "res://types/probes/probe_base.gd"


func run() -> void:
	var c: Combat = Combat.new(Callable())
	var got: Array = []
	c.damage_applied.connect(func(k: Combat.SourceKind, a: int) -> void: got.append([k, a]))
	c.apply(DamageEvent.make(Combat.SourceKind.BURST, 5))
	check("ADR-0009-V6-run", got == [[2, 5]], "damage_applied got %s" % [got], "[[2, 5]], no cyclic-reference error")
	check("ADR-0006-V6-damage_applied", got == [[2, 5]], "got %s" % [got], "enum SourceKind signal parameter delivers 2 (BURST)")
	var e: Enemy = Enemy.new(3, &"grunt")
	var ok_t: bool = e is Targetable and e.health != null and e.status != null and e.spawn_id == 3
	check("ADR-0009-V6-targetable", ok_t, "Enemy is Targetable=%s health=%s status=%s spawn_id=%d" % [e is Targetable, e.health != null, e.status != null, e.spawn_id], "Enemy extends Targetable; Health and Status fields set")
	done = true
