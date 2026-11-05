class_name InputRecord extends RefCounted
## The one Input record. Read directly, not through the stat accessor.
## `left_handed` and `reduce_motion` are data flags until Settings exists.

var id: StringName = &""
var rationale: String = ""
var drag_slop: float = 0.0
var tap_slop: float = 0.0
var edge_reject_margin: float = 0.0
var left_handed: bool = false
var reduce_motion: bool = false


## Builds the Input record from a validated data dictionary.
static func from_dict(data: Dictionary) -> InputRecord:
	var record: InputRecord = InputRecord.new()
	record.id = StringName(String(data["id"]))
	record.rationale = String(data["rationale"])
	record.drag_slop = float(data["drag_slop"])
	record.tap_slop = float(data["tap_slop"])
	record.edge_reject_margin = float(data["edge_reject_margin"])
	record.left_handed = bool(data["left_handed"])
	record.reduce_motion = bool(data["reduce_motion"])
	return record


## A fresh copy of every field, JSON-native types only.
func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"rationale": rationale,
		"drag_slop": drag_slop,
		"tap_slop": tap_slop,
		"edge_reject_margin": edge_reject_margin,
		"left_handed": left_handed,
		"reduce_motion": reduce_motion,
	}
