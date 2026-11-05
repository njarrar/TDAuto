class_name RunInfo extends RefCounted
## The run record of ADR-0012 Decision 4 (owned by ADR-0010 Decision 10). Static
## functions, no state. Debug builds and prototypes only; release builds collect
## nothing. Every key is always present. A value no call reports is "unknown".
## Renderer fields are "none (headless)" when the display server is headless.

## The record keys, in contract order.
const KEYS: Array[String] = [
	"godot", "debug_build", "os", "os_version", "model", "method", "driver", "adapter",
	"adapter_api", "refresh_hz", "max_fps", "vsync", "window_px", "scale",
]
## Value for anything the engine does not report.
const UNKNOWN: String = "unknown"
## Value for the renderer fields in a headless run.
const HEADLESS: String = "none (headless)"
## Prefix of the console form.
const LINE_PREFIX: String = "RUNINFO"


## Builds the record. `window_px` and `scale` are the values InputAdapter read
## (ADR-0003); a size with a side of 0 or less, or a scale of 0.0 or less, means
## the adapter has not read yet and gives "unknown". Values are JSON-native.
static func collect(window_px: Vector2i, scale: float) -> Dictionary:
	var headless: bool = DisplayServer.get_name() == "headless"
	var info: Dictionary = {}
	info["godot"] = text_or_unknown(str(Engine.get_version_info().get("string", "")))
	info["debug_build"] = OS.is_debug_build()
	info["os"] = text_or_unknown(OS.get_name())
	info["os_version"] = text_or_unknown(OS.get_version())
	info["model"] = text_or_unknown(OS.get_model_name())
	if headless:
		info["method"] = HEADLESS
		info["driver"] = HEADLESS
		info["adapter"] = HEADLESS
		info["adapter_api"] = HEADLESS
	else:
		info["method"] = text_or_unknown(RenderingServer.get_current_rendering_method())
		info["driver"] = text_or_unknown(RenderingServer.get_current_rendering_driver_name())
		info["adapter"] = text_or_unknown(RenderingServer.get_video_adapter_name())
		info["adapter_api"] = text_or_unknown(RenderingServer.get_video_adapter_api_version())
	info["refresh_hz"] = refresh_value(DisplayServer.screen_get_refresh_rate())
	info["max_fps"] = Engine.max_fps
	info["vsync"] = vsync_name(DisplayServer.window_get_vsync_mode())
	info["window_px"] = window_text(window_px)
	info["scale"] = scale_value(scale)
	return info


## The console form: `RUNINFO key=value key=value ...` in KEYS order. A key
## missing from `info` prints "unknown". A value with a space is double-quoted.
static func line(info: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray([LINE_PREFIX])
	for key: String in KEYS:
		var value: Variant = info.get(key, UNKNOWN)
		var text: String = str(value)
		if text.is_empty():
			text = UNKNOWN
		if text.contains(" "):
			text = "\"%s\"" % text
		parts.append("%s=%s" % [key, text])
	return " ".join(parts)


## Empty text is "unknown".
static func text_or_unknown(value: String) -> String:
	if value.strip_edges().is_empty():
		return UNKNOWN
	return value


## A refresh rate of 0.0 or less (the engine reports -1.0) is "unknown".
static func refresh_value(hz: float) -> Variant:
	if hz <= 0.0:
		return UNKNOWN
	return hz


## The vsync mode as a lower-case name; a mode outside the known four is "unknown".
static func vsync_name(mode: int) -> String:
	match mode:
		DisplayServer.VSYNC_DISABLED:
			return "disabled"
		DisplayServer.VSYNC_ENABLED:
			return "enabled"
		DisplayServer.VSYNC_ADAPTIVE:
			return "adaptive"
		DisplayServer.VSYNC_MAILBOX:
			return "mailbox"
	return UNKNOWN


## "WxH", or "unknown" when either side is 0 or less.
static func window_text(size: Vector2i) -> String:
	if size.x <= 0 or size.y <= 0:
		return UNKNOWN
	return "%dx%d" % [size.x, size.y]


## The scale, or "unknown" when it is 0.0 or less.
static func scale_value(scale: float) -> Variant:
	if scale <= 0.0:
		return UNKNOWN
	return scale
