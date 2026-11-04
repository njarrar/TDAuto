class_name PinShape extends RefCounted
## A forbidden pin shape: a segment from `a` to `b` with a radius, for one hand
## or both. A disc has `a` equal to `b`. Points are [x, y] float64 pairs.

var a: PackedFloat64Array = PackedFloat64Array()
var b: PackedFloat64Array = PackedFloat64Array()
var radius: float = 0.0
## "right", "left" or "both".
var hand: StringName = &""


## Builds a shape from a validated data dictionary.
static func from_dict(data: Dictionary) -> PinShape:
	var shape: PinShape = PinShape.new()
	var point_a: Array = data["a"]
	var point_b: Array = data["b"]
	shape.a = PackedFloat64Array([float(point_a[0]), float(point_a[1])])
	shape.b = PackedFloat64Array([float(point_b[0]), float(point_b[1])])
	shape.radius = float(data["radius"])
	shape.hand = StringName(String(data["hand"]))
	return shape


## A fresh copy of every field, JSON-native types only.
func to_dict() -> Dictionary:
	return {
		"a": Array(a),
		"b": Array(b),
		"radius": radius,
		"hand": String(hand),
	}
