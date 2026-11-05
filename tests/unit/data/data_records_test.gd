extends GdUnitTestSuite
## Records, lookups and the canonical snapshot: GDD Acceptance 8 and 11,
## ADR-0002 Validation Criteria 7 and 9.

const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")


func _cat() -> Catalogue:
	return DataFixtures.ready(DataFixtures.minimal(), "records")


func test_records_are_typed_and_hold_data_values() -> void:
	var cat: Catalogue = _cat()
	var tower: TowerRecord = cat.tower(&"tower_splash")
	assert_int(tower.levels.size()).is_equal(2)
	assert_int(tower.levels[1].cost).is_equal(80)
	assert_float(tower.levels[1].range_).is_equal(170.0)
	assert_float(tower.levels[1].splash_radius).is_equal(70.0)
	assert_bool(tower.has_tag(&"splash")).is_true()
	assert_float(cat.enemy(&"enemy_grunt").max_hp).is_equal(100.0)
	assert_int(cat.enemy(&"enemy_grunt").bounty).is_equal(4)
	assert_str(String(cat.hero(&"hero_a").burst_id)).is_equal("burst_a")
	assert_float(cat.burst(&"burst_a").cooldown).is_equal(10.0)
	assert_float(cat.input().drag_slop).is_equal(16.0)
	assert_bool(cat.input().left_handed).is_false()


func test_stage_geometry_is_float64_interleaved() -> void:
	var stage: StageRecord = _cat().stage(&"stage_a")
	assert_int(stage.path_point_count()).is_equal(7)
	assert_int(stage.slot_count()).is_equal(2)
	assert_float(stage.path_points[0]).is_equal(-40.0)
	assert_float(stage.path_points[1]).is_equal(200.0)
	assert_array(Array(stage.pin_rect)).contains_exactly([48.0, 174.0, 492.0, 888.0])
	assert_array(Array(stage.hero_start)).contains_exactly([350.0, 800.0])
	assert_int(stage.pin_exclusion.size()).is_equal(1)
	assert_str(String(stage.pin_exclusion[0].hand)).is_equal("right")
	assert_array(stage.wave_ids).contains_exactly([&"wave_a"])


func test_wrong_type_lookup_returns_null() -> void:
	var cat: Catalogue = _cat()
	assert_object(cat.tower(&"enemy_grunt")).is_null()
	assert_object(cat.tower(&"nope")).is_null()
	assert_object(cat.hero(&"burst_a")).is_null()


func test_non_fatal_lookups() -> void:
	var cat: Catalogue = _cat()
	assert_bool(cat.has_record(&"stage_a")).is_true()
	assert_bool(cat.has_record(&"nope")).is_false()
	assert_str(String(cat.record_type(&"burst_a"))).is_equal("burst")
	assert_str(String(cat.record_type(&"nope"))).is_equal("")
	assert_bool(cat.is_tower(&"tower_slow")).is_true()
	assert_bool(cat.is_tower(&"enemy_grunt")).is_false()
	assert_int(cat.level_count(&"tower_single")).is_equal(2)
	assert_int(cat.level_count(&"enemy_grunt")).is_equal(0)
	assert_int(cat.level_count(&"nope")).is_equal(0)


func test_stage_ids_keep_file_then_record_order() -> void:
	var first: Dictionary = DataFixtures.minimal()
	(first["stage"] as Array).append(DataFixtures.stage("stage_b"))
	var second: Dictionary = {"stage": [DataFixtures.stage("stage_c")]}
	var result: LoadResult = Catalogue.from_manifest_data(
			{"files": ["a.json", "b.json"]}, {"a.json": first, "b.json": second})
	assert_bool(result.ok).is_true()
	assert_array(result.catalogue.stage_ids()).contains_exactly([&"stage_a", &"stage_b", &"stage_c"])


# GDD Acceptance 8

func test_two_fixtures_keep_their_own_values() -> void:
	var data_a: Dictionary = DataFixtures.minimal()
	var data_b: Dictionary = DataFixtures.minimal()
	DataFixtures.tower_level(data_b, 0, 0)["cost"] = 55
	var cat_a: Catalogue = DataFixtures.ready(data_a, "a")
	var cat_b: Catalogue = DataFixtures.ready(data_b, "b")
	assert_int(cat_a.tower(&"tower_single").levels[0].cost).is_equal(50)
	assert_int(cat_b.tower(&"tower_single").levels[0].cost).is_equal(55)


# GDD Acceptance 11 and ADR-0002 Validation 7

func test_equal_catalogues_give_equal_snapshots() -> void:
	assert_str(_cat().snapshot()).is_equal(_cat().snapshot())


func test_snapshot_detector_names_a_changed_nested_value() -> void:
	var cat: Catalogue = _cat()
	var before: String = cat.snapshot()
	assert_str(_first_diff(before, cat.snapshot())).is_equal("")
	cat.wave(&"wave_a").groups[0].count = 99
	var after: String = cat.snapshot()
	assert_bool(before == after).is_false()
	assert_str(_first_diff(before, after)).is_equal("wave.wave_a.groups[0].count")


