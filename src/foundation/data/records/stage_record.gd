class_name StageRecord extends RefCounted
## A stage definition. Geometry is stored as float64, x and y interleaved, so no
## 32-bit Vector2 rounding enters the data. Consumers convert at use.

## Used when a stage file leaves out sell_refund_percent (an optional field).
const DEFAULT_SELL_REFUND_PERCENT: int = 70

var id: StringName = &""
var rationale: String = ""
## Path to the stage's look-only scene. The one path in the catalogue.
var scene_ref: String = ""
var wave_ids: Array[StringName] = []
var starting_gold: int = 0
## Percent of a tower's total spend paid back when it is sold (Tower GDD Rule 4).
var sell_refund_percent: int = DEFAULT_SELL_REFUND_PERCENT
var starting_lives: int = 0
var early_call_seconds_per_gold: float = 0.0
## [x0, y0, x1, y1, ...]
var path_points: PackedFloat64Array = PackedFloat64Array()
## [x0, y0, x1, y1, ...]
var slot_positions: PackedFloat64Array = PackedFloat64Array()
var path_width: float = 0.0
var requires_bend: bool = false
## [x, y]
var hero_start: PackedFloat64Array = PackedFloat64Array()
## [min_x, min_y, max_x, max_y]
var pin_rect: PackedFloat64Array = PackedFloat64Array()
var pin_exclusion: Array[PinShape] = []


## Builds a stage from a validated data dictionary.
static func from_dict(data: Dictionary) -> StageRecord:
	var record: StageRecord = StageRecord.new()
	record.id = StringName(String(data["id"]))
	record.rationale = String(data["rationale"])
	record.scene_ref = String(data["scene_ref"])
	for wave_id: Variant in (data["wave_ids"] as Array):
		record.wave_ids.append(StringName(String(wave_id)))
	record.starting_gold = int(data["starting_gold"])
	record.sell_refund_percent = int(data.get("sell_refund_percent", DEFAULT_SELL_REFUND_PERCENT))
	record.starting_lives = int(data["starting_lives"])
	record.early_call_seconds_per_gold = float(data["early_call_seconds_per_gold"])
	record.path_points = _flatten(data["path_points"] as Array)
	record.slot_positions = _flatten(data["slot_positions"] as Array)
	record.path_width = float(data["path_width"])
	record.requires_bend = bool(data["requires_bend"])
	var start: Array = data["hero_start"]
	record.hero_start = PackedFloat64Array([float(start[0]), float(start[1])])
	var rect: Dictionary = data["pin_rect"]
	var low: Array = rect["min"]
	var high: Array = rect["max"]
	record.pin_rect = PackedFloat64Array([float(low[0]), float(low[1]), float(high[0]), float(high[1])])
	for shape_data: Variant in (data["pin_exclusion"] as Array):
		record.pin_exclusion.append(PinShape.from_dict(shape_data as Dictionary))
	return record


static func _flatten(points: Array) -> PackedFloat64Array:
	var coords: PackedFloat64Array = PackedFloat64Array()
	for point_value: Variant in points:
		var pair: Array = point_value
		coords.append(float(pair[0]))
		coords.append(float(pair[1]))
	return coords


## Number of points in `path_points`.
func path_point_count() -> int:
	return path_points.size() >> 1


## Number of tower slots.
func slot_count() -> int:
	return slot_positions.size() >> 1


## A fresh copy of every field, JSON-native types only.
func to_dict() -> Dictionary:
	var wave_list: Array = []
	for wave_id: StringName in wave_ids:
		wave_list.append(String(wave_id))
	var shape_list: Array = []
	for shape: PinShape in pin_exclusion:
		shape_list.append(shape.to_dict())
	return {
		"id": String(id),
		"rationale": rationale,
		"scene_ref": scene_ref,
		"wave_ids": wave_list,
		"starting_gold": starting_gold,
		"sell_refund_percent": sell_refund_percent,
		"starting_lives": starting_lives,
		"early_call_seconds_per_gold": early_call_seconds_per_gold,
		"path_points": Array(path_points),
		"slot_positions": Array(slot_positions),
		"path_width": path_width,
		"requires_bend": requires_bend,
		"hero_start": Array(hero_start),
		"pin_rect": Array(pin_rect),
		"pin_exclusion": shape_list,
	}
