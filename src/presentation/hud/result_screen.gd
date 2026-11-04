class_name ResultScreen extends Control
## Modal result screen (Battle HUD Rules 15 and 16): plain text in a fixed order, Retry or
## Play again the only filled shape. Mounted at the outcome (input dead at once); the text shows
## after the delay HudLogic reports. Fires `retry_requested`. The wrapper adds it as a full-rect
## child, calls open(hud_logic), calls refresh_view() each frame while open, and sets
## the signal to the retry latch on the app root.

signal retry_requested

const RETRY_RECT: Rect2 = Rect2(206.0, 664.0, 128.0, 72.0)
const RETRY_RECT_WON: Rect2 = Rect2(206.0, 868.0, 128.0, 72.0)

var _guard: ModalTapGuard = ModalTapGuard.new()
var _hud: HudLogic = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## Mounts the screen over the field. The guard arms when the text shows.
func open(hud: HudLogic) -> void:
	_hud = hud
	visible = true
	_guard.set_armed(false)
	queue_redraw()


## Hides and drops the HUD reference.
func close() -> void:
	visible = false
	_hud = null
	_guard.set_armed(false)


## Clears a held press.
func clear_press() -> void:
	_guard.clear()


## Called each frame while open: arms once the text is visible and redraws.
func refresh_view() -> void:
	if _hud == null:
		return
	if _hud.result_text_visible() and not _guard.is_armed():
		_guard.set_armed(true)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null:
		return
	accept_event()
	if touch.pressed:
		if _retry_rect().has_point(touch.position):
			_guard.press(touch.index)
	elif _guard.release(touch.index, touch.canceled):
		retry_requested.emit()


func _retry_rect() -> Rect2:
	var won: bool = _hud != null and _hud.snapshot() != null and _hud.snapshot().result != null \
			and _hud.snapshot().result.outcome == Flow.Phase.WON
	return RETRY_RECT_WON if won else RETRY_RECT


func _draw() -> void:
	if _hud == null or not _hud.result_text_visible():
		return
	var s: ResultSnapshot = _hud.snapshot()
	if s == null or s.result == null:
		return
	var font: Font = ThemeDB.fallback_font
	var won: bool = s.result.outcome == Flow.Phase.WON
	var top: float = 752.0 if won else 200.0
	draw_rect(Rect2(48.0, top, 444.0, 192.0 if won else 552.0), ViewStyles.HUD_PANEL)
	var lines: Array[String] = []
	if won:
		lines.append("Stage clear")
		lines.append("Lives %d of %d" % [s.result.lives_left, s.starting_lives])
	else:
		lines.append("Broke on wave %d of %d" % [s.wave_index, s.wave_count])
		if s.next_try != "":
			lines.append(s.next_try)
	var got: String = "Got through:"
	for t: StringName in HudLogic.TYPE_ORDER:
		if s.got_through.has(t):
			got += " %s %d" % [String(t), int(s.got_through[t])]
	lines.append(got)
	var dmg: String = "Damage: Towers %d, Hero %d, Burst %d" % [roundi(s.result.dealt_tower),
			roundi(s.result.dealt_hero), roundi(s.result.dealt_burst)]
	if s.slow_built:
		dmg += ", Slowed %d" % s.slows_applied
	lines.append(dmg)
	var y: float = top + 40.0
	for line: String in lines:
		draw_string(font, Vector2(64.0, y), line, HORIZONTAL_ALIGNMENT_LEFT, 412.0, ViewStyles.TEXT_SIZES[0], ViewStyles.HUD_TEXT)
		y += 36.0
	var r: Rect2 = _retry_rect()
	draw_rect(r, ViewStyles.HUD_FILL)
	draw_string(font, r.position + Vector2(12.0, 44.0), "Play again" if won else "Retry", HORIZONTAL_ALIGNMENT_LEFT,
			112.0, ViewStyles.TEXT_SIZES[0], ViewStyles.HUD_PANEL)
