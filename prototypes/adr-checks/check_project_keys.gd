# PROTOTYPE - NOT FOR PRODUCTION. ADR-0012 R2: project keys, headless.
# Reads the engine's own defaults (this project's project.godot sets none of
# these keys). Prints one RESULT line per key so the answer to each Branch
# (A: no max_fps key, B: a renderer override, C: no fallback key) is on screen.
# Run: godot --headless --path . -s res://check_project_keys.gd
# Not listed in run_all.sh (that file is not edited); run it on its own.
extends SceneTree

const Report := preload("res://types/report.gd")

const RENDERER_KEY: String = "rendering/renderer/rendering_method"
const RENDERER_SUFFIXES: PackedStringArray = ["mobile", "ios", "android", "web", "macos"]
const DRIVER_KEY: String = "rendering/rendering_device/driver.ios"

var _r: Report = Report.new()


func _initialize() -> void:
	_max_fps()
	_vsync()
	_renderer()
	_driver()
	_fallbacks()
	_r.record("R2-engine-max_fps", Engine.max_fps, "Engine.max_fps at start (0 unless the project or --max-fps sets it)")
	_r.record("R2-version", Engine.get_version_info().get("string", "?"), "4.7.2.stable")
	_r.finish(self, "check_project_keys.gd")


func _describe(key: String) -> String:
	if not ProjectSettings.has_setting(key):
		return "ABSENT"
	var value: Variant = ProjectSettings.get_setting(key)
	return "present type=%s value=%s" % [type_string(typeof(value)), str(value)]


func _max_fps() -> void:
	var key: String = "application/run/max_fps"
	var present: bool = ProjectSettings.has_setting(key)
	var observed: String = _describe(key)
	if present:
		var is_int: bool = typeof(ProjectSettings.get_setting(key)) == TYPE_INT
		var is_zero: bool = int(ProjectSettings.get_setting(key)) == 0
		_r.check("R2-max_fps", is_int and is_zero, observed, "present, int, default 0 (absent selects Branch A)")
	else:
		_r.record("R2-max_fps", observed, "present, int, default 0 (absent selects Branch A)")


func _vsync() -> void:
	var key: String = "display/window/vsync/vsync_mode"
	var present: bool = ProjectSettings.has_setting(key)
	var observed: String = _describe(key)
	if present:
		_r.check("R2-vsync_mode", int(ProjectSettings.get_setting(key)) == DisplayServer.VSYNC_ENABLED, observed, "enabled (1)")
	else:
		_r.record("R2-vsync_mode", observed, "enabled (1)")
	_r.record("R2-vsync_mode-live", DisplayServer.window_get_vsync_mode(), "0 disabled, 1 enabled, 2 adaptive, 3 mailbox (headless may differ)")


func _renderer() -> void:
	var observed: String = _describe(RENDERER_KEY)
	_r.record("R2-rendering_method", observed, "present; default forward_plus here, the main project sets mobile")
	var override_text: PackedStringArray = PackedStringArray()
	var any_override: bool = false
	for suffix: String in RENDERER_SUFFIXES:
		var key: String = "%s.%s" % [RENDERER_KEY, suffix]
		var text: String = _describe(key)
		override_text.append("%s: %s" % [suffix, text])
		if ProjectSettings.has_setting(key):
			any_override = true
	_r.record("R2-rendering_method-overrides", "; ".join(override_text), "which override keys exist as engine settings (a present one with another value selects Branch B)")
	_r.record("R2-any-override-key", any_override, "false if the engine registers no override key")


func _driver() -> void:
	var observed: String = _describe(DRIVER_KEY)
	var present: bool = ProjectSettings.has_setting(DRIVER_KEY)
	if present:
		_r.check("R2-driver.ios", str(ProjectSettings.get_setting(DRIVER_KEY)) == "metal", observed, "metal")
	else:
		_r.record("R2-driver.ios", observed, "metal")


func _fallbacks() -> void:
	var names: PackedStringArray = PackedStringArray()
	for info: Dictionary in ProjectSettings.get_property_list():
		var key: String = str(info["name"])
		if key.begins_with("rendering/rendering_device/fallback_to_"):
			names.append(key)
	names.sort()
	for key: String in names:
		_r.record("R2-fallback-" + key.get_file(), _describe(key), "its default; Decision 1 pins the one that applies to Mobile on iOS to false")
	var other: PackedStringArray = PackedStringArray()
	for info: Dictionary in ProjectSettings.get_property_list():
		var key: String = str(info["name"])
		if key.contains("fallback") and not names.has(key):
			other.append(key)
	other.sort()
	_r.record("R2-other-fallback-keys", ", ".join(other) if not other.is_empty() else "none", "any other key with fallback in its name (check by hand)")
	_r.check("R2-fallback-key-exists", not names.is_empty(), "%d key(s): %s" % [names.size(), ", ".join(names)], "at least one fallback_to_* key (none selects Branch C)")
