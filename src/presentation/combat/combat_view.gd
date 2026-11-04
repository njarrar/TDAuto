class_name CombatView extends Node2D
## Drawer 4: damaged cores, slow lines, tracers, splash rings, flashes, death discs, spokes.

var model: CombatViewModel = null


func _draw() -> void:
	if model == null:
		return
	for i: int in range(model.core_n):
		var missing: float = 1.0 - model.core_frac[i]
		if missing > 0.0:
			draw_circle(model.core_pos[i], ViewStyles.ENEMY_RADIUS * missing, ViewStyles.CORE_DAMAGED)
	if model.slow_points.size() > 0:
		draw_multiline(model.slow_points, ViewStyles.SLOW_LINE, ViewStyles.stroke(2.0), false)
	if model.tower_lines.size() > 0:
		draw_multiline(model.tower_lines, ViewStyles.TRACER_TOWER, ViewStyles.stroke(2.0), false)
	if model.hero_lines.size() > 0:
		draw_multiline(model.hero_lines, ViewStyles.TRACER_HERO, ViewStyles.stroke(2.0), false)
	if model.spoke_lines.size() > 0:
		draw_multiline(model.spoke_lines, ViewStyles.TRACER_BURST, ViewStyles.stroke(2.0), false)
	for i: int in range(model.ring_centres.size()):
		var r: float = model.ring_radii[i]
		draw_arc(model.ring_centres[i], r, 0.0, TAU, ViewStyles.ring_points(r), ViewStyles.TRACER_TOWER,
				ViewStyles.stroke(2.0), false)
	for i: int in range(model.flash_centres.size()):
		var f: Color = ViewStyles.FLASH
		f.a = model.flash_alphas[i]
		draw_circle(model.flash_centres[i], ViewStyles.ENEMY_RADIUS, f)
	for i: int in range(model.death_centres.size()):
		var d: Color = ViewStyles.DEATH_DISC
		d.a = model.death_alphas[i]
		draw_circle(model.death_centres[i], ViewStyles.DEATH_RADIUS, d)
