# PROTOTYPE - NOT FOR PRODUCTION. ADR-0012 R1, R3 and R4 probe.
# A node that sits beside the prototype's own scene (see r1_run.tscn). It:
#  1. prints one RUNINFO line (ADR-0012 Decision 4) and writes it first in
#     user://run_probe_log.txt. The functions are a copy of src/root/run_info.gd;
#     prototypes never load src/.
#  2. turns on RenderingServer.viewport_set_measure_render_time for the root
#     viewport and logs the raw cpu and gpu values for the first 60 frames (R1).
#  3. logs the worst frame of the first five seconds (R4 cold-start number).
#  4. logs p50 and p99 of delta_ms, cpu_ms, gpu_ms and cpu+gpu every 600 frames
#     (R4 frame cost; R3 delta). Press P for a window now. Press R to restart the
#     window (do it right after switching test keys).
extends Node

const LOG_PATH: String = "user://run_probe_log.txt"
const WINDOW_FRAMES: int = 600
const COLD_START_USEC: int = 5000000
const KEYS: PackedStringArray = [
	"godot", "debug_build", "os", "os_version", "model", "method", "driver", "adapter",
	"adapter_api", "refresh_hz", "max_fps", "vsync", "window_px", "scale",
]

var _file: FileAccess = null
var _vp: RID = RID()
var _start_usec: int = 0
var _frame: int = 0
var _worst_ms: float = 0.0
var _worst_frame: int = -1
var _cold_done: bool = false
var _delta: PackedFloat64Array = PackedFloat64Array()
var _cpu: PackedFloat64Array = PackedFloat64Array()
var _gpu: PackedFloat64Array = PackedFloat64Array()
var _windows: int = 0
var _nonzero_cpu: int = 0
var _nonzero_gpu: int = 0


func _ready() -> void:
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_start_usec = Time.get_ticks_usec()
	var info: Dictionary = collect(DisplayServer.window_get_size(), DisplayServer.screen_get_scale())
	_log(line(info))
	_log("INFO log=%s" % ProjectSettings.globalize_path(LOG_PATH))
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	_log("INFO measure_render_time enabled on the root viewport")


func _process(delta: float) -> void:
	_frame += 1
	var delta_ms: float = delta * 1000.0
	var cpu_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(_vp)
	var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(_vp)
	if cpu_ms > 0.0:
		_nonzero_cpu += 1
	if gpu_ms > 0.0:
		_nonzero_gpu += 1
	if _frame <= 60 and _frame % 15 == 0:
		_log("R1 frame=%d cpu_ms=%.4f gpu_ms=%.4f (0.0 for a frame or two is normal)" % [_frame, cpu_ms, gpu_ms])
	if _frame == 60:
		_log("R1 nonzero in 60 frames: cpu=%d gpu=%d (0 for gpu means the call returns nothing: write unknown)" % [_nonzero_cpu, _nonzero_gpu])
	if not _cold_done:
		if delta_ms > _worst_ms:
			_worst_ms = delta_ms
			_worst_frame = _frame
		if Time.get_ticks_usec() - _start_usec >= COLD_START_USEC:
			_cold_done = true
			_log("R4 cold-start first 5 s: worst_frame_ms=%.2f at frame %d (50 ms is the T2 warm-up trigger)" % [_worst_ms, _worst_frame])
	_delta.append(delta_ms)
	_cpu.append(cpu_ms)
	_gpu.append(gpu_ms)
	if _delta.size() >= WINDOW_FRAMES:
		_report("window")


func _unhandled_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_P:
		_report("manual")
	elif k.keycode == KEY_R:
		_delta.clear()
		_cpu.clear()
		_gpu.clear()
		_log("INFO window restarted at frame %d" % _frame)


func _report(tag: String) -> void:
	var n: int = _delta.size()
	if n == 0:
		return
	var total: PackedFloat64Array = PackedFloat64Array()
	for i in n:
		total.append(_cpu[i] + _gpu[i])
	_windows += 1
	_log("R4 %s %d frames=%d delta_ms p50=%.2f p99=%.2f | cpu_ms p50=%.2f p99=%.2f | gpu_ms p50=%.2f p99=%.2f | cpu+gpu_ms p50=%.2f p99=%.2f (p99 limit 16.6)" % [
		tag, _windows, n,
		_pct(_delta, 0.5), _pct(_delta, 0.99), _pct(_cpu, 0.5), _pct(_cpu, 0.99),
		_pct(_gpu, 0.5), _pct(_gpu, 0.99), _pct(total, 0.5), _pct(total, 0.99),
	])
	_delta.clear()
	_cpu.clear()
	_gpu.clear()


func _pct(values: PackedFloat64Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	return sorted[clampi(int(q * float(sorted.size() - 1)), 0, sorted.size() - 1)]


func _log(text: String) -> void:
	print(text)
	if _file != null:
		_file.store_line(text)
		_file.flush()


# --- copy of src/root/run_info.gd (ADR-0012 Decision 4 contract) ---

func collect(window_px: Vector2i, scale: float) -> Dictionary:
	var headless: bool = DisplayServer.get_name() == "headless"
	var info: Dictionary = {}
	info["godot"] = _text(str(Engine.get_version_info().get("string", "")))
	info["debug_build"] = OS.is_debug_build()
	info["os"] = _text(OS.get_name())
	info["os_version"] = _text(OS.get_version())
	info["model"] = _text(OS.get_model_name())
	if headless:
		info["method"] = "none (headless)"
		info["driver"] = "none (headless)"
		info["adapter"] = "none (headless)"
		info["adapter_api"] = "none (headless)"
	else:
		info["method"] = _text(RenderingServer.get_current_rendering_method())
		info["driver"] = _text(RenderingServer.get_current_rendering_driver_name())
		info["adapter"] = _text(RenderingServer.get_video_adapter_name())
		info["adapter_api"] = _text(RenderingServer.get_video_adapter_api_version())
	var hz: float = DisplayServer.screen_get_refresh_rate()
	info["refresh_hz"] = hz if hz > 0.0 else "unknown"
	info["max_fps"] = Engine.max_fps
	info["vsync"] = _vsync_name(DisplayServer.window_get_vsync_mode())
	info["window_px"] = "%dx%d" % [window_px.x, window_px.y] if window_px.x > 0 and window_px.y > 0 else "unknown"
	info["scale"] = scale if scale > 0.0 else "unknown"
	return info


func line(info: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray(["RUNINFO"])
	for key: String in KEYS:
		var text: String = str(info.get(key, "unknown"))
		if text.is_empty():
			text = "unknown"
		if text.contains(" "):
			text = "\"%s\"" % text
		parts.append("%s=%s" % [key, text])
	return " ".join(parts)


func _text(value: String) -> String:
	return "unknown" if value.strip_edges().is_empty() else value


func _vsync_name(mode: int) -> String:
	match mode:
		DisplayServer.VSYNC_DISABLED:
			return "disabled"
		DisplayServer.VSYNC_ENABLED:
			return "enabled"
		DisplayServer.VSYNC_ADAPTIVE:
			return "adaptive"
		DisplayServer.VSYNC_MAILBOX:
			return "mailbox"
	return "unknown"
