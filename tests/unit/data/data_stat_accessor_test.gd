extends GdUnitTestSuite
## StatAccessor and ReadContext: GDD Acceptance 6, 7, 8 and 12, ADR-0005
## Validation Criteria 1, 2, 3, 5, 7, 8, 9 and 10. Return values after a bad
## call are never asserted.

const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")

var _spy: DataFixtures.FatalSpy
var _cat: Catalogue
var _acc: StatAccessor


func before_test() -> void:
	_spy = DataFixtures.FatalSpy.new()
	_cat = DataFixtures.ready(DataFixtures.minimal(), "accessor")
	_acc = StatAccessor.new(_cat, _spy.fatal)


## One read of every applicable key on every record, against the raw fixture values.
func _read_all(live: Object) -> void:
	var data: Dictionary = DataFixtures.minimal()
	for tower: Dictionary in (data["tower"] as Array):
		var tags: Array = tower["tags"]
		var levels: Array = tower["levels"]
		assert_int(_acc.level_count(StringName(tower["id"]))).is_equal(levels.size())
		for i: int in range(levels.size()):
			var ctx: ReadContext = ReadContext.make(StringName(tower["id"]), i + 1, live)
			for key: StringName in StatKeys.all_keys():
				if not StatKeys.applies_to(key, &"tower"):
					continue
				var role: StringName = StatKeys.role_tag(key)
				if role != &"" and not tags.has(String(role)):
					continue
				_assert_value(ctx, key, (levels[i] as Dictionary)[String(key)])
	_read_flat(data, "enemy", &"enemy", live)
	_read_flat(data, "hero", &"hero", live)
	_read_flat(data, "burst", &"burst", live)


func _read_flat(data: Dictionary, type_name: String, record_type: StringName, live: Object) -> void:
	for record: Dictionary in (data[type_name] as Array):
		var ctx: ReadContext = ReadContext.make(StringName(record["id"]), 0, live)
		for key: StringName in StatKeys.all_keys():
			if StatKeys.applies_to(key, record_type):
				_assert_value(ctx, key, record[String(key)])


func _assert_value(ctx: ReadContext, key: StringName, expected: Variant) -> void:
	if StatKeys.is_int(key):
		assert_int(_acc.stat_int(ctx, key)).is_equal(int(expected))
	else:
		assert_float(_acc.stat_float(ctx, key)).is_equal(float(expected))


# GDD Acceptance 6, ADR-0005 Validation 1

func test_every_applicable_key_returns_the_base_value_with_a_live_entity() -> void:
	_read_all(RefCounted.new())
	assert_array(_spy.causes).is_empty()


func test_every_applicable_key_returns_the_base_value_with_a_preview_context() -> void:
	_read_all(null)
	assert_array(_spy.causes).is_empty()


# GDD Acceptance 7, ADR-0005 Validation 2: each bad call fires once

func _assert_one_cause(fragment: String) -> void:
	assert_int(_spy.causes.size()).is_equal(1)
	assert_str(_spy.causes[0]).contains(fragment)


func test_bad_call_1_unknown_key() -> void:
	_acc.stat_float(ReadContext.make(&"tower_single", 1), &"nope")
	_assert_one_cause("nope")


func test_bad_call_2_wrong_number_type() -> void:
	_acc.stat_int(ReadContext.make(&"tower_single", 1), StatKeys.DAMAGE)
	_assert_one_cause("damage")
	_acc.stat_float(ReadContext.make(&"tower_single", 1), StatKeys.COST)
	assert_int(_spy.causes.size()).is_equal(2)


func test_bad_call_3_null_context_and_unresolved_def_id() -> void:
	_acc.stat_float(null, StatKeys.DAMAGE)
	_assert_one_cause("null context")
	_acc.stat_float(ReadContext.make(&"nope", 1), StatKeys.DAMAGE)
	assert_int(_spy.causes.size()).is_equal(2)
	assert_str(_spy.causes[1]).contains("nope")


func test_bad_call_4_key_not_applicable_to_record_type() -> void:
	_acc.stat_int(ReadContext.make(&"tower_single", 1), StatKeys.BOUNTY)
	_assert_one_cause("bounty")


func test_bad_call_4_record_without_stats() -> void:
	_acc.stat_float(ReadContext.make(&"stage_a", 0), StatKeys.DAMAGE)
	_assert_one_cause("stage_a")


func test_bad_call_5_role_key_without_the_role_tag() -> void:
	_acc.stat_float(ReadContext.make(&"tower_slow", 1), StatKeys.SPLASH_RADIUS)
	_assert_one_cause("splash")
	_acc.stat_float(ReadContext.make(&"tower_single", 1), StatKeys.SLOW_DURATION)
	assert_int(_spy.causes.size()).is_equal(2)


