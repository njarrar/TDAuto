extends GdUnitTestSuite
## ADR-0012 Decision 4 and ADR-0010 Decision 10: RunInfo key order, "unknown"
## handling, the console line. Headless-safe: reads engine values only.


func test_collect_has_every_key_in_contract_order() -> void:
	var info: Dictionary = RunInfo.collect(Vector2i(1280, 720), 2.0)
	var keys: Array[String] = []
	for key: Variant in info.keys():
		keys.append(str(key))
	assert_array(keys).is_equal(RunInfo.KEYS)
	assert_array(RunInfo.KEYS).is_equal([
		"godot", "debug_build", "os", "os_version", "model", "method", "driver", "adapter",
		"adapter_api", "refresh_hz", "max_fps", "vsync", "window_px", "scale",
	])


func test_collect_passes_window_and_scale_through() -> void:
	var info: Dictionary = RunInfo.collect(Vector2i(1280, 720), 2.0)
	assert_str(str(info["window_px"])).is_equal("1280x720")
	assert_float(float(info["scale"])).is_equal(2.0)


func test_collect_unread_window_and_scale_are_unknown() -> void:
	var info: Dictionary = RunInfo.collect(Vector2i(-1, -1), -1.0)
	assert_str(str(info["window_px"])).is_equal(RunInfo.UNKNOWN)
	assert_str(str(info["scale"])).is_equal(RunInfo.UNKNOWN)
	assert_int(info.size()).is_equal(RunInfo.KEYS.size())


func test_collect_headless_renderer_fields_say_none() -> void:
	if DisplayServer.get_name() != "headless":
		return
	var info: Dictionary = RunInfo.collect(Vector2i(1, 1), 1.0)
	for key: String in ["method", "driver", "adapter", "adapter_api"]:
		assert_str(str(info[key])).is_equal(RunInfo.HEADLESS)


func test_collect_values_are_json_native_and_never_empty() -> void:
	var info: Dictionary = RunInfo.collect(Vector2i(800, 600), 1.0)
	for key: Variant in info.keys():
		var value: Variant = info[key]
		var kind: int = typeof(value)
		assert_bool(kind == TYPE_STRING or kind == TYPE_INT or kind == TYPE_FLOAT or kind == TYPE_BOOL).is_true()
		if kind == TYPE_STRING:
			assert_str(str(value)).is_not_empty()


func test_refresh_value_minus_one_is_unknown() -> void:
	assert_str(str(RunInfo.refresh_value(-1.0))).is_equal(RunInfo.UNKNOWN)
	assert_str(str(RunInfo.refresh_value(0.0))).is_equal(RunInfo.UNKNOWN)
	assert_float(float(RunInfo.refresh_value(60.0))).is_equal(60.0)


func test_text_or_unknown_handles_empty_and_blank() -> void:
	assert_str(RunInfo.text_or_unknown("")).is_equal(RunInfo.UNKNOWN)
	assert_str(RunInfo.text_or_unknown("  ")).is_equal(RunInfo.UNKNOWN)
	assert_str(RunInfo.text_or_unknown("mobile")).is_equal("mobile")


func test_vsync_name_covers_the_four_modes_and_unknown() -> void:
	assert_str(RunInfo.vsync_name(DisplayServer.VSYNC_DISABLED)).is_equal("disabled")
	assert_str(RunInfo.vsync_name(DisplayServer.VSYNC_ENABLED)).is_equal("enabled")
	assert_str(RunInfo.vsync_name(DisplayServer.VSYNC_ADAPTIVE)).is_equal("adaptive")
	assert_str(RunInfo.vsync_name(DisplayServer.VSYNC_MAILBOX)).is_equal("mailbox")
	assert_str(RunInfo.vsync_name(99)).is_equal(RunInfo.UNKNOWN)


func test_line_prints_every_key_in_order() -> void:
	var info: Dictionary = {}
	var i: int = 0
	for key: String in RunInfo.KEYS:
		info[key] = "v%d" % i
		i += 1
	var expected: PackedStringArray = PackedStringArray(["RUNINFO"])
	i = 0
	for key: String in RunInfo.KEYS:
		expected.append("%s=v%d" % [key, i])
		i += 1
	assert_str(RunInfo.line(info)).is_equal(" ".join(expected))


func test_line_fills_missing_keys_with_unknown_and_quotes_spaces() -> void:
	var info: Dictionary = {"godot": "4.7.2.stable", "method": "none (headless)"}
	var text: String = RunInfo.line(info)
	assert_str(text).starts_with("RUNINFO godot=4.7.2.stable debug_build=unknown ")
	assert_str(text).contains("method=\"none (headless)\"")
	assert_str(text).ends_with("window_px=unknown scale=unknown")
