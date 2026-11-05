class_name PausedScreen extends Control
## Modal Paused screen (Battle HUD Rule 17): a 40% scrim and "Paused. Tap to resume". The whole
## screen is the control. Fires `resume_requested` on the release of a press it saw while armed.
## Add it to the wrapper as a full-rect child and call open(); the wrapper connects the signal
## to Flow.resume and calls clear_press on lifecycle_paused and display_changed.

signal resume_requested

var _guard: ModalTapGuard = ModalTapGuard.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## Shows the screen and arms it.
func open() -> void:
	visible = true
	_guard.set_armed(true)
	queue_redraw()


## Hides the screen and disarms it.
func close() -> void:
	visible = false
	_guard.set_armed(false)


## Clears a held press.
func clear_press() -> void:
	_guard.clear()


func _gui_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null:
		return
	accept_event()
	if touch.pressed:
		_guard.press(touch.index)
	elif _guard.release(touch.index, touch.canceled):
		resume_requested.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ViewStyles.SCRIM)
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 150.0, size.y * 0.5), "Paused. Tap to resume",
			HORIZONTAL_ALIGNMENT_CENTER, 300.0, ViewStyles.TEXT_SIZES[1], ViewStyles.HUD_TEXT)
