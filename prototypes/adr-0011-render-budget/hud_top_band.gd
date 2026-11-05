# PROTOTYPE - NOT FOR PRODUCTION. ADR-0011 V2.
extends Control
## The seventh drawer: HudTopBand, a Control with MOUSE_FILTER_IGNORE that
## draws the band panel, lives dashes, wave pips and gold digits.

const RenderData := preload("res://render_data.gd")

var data: RenderData
var draw_usec: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(540.0, 84.0)


func _draw() -> void:
	var t0: int = Time.get_ticks_usec()
	var font: Font = ThemeDB.fallback_font
	var w: float = maxf(2.0 + data.line_bias, 2.0)
	draw_rect(Rect2(0, 0, 540, 84), Color(0.05, 0.06, 0.1, 0.9))
	for i in 10:
		draw_rect(Rect2(20.0 + 16.0 * float(i), 30.0, 10.0, 24.0), Color(0.9, 0.3, 0.3))
	for i in 5:
		draw_circle(Vector2(240.0 + 22.0 * float(i), 42.0), 7.0, Color(1, 1, 1, 0.8 if i < 2 else 0.3))
	draw_arc(Vector2(240.0, 42.0), 11.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), w, data.antialiased)
	var gold_size: int = 24 if data.one_text_size else 36
	draw_string(font, Vector2(400, 56), str(data.gold), HORIZONTAL_ALIGNMENT_LEFT, -1.0, gold_size, Color(1, 0.85, 0.3))
	draw_usec = Time.get_ticks_usec() - t0
