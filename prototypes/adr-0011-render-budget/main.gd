# PROTOTYPE - NOT FOR PRODUCTION. ADR-0011 V1 to V5 (desktop leg).
extends Node2D
## Builds each test scene in code and logs three draw-call counters, frame
## time and the step 4 stand-in time. Keys (the window must have focus):
##   1 empty field   2 one disc   3 ten discs   4 48 discs in one node
##   5 48 discs in 48 nodes   6 worst case, Decision 6 order
##   7 worst case, interleaved order   8 triangle-array enemies on or off
##   9 path corners (C cycles polyline, Line2D, quads)   0 line widths (V4)
##   F1..F7 hide or show drawer 1..7   A antialiasing   B LINE_BIAS 0 or 1
##   T one text size   M flashes on a ShaderMaterial node (V5)
##   Z zoom to the next corner   V vsync   S screenshot   P print stats now
##   H overlay text (adds draw calls: keep it off when reading numbers)
## Log: user://adr0011_log.txt. Screenshots: user://adr0011_*.png.

const RenderData := preload("res://render_data.gd")
const FieldDrawer := preload("res://field_drawer.gd")
const HudTopBand := preload("res://hud_top_band.gd")

enum Mode { EMPTY, ONE, TEN, FORTY_EIGHT, NODES_48, WORST, WORST_MIXED, CORNERS, LINES }

const LOG_PATH := "user://adr0011_log.txt"
const WINDOW_FRAMES := 600
const CORNERS: PackedVector2Array = [Vector2(430, 210), Vector2(430, 400), Vector2(110, 400), Vector2(110, 570), Vector2(270, 570)]
const CORNER_METHODS: PackedStringArray = ["polyline", "line2d", "quads"]
const SHADER_CODE := "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR = COLOR * vec4(1.0);\n}\n"

var _data: RenderData = RenderData.new()
var _mode: Mode = Mode.EMPTY
var _holder: Node2D
var _drawers: Array[CanvasItem] = []
var _flash_node: FieldDrawer
var _camera: Camera2D
var _overlay: Label
var _corner_method: int = 2
var _zoom_index: int = -1
var _frame: int = 0
var _shots: int = 0
var _file: FileAccess
var _c_perf: int = -1
var _c_rs: int = -1
var _c_vp_type: int = -1
var _c_vp_info: int = -1
var _frame_us: PackedInt32Array = []
var _step4_us: PackedInt32Array = []
var _draw_us: PackedInt32Array = []
var _last_perf: int = -1
var _last_rs: int = -1
var _last_vp: int = -1


