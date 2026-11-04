class_name StageLook extends Node
## Root of the scene at StageRecord.scene_ref (ADR-0011 Decision 3). Three values, no drawing.
## The wrapper instantiates it in attach, hands the values to FieldBackdropModel, frees it.

## Field hue in degrees, 170 to 280.
@export var field_hue: float = 220.0
## Base value (brightness), 0.08 to 0.14.
@export var base_value: float = 0.10
## Grid tilt in degrees: 0, 15 or 30.
@export var grid_tilt_deg: int = 0


## True when every value is inside art bible section 6's ranges.
func is_in_range() -> bool:
	return StageLook.values_in_range(field_hue, base_value, grid_tilt_deg)


## Range check on plain values, used by the model and the content test.
static func values_in_range(hue: float, value: float, tilt: int) -> bool:
	if not is_finite(hue) or not is_finite(value):
		return false
	if hue < ViewStyles.FIELD_HUE_MIN or hue > ViewStyles.FIELD_HUE_MAX:
		return false
	if value < ViewStyles.BASE_VALUE_MIN or value > ViewStyles.BASE_VALUE_MAX:
		return false
	return ViewStyles.GRID_TILTS.has(tilt)