func test_snapshot_detects_a_one_ulp_float_change() -> void:
	var cat: Catalogue = _cat()
	var before: String = cat.snapshot()
	cat.burst(&"burst_a").damage = 130.0 + 2.842170943040401e-14  # the next float after 130.0
	assert_bool(before == cat.snapshot()).is_false()


func test_to_dict_keys_equal_script_property_names() -> void:
	_assert_covered(TowerRecord.new(), TowerRecord.new().to_dict())
	_assert_covered(TowerLevel.new(), TowerLevel.new().to_dict())
	_assert_covered(EnemyRecord.new(), EnemyRecord.new().to_dict())
	_assert_covered(WaveRecord.new(), WaveRecord.new().to_dict())
	_assert_covered(WaveGroup.new(), WaveGroup.new().to_dict())
	_assert_covered(StageRecord.new(), StageRecord.new().to_dict())
	_assert_covered(PinShape.new(), PinShape.new().to_dict())
	_assert_covered(HeroRecord.new(), HeroRecord.new().to_dict())
	_assert_covered(BurstRecord.new(), BurstRecord.new().to_dict())
	_assert_covered(InputRecord.new(), InputRecord.new().to_dict())


func test_to_dict_holds_json_native_types_only() -> void:
	var cat: Catalogue = _cat()
	assert_bool(_is_json_native(cat.tower(&"tower_splash").to_dict())).is_true()
	assert_bool(_is_json_native(cat.stage(&"stage_a").to_dict())).is_true()
	assert_bool(_is_json_native(cat.wave(&"wave_a").to_dict())).is_true()
	assert_bool(_is_json_native(cat.hero(&"hero_a").to_dict())).is_true()


# ADR-0002 Validation 9

func test_catalogue_and_records_declare_no_signal_and_no_callable_member() -> void:
	var objects: Array[Object] = [
		Catalogue.new(), TowerRecord.new(), TowerLevel.new(), EnemyRecord.new(),
		WaveRecord.new(), WaveGroup.new(), StageRecord.new(), PinShape.new(),
		HeroRecord.new(), BurstRecord.new(), InputRecord.new(),
	]
	for obj: Object in objects:
		var script: Script = obj.get_script() as Script
		assert_array(script.get_script_signal_list()).is_empty()
		for prop: Dictionary in script.get_script_property_list():
			if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
				assert_int(int(prop["type"])).is_not_equal(TYPE_CALLABLE)


func _assert_covered(obj: Object, dict: Dictionary) -> void:
	var names: Array[String] = []
	for prop: Dictionary in (obj.get_script() as Script).get_script_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			# `range_` is the member for the data key `range`.
			names.append(String(prop["name"]).trim_suffix("_"))
	names.sort()
	var keys: Array[String] = []
	for key: Variant in dict.keys():
		keys.append(String(key))
	keys.sort()
	assert_array(keys).contains_exactly(names)


func _is_json_native(value: Variant) -> bool:
	var value_type: int = typeof(value)
	if value_type == TYPE_DICTIONARY:
		for key: Variant in (value as Dictionary).keys():
			if typeof(key) != TYPE_STRING or not _is_json_native((value as Dictionary)[key]):
				return false
		return true
	if value_type == TYPE_ARRAY:
		for item: Variant in (value as Array):
			if not _is_json_native(item):
				return false
		return true
	return value_type == TYPE_STRING or value_type == TYPE_INT \
			or value_type == TYPE_FLOAT or value_type == TYPE_BOOL


## Path of the first difference between two snapshot strings, "" if equal.
func _first_diff(left_text: String, right_text: String) -> String:
	return _diff(JSON.parse_string(left_text), JSON.parse_string(right_text), "")


func _diff(left: Variant, right: Variant, path: String) -> String:
	if typeof(left) == TYPE_DICTIONARY and typeof(right) == TYPE_DICTIONARY:
		var left_dict: Dictionary = left
		var right_dict: Dictionary = right
		var keys: Array = left_dict.keys()
		keys.sort()
		for key: Variant in keys:
			var child: String = String(key) if path == "" else path + "." + String(key)
			if not right_dict.has(key):
				return child
			var found: String = _diff(left_dict[key], right_dict[key], child)
			if found != "":
				return found
		return ""
	if typeof(left) == TYPE_ARRAY and typeof(right) == TYPE_ARRAY:
		var left_array: Array = left
		var right_array: Array = right
		if left_array.size() != right_array.size():
			return path
		for i: int in range(left_array.size()):
			var found: String = _diff(left_array[i], right_array[i], "%s[%d]" % [path, i])
			if found != "":
				return found
		return ""
	return "" if left == right else path