func _ready() -> void:
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_c_perf = _const("Performance", "RENDER_TOTAL_DRAW_CALLS_IN_FRAME")
	_c_rs = _const("RenderingServer", "RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME")
	_c_vp_type = _const("Viewport", "RENDER_INFO_TYPE_CANVAS")
	_c_vp_info = _const("Viewport", "RENDER_INFO_DRAW_CALLS_IN_FRAME")
	_log("INFO godot=%s renderer=%s adapter=%s os=%s log=%s" % [Engine.get_version_info().get("string", "?"), ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"), RenderingServer.get_video_adapter_name(), OS.get_name(), ProjectSettings.globalize_path(LOG_PATH)])
	_log("INFO counter constants perf=%d rs=%d vp_type_canvas=%d vp_draw_calls=%d (-1 means absent)" % [_c_perf, _c_rs, _c_vp_type, _c_vp_info])
	_camera = Camera2D.new()
	_camera.position = Vector2(270, 480)
	add_child(_camera)
	_camera.make_current()
	_overlay = Label.new()
	_overlay.visible = false
	_overlay.position = Vector2(8, 90)
	_overlay.add_theme_color_override("font_color", Color(1, 1, 0.4))
	add_child(_overlay)
	_set_mode(Mode.EMPTY)


func _process(delta: float) -> void:
	_frame += 1
	_frame_us.append(int(delta * 1000000.0))
	_read_counters()
	var t0: int = Time.get_ticks_usec()
	if _mode == Mode.WORST or _mode == Mode.WORST_MIXED or _mode == Mode.FORTY_EIGHT or _mode == Mode.NODES_48:
		_data.update(_frame)
	_step4_us.append(Time.get_ticks_usec() - t0)
	var d_sum: int = 0
	for d: CanvasItem in _drawers:
		d_sum += int(d.get("draw_usec"))
	_draw_us.append(d_sum)
	for d: CanvasItem in _drawers:
		var fd: FieldDrawer = d as FieldDrawer
		if fd != null and fd.kind == FieldDrawer.Kind.BACKDROP:
			continue
		d.queue_redraw()
	if _overlay.visible:
		_overlay.text = "%s perf=%d rs=%d vp=%d fps=%d" % [_mode_name(), _last_perf, _last_rs, _last_vp, Engine.get_frames_per_second()]
	if _frame_us.size() >= WINDOW_FRAMES:
		_print_stats("window")


func _unhandled_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_1:
			_set_mode(Mode.EMPTY)
		KEY_2:
			_set_mode(Mode.ONE)
		KEY_3:
			_set_mode(Mode.TEN)
		KEY_4:
			_set_mode(Mode.FORTY_EIGHT)
		KEY_5:
			_set_mode(Mode.NODES_48)
		KEY_6:
			_set_mode(Mode.WORST)
		KEY_7:
			_set_mode(Mode.WORST_MIXED)
		KEY_8:
			_data.tri_array = not _data.tri_array
			_flag_changed("tri_array=%s" % _data.tri_array)
		KEY_9:
			_set_mode(Mode.CORNERS)
		KEY_0:
			_set_mode(Mode.LINES)
		KEY_A:
			_data.antialiased = not _data.antialiased
			_flag_changed("antialiased=%s" % _data.antialiased)
		KEY_B:
			_data.line_bias = 0.0 if _data.line_bias > 0.5 else 1.0
			_flag_changed("line_bias=%.1f" % _data.line_bias)
		KEY_T:
			_data.one_text_size = not _data.one_text_size
			_flag_changed("one_text_size=%s" % _data.one_text_size)
		KEY_M:
			_data.flash_on_material = not _data.flash_on_material
			_set_mode(_mode)
		KEY_C:
			_corner_method = (_corner_method + 1) % CORNER_METHODS.size()
			_set_mode(Mode.CORNERS)
		KEY_Z:
			_next_zoom()
		KEY_V:
			_toggle_vsync()
		KEY_S:
			_screenshot()
		KEY_P:
			_print_stats("on_request")
		KEY_H:
			_overlay.visible = not _overlay.visible
		_:
			if k.keycode >= KEY_F1 and k.keycode <= KEY_F7:
				_toggle_drawer(int(k.keycode - KEY_F1))


func _set_mode(mode: Mode) -> void:
	_mode = mode
	if _holder != null:
		remove_child(_holder)
		_holder.queue_free()
	_holder = Node2D.new()
	_holder.name = "Holder"
	add_child(_holder)
	move_child(_holder, 0)
	_drawers.clear()
	_flash_node = null
	_data.interleaved = mode == Mode.WORST_MIXED
	_data.update(_frame)
	match mode:
		Mode.EMPTY:
			_add_drawer(FieldDrawer.Kind.BACKDROP, "FieldBackdrop")
		Mode.ONE, Mode.TEN, Mode.FORTY_EIGHT:
			_add_drawer(FieldDrawer.Kind.BACKDROP, "FieldBackdrop")
			var d: FieldDrawer = _add_drawer(FieldDrawer.Kind.DISCS, "Discs")
			d.disc_count = 1 if mode == Mode.ONE else (10 if mode == Mode.TEN else 48)
		Mode.NODES_48:
			_add_drawer(FieldDrawer.Kind.BACKDROP, "FieldBackdrop")
			for i in 48:
				var one: FieldDrawer = _add_drawer(FieldDrawer.Kind.ONE_DISC, "Disc%d" % i)
				one.disc_index = i
		Mode.WORST, Mode.WORST_MIXED:
			_add_drawer(FieldDrawer.Kind.BACKDROP, "FieldBackdrop")
			_add_drawer(FieldDrawer.Kind.TOWERS, "TowerView")
			_add_drawer(FieldDrawer.Kind.ENEMIES, "EnemyView")
			_add_drawer(FieldDrawer.Kind.COMBAT, "CombatView")
			_add_drawer(FieldDrawer.Kind.HERO, "HeroView")
			_add_drawer(FieldDrawer.Kind.HUD_FIELD, "HudField")
			var band: HudTopBand = HudTopBand.new()
			band.name = "HudTopBand"
			band.data = _data
			_holder.add_child(band)
			_drawers.append(band)
			if _data.flash_on_material:
				_flash_node = _add_drawer(FieldDrawer.Kind.FLASH_ONLY, "FlashOnMaterial")
				var mat: ShaderMaterial = ShaderMaterial.new()
				var sh: Shader = Shader.new()
				sh.code = SHADER_CODE
				mat.shader = sh
				_flash_node.material = mat
		Mode.CORNERS:
			_add_corner_drawers()
		Mode.LINES:
			_add_drawer(FieldDrawer.Kind.LINE_TEST, "LineTest")
	_reset_window()
	_log("MODE %s" % _mode_name())


func _add_drawer(kind: FieldDrawer.Kind, node_name: String) -> FieldDrawer:
	var d: FieldDrawer = FieldDrawer.new()
	d.kind = kind
	d.data = _data
	d.name = node_name
	_holder.add_child(d)
	_drawers.append(d)
	return d


func _add_corner_drawers() -> void:
	var bg: FieldDrawer = _add_drawer(FieldDrawer.Kind.BACKDROP, "FieldBackdrop")
	bg.visible = false
	var method: String = CORNER_METHODS[_corner_method]
	if method == "polyline":
		_add_drawer(FieldDrawer.Kind.PATH_POLYLINE, "PathPolyline")
	elif method == "quads":
		_add_drawer(FieldDrawer.Kind.PATH_QUADS, "PathQuads")
	else:
		var pts: PackedVector2Array = []
		for i in RenderData.PATH_POINTS.size() / 2:
			pts.append(Vector2(RenderData.PATH_POINTS[2 * i], RenderData.PATH_POINTS[2 * i + 1]))
		var widths: PackedFloat32Array = [72.0, 68.0]
		var colors: PackedColorArray = [FieldDrawer.FIELD.lightened(0.10), FieldDrawer.FIELD.lightened(0.05)]
		for j in 2:
			var line: Line2D = Line2D.new()
			line.points = pts
			line.width = widths[j]
			line.default_color = colors[j]
			line.joint_mode = Line2D.LINE_JOINT_SHARP
			line.antialiased = _data.antialiased
			_holder.add_child(line)


func _next_zoom() -> void:
	_zoom_index += 1
	if _zoom_index >= CORNERS.size():
		_zoom_index = -1
	if _zoom_index < 0:
		_camera.position = Vector2(270, 480)
		_camera.zoom = Vector2.ONE
	else:
		_camera.position = CORNERS[_zoom_index]
		_camera.zoom = Vector2(4, 4)
	_log("ZOOM corner=%d position=%s zoom=%s" % [_zoom_index, _camera.position, _camera.zoom])


func _toggle_drawer(i: int) -> void:
	if i < 0 or i >= _drawers.size():
		return
	_drawers[i].visible = not _drawers[i].visible
	_flag_changed("drawer %d %s visible=%s" % [i + 1, _drawers[i].name, _drawers[i].visible])


func _toggle_vsync() -> void:
	var on: bool = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if on else DisplayServer.VSYNC_ENABLED)
	_flag_changed("vsync_mode=%d" % DisplayServer.window_get_vsync_mode())


func _flag_changed(what: String) -> void:
	for d: CanvasItem in _drawers:
		d.queue_redraw()
	if _mode == Mode.CORNERS:
		_set_mode(Mode.CORNERS)
	_reset_window()
	_log("FLAG %s" % what)


func _screenshot() -> void:
	await RenderingServer.frame_post_draw
	_shots += 1
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "user://adr0011_%02d_%s.png" % [_shots, _mode_name().replace(" ", "_")]
	var err: Error = img.save_png(path)
	_log("SHOT %s err=%d size=%s" % [ProjectSettings.globalize_path(path), err, img.get_size()])


func _const(cls: String, name_: String) -> int:
	if ClassDB.class_has_integer_constant(cls, name_):
		return ClassDB.class_get_integer_constant(cls, name_)
	return -1


func _read_counters() -> void:
	_last_perf = -1
	_last_rs = -1
	_last_vp = -1
	if _c_perf >= 0:
		_last_perf = int(Performance.get_monitor(_c_perf))
	if _c_rs >= 0:
		_last_rs = int(RenderingServer.get_rendering_info(_c_rs))
	if _c_vp_type >= 0 and _c_vp_info >= 0:
		_last_vp = int(get_viewport().get_render_info(_c_vp_type, _c_vp_info))


func _reset_window() -> void:
	_frame_us = PackedInt32Array()
	_step4_us = PackedInt32Array()
	_draw_us = PackedInt32Array()


func _p(values: PackedInt32Array, q: float) -> int:
	if values.is_empty():
		return -1
	var s: PackedInt32Array = values.duplicate()
	s.sort()
	return s[int(q * float(s.size() - 1))]


func _print_stats(why: String) -> void:
	_log("STAT %s mode=%s frames=%d perf=%d rs=%d vp=%d fps=%d frame_ms_p50=%.2f frame_ms_p99=%.2f step4_us_p99=%d draw_us_p99=%d max_hp_reads=%d" % [
		why, _mode_name(), _frame_us.size(), _last_perf, _last_rs, _last_vp,
		Engine.get_frames_per_second(),
		float(_p(_frame_us, 0.5)) / 1000.0, float(_p(_frame_us, 0.99)) / 1000.0,
		_p(_step4_us, 0.99), _p(_draw_us, 0.99), _data.max_hp_reads,
	])
	_reset_window()


func _mode_name() -> String:
	var flags: PackedStringArray = [Mode.keys()[_mode]]
	if _mode == Mode.CORNERS:
		flags.append(CORNER_METHODS[_corner_method])
	if _data.antialiased:
		flags.append("aa")
	flags.append("bias%d" % int(_data.line_bias))
	if _data.tri_array:
		flags.append("tri")
	if _data.one_text_size:
		flags.append("onesize")
	if _data.flash_on_material:
		flags.append("mat")
	return " ".join(flags)


func _log(text: String) -> void:
	var line: String = "f%d %s" % [_frame, text]
	print(line)
	if _file != null:
		_file.store_line(line)
		_file.flush()
