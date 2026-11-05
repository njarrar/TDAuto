extends GdUnitTestSuite
## StatKeys consistency with the ADR-0002 schema: ADR-0005 Validation 4.

const GDD_KEYS: Array[String] = [
	"cost", "damage", "range", "attack_interval", "splash_radius", "slow_strength",
	"slow_duration", "bounty", "lives_cost", "max_hp", "move_speed", "leash_radius",
	"walk_speed", "radius", "reach", "cooldown", "telegraph_duration",
]


func _schema_name(record_type: StringName) -> String:
	return "tower_level" if record_type == &"tower" else String(record_type)


func test_every_gdd_key_has_a_constant() -> void:
	var names: Array[String] = []
	for key: StringName in StatKeys.all_keys():
		names.append(String(key))
	assert_array(names).contains_exactly_in_any_order(GDD_KEYS)


func test_every_key_is_a_schema_field_of_the_right_type_on_each_record() -> void:
	for key: StringName in StatKeys.all_keys():
		for record_type: StringName in CatalogueSchema.TYPE_ORDER:
			if not StatKeys.applies_to(key, record_type):
				continue
			var fields: Dictionary = CatalogueSchema.FIELDS[_schema_name(record_type)]
			assert_bool(fields.has(String(key))).is_true()
			var kind: String = (fields[String(key)] as Array)[CatalogueSchema.SPEC_KIND]
			assert_str(kind).is_equal("int" if StatKeys.is_int(key) else "float")


func test_every_key_is_a_field_of_its_record_class() -> void:
	var level_keys: Array = TowerLevel.new().to_dict().keys()
	var enemy_keys: Array = EnemyRecord.new().to_dict().keys()
	var hero_keys: Array = HeroRecord.new().to_dict().keys()
	var burst_keys: Array = BurstRecord.new().to_dict().keys()
	for key: StringName in StatKeys.all_keys():
		if StatKeys.applies_to(key, &"tower"):
			assert_bool(level_keys.has(String(key))).is_true()
		if StatKeys.applies_to(key, &"enemy"):
			assert_bool(enemy_keys.has(String(key))).is_true()
		if StatKeys.applies_to(key, &"hero"):
			assert_bool(hero_keys.has(String(key))).is_true()
		if StatKeys.applies_to(key, &"burst"):
			assert_bool(burst_keys.has(String(key))).is_true()


func test_role_tags_match_the_schema_role_fields() -> void:
	for key: StringName in StatKeys.all_keys():
		var role: StringName = StatKeys.role_tag(key)
		if role == &"":
			continue
		var role_fields: Array = CatalogueSchema.ROLE_FIELDS[String(role)]
		assert_bool(role_fields.has(String(key))).is_true()


func test_helpers_on_known_and_unknown_keys() -> void:
	assert_bool(StatKeys.is_key(StatKeys.COST)).is_true()
	assert_bool(StatKeys.is_key(&"nope")).is_false()
	assert_bool(StatKeys.is_int(StatKeys.BOUNTY)).is_true()
	assert_bool(StatKeys.is_int(StatKeys.DAMAGE)).is_false()
	assert_bool(StatKeys.applies_to(StatKeys.BOUNTY, &"tower")).is_false()
	assert_str(String(StatKeys.role_tag(StatKeys.SLOW_DURATION))).is_equal("slow")
	assert_str(String(StatKeys.role_tag(StatKeys.COST))).is_equal("")
