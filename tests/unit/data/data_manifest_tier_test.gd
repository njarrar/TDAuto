extends GdUnitTestSuite
## Tier 1 (manifest and file) behaviour: GDD Acceptance 5, ADR-0002
## Validation Criterion 5. The file-reading half of `load_manifest` is covered by
## the integration suite; here the same logic runs on parsed values, no file I/O.

const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")


func _invalid_record_data() -> Dictionary:
	var data: Dictionary = DataFixtures.minimal()
	DataFixtures.tower_level(data, 0, 0).erase("cost")
	return data


func _assert_only(result: LoadResult, expected: Array[String]) -> void:
	assert_bool(result.ok).is_false()
	assert_object(result.catalogue).is_null()
	assert_array(DataFixtures.sigs(result)).contains_exactly(expected)


func test_valid_fixture_is_ready() -> void:
	var result: LoadResult = Catalogue.from_manifest_data(
			{"files": ["a.json"]}, {"a.json": DataFixtures.minimal()})
	assert_bool(result.ok).is_true()
	assert_object(result.catalogue).is_not_null()


func test_empty_manifest_reports_one_error() -> void:
	var result: LoadResult = Catalogue.from_manifest_data(
			{"files": []}, {"a.json": _invalid_record_data()})
	_assert_only(result, ["manifest_empty||"])


func test_repeated_path_reports_one_error() -> void:
	var result: LoadResult = Catalogue.from_manifest_data(
			{"files": ["a.json", "a.json", "a.json"]}, {"a.json": _invalid_record_data()})
	_assert_only(result, ["manifest_repeat_path||a.json"])


func test_manifest_shape_errors() -> void:
	for bad: Variant in [null, [], {"files": "a.json"}, {"files": [1]}, {"files": ["a.json"], "extra": 1}, {}]:
		var result: LoadResult = Catalogue.from_manifest_data(bad, {})
		_assert_only(result, ["manifest_shape||"])


func test_empty_file_reports_one_error_alongside_invalid_record() -> void:
	var files: Dictionary = {"a.json": _invalid_record_data(), "b.json": {}}
	var result: LoadResult = Catalogue.from_manifest_data({"files": ["a.json", "b.json"]}, files)
	_assert_only(result, ["file_empty||"])
	assert_str(result.errors[0].source).is_equal("b.json")


func test_missing_file_reports_one_error() -> void:
	var result: LoadResult = Catalogue.from_manifest_data(
			{"files": ["a.json", "gone.json"]}, {"a.json": _invalid_record_data()})
	_assert_only(result, ["file_missing||"])


func test_failed_read_error_is_passed_through() -> void:
	var read_error: ValidationError = ValidationError.make(&"file_parse", "a.json")
	var result: LoadResult = Catalogue.from_manifest_data({"files": ["a.json"]}, {"a.json": read_error})
	_assert_only(result, ["file_parse||"])


func test_type_with_no_records_reports_one_error_and_no_record_error() -> void:
	var data: Dictionary = _invalid_record_data()
	data.erase("burst")
	var result: LoadResult = Catalogue.from_manifest_data({"files": ["a.json"]}, {"a.json": data})
	_assert_only(result, ["type_has_no_records||burst"])


func test_type_with_empty_array_counts_as_no_records() -> void:
	var data: Dictionary = DataFixtures.minimal()
	data["enemy"] = []
	_assert_only(Catalogue.from_data("fixture:x", data), ["type_has_no_records||enemy"])


func test_unknown_record_type_and_file_shape() -> void:
	var data: Dictionary = _invalid_record_data()
	data["monster"] = []
	_assert_only(Catalogue.from_data("fixture:x", data), ["unknown_record_type||monster"])
	var not_array: Dictionary = DataFixtures.minimal()
	not_array["tower"] = {}
	_assert_only(Catalogue.from_data("fixture:x", not_array), ["file_shape||tower"])


func test_empty_dictionary_is_file_empty() -> void:
	_assert_only(Catalogue.from_data("fixture:x", {}), ["file_empty||"])


func test_a_type_may_be_split_across_files() -> void:
	var first: Dictionary = DataFixtures.minimal()
	var second: Dictionary = {"tower": [first["tower"][2]]}
	(first["tower"] as Array).remove_at(2)
	var result: LoadResult = Catalogue.from_manifest_data(
			{"files": ["a.json", "b.json"]}, {"a.json": first, "b.json": second})
	assert_bool(result.ok).is_true()
	assert_bool(result.catalogue.is_tower(&"tower_slow")).is_true()
