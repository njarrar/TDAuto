# PROTOTYPE - NOT FOR PRODUCTION. ADR-0003 device spike.
# Question: on Godot 4.7.2, with the display and input settings ADR-0003 proposes,
# in what order do input events, Controls, _unhandled_input, _physics_process and
# _process run; which lifecycle notifications fire per platform; and what do the
# safe area, screen size and stretch report? See README.md for spike items SP0 to SP12.
#
# Scene built in code:
#   SpikeRoot (this script)      logs notifications (NOTE-ROOT), window signals (WIN-SIG),
#                                display changes (DISPLAY), and marks PHYS and PROC
#     FieldView (Node2D)         field, edge margins, insets, crosshairs, touch circles
#     WrapperStandIn (Node)
#       AdapterStandIn (Node)    logs _input (IN), _unhandled_input (UNH), NOTE-DEEP
#     Labels                     status line and the on-screen log (mouse_filter IGNORE)
#     STOP band, PASS band       Controls that log their _gui_input (CTRL-STOP, CTRL-PASS)
#     Buttons                    Mark, Clear, Copy, Aspect, Hover, Accept
# No autoloads.
extends Node

const SpikeLog := preload("res://spike_log.gd")
const SpikeInfo := preload("res://spike_info.gd")
const AdapterStandIn := preload("res://adapter_stand_in.gd")
const SpikePanel := preload("res://spike_panel.gd")
const FieldView := preload("res://field_view.gd")

const FIELD: Vector2 = Vector2(540.0, 960.0)
const POLL_EVERY_FRAMES: int = 15
const BUTTON_Y: float = 890.0

var _log: SpikeLog = SpikeLog.new()
var _info: SpikeInfo = SpikeInfo.new()
var _adapter: AdapterStandIn = null
var _field_view: FieldView = null
var _status_label: Label = null
var _log_label: Label = null
var _stop_panel: SpikePanel = null
var _pass_panel: SpikePanel = null
var _aspect_button: Button = null
var _hover_button: Button = null
var _accept_button: Button = null
var _mark_count: int = 0
var _poll_counter: int = 0
var _last_display_key: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_log.open_file()
	_build_scene()
	_write_start_report()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	var win: Window = get_window()
	for sig: String in ["focus_entered", "focus_exited", "go_back_requested", "visibility_changed", "close_requested"]:
		if win.has_signal(sig):
			win.connect(sig, _on_window_signal.bind(sig))
		else:
			_log.entry("INFO", "Window has no signal %s" % sig)
	_last_display_key = _display_key()
	_log.flush_now()


func _physics_process(_delta: float) -> void:
	_log.marker("PHYS", "")


func _process(delta: float) -> void:
	_log.marker("PROC", "delta_ms=%.2f" % (delta * 1000.0))
	_poll_counter += 1
	if _poll_counter >= POLL_EVERY_FRAMES:
		_poll_counter = 0
		_poll_display()
	if _log.screen_dirty:
		_log_label.text = _log.screen_text()
		_log.screen_dirty = false
	var press_text: String = _info.v2(_adapter.last_press) if _adapter.has_press else "none"
	_status_label.text = "ADR-0003 spike  frame %d  events after PROC %d, after PHYS %d\nlast press %s  marks %d  lines %d" % [
		Engine.get_process_frames(), _log.events_after_proc, _log.events_after_phys,
		press_text, _mark_count, _log.kept_count()]
	_field_view.queue_redraw()


func _notification(what: int) -> void:
	if _log == null or _info == null or _info.is_spam(what):
		return
	_log.entry("NOTE-ROOT", _info.notification_label(what))
	if _info.is_lifecycle(what):
		_log.flush_now()
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_log.close()


func _exit_tree() -> void:
	_log.entry("INFO", "exit_tree")
	_log.close()


# --- scene ------------------------------------------------------------------

func _build_scene() -> void:
	_field_view = FieldView.new()
	_field_view.name = "FieldView"
	add_child(_field_view)

	var wrapper: Node = Node.new()
	wrapper.name = "WrapperStandIn"
	_adapter = AdapterStandIn.new()
	_adapter.name = "AdapterStandIn"
	_adapter.spike_log = _log
	_adapter.info = _info
	wrapper.add_child(_adapter)
	add_child(wrapper)
	_field_view.adapter = _adapter

	_status_label = _make_label(Vector2(6.0, 2.0), Vector2(528.0, 38.0), 13)
	_log_label = _make_label(Vector2(6.0, 42.0), Vector2(528.0, 552.0), 12)

	_stop_panel = _make_panel("CTRL-STOP", Rect2(0.0, 600.0, 540.0, 90.0),
		Color(0.8, 0.2, 0.2, 0.45), Control.MOUSE_FILTER_STOP, "STOP Control (mouse_filter STOP)")
	_pass_panel = _make_panel("CTRL-PASS", Rect2(0.0, 700.0, 540.0, 70.0),
		Color(0.9, 0.6, 0.1, 0.4), Control.MOUSE_FILTER_PASS, "PASS Control (mouse_filter PASS)")

	_add_button("Mark", 0, _on_mark)
	_add_button("Clear", 1, _on_clear)
	_add_button("Copy", 2, _on_copy)
	_aspect_button = _add_button("keep", 3, _on_aspect)
	_hover_button = _add_button("Hover off", 4, _on_hover)
	_accept_button = _add_button("Accept off", 5, _on_accept)


