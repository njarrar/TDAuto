class_name TowerView extends Node2D
## Drawer 2: range ring request, then tower bodies, level insets and state rings.

var model: TowerViewModel = null


func _draw() -> void:
	if model == null:
		return
	if model.ring_slot >= 0:
		draw_arc(model.centres[model.ring_slot], model.ring_radius, 0.0, TAU,
				ViewStyles.ring_points(model.ring_radius), ViewStyles.RING_RANGE, ViewStyles.stroke(2.0), false)
	for i: int in range(model.slot_n):
		if model.present[i] == 0:
			continue
		var c: Vector2 = model.centres[i]
		var col: Color = ViewStyles.color_of(model.keys[i])
		draw_circle(c, ViewStyles.SLOT_RADIUS - 8.0, col)
		for lv: int in range(model.levels[i]):
			draw_circle(c + Vector2(float(lv) * 10.0 - 5.0, 0.0), 3.0, ViewStyles.KEYLINE)
		var ring: Color = ViewStyles.RING_READY if model.cooling[i] <= 0.0 else ViewStyles.RING_COOLING
		var sweep: float = TAU if model.cooling[i] <= 0.0 else TAU * (1.0 - model.cooling[i])
		draw_arc(c, ViewStyles.SLOT_RADIUS - 2.0, -PI * 0.5, -PI * 0.5 + sweep,
				ViewStyles.ring_points(ViewStyles.SLOT_RADIUS), ring, ViewStyles.stroke(2.0), false)
