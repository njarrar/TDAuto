class_name HeroView extends Node2D
## Drawer 5: zones (leash, reach, ghost, preview, reticle, kill marks), then the glow texture,
## then the hero body and burst ring.

var model: HeroViewModel = null
var _glow: GradientTexture2D = null


func _ready() -> void:
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 0.8))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_glow = GradientTexture2D.new()
	_glow.gradient = grad
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 128
	_glow.height = 128


func _draw() -> void:
	if model == null:
		return
	var h: Vector2 = model.hero_pos
	if model.show_grab:
		draw_arc(h, 56.0, 0.0, TAU, ViewStyles.ring_points(56.0), ViewStyles.HERO_LEASH, ViewStyles.stroke(2.0), false)
	if model.show_leash and model.leash_radius > 0.0:
		draw_arc(model.pin_pos, model.leash_radius, 0.0, TAU, ViewStyles.ring_points(model.leash_radius),
				ViewStyles.HERO_LEASH, ViewStyles.stroke(2.0), false)
	if model.show_ghost:
		draw_arc(model.ghost_pos, ViewStyles.HERO_RADIUS, 0.0, TAU, 24, ViewStyles.HERO_GHOST, ViewStyles.stroke(2.0), false)
	if model.show_reach and model.reach_radius > 0.0:
		draw_arc(h, model.reach_radius, 0.0, TAU, ViewStyles.ring_points(model.reach_radius),
				ViewStyles.HERO_REACH, ViewStyles.stroke(2.0), false)
	if model.show_reach:
		var col: Color = ViewStyles.HERO_PREVIEW
		if model.cancelling:
			col.a = 0.35
		draw_arc(model.aim_pos, maxf(model.burst_radius, 8.0), 0.0, TAU, 32, col, ViewStyles.stroke(2.0), false)
		draw_multiline(PackedVector2Array([model.aim_pos + Vector2(-8, 0), model.aim_pos + Vector2(8, 0),
				model.aim_pos + Vector2(0, -8), model.aim_pos + Vector2(0, 8)]), col, ViewStyles.stroke(2.0), false)
	for m: Vector2 in model.kill_marks:
		draw_multiline(PackedVector2Array([m + Vector2(-8, -8), m + Vector2(8, 8), m + Vector2(-8, 8), m + Vector2(8, -8)]),
				ViewStyles.KILL_MARK, ViewStyles.stroke(2.0), false)
	if _glow != null:
		for i: int in range(model.glow_centres.size()):
			var c: Color = Color(1.0, 1.0, 1.0, model.glow_alphas[i])
			draw_texture_rect(_glow, Rect2(model.glow_centres[i] - Vector2(64, 64), Vector2(128, 128)), false, c)
	draw_circle(h, ViewStyles.HERO_RADIUS, ViewStyles.HERO_BODY)
	if model.telegraph_ring:
		draw_arc(model.telegraph_pos, maxf(model.burst_radius, 8.0), 0.0, TAU, 32, ViewStyles.TRACER_BURST,
				ViewStyles.stroke(3.0), false)
