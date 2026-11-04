class_name HudField extends Node2D
## Drawer 6: arc, chip, Start/Call, burst button, ring requests, ground rings, prompt.
## Primitives first, then text grouped by size (21, 24, 36). Reads HudLogic's plain fields only.

var model: HudLogic = null
var tower_input: TowerInput = null
var tower_view_centres: PackedVector2Array = PackedVector2Array()
var _texts: Array[Array] = [[], [], []]


func _draw() -> void:
	if model == null:
		return
	for t: Array in _texts:
		t.clear()
	var font: Font = ThemeDB.fallback_font
	_draw_arc_ui()
	_draw_button()
	_draw_burst()
	for i: int in range(model.ground_ring_count()):
		var c: Color = ViewStyles.HUD_TEXT
		c.a = 0.4 * model.ground_ring_alpha(i)
		draw_arc(model.ground_ring_point(i), 30.0, 0.0, TAU, 24, c, ViewStyles.stroke(2.0), false)
	var prompt: String = model.prompt_text()
	if prompt != "":
		draw_rect(Rect2(120.0, 72.0, 300.0, 34.0), ViewStyles.HUD_PANEL)
		_texts[0].append([prompt, Vector2(132.0, 96.0), ViewStyles.HUD_TEXT])
	for size_index: int in range(3):
		for item: Array in _texts[size_index]:
			draw_string(font, item[1] as Vector2, item[0] as String, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
					ViewStyles.TEXT_SIZES[size_index], item[2] as Color)


func _draw_arc_ui() -> void:
	if not model.arc_open():
		return
	for k: int in range(3):
		var c: Vector2 = model.arc_centre(k)
		var ok: bool = model.arc_affordable(k)
		var col: Color = ViewStyles.HUD_TEXT if ok else ViewStyles.HUD_DIM
		draw_circle(c, HudLogic.ARC_DISC_RADIUS, ViewStyles.HUD_PANEL)
		draw_arc(c, HudLogic.ARC_DISC_RADIUS, 0.0, TAU, 32, col, ViewStyles.stroke(2.0), false)
		draw_rect(Rect2(c.x - 40.0, c.y - 90.0, 80.0, 48.0), ViewStyles.HUD_PANEL)
		_texts[0].append([model.arc_word(k), Vector2(c.x - 34.0, c.y - 70.0), col])
		_texts[0].append([str(model.arc_cost(k)), Vector2(c.x - 34.0, c.y - 48.0), col])
		if not ok:
			draw_line(c + Vector2(-20.0, 0.0), c + Vector2(20.0, 0.0), col, ViewStyles.stroke(2.0), false)
	if model.nudge_active():
		draw_arc(model.arc_centre(1), HudLogic.ARC_DISC_RADIUS + 6.0, 0.0, TAU, 32, ViewStyles.KILL_MARK, ViewStyles.stroke(2.0), false)


func _draw_button() -> void:
	var label: String = model.button_label()
	if label == "":
		return
	var armed: bool = model.button_arm() == HudLogic.Arm.ARMED
	var col: Color = ViewStyles.HUD_TEXT if armed else ViewStyles.HUD_DIM
	var r: Rect2 = Rect2(HudLogic.START_CENTRE - Vector2(44.0, 36.0), Vector2(88.0, 72.0))
	draw_rect(r, ViewStyles.HUD_PANEL)
	draw_rect(r, col, false, ViewStyles.stroke(2.0))
	_texts[1].append([label, r.position + Vector2(8.0, 30.0), col])
	if model.button_mode() == HudLogic.ButtonMode.CALL:
		_texts[0].append([str(model.call_seconds()), r.position + Vector2(8.0, 62.0), col])


func _draw_burst() -> void:
	var c: Vector2 = model.burst_button_centre()
	var state: HudLogic.BurstButton = model.burst_button_state()
	var col: Color = ViewStyles.HUD_TEXT if state == HudLogic.BurstButton.READY else ViewStyles.HUD_DIM
	draw_arc(c, 48.0, 0.0, TAU, 48, col, ViewStyles.stroke(3.0), false)
	if state == HudLogic.BurstButton.COOLING:
		draw_arc(c, 36.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - model.burst_wedge()), 32, col, ViewStyles.stroke(6.0), false)
		_texts[2].append([str(model.burst_digit()), c + Vector2(-10.0, -60.0), ViewStyles.HUD_TEXT])
	if model.chip_cost() > 0 and tower_input != null:
		var cs: TowerInput.ChipState = tower_input.chip_state()
		if cs.open and cs.slot_index < tower_view_centres.size():
			var p: Vector2 = tower_view_centres[cs.slot_index] + Vector2(0.0, -TowerInput.CHIP_OFFSET_Y)
			var cc: Color = ViewStyles.HUD_TEXT if model.chip_affordable() else ViewStyles.HUD_DIM
			draw_circle(p, TowerInput.CHIP_RADIUS, ViewStyles.HUD_PANEL)
			draw_arc(p, TowerInput.CHIP_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * model.chip_bar(), 32, cc, ViewStyles.stroke(3.0), false)
			_texts[0].append([str(model.chip_cost()), p + Vector2(-12.0, 8.0), cc])
