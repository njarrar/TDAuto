# PROTOTYPE - NOT FOR PRODUCTION. ADR-0003 device spike.
# Draws the 540x960 field, the 36-unit side edge margins, the safe-area insets
# (from the ADR's formula, in field units), five crosshair targets at known field
# positions (SP6) and a circle under each touch that is down.
extends Node2D

const AdapterStandIn := preload("res://adapter_stand_in.gd")
const FIELD: Vector2 = Vector2(540.0, 960.0)
const EDGE_REJECT_MARGIN: float = 36.0

var adapter: AdapterStandIn = null
## Insets in field units: top, bottom, left, right.
var insets: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


## The crosshair targets, in field units. The README lists the same points.
func targets() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(270.0, 300.0),
		Vector2(36.0, 300.0),
		Vector2(504.0, 300.0),
		Vector2(270.0, 825.0),
		Vector2(36.0, 825.0),
	])


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, FIELD), Color(0.12, 0.13, 0.16))
	draw_rect(Rect2(Vector2.ZERO, FIELD), Color(0.85, 0.85, 0.85), false, 2.0)
	var margin_color: Color = Color(1.0, 1.0, 0.0, 0.4)
	draw_line(Vector2(EDGE_REJECT_MARGIN, 0.0), Vector2(EDGE_REJECT_MARGIN, FIELD.y), margin_color, 1.0)
	draw_line(Vector2(FIELD.x - EDGE_REJECT_MARGIN, 0.0), Vector2(FIELD.x - EDGE_REJECT_MARGIN, FIELD.y), margin_color, 1.0)
	var inset_color: Color = Color(1.0, 0.0, 1.0, 0.3)
	if insets[0] > 0.0:
		draw_rect(Rect2(0.0, 0.0, FIELD.x, insets[0]), inset_color)
	if insets[1] > 0.0:
		draw_rect(Rect2(0.0, FIELD.y - insets[1], FIELD.x, insets[1]), inset_color)
	if insets[2] > 0.0:
		draw_rect(Rect2(0.0, 0.0, insets[2], FIELD.y), inset_color)
	if insets[3] > 0.0:
		draw_rect(Rect2(FIELD.x - insets[3], 0.0, insets[3], FIELD.y), inset_color)
	var cross_color: Color = Color(0.3, 1.0, 0.4)
	for p: Vector2 in targets():
		draw_line(p - Vector2(14.0, 0.0), p + Vector2(14.0, 0.0), cross_color, 2.0)
		draw_line(p - Vector2(0.0, 14.0), p + Vector2(0.0, 14.0), cross_color, 2.0)
		draw_arc(p, 10.0, 0.0, TAU, 24, cross_color, 1.0)
		draw_string(font, p + Vector2(8.0, -16.0), "(%d,%d)" % [int(p.x), int(p.y)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, cross_color)
	if adapter == null:
		return
	for i: int in adapter.touch_points:
		var tp: Vector2 = adapter.touch_points[i]
		draw_circle(tp, 22.0, Color(0.2, 0.6, 1.0, 0.5))
		draw_string(font, tp + Vector2(24.0, 0.0), "i=%d" % i, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color.WHITE)
	if adapter.has_press:
		var lp: Vector2 = adapter.last_press
		draw_line(lp - Vector2(6.0, 6.0), lp + Vector2(6.0, 6.0), Color.RED, 2.0)
		draw_line(lp - Vector2(6.0, -6.0), lp + Vector2(6.0, -6.0), Color.RED, 2.0)
