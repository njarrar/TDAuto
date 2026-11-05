# PROTOTYPE - NOT FOR PRODUCTION. ADR checks stub. (ADR-0009 V6)
class_name DamageEvent
extends RefCounted

var source_kind: Combat.SourceKind = Combat.SourceKind.TOWER
var amount: int = 0


static func make(p_kind: Combat.SourceKind, p_amount: int) -> DamageEvent:
	var e: DamageEvent = DamageEvent.new()
	e.source_kind = p_kind
	e.amount = p_amount
	return e
