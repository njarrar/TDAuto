extends GdUnitTestSuite
## ADR-0001 Validation 3a, 9, 10, 11 at the AppRoot level, with a fake wrapper.

const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")
const TestBattles := preload("res://tests/helpers/test_battles.gd")
const Probe := preload("res://tests/helpers/battle_probe.gd")
const FAKE_OK: String = "res://tests/integration/root/fixtures/fake_wrapper.tscn"
const FAKE_FAIL: String = "res://tests/integration/root/fixtures/fake_wrapper_fail.tscn"


func _options(extra: Dictionary = {}) -> Dictionary:
	var opts: Dictionary = {
		"load_result": DataFixtures.catalogue(DataFixtures.minimal(), "app"),
		"wrapper_scene_path": FAKE_OK,
		"rng_seed": 42,
	}
	opts.merge(extra, true)
	return opts


func _make(opts: Dictionary) -> AppRoot:
	var app: AppRoot = auto_free(AppRoot.new())
	app.configure(opts)
	return app


func _boot(opts: Dictionary) -> AppRoot:
	var app: AppRoot = _make(opts)
	add_child(app)
	return app


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _add(app: AppRoot) -> void:
	add_child(app)


func _refs(app: AppRoot) -> Array[WeakRef]:
	var b: Battle = app.battle()
	var refs: Array[WeakRef] = [
		weakref(b), weakref(b.flow), weakref(b.tower_sim), weakref(b.enemy_wave),
		weakref(b.hero_sim), weakref(b.resolver), weakref(app.wrapper()),
	]
	return refs


func _finish_battle(app: AppRoot) -> void:
	TestBattles.finish(app.battle())


func test_boot_with_fixture_catalogue_is_in_stage_with_wrapper_attached() -> void:
	var app: AppRoot = _boot(_options())

	assert_int(int(app.state())).is_equal(int(AppRoot.AppState.IN_STAGE))
	assert_object(app.battle()).is_not_null()
	assert_int(app.builds_made()).is_equal(1)
	assert_int(app.wrapper().get("attach_calls")).is_equal(1)
	assert_int(app.rng_seed()).is_equal(42)


func test_failing_catalogue_ends_in_fatal_with_the_fatal_scene() -> void:
	var errors: Array[ValidationError] = []
	var app: AppRoot = _make(_options({"load_result": LoadResult.failure(errors)}))

	await assert_error(_add.bind(app)).is_push_error("%s: no errors listed" % AppRoot.ERR_CATALOGUE)

	assert_int(int(app.state())).is_equal(int(AppRoot.AppState.FATAL))
	assert_bool(app.app_latch().is_fatal()).is_true()
	assert_str(app.fatal_screen().name).is_equal("FatalScreen")
	assert_object(app.battle()).is_null()


func test_missing_fatal_scene_path_shows_the_code_built_label() -> void:
	var errors: Array[ValidationError] = []
	var app: AppRoot = _make(_options({
		"load_result": LoadResult.failure(errors), "fatal_scene_path": "res://no/such/fatal.tscn"}))

	await assert_error(_add.bind(app)).is_push_error("%s: no errors listed" % AppRoot.ERR_CATALOGUE)

	assert_bool(app.fatal_screen() is Label).is_true()


func test_fatal_scene_path_that_is_not_a_scene_shows_the_label() -> void:
	var errors: Array[ValidationError] = []
	var app: AppRoot = _make(_options({
		"load_result": LoadResult.failure(errors), "fatal_scene_path": "res://src/root/battle.gd"}))

	await assert_error(_add.bind(app)).is_push_error("%s: no errors listed" % AppRoot.ERR_CATALOGUE)

	assert_bool(app.fatal_screen() is Label).is_true()


func test_real_app_root_scene_boots_headless() -> void:
	var packed: PackedScene = load("res://src/root/app_root.tscn") as PackedScene
	var app: AppRoot = auto_free(packed.instantiate() as AppRoot)
	app.configure(_options())
	add_child(app)

	assert_int(int(app.state())).is_equal(int(AppRoot.AppState.IN_STAGE))


func test_missing_wrapper_sets_both_latches_and_flow_reads_fatal() -> void:
	var path: String = "res://no/such/wrapper.tscn"
	var app: AppRoot = _make(_options({"wrapper_scene_path": path}))

	await assert_error(_add.bind(app)).is_push_error("%s: %s" % [AppRoot.ERR_WRAPPER_LOAD, path])

	assert_bool(app.app_latch().is_fatal()).is_true()
	assert_bool(app.battle().latch.is_fatal()).is_true()
	assert_int(int(app.battle().flow.phase())).is_equal(int(Flow.Phase.FATAL))
	await _frames(2)
	assert_int(int(app.state())).is_equal(int(AppRoot.AppState.FATAL))
	assert_object(app.battle()).is_null()


func test_failed_attach_sets_both_latches_and_flow_reads_fatal() -> void:
	var app: AppRoot = _make(_options({"wrapper_scene_path": FAKE_FAIL}))

	await assert_error(_add.bind(app)).is_push_error(AppRoot.ERR_WRAPPER_ATTACH)

	assert_bool(app.app_latch().is_fatal()).is_true()
	assert_int(int(app.battle().flow.phase())).is_equal(int(Flow.Phase.FATAL))


func test_retry_twice_in_one_frame_rebuilds_once_and_drops_the_old_battle() -> void:
	var app: AppRoot = _boot(_options())
	_finish_battle(app)
	var refs: Array[WeakRef] = _refs(app)

	app.request_retry()
	app.request_retry()
	await _frames(3)

	assert_int(app.builds_made()).is_equal(2)
	assert_int(int(app.state())).is_equal(int(AppRoot.AppState.IN_STAGE))
	assert_object(app.battle()).is_not_null()
	assert_array(Probe.alive(refs)).is_empty()
	assert_int(int(app.battle().flow.phase())).is_equal(int(Flow.Phase.BUILD))


func test_retry_while_the_battle_is_not_over_is_ignored() -> void:
	var app: AppRoot = _boot(_options())
	var first: Battle = app.battle()

	app.request_retry()
	await _frames(2)

	assert_int(app.builds_made()).is_equal(1)
	assert_object(app.battle()).is_same(first)


func test_fatal_wins_over_retry() -> void:
	var app: AppRoot = _boot(_options())
	_finish_battle(app)

	app.on_fatal("late fatal")
	app.request_retry()
	await _frames(2)

	assert_int(int(app.state())).is_equal(int(AppRoot.AppState.FATAL))
	assert_int(app.builds_made()).is_equal(1)


func test_the_seed_is_reused_on_retry() -> void:
	var app: AppRoot = _boot(_options())
	_finish_battle(app)

	app.request_retry()
	await _frames(3)

	assert_int(app.rng_seed()).is_equal(42)
