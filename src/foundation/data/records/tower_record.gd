class_name TowerRecord extends RefCounted
## A tower definition: tags and its levels (levels are numbered from 1).

var id: StringName = &""
var rationale: String = ""
var tags: Array[StringName] = []
var levels: Array[TowerLevel] = []


## Builds a tower from a validated data dictionary.
static func from_dict(data: Dictionary) -> TowerRecord:
	var record: TowerRecord = TowerRecord.new()
	record.id = StringName(String(data["id"]))
	record.rationale = String(data["rationale"])
	for tag: Variant in (data["tags"] as Array):
		record.tags.append(StringName(String(tag)))
	for level_data: Variant in (data["levels"] as Array):
		record.levels.append(TowerLevel.from_dict(level_data as Dictionary))
	return record


## True if the tower carries this tag.
func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


## A fresh copy of every field, JSON-native types only.
func to_dict() -> Dictionary:
	var tag_list: Array = []
	for tag: StringName in tags:
		tag_list.append(String(tag))
	var level_list: Array = []
	for level: TowerLevel in levels:
		level_list.append(level.to_dict())
	return {
		"id": String(id),
		"rationale": rationale,
		"tags": tag_list,
		"levels": level_list,
	}
