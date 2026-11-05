# PROTOTYPE - NOT FOR PRODUCTION. ADR checks stub. (ADR-0009 V6, ADR-0006 V6)
class_name Combat
extends RefCounted
## Holds enum SourceKind and takes a DamageEvent, while DamageEvent types a
## field Combat.SourceKind: the cyclic reference under test.

enum SourceKind { TOWER = 0, HERO = 1, BURST = 2 }

signal damage_applied(source_kind: SourceKind, amount: int)

var last_event: DamageEvent = null
var _targets: Callable


func _init(p_targets: Callable) -> void:
	_targets = p_targets


func apply(event: DamageEvent) -> void:
	last_event = event
	damage_applied.emit(event.source_kind, event.amount)
