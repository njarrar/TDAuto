extends Node2D
## Logs the order engine callbacks run in and which node sees each injected
## event. Every line of interest starts with SPIKE| so the runner can grep it.

var seq: int = 0
var frame_log: Array[String] = []

func _ready() -> void:
	var m: String = str(ProjectSettings.get_setting("display/window/stretch/mode"))
	var a: String = str(ProjectSettings.get_setting("display/window/stretch/aspect"))
	out("ready stretch=%s/%s window=%s viewport_visible=%s" % [m, a, DisplayServer.window_get_size(), get_viewport().get_visible_rect()])
	out("ready safe_area=%s screen_scale=%s" % [DisplayServer.get_display_safe_area(), DisplayServer.screen_get_scale()])
	out("ready canvas_transform=%s screen_transform=%s" % [get_viewport().get_canvas_transform(), get_viewport().get_screen_transform()])
	out("const DEVICE_ID_MOUSE=%d DEVICE_ID_KEYBOARD=%d" % [InputEvent.DEVICE_ID_MOUSE, InputEvent.DEVICE_ID_KEYBOARD])
	out("const FOCUS_OUT app=%d wm=%d PAUSED=%d RESUMED=%d" % [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_RESUMED])
	out("setting emulate_touch_from_mouse=%s emulate_mouse_from_touch=%s agile_flush=%s" % [ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"), ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), ProjectSettings.get_setting("input/buffering/agile_event_flushing")])
	$HUD/Modal.gui_input.connect(_on_modal_gui_input)
	out("ready modal_rect=%s" % $HUD/Modal.get_global_rect())
	get_viewport().size_changed.connect(func() -> void: out("signal viewport.size_changed window=%s screen_transform=%s" % [DisplayServer.window_get_size(), get_viewport().get_screen_transform()]))

func _on_modal_gui_input(e: InputEvent) -> void:
	log_event("modal.gui_input", e)

func out(s: String) -> void:
	print("SPIKE|f%d|%s" % [Engine.get_process_frames(), s])

func mark(what: String) -> void:
	seq += 1
	out("%03d %s" % [seq, what])

func log_event(where: String, e: InputEvent) -> void:
	seq += 1
	var kind: String = e.get_class()
	var extra: String = ""
	if e is InputEventMouseButton:
		extra = "btn=%d pressed=%s pos=%s dev=%d" % [e.button_index, e.pressed, e.position, e.device]
	elif e is InputEventMouseMotion:
		extra = "pos=%s mask=%d dev=%d" % [e.position, e.button_mask, e.device]
	elif e is InputEventScreenTouch:
		extra = "idx=%d pressed=%s canceled=%s pos=%s dev=%d" % [e.index, e.pressed, e.canceled, e.position, e.device]
	elif e is InputEventScreenDrag:
		extra = "idx=%d pos=%s dev=%d" % [e.index, e.position, e.device]
	out("%03d %s %s %s" % [seq, where, kind, extra])

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey):
		log_event("main._input", e)

func _unhandled_input(e: InputEvent) -> void:
	log_event("main._unhandled_input", e)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_SIZE_CHANGED]:
		out("notification %d" % what)

func mouse(pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)
	mark("inject mouse pressed=%s pos=%s" % [pressed, pos])

func motion(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	mark("inject motion pos=%s" % pos)

func touch(pressed: bool, pos: Vector2, idx: int) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.pressed = pressed
	e.position = pos
	Input.parse_input_event(e)
	mark("inject touch idx=%d pressed=%s pos=%s" % [idx, pressed, pos])

func _physics_process(_delta: float) -> void:
	mark("main._physics_process")

func _process(_delta: float) -> void:
	mark("main._process")
	var f := Engine.get_process_frames()
	match f:
		3: mouse(true, Vector2(300, 600))        # A: press on the field, window coords
		5: motion(Vector2(330, 600))
		7:
			$HUD/Modal.visible = true
			mark("modal shown")
		9: motion(Vector2(360, 600))             # B1: move of the active pointer under a STOP Control
		11: mouse(false, Vector2(360, 600))      # B1: release under the Control
		13: mouse(true, Vector2(300, 600))       # B2: a NEW press under the Control
		15: motion(Vector2(330, 600))
		17: mouse(false, Vector2(330, 600))
		19: mouse(true, Vector2(300, 600))       # B3: press on the Control, then it hides mid-gesture
		21:
			$HUD/Modal.visible = false
			mark("modal hidden")
		23: motion(Vector2(330, 600))
		25: mouse(false, Vector2(330, 600))
		27: touch(true, Vector2(300, 600), 0)    # C: two-finger touch, emulation on
		29: touch(true, Vector2(100, 100), 1)
		31: touch(false, Vector2(300, 600), 0)
		33: touch(false, Vector2(100, 100), 1)
		35:
			DisplayServer.window_set_size(Vector2i(500, 1000))
			mark("resize requested")
		39:
			out("end window=%s viewport_visible=%s screen_transform=%s" % [DisplayServer.window_get_size(), get_viewport().get_visible_rect(), get_viewport().get_screen_transform()])
			get_tree().quit()
