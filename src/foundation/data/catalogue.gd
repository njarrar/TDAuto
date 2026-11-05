class_name Catalogue extends RefCounted
## The read-only catalogue of every authored gameplay value (ADR-0002).
##
## A Catalogue exists only in READY: both entry points are static and return a
## LoadResult. It declares no signals and holds no Callable. Records are
## read-only by rule: nothing outside `src/foundation/data/` writes a field.

var _towers: Dictionary = {}
var _enemies: Dictionary = {}
var _waves: Dictionary = {}
var _stages: Dictionary = {}
var _heroes: Dictionary = {}
var _bursts: Dictionary = {}
var _inputs: Dictionary = {}
## StringName id -> StringName record type.
var _type_of: Dictionary = {}
var _stage_ids: Array[StringName] = []
var _hero_ids: Array[StringName] = []
var _tower_ids: Array[StringName] = []
var _enemy_ids: Array[StringName] = []
var _input: InputRecord = null


## Reads the manifest and every file it lists, validates everything, and builds
## the records only if there is no error. Synchronous. Called once, by AppRoot.
static func load_manifest(manifest_path: String) -> LoadResult:
	var manifest_text: String = FileAccess.get_file_as_string(manifest_path)
	var open_error: Error = FileAccess.get_open_error()
	if open_error != OK:
		return LoadResult.failure(_one_error(&"manifest_missing", Validator.MANIFEST_SOURCE, manifest_path))
	var manifest_json: JSON = JSON.new()
	var parse_error: Error = manifest_json.parse(manifest_text)
	if parse_error != OK:
		return LoadResult.failure(_one_error(
				&"manifest_parse", Validator.MANIFEST_SOURCE, _parse_detail(manifest_json)))
	var manifest: Variant = manifest_json.data
	var manifest_errors: Array[ValidationError] = Validator.check_manifest(manifest)
	if not manifest_errors.is_empty():
		return LoadResult.failure(manifest_errors)
	var base_dir: String = manifest_path.get_base_dir()
	var files: Dictionary = {}
	for item: Variant in ((manifest as Dictionary)["files"] as Array):
		var rel_path: String = item
		files[rel_path] = _read_data_file(base_dir.path_join(rel_path).simplify_path(), rel_path)
	return from_manifest_data(manifest, files)


## Same validation and build, from data already in memory. No file I/O.
## For code-built test fixtures; `source_label` stands in for the file name.
static func from_data(source_label: String, data: Dictionary) -> LoadResult:
	var entries: Array = [{"source": source_label, "data": data}]
	var no_errors: Array[ValidationError] = []
	return _validate_and_build(entries, no_errors)


## The manifest tier and everything after it, with no file I/O. `manifest` is
## the parsed manifest value. `files` maps each listed relative path to its
## parsed JSON value (or to a ValidationError for a file that failed to read).
## A listed path with no entry is `file_missing`.
static func from_manifest_data(manifest: Variant, files: Dictionary) -> LoadResult:
	var manifest_errors: Array[ValidationError] = Validator.check_manifest(manifest)
	if not manifest_errors.is_empty():
		return LoadResult.failure(manifest_errors)
	var entries: Array = []
	var pre_errors: Array[ValidationError] = []
	for item: Variant in ((manifest as Dictionary)["files"] as Array):
		var rel_path: String = item
		if not files.has(rel_path):
			pre_errors.append(ValidationError.make(&"file_missing", rel_path))
		elif files[rel_path] is ValidationError:
			pre_errors.append(files[rel_path] as ValidationError)
		else:
			entries.append({"source": rel_path, "data": files[rel_path]})
	return _validate_and_build(entries, pre_errors)


func tower(id: StringName) -> TowerRecord:
	return _towers.get(id) as TowerRecord


func enemy(id: StringName) -> EnemyRecord:
	return _enemies.get(id) as EnemyRecord


func wave(id: StringName) -> WaveRecord:
	return _waves.get(id) as WaveRecord


func stage(id: StringName) -> StageRecord:
	return _stages.get(id) as StageRecord


func hero(id: StringName) -> HeroRecord:
	return _heroes.get(id) as HeroRecord


func burst(id: StringName) -> BurstRecord:
	return _bursts.get(id) as BurstRecord


## The one Input record.
func input() -> InputRecord:
	return _input


## Stage IDs in manifest file order, then order in file.
func stage_ids() -> Array[StringName]:
	return _stage_ids.duplicate()


## Hero IDs in manifest file order, then order in file. Non-fatal.
func hero_ids() -> Array[StringName]:
	return _hero_ids.duplicate()


## Tower IDs in manifest file order, then order in file. Non-fatal.
func tower_ids() -> Array[StringName]:
	return _tower_ids.duplicate()


## Enemy IDs in manifest file order, then order in file. Non-fatal.
func enemy_ids() -> Array[StringName]:
	return _enemy_ids.duplicate()


## Non-fatal: true if any record has this ID.
func has_record(id: StringName) -> bool:
	return _type_of.has(id)


