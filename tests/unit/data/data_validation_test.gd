extends GdUnitTestSuite
## Validator tests on code-built fixtures: GDD Acceptance 1 to 4, ADR-0002
## Validation Criteria 1 to 4, and the ADR-0011 path rule. No file I/O.

const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")


## Loads `data`; "" as `code` means it must load cleanly, otherwise exactly one error.
func _expect(data: Dictionary, code: String, record_id: String, field: String) -> void:
	var result: LoadResult = DataFixtures.catalogue(data, "case")
	if code == "":
		assert_array(DataFixtures.sigs(result)).is_empty()
		assert_bool(result.ok).is_true()
		return
	assert_bool(result.ok).is_false()
	assert_object(result.catalogue).is_null()
	assert_array(DataFixtures.sigs(result)).contains_exactly(["%s|%s|%s" % [code, record_id, field]])


func _with_level(field: String, value: Variant) -> Dictionary:
	var data: Dictionary = DataFixtures.minimal()
	DataFixtures.tower_level(data, 0, 0)[field] = value
	return data


func _with_record(type_name: String, field: String, value: Variant) -> Dictionary:
	var data: Dictionary = DataFixtures.minimal()
	DataFixtures.record(data, type_name)[field] = value
	return data


func test_minimal_fixture_loads_ready() -> void:
	var result: LoadResult = DataFixtures.catalogue(DataFixtures.minimal(), "minimal")
	assert_bool(result.ok).is_true()
	assert_array(DataFixtures.sigs(result)).is_empty()
	assert_object(result.catalogue).is_not_null()


# GDD Acceptance 1

func test_duplicate_id_across_types_reports_one_error_per_record() -> void:
	var data: Dictionary = DataFixtures.minimal()
	DataFixtures.record(data, "hero")["id"] = "tower_single"
	var result: LoadResult = DataFixtures.catalogue(data, "dup")
	assert_bool(result.ok).is_false()
	assert_array(DataFixtures.sigs(result)).contains_exactly(
			["id_duplicate|tower_single|id", "id_duplicate|tower_single|id"])
	for err: ValidationError in result.errors:
		assert_str(err.source).is_equal("fixture:dup")


func test_dangling_reference_is_reported() -> void:
	var data: Dictionary = DataFixtures.minimal()
	(DataFixtures.record(data, "stage")["wave_ids"] as Array)[0] = "wave_missing"
	_expect(data, "dangling_reference", "stage_a", "wave_ids[0]")


func test_burst_id_naming_an_enemy_is_wrong_reference_type() -> void:
	_expect(_with_record("hero", "burst_id", "enemy_grunt"), "wrong_reference_type", "hero_a", "burst_id")


# GDD Acceptance 2

func test_missing_field_is_reported_with_its_path() -> void:
	var data: Dictionary = DataFixtures.minimal()
	DataFixtures.tower_level(data, 0, 0).erase("cost")
	_expect(data, "missing_field", "tower_single", "levels[0].cost")


func test_unknown_property_is_reported() -> void:
	_expect(_with_record("tower", "colour", "red"), "unknown_property", "tower_single", "colour")


func test_property_valid_on_another_type_is_unknown_here() -> void:
	_expect(_with_record("tower", "bounty", 4), "unknown_property", "tower_single", "bounty")


func test_unknown_tag_gives_one_error_and_skips_role_checks() -> void:
	_expect(_with_record("tower", "tags", ["bogus"]), "unknown_tag", "tower_single", "tags[0]")


func test_role_field_missing_on_one_level() -> void:
	var data: Dictionary = DataFixtures.minimal()
	DataFixtures.tower_level(data, 1, 1).erase("splash_radius")
	_expect(data, "role_field_missing", "tower_splash", "levels[1].splash_radius")


func test_role_field_without_its_tag() -> void:
	_expect(_with_level("splash_radius", 10.0), "role_field_without_tag", "tower_single", "levels[0].splash_radius")


func test_tower_with_no_role_tag() -> void:
	_expect(_with_record("tower", "tags", []), "role_tag_count", "tower_single", "tags")


func test_tower_with_two_role_tags() -> void:
	_expect(_with_record("tower", "tags", ["single_target", "splash"]), "role_tag_count", "tower_single", "tags")


func test_id_not_snake_case() -> void:
	var data: Dictionary = DataFixtures.minimal()
	DataFixtures.record(data, "tower", 2)["id"] = "Bad-Id"
	_expect(data, "id_format", "Bad-Id", "id")


func test_empty_wave_ids_and_empty_levels() -> void:
	_expect(_with_record("stage", "wave_ids", []), "empty_list", "stage_a", "wave_ids")
	_expect(_with_record("tower", "levels", []), "empty_list", "tower_single", "levels")


