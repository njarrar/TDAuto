extends GdUnitTestSuite
## ADR-0003 Validation: insets_from_safe_area hand-computed cases, press_allowed
## boundaries, width_supported at 360 and 359. Also FieldInsets.

const EPS: float = 0.0001


func test_tall_phone_bars_absorb_the_cutout() -> void:
	var insets: FieldInsets = FieldMapping.insets_from_safe_area(
			Rect2(0.0, 120.0, 1080.0, 2220.0), Vector2.ZERO, Vector2(1080.0, 2400.0))

	assert_float(insets.top).is_equal_approx(0.0, EPS)
	assert_float(insets.bottom).is_equal_approx(0.0, EPS)


func test_nine_sixteen_phone_inset_lies_inside_the_field() -> void:
	var insets: FieldInsets = FieldMapping.insets_from_safe_area(
			Rect2(0.0, 48.0, 540.0, 864.0), Vector2.ZERO, Vector2(540.0, 960.0))

	assert_float(insets.top).is_equal_approx(48.0, EPS)
	assert_float(insets.bottom).is_equal_approx(48.0, EPS)
	assert_float(insets.left).is_equal_approx(0.0, EPS)
	assert_float(insets.right).is_equal_approx(0.0, EPS)


func test_landscape_window_side_inset() -> void:
	var insets: FieldInsets = FieldMapping.insets_from_safe_area(
			Rect2(700.0, 0.0, 1180.0, 1080.0), Vector2.ZERO, Vector2(1920.0, 1080.0))

	assert_float(insets.left).is_equal_approx((700.0 - 656.25) / 1.125, EPS)
	assert_float(insets.right).is_equal_approx(0.0, EPS)
	assert_float(insets.top).is_equal_approx(0.0, EPS)


func test_window_offset_from_the_screen_origin() -> void:
	var insets: FieldInsets = FieldMapping.insets_from_safe_area(
			Rect2(100.0, 146.0, 1080.0, 1824.0), Vector2(100.0, 50.0), Vector2(1080.0, 1920.0))

	assert_float(insets.top).is_equal_approx(48.0, EPS)
	assert_float(insets.bottom).is_equal_approx(0.0, EPS)
	assert_float(insets.left).is_equal_approx(0.0, EPS)


func test_zero_window_gives_all_zeros() -> void:
	var insets: FieldInsets = FieldMapping.insets_from_safe_area(
			Rect2(0.0, 10.0, 10.0, 10.0), Vector2.ZERO, Vector2.ZERO)

	assert_bool(insets.is_equal_to(FieldInsets.new())).is_true()


func test_press_allowed_side_boundaries() -> void:
	var none: FieldInsets = FieldInsets.new()

	assert_bool(FieldMapping.press_allowed(Vector2(10.0, 480.0), none, 10.0)).is_true()
	assert_bool(FieldMapping.press_allowed(Vector2(9.9, 480.0), none, 10.0)).is_false()
	assert_bool(FieldMapping.press_allowed(Vector2(530.0, 480.0), none, 10.0)).is_true()
	assert_bool(FieldMapping.press_allowed(Vector2(530.1, 480.0), none, 10.0)).is_false()


func test_press_allowed_field_edges() -> void:
	var none: FieldInsets = FieldInsets.new()

	assert_bool(FieldMapping.press_allowed(Vector2(270.0, 0.0), none, 10.0)).is_true()
	assert_bool(FieldMapping.press_allowed(Vector2(270.0, -0.1), none, 10.0)).is_false()
	assert_bool(FieldMapping.press_allowed(Vector2(270.0, 960.0), none, 10.0)).is_true()
	assert_bool(FieldMapping.press_allowed(Vector2(270.0, 960.1), none, 10.0)).is_false()
	assert_bool(FieldMapping.press_allowed(Vector2(NAN, 480.0), none, 10.0)).is_false()


func test_press_allowed_respects_insets() -> void:
	var insets: FieldInsets = FieldInsets.new(48.0, 48.0, 20.0, 20.0)

	assert_bool(FieldMapping.press_allowed(Vector2(270.0, 47.9), insets, 10.0)).is_false()
	assert_bool(FieldMapping.press_allowed(Vector2(270.0, 48.0), insets, 10.0)).is_true()
	assert_bool(FieldMapping.press_allowed(Vector2(270.0, 912.0), insets, 10.0)).is_true()
	assert_bool(FieldMapping.press_allowed(Vector2(270.0, 912.1), insets, 10.0)).is_false()
	assert_bool(FieldMapping.press_allowed(Vector2(29.9, 480.0), insets, 10.0)).is_false()
	assert_bool(FieldMapping.press_allowed(Vector2(510.1, 480.0), insets, 10.0)).is_false()


func test_width_supported_boundary() -> void:
	assert_bool(FieldMapping.width_supported(360)).is_true()
	assert_bool(FieldMapping.width_supported(359)).is_false()


func test_field_width_dp() -> void:
	assert_float(FieldMapping.field_width_dp(Vector2(1080.0, 1920.0), 3.0)).is_equal_approx(360.0, EPS)
	assert_float(FieldMapping.field_width_dp(Vector2(1080.0, 1920.0), 0.0)).is_equal(-1.0)


func test_insets_equality() -> void:
	assert_bool(FieldInsets.new(1.0, 2.0, 3.0, 4.0).is_equal_to(FieldInsets.new(1.0, 2.0, 3.0, 4.0))).is_true()
	assert_bool(FieldInsets.new(1.0, 2.0, 3.0, 4.0).is_equal_to(FieldInsets.new(1.0, 2.0, 3.0, 5.0))).is_false()
	assert_bool(FieldInsets.new().is_equal_to(null)).is_false()