func _make_label(pos: Vector2, box: Vector2, font_size: int) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.size = box
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l


func _make_panel(tag: String, rect: Rect2, color: Color, filter: Control.MouseFilter, caption: String) -> SpikePanel:
	var p: SpikePanel = SpikePanel.new()
	p.name = tag
	p.tag = tag
	p.spike_log = _log
	p.info = _info
	p.position = rect.position
	p.size = rect.size
	p.color = color
	p.mouse_filter = filter
	p.focus_mode = Control.FOCUS_NONE
	var l: Label = Label.new()
	l.text = caption
	l.position = Vector2(8.0, 6.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	add_child(p)
	return p


func _add_button(text: String, slot: int, handler: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.position = Vector2(6.0 + 88.0 * slot, BUTTON_Y)
	b.size = Vector2(84.0, 60.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(handler)
	add_child(b)
	return b


# --- buttons ----------------------------------------------------------------

func _on_mark() -> void:
	_mark_count += 1
	_log.entry("MARK", "---------------- MARK %d ----------------" % _mark_count)


func _on_clear() -> void:
	_log.clear_screen()
	_log.entry("INFO", "screen cleared (file keeps every line)")


func _on_copy() -> void:
	DisplayServer.clipboard_set(_log.all_text())
	_log.entry("INFO", "copied %d lines to the clipboard" % _log.kept_count())


func _on_aspect() -> void:
	var root: Window = get_tree().root
	if root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP:
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
		_aspect_button.text = "keep_width"
	elif root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH:
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		_aspect_button.text = "expand"
	else:
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		_aspect_button.text = "keep"
	_log.entry("DISPLAY", "aspect set to %s: %s" % [_aspect_button.text, _display_snapshot()])


func _on_hover() -> void:
	_log.hide_hover_on_screen = not _log.hide_hover_on_screen
	_hover_button.text = "Hover off" if _log.hide_hover_on_screen else "Hover on"


func _on_accept() -> void:
	var on: bool = not _stop_panel.accept_touch
	_stop_panel.accept_touch = on
	_pass_panel.accept_touch = on
	_accept_button.text = "Accept on" if on else "Accept off"
	_log.entry("INFO", "bands call accept_event() on touch: %s" % str(on))


# --- signals and display ----------------------------------------------------

func _on_window_signal(sig: String) -> void:
	_log.entry("WIN-SIG", sig)
	_log.flush_now()


func _on_viewport_size_changed() -> void:
	_log.entry("DISPLAY", "Viewport.size_changed: %s" % _display_snapshot())
	_field_view.insets = _field_insets()
	_last_display_key = _display_key()


func _poll_display() -> void:
	var key: String = _display_key()
	if key == _last_display_key:
		return
	_last_display_key = key
	_log.entry("DISPLAY", "changed (seen by polling): %s" % _display_snapshot())
	_field_view.insets = _field_insets()


func _display_key() -> String:
	return "%s|%s|%s|%s|%s|%d" % [
		str(DisplayServer.screen_get_size()), str(DisplayServer.window_get_size()),
		str(DisplayServer.window_get_position()), str(DisplayServer.get_display_safe_area()),
		str(get_viewport().get_visible_rect()), int(DisplayServer.screen_get_orientation())]


func _display_snapshot() -> String:
	var root: Window = get_tree().root
	var parts: PackedStringArray = PackedStringArray()
	parts.append("screen=%s" % str(DisplayServer.screen_get_size()))
	parts.append("dpi=%d" % DisplayServer.screen_get_dpi())
	parts.append("scale=%.3f" % DisplayServer.screen_get_scale())
	parts.append("usable=%s" % str(DisplayServer.screen_get_usable_rect()))
	parts.append("window=%s" % str(DisplayServer.window_get_size()))
	parts.append("window_pos=%s" % str(DisplayServer.window_get_position()))
	parts.append("safe=%s" % str(DisplayServer.get_display_safe_area()))
	if DisplayServer.has_method("get_display_cutouts"):
		parts.append("cutouts=%s" % str(DisplayServer.call("get_display_cutouts")))
	parts.append("orientation=%d" % int(DisplayServer.screen_get_orientation()))
	parts.append("root.size=%s" % str(root.size))
	parts.append("visible_rect=%s" % str(get_viewport().get_visible_rect()))
	parts.append("final_xform=%s" % str(get_viewport().get_final_transform()))
	parts.append("content_scale mode=%d aspect=%d size=%s factor=%.3f" % [
		int(root.content_scale_mode), int(root.content_scale_aspect),
		str(root.content_scale_size), root.content_scale_factor])
	var ins: PackedFloat32Array = _field_insets()
	parts.append("formula_insets_field(top,bottom,left,right)=(%.1f,%.1f,%.1f,%.1f)" % [ins[0], ins[1], ins[2], ins[3]])
	parts.append("formula_field_width_dp=%.1f" % _field_width_dp())
	parts.append("mobile=%s" % str(OS.has_feature("mobile")))
	return " ".join(parts)


# The inset formula ADR-0003 proposes (Decision 5), for a keep aspect: the
# safe area in window pixels, minus the letterbox bars, divided by the scale.
# It is computed on every platform so the log shows what it gives; the game
# uses it only on Android and iOS.
func _field_insets() -> PackedFloat32Array:
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var win_pos: Vector2 = Vector2(DisplayServer.window_get_position())
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	safe.position -= win_pos
	var s: float = minf(win.x / FIELD.x, win.y / FIELD.y)
	if s <= 0.0:
		return PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var ox: float = (win.x - FIELD.x * s) * 0.5
	var oy: float = (win.y - FIELD.y * s) * 0.5
	var top: float = maxf(0.0, (safe.position.y - oy) / s)
	var bottom: float = maxf(0.0, ((oy + FIELD.y * s) - safe.end.y) / s)
	var left: float = maxf(0.0, (safe.position.x - ox) / s)
	var right: float = maxf(0.0, ((ox + FIELD.x * s) - safe.end.x) / s)
	return PackedFloat32Array([top, bottom, left, right])


# The field's drawn width in dp, the quantity ADR-0003's 360 dp guard checks.
# -1 when not on a phone. Android: dp = px * 160 / dpi. iOS: points = px / scale.
func _field_width_dp() -> float:
	if not OS.has_feature("mobile"):
		return -1.0
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var s: float = minf(win.x / FIELD.x, win.y / FIELD.y)
	var px_per_dp: float = 0.0
	if OS.has_feature("ios"):
		px_per_dp = DisplayServer.screen_get_scale()
	else:
		px_per_dp = float(DisplayServer.screen_get_dpi()) / 160.0
	if px_per_dp <= 0.0:
		return -1.0
	return FIELD.x * s / px_per_dp


func _write_start_report() -> void:
	var v: Dictionary = Engine.get_version_info()
	_log.entry("INFO", "log format: seq f<process frame> pf<physics frame> t<usec> after=<last marker> TAG text")
	_log.entry("INFO", "engine=%s os=%s model=%s" % [str(v.get("string", "?")), OS.get_name(), OS.get_model_name()])
	_log.entry("INFO", "user_dir=%s log=%s" % [OS.get_user_data_dir(), ProjectSettings.globalize_path(SpikeLog.LOG_PATH)])
	for key: String in [
		"display/window/size/viewport_width",
		"display/window/size/viewport_height",
		"display/window/stretch/mode",
		"display/window/stretch/aspect",
		"display/window/stretch/scale_mode",
		"display/window/handheld/orientation",
		"input_devices/pointing/emulate_touch_from_mouse",
		"input_devices/pointing/emulate_mouse_from_touch",
		"input_devices/buffering/agile_event_flushing",
		"input_devices/pointing/android/enable_long_press_as_right_click",
		"input_devices/pointing/android/enable_pan_and_scale_gestures",
		"application/config/quit_on_go_back",
		"physics/common/physics_ticks_per_second",
	]:
		_log.entry("INFO", "setting %s has=%s value=%s" % [key, str(ProjectSettings.has_setting(key)), str(ProjectSettings.get_setting(key, "<unset>"))])
	_log.entry("INFO", "runtime Input.use_accumulated_input=%s Input.emulate_touch_from_mouse=%s Input.emulate_mouse_from_touch=%s SceneTree.quit_on_go_back=%s" % [
		str(Input.get("use_accumulated_input")), str(Input.get("emulate_touch_from_mouse")),
		str(Input.get("emulate_mouse_from_touch")), str(get_tree().get("quit_on_go_back"))])
	_log.entry("INFO", "runtime physics_ticks=%d max_fps=%d" % [Engine.physics_ticks_per_second, Engine.max_fps])
	_log.entry("INFO", "devices: %s" % _info.device_report())
	_log.entry("INFO", "lifecycle constants: %s" % _info.lifecycle_report())
	_log.entry("DISPLAY", "start: %s" % _display_snapshot())
	_field_view.insets = _field_insets()
