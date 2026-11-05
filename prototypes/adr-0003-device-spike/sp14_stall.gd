# PROTOTYPE - NOT FOR PRODUCTION. ADR-0004 SP14 (V2, V3, V9 desktop leg).
extends Control
## Stall and frame cadence. Run this scene on its own (F6 in the editor).
## Stall buttons block one frame for 300 or 1000 ms with OS.delay_msec and
## log the next two frames' delta_ms and the ticks the kit clock runs.
## Cadence records 10 s of per-frame delta_ms and kit-clock ticks.
## Log: user://sp14_log.txt; cadence frames: user://sp14_cadence_<n>.csv.

const SpClock := preload("res://sp14_clock.gd")
const LOG_PATH := "user://sp14_log.txt"
const CADENCE_SECONDS := 10.0
const AFTER_STALL_FRAMES := 2

var _clock: SpClock = SpClock.new(60)
var _frame: int = 0
var _stall_pending_ms: int = 0
var _after_stall_left: int = 0
var _capturing: bool = false
var _cadence_runs: int = 0
var _cad_elapsed: float = 0.0
var _cad_deltas: PackedFloat32Array = []
var _cad_ticks: PackedInt32Array = []
var _last_refresh: float = -1.0
var _lines: PackedStringArray = []
var _file: FileAccess
var _view: Label


func _ready() -> void:
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_build_ui()
	_log("INFO godot=%s os=%s log=%s" % [Engine.get_version_info().get("string", "?"), OS.get_name(), ProjectSettings.globalize_path(LOG_PATH)])
	_log_display("start")


func _process(delta: float) -> void:
	_frame += 1
	var ms: float = delta * 1000.0
	var ticks: int = _clock.advance(delta)
	if _after_stall_left > 0:
		_log("PROC after_stall n=%d delta_ms=%.3f kit_ticks=%d" % [AFTER_STALL_FRAMES - _after_stall_left + 1, ms, ticks])
		_after_stall_left -= 1
	if _capturing:
		_cad_deltas.append(ms)
		_cad_ticks.append(ticks)
		_cad_elapsed += delta
		if _cad_elapsed >= CADENCE_SECONDS:
			_finish_cadence()
	if _frame % 60 == 0:
		_check_refresh()
	if _stall_pending_ms > 0:
		var stall_ms: int = _stall_pending_ms
		_stall_pending_ms = 0
		_log("STALL begin ms=%d frame=%d" % [stall_ms, _frame])
		var t0: int = Time.get_ticks_usec()
		OS.delay_msec(stall_ms)
		_log("STALL end measured_ms=%.1f" % (float(Time.get_ticks_usec() - t0) / 1000.0))
		_after_stall_left = AFTER_STALL_FRAMES


func _build_ui() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(20.0, 20.0)
	box.size = Vector2(500.0, 920.0)
	add_child(box)
	_add_button(box, "Stall 300 ms", _on_stall_300)
	_add_button(box, "Stall 1000 ms", _on_stall_1000)
	_add_button(box, "Cadence 10 s (hands off)", _on_cadence)
	_add_button(box, "Copy log", _on_copy)
	_view = Label.new()
	_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_view.custom_minimum_size = Vector2(500.0, 600.0)
	box.add_child(_view)


func _add_button(box: VBoxContainer, text: String, handler: Callable) -> void:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(500.0, 72.0)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(handler)
	box.add_child(b)


func _on_stall_300() -> void:
	_stall_pending_ms = 300


func _on_stall_1000() -> void:
	_stall_pending_ms = 1000


func _on_cadence() -> void:
	if _capturing:
		return
	_cadence_runs += 1
	_cad_elapsed = 0.0
	_cad_deltas = PackedFloat32Array()
	_cad_ticks = PackedInt32Array()
	_capturing = true
	_log("CADENCE begin run=%d frame=%d" % [_cadence_runs, _frame])
	_log_display("cadence_begin")


func _on_copy() -> void:
	DisplayServer.clipboard_set("\n".join(_lines))
	_log("INFO copied %d lines" % _lines.size())


func _finish_cadence() -> void:
	_capturing = false
	var hist: PackedInt32Array = [0, 0, 0, 0]
	var dmin: float = INF
	var dmax: float = 0.0
	var dsum: float = 0.0
	var off_frames: int = 0
	var odd: PackedStringArray = []
	var csv: FileAccess = FileAccess.open("user://sp14_cadence_%d.csv" % _cadence_runs, FileAccess.WRITE)
	if csv != null:
		csv.store_line("frame,delta_ms,kit_ticks")
	for i in _cad_deltas.size():
		var d: float = _cad_deltas[i]
		var t: int = clampi(_cad_ticks[i], 0, 3)
		hist[t] += 1
		dmin = minf(dmin, d)
		dmax = maxf(dmax, d)
		dsum += d
		if absf(d - 1000.0 / 60.0) > 2.0:
			off_frames += 1
		if t != 1 and odd.size() < 20:
			odd.append("%d:%.2fms/%dt" % [i, d, t])
		if csv != null:
			csv.store_line("%d,%.4f,%d" % [i, d, _cad_ticks[i]])
	if csv != null:
		csv.close()
	var n: int = _cad_deltas.size()
	var mean: float = dsum / float(maxi(n, 1))
	_log("CADENCE end run=%d frames=%d ticks0=%d ticks1=%d ticks2=%d ticks3=%d" % [_cadence_runs, n, hist[0], hist[1], hist[2], hist[3]])
	_log("CADENCE delta_ms min=%.3f max=%.3f mean=%.3f off_by_2ms=%d" % [dmin, dmax, mean, off_frames])
	_log("CADENCE first_non_one_tick_frames=[%s]" % ", ".join(odd))
	_log("CADENCE csv=%s" % ProjectSettings.globalize_path("user://sp14_cadence_%d.csv" % _cadence_runs))
	_log_display("cadence_end")


func _check_refresh() -> void:
	var rate: float = DisplayServer.screen_get_refresh_rate()
	if rate != _last_refresh:
		_log("REFRESH screen_refresh_hz=%.2f (was %.2f) frame=%d" % [rate, _last_refresh, _frame])
		_last_refresh = rate


func _log_display(stage: String) -> void:
	_log("DISPLAY %s max_fps=%d refresh_hz=%.2f vsync_mode=%d physics_tps=%d delta_smoothing=%s low_processor=%s fps=%.1f" % [
		stage,
		Engine.max_fps,
		DisplayServer.screen_get_refresh_rate(),
		DisplayServer.window_get_vsync_mode(),
		Engine.physics_ticks_per_second,
		ProjectSettings.get_setting("application/run/delta_smoothing", "absent"),
		OS.low_processor_usage_mode,
		Engine.get_frames_per_second(),
	])


func _log(text: String) -> void:
	var line: String = "f%d t%d %s" % [_frame, Time.get_ticks_usec(), text]
	print(line)
	_lines.append(line)
	if _file != null:
		_file.store_line(line)
		_file.flush()
	var start: int = maxi(_lines.size() - 24, 0)
	if _view != null:
		_view.text = "\n".join(_lines.slice(start))
