extends GdUnitTestSuite
## Catalogue.hero_ids, tower_ids, enemy_ids (ADR-0002 Decision 6, added
## 2026-11-04) and VisualKeys.from_catalogue (ADR-0011 Decision 3).

const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")


func _renamed_copy(record: Dictionary, new_id: String) -> Dictionary:
	var copy: Dictionary = record.duplicate(true)
	copy["id"] = new_id
	return copy


func _two_file_catalogue() -> Catalogue:
	var first: Dictionary = DataFixtures.minimal()
	var second: Dictionary = {
		"hero": [_renamed_copy((first["hero"] as Array)[0] as Dictionary, "hero_b")],
		"tower": [_renamed_copy((first["tower"] as Array)[0] as Dictionary, "tower_extra")],
		"enemy": [_renamed_copy((first["enemy"] as Array)[0] as Dictionary, "enemy_extra")],
	}
	var result: LoadResult = Catalogue.from_manifest_data(
			{"files": ["a.json", "b.json"]}, {"a.json": first, "b.json": second})
	assert_bool(result.ok).is_true()
	return result.catalogue


func test_id_lists_of_minimal_fixture_hold_every_record() -> void:
	var cat: Catalogue = DataFixtures.ready(DataFixtures.minimal(), "ids")

	assert_array(cat.hero_ids()).contains_exactly([&"hero_a"])
	assert_array(cat.enemy_ids()).contains_exactly([&"enemy_grunt"])
	assert_array(cat.tower_ids()).contains_exactly([&"tower_single", &"tower_splash", &"tower_slow"])


func test_id_lists_keep_file_then_record_order() -> void:
	var cat: Catalogue = _two_file_catalogue()

	assert_array(cat.hero_ids()).contains_exactly([&"hero_a", &"hero_b"])
	assert_array(cat.enemy_ids()).contains_exactly([&"enemy_grunt", &"enemy_extra"])
	assert_array(cat.tower_ids()).contains_exactly(
			[&"tower_single", &"tower_splash", &"tower_slow", &"tower_extra"])


func test_id_lists_are_copies_so_edits_do_not_reach_the_catalogue() -> void:
	var cat: Catalogue = DataFixtures.ready(DataFixtures.minimal(), "copy")

	var ids: Array[StringName] = cat.hero_ids()
	ids.clear()

	assert_int(cat.hero_ids().size()).is_equal(1)


func test_id_lists_are_empty_when_the_type_has_no_records() -> void:
	var data: Dictionary = DataFixtures.minimal()
	data.erase("hero")
	var result: LoadResult = Catalogue.from_data("no_hero", data)
	if not result.ok:
		# The validator may require a hero; then there is nothing to list.
		assert_bool(result.catalogue == null).is_true()
		return

	assert_array(result.catalogue.hero_ids()).is_empty()


func test_visual_keys_from_catalogue_read_record_visual_keys() -> void:
	var cat: Catalogue = DataFixtures.ready(DataFixtures.minimal(), "keys")

	var keys: VisualKeys = VisualKeys.from_catalogue(cat, &"hero_a")

	assert_str(String(keys.hero())).is_equal(cat.hero(&"hero_a").visual_key)
	assert_str(String(keys.enemy(&"enemy_grunt"))).is_equal(cat.enemy(&"enemy_grunt").visual_key)
	assert_str(String(keys.tower(&"tower_splash", 2))).is_equal(
			cat.tower(&"tower_splash").levels[1].visual_key)


func test_visual_keys_unknown_ids_and_levels_give_empty_name() -> void:
	var cat: Catalogue = DataFixtures.ready(DataFixtures.minimal(), "keys_unknown")

	var keys: VisualKeys = VisualKeys.from_catalogue(cat, &"nope")

	assert_str(String(keys.hero())).is_equal("")
	assert_str(String(keys.enemy(&"nope"))).is_equal("")
	assert_str(String(keys.tower(&"tower_single", 0))).is_equal("")
	assert_str(String(keys.tower(&"tower_single", 3))).is_equal("")
	assert_str(String(keys.tower(&"nope", 1))).is_equal("")
