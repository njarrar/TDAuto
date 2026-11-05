class_name WaveRecord extends RefCounted
## A wave definition: its groups and the time before the next wave.

var id: StringName = &""
var rationale: String = ""
var groups: Array[WaveGroup] = []
## Seconds before the next wave; ignored on the last wave.
var intermission_duration: float = 0.0
## Multiplies every enemy's max_hp in this wave (Enemy & Wave Rule 5, playtest 2026-11-05).
var hp_scale: float = 1.0


## Builds a wave from a validated data dictionary.
static func from_dict(data: Dictionary) -> WaveRecord:
	var record: WaveRecord = WaveRecord.new()
	record.id = StringName(String(data["id"]))
	record.rationale = String(data["rationale"])
	record.intermission_duration = float(data["intermission_duration"])
	record.hp_scale = float(data.get("hp_scale", 1.0))
	for group_data: Variant in (data["groups"] as Array):
		record.groups.append(WaveGroup.from_dict(group_data as Dictionary))
	return record


## A fresh copy of every field, JSON-native types only.
func to_dict() -> Dictionary:
	var group_list: Array = []
	for group: WaveGroup in groups:
		group_list.append(group.to_dict())
	return {
		"id": String(id),
		"rationale": rationale,
		"groups": group_list,
		"intermission_duration": intermission_duration,
		"hp_scale": hp_scale,
	}