func test_bad_call_6_tower_level_out_of_range() -> void:
	_acc.stat_int(ReadContext.make(&"tower_single", 0), StatKeys.COST)
	_assert_one_cause("level 0")
	_acc.stat_int(ReadContext.make(&"tower_single", 3), StatKeys.COST)
	assert_int(_spy.causes.size()).is_equal(2)
	_acc.stat_int(ReadContext.make(&"tower_single", -1), StatKeys.COST)
	assert_int(_spy.causes.size()).is_equal(3)


func test_bad_call_7_level_on_a_record_without_levels() -> void:
	_acc.stat_float(ReadContext.make(&"enemy_grunt", 1), StatKeys.MAX_HP)
	_assert_one_cause("enemy_grunt")


func test_one_bad_call_with_two_faults_reports_its_first_cause_only() -> void:
	_acc.stat_int(ReadContext.make(&"tower_single", 9), StatKeys.BOUNTY)
	_assert_one_cause("bounty")
	assert_str(_spy.causes[0]).not_contains("level 9")


# ADR-0005 Validation 3

func test_is_tower_and_level_count_never_call_fatal() -> void:
	for id: StringName in [&"tower_single", &"enemy_grunt", &"stage_a", &"nope", &""]:
		_acc.is_tower(id)
		_acc.level_count(id)
	assert_bool(_acc.is_tower(&"tower_splash")).is_true()
	assert_bool(_acc.is_tower(&"enemy_grunt")).is_false()
	assert_int(_acc.level_count(&"tower_splash")).is_equal(2)
	assert_int(_acc.level_count(&"nope")).is_equal(0)
	assert_array(_spy.causes).is_empty()


# ADR-0005 Validation 5

func test_reads_on_existing_contexts_allocate_no_objects() -> void:
	var tower_ctx: ReadContext = ReadContext.make(&"tower_single", 2)
	var enemy_ctx: ReadContext = ReadContext.make(&"enemy_grunt")
	var before: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	for i: int in range(500):
		_acc.stat_float(tower_ctx, StatKeys.RANGE)
		_acc.stat_int(tower_ctx, StatKeys.COST)
		_acc.stat_float(enemy_ctx, StatKeys.MOVE_SPEED)
	assert_float(Performance.get_monitor(Performance.OBJECT_COUNT)).is_equal(before)


# ADR-0005 Validation 7 (reduced: the owner holds the context, the entity does not)

func test_entity_and_context_are_freed_when_the_owner_drops_the_context() -> void:
	var entity: RefCounted = RefCounted.new()
	var owner_table: Dictionary = {}
	owner_table[1] = ReadContext.make(&"enemy_grunt", 0, entity)
	_acc.stat_float(owner_table[1] as ReadContext, StatKeys.MAX_HP)
	var entity_ref: WeakRef = weakref(entity)
	var ctx_ref: WeakRef = weakref(owner_table[1])
	entity = null
	assert_object(entity_ref.get_ref()).is_not_null()
	owner_table.erase(1)
	assert_object(ctx_ref.get_ref()).is_null()
	assert_object(entity_ref.get_ref()).is_null()


# GDD Acceptance 8, ADR-0005 Validation 8

func test_two_catalogues_behind_two_accessors_return_their_own_values() -> void:
	var data_b: Dictionary = DataFixtures.minimal()
	DataFixtures.tower_level(data_b, 0, 0)["cost"] = 55
	var acc_b: StatAccessor = StatAccessor.new(DataFixtures.ready(data_b, "b"), _spy.fatal)
	var ctx: ReadContext = ReadContext.make(&"tower_single", 1)
	assert_int(_acc.stat_int(ctx, StatKeys.COST)).is_equal(50)
	assert_int(acc_b.stat_int(ctx, StatKeys.COST)).is_equal(55)


# GDD Acceptance 12, ADR-0005 Validation 9 and 10

func test_bad_call_calls_the_handler_and_leaves_the_catalogue_unchanged() -> void:
	var before: String = _cat.snapshot()
	_acc.stat_float(ReadContext.make(&"nope", 1), StatKeys.DAMAGE)
	assert_int(_spy.causes.size()).is_equal(1)
	assert_str(_cat.snapshot()).is_equal(before)
	assert_bool(_cat.has_record(&"tower_single")).is_true()


func test_every_bad_call_reaches_the_handler_whatever_came_before() -> void:
	_acc.stat_float(null, StatKeys.DAMAGE)
	_acc.stat_float(null, StatKeys.DAMAGE)
	assert_int(_spy.causes.size()).is_equal(2)
