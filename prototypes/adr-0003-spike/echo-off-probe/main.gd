extends Node2D
var seq: int = 0
var proc: int = 0

func out(s: String) -> void:
	print("PROBE|f%d|p%d|%s" % [Engine.get_process_frames(), proc, s])

func _ready() -> void:
	out("ready stretch=%s/%s window=%s visible=%s st=%s" % [ProjectSettings.get_setting("display/window/stretch/mode"), ProjectSettings.get_setting("display/window/stretch/aspect"), DisplayServer.window_get_size(), get_viewport().get_visible_rect(), get_viewport().get_screen_transform()])
	out("settings etfm=%s emft=%s" % [ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"), ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")])
	out("agile input/=%s input_devices/=%s has_input_devices=%s" % [ProjectSettings.get_setting("input/buffering/agile_event_flushing"), ProjectSettings.get_setting("input_devices/buffering/agile_event_flushing"), ProjectSettings.has_setting("input_devices/buffering/agile_event_flushing")])
	out("const DEVICE_ID_MOUSE=%d DEVICE_ID_EMULATION=%d" % [InputEvent.DEVICE_ID_MOUSE, InputEvent.DEVICE_ID_EMULATION])
	out("btn_rect=%s modal_rect=%s focused=%s" % [$HUD/Btn.get_global_rect(), $HUD/Modal.get_global_rect(), DisplayServer.window_is_focused()])
	$HUD/Btn.pressed.connect(func() -> void: out("BTN.pressed fired"))
	$HUD/Btn.gui_input.connect(func(e: InputEvent) -> void: ev("btn.gui_input", e))
	$HUD/Modal.gui_input.connect(func(e: InputEvent) -> void: ev("modal.gui_input", e))
	get_viewport().size_changed.connect(func() -> void: out("size_changed window=%s visible=%s st=%s" % [DisplayServer.window_get_size(), get_viewport().get_visible_rect(), get_viewport().get_screen_transform()]))

func ev(where: String, e: InputEvent) -> void:
	seq += 1
	var extra := ""
	if e is InputEventMouseButton: extra = "btn=%d pressed=%s pos=%s dev=%d" % [e.button_index, e.pressed, e.position, e.device]
	elif e is InputEventMouseMotion: extra = "pos=%s mask=%d dev=%d" % [e.position, e.button_mask, e.device]
	elif e is InputEventScreenTouch: extra = "idx=%d pressed=%s canceled=%s pos=%s dev=%d" % [e.index, e.pressed, e.canceled, e.position, e.device]
	elif e is InputEventScreenDrag: extra = "idx=%d pos=%s dev=%d" % [e.index, e.position, e.device]
	out("%03d %s %s %s" % [seq, where, e.get_class(), extra])

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey): ev("_input", e)

func _unhandled_input(e: InputEvent) -> void:
	ev("_unhandled_input", e)

func _notification(what: int) -> void:
	if what in [2014, 2015, 2016, 2017, 1004, 1005]:
		out("notification %d" % what)

func mouse(pressed: bool, pos: Vector2, btn: int = MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new(); e.button_index = btn as MouseButton; e.pressed = pressed; e.position = pos; e.global_position = pos
	Input.parse_input_event(e); out("inject mouse btn=%d pressed=%s pos=%s" % [btn, pressed, pos])

func touch(pressed: bool, pos: Vector2, idx: int = 0) -> void:
	var e := InputEventScreenTouch.new(); e.index = idx; e.pressed = pressed; e.position = pos
	Input.parse_input_event(e); out("inject touch idx=%d pressed=%s pos=%s" % [idx, pressed, pos])

func drag(pos: Vector2, idx: int = 0) -> void:
	var e := InputEventScreenDrag.new(); e.index = idx; e.position = pos
	Input.parse_input_event(e); out("inject drag idx=%d pos=%s" % [idx, pos])

func _process(_d: float) -> void:
	proc += 1
	var f := Engine.get_process_frames()
	match f:
		3: out("--- A: touch on Button (emft off), window coords of btn centre"); touch(true, win(Vector2(200, 150)))
		5: touch(false, win(Vector2(200, 150)))
		7: out("--- B: mouse left click on Button"); mouse(true, win(Vector2(200, 150)))
		9: mouse(false, win(Vector2(200, 150)))
		11: out("--- C: right click on field"); mouse(true, win(Vector2(300, 600)), MOUSE_BUTTON_RIGHT)
		13: mouse(false, win(Vector2(300, 600)), MOUSE_BUTTON_RIGHT)
		15: $HUD/Modal.visible = true; out("--- D: modal shown; new touch under it")
		17: touch(true, win(Vector2(300, 600)))
		19: drag(win(Vector2(330, 600)))
		21: touch(false, win(Vector2(330, 600)))
		23: out("--- E: touch on field, modal appears mid-gesture, drag, release"); $HUD/Modal.visible = false
		25: touch(true, win(Vector2(300, 700)))
		27: $HUD/Modal.visible = true; out("modal shown mid-gesture")
		29: drag(win(Vector2(330, 700)))
		31: touch(false, win(Vector2(330, 700)))
		33: $HUD/Modal.visible = false; out("--- F: presses in the letterbox bars, raw window coords"); touch(true, Vector2(1, 500))
		35: touch(false, Vector2(1, 500))
		37: DisplayServer.window_set_size(Vector2i(500, 1000)); out("resize requested")
		41: touch(true, Vector2(250, 10))
		43: touch(false, Vector2(250, 10))
		45: out("end window=%s visible=%s st=%s" % [DisplayServer.window_get_size(), get_viewport().get_visible_rect(), get_viewport().get_screen_transform()]); get_tree().quit()

func win(canvas: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * canvas