func test_empty_slot_positions() -> void:
	_expect(_with_record("stage", "slot_positions", []), "empty_list", "stage_a", "slot_positions")


func test_path_of_one_point_is_too_short() -> void:
	_expect(_with_record("stage", "path_points", [[0, 0]]), "path_too_short", "stage_a", "path_points")


func test_path_with_repeated_consecutive_point() -> void:
	_expect(_with_record("stage", "path_points", [[0, 0], [0, 0], [100, 0]]),
			"path_repeat_point", "stage_a", "path_points[1]")


func test_fractional_int_is_reported() -> void:
	_expect(_with_level("cost", 1.5), "fractional_int", "tower_single", "levels[0].cost")


func test_wrong_type_is_reported() -> void:
	_expect(_with_record("enemy", "bounty", "4"), "wrong_type", "enemy_grunt", "bounty")
	_expect(_with_record("enemy", "tags", "none"), "wrong_type", "enemy_grunt", "tags")


# ADR-0002 Validation 3: number kinds

func test_cost_accepts_whole_numbers_in_either_spelling() -> void:
	_expect(_with_level("cost", 1), "", "", "")
	_expect(_with_level("cost", 1.0), "", "", "")
	_expect(_with_level("cost", 100000), "", "", "")


func test_cost_above_ceiling_is_out_of_bounds() -> void:
	_expect(_with_level("cost", 100001), "out_of_bounds", "tower_single", "levels[0].cost")
	_expect(_with_level("cost", -1), "out_of_bounds", "tower_single", "levels[0].cost")
	_expect(_with_level("cost", 0), "", "", "")


func test_float_field_accepts_whole_number_and_rejects_string() -> void:
	_expect(_with_level("range", 160), "", "", "")
	_expect(_with_level("range", 160.0), "", "", "")
	_expect(_with_level("range", "160"), "wrong_type", "tower_single", "levels[0].range")


# GDD Acceptance 3

func test_interval_floor_is_one_tick() -> void:
	_expect(_with_level("attack_interval", 0.01), "out_of_bounds", "tower_single", "levels[0].attack_interval")
	_expect(_with_level("attack_interval", 1.0 / 60.0), "", "", "")
	_expect(_with_level("attack_interval", 600.0), "", "", "")
	_expect(_with_level("attack_interval", 600.25), "out_of_bounds", "tower_single", "levels[0].attack_interval")


func test_exclusive_floors_reject_zero() -> void:
	_expect(_with_record("enemy", "max_hp", 0.0), "out_of_bounds", "enemy_grunt", "max_hp")
	_expect(_with_record("stage", "starting_lives", 0), "out_of_bounds", "stage_a", "starting_lives")
	_expect(_with_record("stage", "starting_lives", 1), "", "", "")
	# sell_refund_percent is optional (default 70) and bounded 0 to 100.
	_expect(_with_record("stage", "sell_refund_percent", 101), "out_of_bounds", "stage_a", "sell_refund_percent")
	_expect(_with_record("stage", "sell_refund_percent", 0), "", "", "")
	_expect(_with_record("stage", "sell_refund_percent", 100), "", "", "")
	_expect(_with_record("enemy", "lives_cost", 0), "", "", "")


func test_wave_group_bounds() -> void:
	var data: Dictionary = DataFixtures.minimal()
	var group: Dictionary = (DataFixtures.record(data, "wave")["groups"] as Array)[0] as Dictionary
	group["count"] = 0
	_expect(data, "out_of_bounds", "wave_a", "groups[0].count")
	group["count"] = 4
	group["start_delay"] = -1.0
	_expect(data, "out_of_bounds", "wave_a", "groups[0].start_delay")
	group["start_delay"] = 0.0
	_expect(data, "", "", "")


func test_slow_strength_is_open_at_both_ends() -> void:
	var data: Dictionary = DataFixtures.minimal()
	var level: Dictionary = DataFixtures.tower_level(data, 2, 0)
	for bad: float in [0.0, 1.0, 1.01]:
		level["slow_strength"] = bad
		_expect(data, "out_of_bounds", "tower_slow", "levels[0].slow_strength")
	level["slow_strength"] = 0.5
	_expect(data, "", "", "")


func test_non_finite_is_reported_before_bounds() -> void:
	_expect(_with_level("damage", NAN), "non_finite", "tower_single", "levels[0].damage")
	_expect(_with_level("damage", INF), "non_finite", "tower_single", "levels[0].damage")
	_expect(_with_level("range", -INF), "non_finite", "tower_single", "levels[0].range")


func test_inclusive_ceiling_passes_and_above_fails() -> void:
	_expect(_with_level("damage", 1000000.0), "", "", "")
	_expect(_with_level("damage", 1000000.25), "out_of_bounds", "tower_single", "levels[0].damage")