## Non-fatal: the record's type (`CatalogueSchema.TOWER` and so on), or &"" if unknown.
func record_type(id: StringName) -> StringName:
	return _type_of.get(id, &"") as StringName


## Non-fatal: true if the ID names a tower.
func is_tower(id: StringName) -> bool:
	return _towers.has(id)


## Non-fatal: the number of levels of a tower; 0 if the ID is not a tower.
func level_count(def_id: StringName) -> int:
	var record: TowerRecord = _towers.get(def_id) as TowerRecord
	if record == null:
		return 0
	return record.levels.size()


## Canonical string of the whole catalogue: every record's `to_dict()`, keyed by
## type then ID, with sorted keys and full float precision.
func snapshot() -> String:
	var towers: Dictionary = {}
	for key: Variant in _towers.keys():
		towers[String(key)] = (_towers[key] as TowerRecord).to_dict()
	var enemies: Dictionary = {}
	for key: Variant in _enemies.keys():
		enemies[String(key)] = (_enemies[key] as EnemyRecord).to_dict()
	var waves: Dictionary = {}
	for key: Variant in _waves.keys():
		waves[String(key)] = (_waves[key] as WaveRecord).to_dict()
	var stages: Dictionary = {}
	for key: Variant in _stages.keys():
		stages[String(key)] = (_stages[key] as StageRecord).to_dict()
	var heroes: Dictionary = {}
	for key: Variant in _heroes.keys():
		heroes[String(key)] = (_heroes[key] as HeroRecord).to_dict()
	var bursts: Dictionary = {}
	for key: Variant in _bursts.keys():
		bursts[String(key)] = (_bursts[key] as BurstRecord).to_dict()
	var inputs: Dictionary = {}
	for key: Variant in _inputs.keys():
		inputs[String(key)] = (_inputs[key] as InputRecord).to_dict()
	var all: Dictionary = {
		"tower": towers, "enemy": enemies, "wave": waves, "stage": stages,
		"hero": heroes, "burst": bursts, "input": inputs,
	}
	return JSON.stringify(all, "", true, true)


# ---------------------------------------------------------------------------

static func _one_error(code: StringName, source: String, detail: String) -> Array[ValidationError]:
	var errors: Array[ValidationError] = []
	errors.append(ValidationError.make(code, source, &"", &"", detail))
	return errors


static func _parse_detail(parsed: JSON) -> String:
	return "line %d: %s" % [parsed.get_error_line(), parsed.get_error_message()]


## Reads and parses one data file. Returns the parsed value, or a ValidationError.
static func _read_data_file(path: String, source: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	var open_error: Error = FileAccess.get_open_error()
	if open_error != OK:
		return ValidationError.make(&"file_missing", source)
	if text.strip_edges().is_empty():
		return ValidationError.make(&"file_empty", source)
	var file_json: JSON = JSON.new()
	var parse_error: Error = file_json.parse(text)
	if parse_error != OK:
		return ValidationError.make(&"file_parse", source, &"", &"", _parse_detail(file_json))
	return file_json.data


static func _validate_and_build(entries: Array, pre_errors: Array[ValidationError]) -> LoadResult:
	var errors: Array[ValidationError] = []
	errors.append_array(pre_errors)
	errors.append_array(Validator.check_files(entries, pre_errors.is_empty()))
	if not errors.is_empty():
		return LoadResult.failure(errors)
	var record_errors: Array[ValidationError] = Validator.check_records(entries)
	if not record_errors.is_empty():
		return LoadResult.failure(record_errors)
	return LoadResult.success(_build(entries))


static func _build(entries: Array) -> Catalogue:
	var built: Catalogue = Catalogue.new()
	for entry_value: Variant in entries:
		var data: Dictionary = (entry_value as Dictionary)["data"]
		for type_name: StringName in CatalogueSchema.TYPE_ORDER:
			if not data.has(String(type_name)):
				continue
			for record_value: Variant in (data[String(type_name)] as Array):
				built._add_record(type_name, record_value as Dictionary)
	return built


func _add_record(type_name: StringName, data: Dictionary) -> void:
	var id: StringName = StringName(String(data["id"]))
	_type_of[id] = type_name
	if type_name == CatalogueSchema.TOWER:
		var tower_record: TowerRecord = TowerRecord.from_dict(data)
		_towers[id] = tower_record
		_tower_ids.append(id)
	elif type_name == CatalogueSchema.ENEMY:
		_enemies[id] = EnemyRecord.from_dict(data)
		_enemy_ids.append(id)
	elif type_name == CatalogueSchema.WAVE:
		_waves[id] = WaveRecord.from_dict(data)
	elif type_name == CatalogueSchema.STAGE:
		_stages[id] = StageRecord.from_dict(data)
		_stage_ids.append(id)
	elif type_name == CatalogueSchema.HERO:
		_heroes[id] = HeroRecord.from_dict(data)
		_hero_ids.append(id)
	elif type_name == CatalogueSchema.BURST:
		_bursts[id] = BurstRecord.from_dict(data)
	elif type_name == CatalogueSchema.INPUT:
		var input_record: InputRecord = InputRecord.from_dict(data)
		_inputs[id] = input_record
		_input = input_record
