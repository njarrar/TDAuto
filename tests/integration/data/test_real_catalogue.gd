extends GdUnitTestSuite
## GDD Acceptance 9 on the real manifest: it loads with no error, every listed
## record is present, and a valid data file the manifest does not list stays
## absent. Proves manifest logic only, not export behaviour.
## (A missing-manifest case is not tested here: the engine logs an error when
## it opens a missing file, which gdUnit4 reports as a failure.)

const MANIFEST: String = "res://assets/data/manifest.json"
## A copy of the real manifest that lives next to `unlisted.json`, which it does not list.
const PROBE_MANIFEST: String = "res://tests/integration/data/fixtures/probe/manifest.json"


func _listed_records(manifest_path: String) -> Dictionary:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path)) as Dictionary
	var ids: Dictionary = {}
	for rel: String in (manifest["files"] as Array):
		var path: String = manifest_path.get_base_dir().path_join(rel).simplify_path()
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
		for type_name: String in data.keys():
			for record: Dictionary in (data[type_name] as Array):
				ids[StringName(String(record["id"]))] = StringName(type_name)
	return ids


func test_real_manifest_loads_with_no_errors() -> void:
	var result: LoadResult = Catalogue.load_manifest(MANIFEST)
	var texts: Array[String] = []
	for err: ValidationError in result.errors:
		texts.append(err.to_text())
	assert_array(texts).is_empty()
	assert_bool(result.ok).is_true()
	assert_object(result.catalogue).is_not_null()


func test_every_listed_record_is_present_with_its_type() -> void:
	var catalogue: Catalogue = Catalogue.load_manifest(MANIFEST).catalogue
	var ids: Dictionary = _listed_records(MANIFEST)
	assert_bool(ids.is_empty()).is_false()
	for id: StringName in ids.keys():
		assert_bool(catalogue.has_record(id)).is_true()
		assert_str(String(catalogue.record_type(id))).is_equal(String(ids[id]))
	assert_int(catalogue.stage_ids().size()).is_greater(0)
	assert_object(catalogue.input()).is_not_null()


func test_unlisted_file_beside_the_manifest_is_never_read() -> void:
	var result: LoadResult = Catalogue.load_manifest(PROBE_MANIFEST)
	assert_bool(result.ok).is_true()
	assert_bool(result.catalogue.has_record(&"unlisted_tower")).is_false()
	assert_bool(result.catalogue.has_record(&"tower_single")).is_true()
	# The unlisted file exists and is itself well formed.
	var unlisted_path: String = PROBE_MANIFEST.get_base_dir().path_join("unlisted.json")
	var unlisted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(unlisted_path)) as Dictionary
	assert_int((unlisted["tower"] as Array).size()).is_equal(1)