func test_repeated_wave_ids_and_overlapping_groups_pass() -> void:
	var data: Dictionary = DataFixtures.minimal()
	DataFixtures.record(data, "stage")["wave_ids"] = ["wave_a", "wave_a"]
	var groups: Array = DataFixtures.record(data, "wave")["groups"] as Array
	groups.append((groups[0] as Dictionary).duplicate())
	_expect(data, "", "", "")


func test_input_record_domains() -> void:
	_expect(_with_record("input", "drag_slop", 7.75), "out_of_bounds", "input_a", "drag_slop")
	_expect(_with_record("input", "tap_slop", 34.25), "out_of_bounds", "input_a", "tap_slop")
	_expect(_with_record("input", "left_handed", 0), "wrong_type", "input_a", "left_handed")


# GDD Acceptance 4, ADR-0002 Validation 4

func test_five_unrelated_errors_are_all_reported() -> void:
	var data: Dictionary = DataFixtures.minimal()
	DataFixtures.tower_level(data, 0, 0).erase("cost")
	DataFixtures.record(data, "enemy")["max_hp"] = 0.0
	DataFixtures.record(data, "tower", 2)["tags"] = ["bogus"]
	DataFixtures.record(data, "stage")["path_points"] = [[0, 0]]
	DataFixtures.record(data, "hero")["burst_id"] = "nope"
	var result: LoadResult = DataFixtures.catalogue(data, "five")
	assert_array(DataFixtures.sigs(result)).contains_exactly_in_any_order([
		"missing_field|tower_single|levels[0].cost",
		"out_of_bounds|enemy_grunt|max_hp",
		"unknown_tag|tower_slow|tags[0]",
		"path_too_short|stage_a|path_points",
		"dangling_reference|hero_a|burst_id",
	])


# Geometry

func test_point_outside_coordinate_range() -> void:
	_expect(_with_record("stage", "hero_start", [2000.5, 0]), "out_of_bounds", "stage_a", "hero_start")
	_expect(_with_record("stage", "hero_start", [2000, -2000]), "", "", "")
	_expect(_with_record("stage", "hero_start", [1, 2, 3]), "wrong_type", "stage_a", "hero_start")


func test_pin_rect_inverted() -> void:
	_expect(_with_record("stage", "pin_rect", {"min": [492, 174], "max": [48, 888]}),
			"pin_rect_inverted", "stage_a", "pin_rect")


func test_pin_shape_radius_and_hand() -> void:
	var data: Dictionary = DataFixtures.minimal()
	var shape: Dictionary = (DataFixtures.record(data, "stage")["pin_exclusion"] as Array)[0] as Dictionary
	shape["radius"] = 0.0
	_expect(data, "shape_invalid", "stage_a", "pin_exclusion[0].radius")
	shape["radius"] = 60.0
	shape["hand"] = "middle"
	_expect(data, "shape_invalid", "stage_a", "pin_exclusion[0].hand")
	shape["hand"] = "both"
	shape["b"] = shape["a"]
	_expect(data, "", "", "")


func test_path_turn_sharper_than_90_degrees() -> void:
	var points: Array = [[0, 0], [300, 0], [150, 259.8076211353316]]
	_expect(_with_record("stage", "path_points", points), "path_turn_too_sharp", "stage_a", "path_points[1]")


func test_path_segment_too_short_between_two_square_turns() -> void:
	var data: Dictionary = DataFixtures.minimal()
	var stage: Dictionary = DataFixtures.record(data, "stage")
	stage["path_points"] = [[0, 0], [300, 0], [300, 100], [600, 100]]
	stage["path_width"] = 120.0
	_expect(data, "path_segment_too_short", "stage_a", "path_points[1]")


func test_starter_style_path_and_quarter_circle_pass() -> void:
	var data: Dictionary = DataFixtures.minimal()
	var stage: Dictionary = DataFixtures.record(data, "stage")
	stage["path_points"] = [[-40, 210], [430, 210], [430, 400], [110, 400], [110, 570], [270, 570], [270, 980]]
	_expect(data, "", "", "")
	var arc: Array = []
	for i: int in range(16):
		var angle: float = (PI / 2.0) * float(i) / 15.0
		arc.append([200.0 * cos(angle), 200.0 * sin(angle)])
	stage["path_points"] = arc
	stage["path_width"] = 96.0
	_expect(data, "", "", "")


func test_path_check_is_skipped_when_width_failed() -> void:
	var data: Dictionary = DataFixtures.minimal()
	var stage: Dictionary = DataFixtures.record(data, "stage")
	stage["path_points"] = [[0, 0], [300, 0], [300, 100], [600, 100]]
	stage["path_width"] = 0.0
	_expect(data, "out_of_bounds", "stage_a", "path_width")
