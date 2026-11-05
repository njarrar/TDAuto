class_name HeroRecord extends RefCounted
## The hero definition. `burst_id` names a BurstRecord.

var id: StringName = &""
var rationale: String = ""
var damage: float = 0.0
var attack_interval: float = 0.0
var leash_radius: float = 0.0
var walk_speed: float = 0.0
var burst_id: StringName = &""
var visual_key: String = ""


## Builds the hero from a validated data dictionary.
static func from_dict(data: Dictionary) -> HeroRecord:
	var record: HeroRecord = HeroRecord.new()
	record.id = StringName(String(data["id"]))
	record.rationale = String(data["rationale"])
	record.damage = float(data["damage"])
	record.attack_interval = float(data["attack_interval"])
	record.leash_radius = float(data["leash_radius"])
	record.walk_speed = float(data["walk_speed"])
	record.burst_id = StringName(String(data["burst_id"]))
	record.visual_key = String(data["visual_key"])
	return record


## A fresh copy of every field, JSON-native types only.
func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"rationale": rationale,
		"damage": damage,
		"attack_interval": attack_interval,
		"leash_radius": leash_radius,
		"walk_speed": walk_speed,
		"burst_id": String(burst_id),
		"visual_key": visual_key,
	}
