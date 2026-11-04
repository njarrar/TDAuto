class_name EnemyRecord extends RefCounted
## An enemy definition.

var id: StringName = &""
var rationale: String = ""
var max_hp: float = 0.0
var move_speed: float = 0.0
var bounty: int = 0
var lives_cost: int = 0
var visual_key: String = ""
var tags: Array[StringName] = []


## Builds an enemy from a validated data dictionary.
static func from_dict(data: Dictionary) -> EnemyRecord:
	var record: EnemyRecord = EnemyRecord.new()
	record.id = StringName(String(data["id"]))
	record.rationale = String(data["rationale"])
	record.max_hp = float(data["max_hp"])
	record.move_speed = float(data["move_speed"])
	record.bounty = int(data["bounty"])
	record.lives_cost = int(data["lives_cost"])
	record.visual_key = String(data["visual_key"])
	for tag: Variant in (data["tags"] as Array):
		record.tags.append(StringName(String(tag)))
	return record


## A fresh copy of every field, JSON-native types only.
func to_dict() -> Dictionary:
	var tag_list: Array = []
	for tag: StringName in tags:
		tag_list.append(String(tag))
	return {
		"id": String(id),
		"rationale": rationale,
		"max_hp": max_hp,
		"move_speed": move_speed,
		"bounty": bounty,
		"lives_cost": lives_cost,
		"visual_key": visual_key,
		"tags": tag_list,
	}
