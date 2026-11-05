class_name DamageEvent extends RefCounted
## One hit on one victim (ADR-0009 Decision 4). Callers make one per victim;
## Combat never stores one.

var target: Targetable
var amount: float
var source_kind: Combat.SourceKind
## The dealer's definition ID.
var source_id: StringName


## Builds an event.
static func make(p_target: Targetable, p_amount: float, p_source_kind: Combat.SourceKind, p_source_id: StringName) -> DamageEvent:
	var event: DamageEvent = DamageEvent.new()
	event.target = p_target
	event.amount = p_amount
	event.source_kind = p_source_kind
	event.source_id = p_source_id
	return event
