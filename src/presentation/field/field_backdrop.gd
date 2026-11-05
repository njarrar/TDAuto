class_name FieldBackdrop extends Node2D
## Drawer 1: field fill, grid, path, slots, exit chevrons. Reads only its model's buffers.

var model: FieldBackdropModel = null


func _draw() -> void:
	if model == null:
		return
	draw_rect(Rect2(0.0, 0.0, FieldBounds.WIDTH, FieldBounds.HEIGHT), model.field_color)
	draw_multiline(model.grid_lines, ViewStyles.GRID_LINE, ViewStyles.stroke(0.0), false)
	_quads(model.edge_quads, ViewStyles.PATH_EDGE)
	_quads(model.body_quads, ViewStyles.PATH_BODY)
	if model.danger_on:
		var tint: Color = ViewStyles.DANGER_TINT
		tint.a *= model.danger_alpha
		_quads(model.edge_quads, tint)
	var pop: float = model.leak_pop
	for i: int in range(model.slot_free.size()):
		if model.slot_free[i] != 0:
			draw_arc(model.slot_centres[i], ViewStyles.SLOT_RADIUS, 0.0, TAU,
					ViewStyles.ring_points(ViewStyles.SLOT_RADIUS), ViewStyles.SLOT_RING, ViewStyles.stroke(2.0), false)
	var d: Vector2 = model.exit_dir
	var perp: Vector2 = Vector2(-d.y, d.x)
	var tip: Vector2 = model.exit_pos - d * 20.0
	var base: Vector2 = tip - d * 18.0
	var col: Color = ViewStyles.CHEVRON
	col.a = clampf(col.a + pop, 0.0, 1.0)
	draw_multiline(PackedVector2Array([base + perp * 18.0, tip, tip, base - perp * 18.0]), col,
			ViewStyles.stroke(3.0), false)


func _quads(pts: PackedVector2Array, color: Color) -> void:
	var colors: PackedColorArray = PackedColorArray([color, color, color, color])
	var quad: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	@warning_ignore("integer_division")
	var quad_n: int = pts.size() / 4
	for i: int in range(quad_n):
		for j: int in range(4):
			quad[j] = pts[i * 4 + j]
		draw_primitive(quad, colors, PackedVector2Array())
