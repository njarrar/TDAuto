class_name Combat extends RefCounted
enum SourceKind { TOWER, HERO, BURST }
signal damage_applied(event: DamageEvent, applied: float, killed: bool)
signal attack_fired(source_kind: SourceKind, source_id: StringName)
var _by_kind: Array[float] = [0.0, 0.0, 0.0]
var _by_id: Dictionary[StringName, float] = {}
func deliver(event: DamageEvent) -> float:
	if event == null or event.target == null or event.target.health == null: return 0.0
	if not is_finite(event.amount) or event.amount < 0.0: return 0.0
	var applied: float = minf(event.amount, event.target.health.hp)
	event.target.health.hp -= applied
	_by_kind[event.source_kind] += applied
	_by_id[event.source_id] = _by_id.get(event.source_id, 0.0) + applied
	damage_applied.emit(event, applied, event.target.health.hp <= 0.0)
	return applied
func kind_name(k: SourceKind) -> String: return SourceKind.keys()[k]
