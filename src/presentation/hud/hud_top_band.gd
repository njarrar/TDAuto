class_name HudTopBand extends Control
## Drawer 7: band panel, lives dashes, wave pips and gold digits. Ignores input.

var model: HudLogic = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if model == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), ViewStyles.HUD_PANEL)
	var total: int = model.starting_lives()
	for i: int in range(total):
		@warning_ignore("integer_division")
		var row: int = i / 5
		var col: int = i % 5
		var c: Color = ViewStyles.HUD_FILL if i < model.lives() else ViewStyles.HUD_DIM
		draw_rect(Rect2(24.0 + float(col) * 28.0, 20.0 + float(row) * 12.0, 24.0, 4.5), c)
	for w: int in range(model.wave_count()):
		var c2: Color = ViewStyles.HUD_FILL if w <= model.wave_index() else ViewStyles.HUD_DIM
		draw_rect(Rect2(185.0 + float(w) * 30.0, 12.0, 20.0, 20.0), c2)
	draw_string(ThemeDB.fallback_font, Vector2(434.0, 36.0), str(model.gold()), HORIZONTAL_ALIGNMENT_RIGHT,
			82.0, ViewStyles.TEXT_SIZES[2], ViewStyles.HUD_TEXT)
