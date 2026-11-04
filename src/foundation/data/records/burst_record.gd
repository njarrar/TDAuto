class_name BurstRecord extends RefCounted
## The hero's burst definition.

var id: StringName = &""
var rationale: String = ""
var damage: float = 0.0
var radius: float = 0.0
var reach: float = 0.0
var cooldown: float = 0.0
var telegraph_duration: float = 0.0


## Builds a burst from a validated data dictionary.
static func from_dict(data: Dictionary) -> BurstRecord:
	var record: BurstRecord = BurstRecord.new()
	record.id = StringName(String(data["id"]))
	record.rationale = String(data["rationale"])
	record.damage = float(data["damage"])
	record.radius = float(data["radius"])
	record.reach = float(data["reach"])
	record.cooldown = float(data["cooldown"])
	record.telegraph_duration = float(data["telegraph_duration"])
	return record


## A fresh copy of every field, JSON-native types only.
func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"rationale": rationale,
		"damage": damage,
		"radius": radius,
		"reach": reach,
		"cooldown": cooldown,
		"telegraph_duration": telegraph_duration,
	}
