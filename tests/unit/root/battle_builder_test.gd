extends GdUnitTestSuite
## ADR-0001 Validation 2 to 6 (headless), ADR-0005 Builder order, ADR-0008
## Decision 2 (resolver, null is fatal), ADR-0011 members.

const TestBattles := preload("res://tests/helpers/test_battles.gd")
const Probe := preload("res://tests/helpers/battle_probe.gd")
const CAUSE_A: String = "cause a"
const CAUSE_B: String = "cause b"


## Records the app handler call.
class FakeApp extends RefCounted:
	var causes: Array[String] = []

	func on_fatal(cause: String) -> void:
		causes.append(cause)


## A catalogue whose Input record has slops the resolver refuses.
class BadSlopCatalogue extends Catalogue:
	var inner: Catalogue = null

	func _init(p_inner: Catalogue) -> void:
		inner = p_inner

	func input() -> InputRecord:
		var rec: InputRecord = InputRecord.new()
		rec.drag_slop = 1.0
		rec.tap_slop = 1.0
		return rec

	func stage(id: StringName) -> StageRecord:
		return inner.stage(id)

	func wave(id: StringName) -> WaveRecord:
		return inner.wave(id)

	func hero(id: StringName) -> HeroRecord:
		return inner.hero(id)

	func hero_ids() -> Array[StringName]:
		return inner.hero_ids()

	func tower_ids() -> Array[StringName]:
		return inner.tower_ids()

	func snapshot() -> String:
		return inner.snapshot()


## Runs build and keeps the result, so assert_error can wrap it.
class BuildRun extends RefCounted:
	var result: Battle = null
	var cat: Catalogue = null
	var handler: Callable = Callable()

	func go() -> void:
		result = BattleBuilder.build(cat, &"stage_a", 1, handler)


func _refs(battle: Battle) -> Array[WeakRef]:
	var refs: Array[WeakRef] = [
		weakref(battle), weakref(battle.flow), weakref(battle.combat), weakref(battle.enemy_wave),
		weakref(battle.tower_sim), weakref(battle.hero_sim), weakref(battle.resolver),
		weakref(battle.relay), weakref(battle.accessor),
	]
	return refs


func _build_refs() -> Array[WeakRef]:
	return _refs(TestBattles.build())


func _micro_refs() -> Array[WeakRef]:
	var battle: Battle = TestBattles.build()
	battle.tower_sim.build(0, &"tower_single")
	TestBattles.finish(battle)
	return _refs(battle)


func _fatal_refs() -> Array[WeakRef]:
	var battle: Battle = TestBattles.build()
	await assert_error(battle.report_fatal.bind(CAUSE_A)).is_push_error(CAUSE_A)
	return _refs(battle)


func test_build_returns_battle_with_every_member_and_no_node() -> void:
	var battle: Battle = TestBattles.build()

	assert_object(battle).is_not_null()
	# `battle is Node` does not compile: Battle is a RefCounted, so the parser rejects it.
	assert_bool(battle.is_class("Node")).is_false()
	assert_object(battle.flow).is_not_null()
	assert_object(battle.combat).is_not_null()
	assert_object(battle.enemy_wave).is_not_null()
	assert_object(battle.tower_sim).is_not_null()
	assert_object(battle.hero_sim).is_not_null()
	assert_object(battle.resolver).is_not_null()
	assert_object(battle.sim_time).is_not_null()
	assert_object(battle.sim_rng).is_not_null()
	assert_int(int(battle.flow.phase())).is_equal(int(Flow.Phase.BUILD))
	assert_bool(battle.in_build()).is_true()
	assert_bool(battle.halted()).is_false()
	assert_int(battle.ticks_run()).is_equal(0)


func test_build_sets_seed_arc_tower_ids_and_wave_records() -> void:
	var cat: Catalogue = TestBattles.catalogue()
	var battle: Battle = BattleBuilder.build(cat, TestBattles.STAGE, 4242, Callable())

	assert_int(battle.rng_seed).is_equal(4242)
	var ids: Array[StringName] = cat.tower_ids()
	assert_int(battle.arc_tower_ids.size()).is_equal(mini(3, ids.size()))
	for i: int in battle.arc_tower_ids.size():
		assert_str(String(battle.arc_tower_ids[i])).is_equal(String(ids[i]))
	var stage: StageRecord = cat.stage(TestBattles.STAGE)
	assert_int(battle.wave_records.size()).is_equal(stage.wave_ids.size())
	for i: int in battle.wave_records.size():
		assert_str(String(battle.wave_records[i].id)).is_equal(String(stage.wave_ids[i]))


func test_build_sets_stage_record_and_visual_keys() -> void:
	var battle: Battle = TestBattles.build()

	assert_str(String(battle.stage_record.id)).is_equal("stage_a")
	assert_str(String(battle.input_record.id)).is_equal("input_a")
	assert_str(String(battle.visual_keys.hero())).is_equal("hero_a")
	assert_str(String(battle.visual_keys.enemy(&"enemy_grunt"))).is_equal("enemy_grunt")
	assert_str(String(battle.visual_keys.tower(&"tower_single", 2))).is_equal("tower_single_2")
	assert_str(String(battle.visual_keys.tower(&"tower_single", 3))).is_equal("")


func test_build_takes_values_from_the_stage_record() -> void:
	var battle: Battle = TestBattles.build()

	assert_int(battle.flow.lives()).is_equal(10)
	assert_int(battle.tower_sim.gold()).is_equal(120)
	assert_int(battle.tower_sim.slot_count()).is_equal(2)


func test_emitters_follow_emitter_keys_order() -> void:
	var battle: Battle = TestBattles.build()
	var list: Array[Object] = battle.emitters()

	assert_int(list.size()).is_equal(Battle.EMITTER_KEYS.size())
	assert_object(list[0]).is_same(battle.flow)
	assert_object(list[1]).is_same(battle.combat)
	assert_object(list[2]).is_same(battle.enemy_wave)
	assert_object(list[3]).is_same(battle.tower_sim)
	assert_object(list[4]).is_same(battle.hero_sim)
	assert_object(list[5]).is_same(battle.resolver)
	assert_object(Probe.system(battle, &"tower_sim")).is_same(battle.tower_sim)
	assert_object(Probe.system(battle, &"nope")).is_null()


func test_weakrefs_are_null_after_drop() -> void:
	var refs: Array[WeakRef] = _build_refs()

	assert_array(Probe.alive(refs)).is_empty()


func test_weakrefs_are_null_after_a_scripted_micro_battle() -> void:
	var refs: Array[WeakRef] = _micro_refs()

	assert_array(Probe.alive(refs)).is_empty()


func test_weakrefs_are_null_after_a_fatal() -> void:
	var refs: Array[WeakRef] = await _fatal_refs()

	assert_array(Probe.alive(refs)).is_empty()


func test_fatal_during_build_returns_null_and_sets_the_app_handler() -> void:
	var app: FakeApp = FakeApp.new()
	var run: BuildRun = BuildRun.new()
	run.cat = BadSlopCatalogue.new(TestBattles.catalogue())
	run.handler = app.on_fatal

	await assert_error(run.go).is_push_error(BattleBuilder.ERR_BAD_SLOPS)

	assert_object(run.result).is_null()
	assert_array(app.causes).is_equal([BattleBuilder.ERR_BAD_SLOPS])


func test_unknown_stage_is_fatal_during_build() -> void:
	var app: FakeApp = FakeApp.new()
	var cat: Catalogue = TestBattles.catalogue()

	var holder: Array[Battle] = [null]
	var go: Callable = _build_bad_stage.bind(cat, app, holder)
	await assert_error(go).is_push_error(BattleBuilder.ERR_NO_STAGE)

	assert_object(holder[0]).is_null()
	assert_int(app.causes.size()).is_equal(1)


func _build_bad_stage(cat: Catalogue, app: FakeApp, holder: Array[Battle]) -> void:
	holder[0] = BattleBuilder.build(cat, &"no_such_stage", 1, app.on_fatal)


func test_fatal_twice_keeps_the_first_cause_in_both_latches() -> void:
	var app: FakeApp = FakeApp.new()
	var battle: Battle = TestBattles.build(null, app.on_fatal)

	await assert_error(battle.report_fatal.bind(CAUSE_A)).is_push_error(CAUSE_A)
	battle.report_fatal(CAUSE_B)

	assert_str(battle.latch.cause()).is_equal(CAUSE_A)
	assert_array(app.causes).is_equal([CAUSE_A])


func test_after_fatal_halted_is_true_and_flow_reads_fatal() -> void:
	var battle: Battle = TestBattles.build()
	battle.flow.start_wave()

	await assert_error(battle.report_fatal.bind(CAUSE_A)).is_push_error(CAUSE_A)

	assert_bool(battle.halted()).is_true()
	assert_int(int(battle.flow.phase())).is_equal(int(Flow.Phase.FATAL))


func test_scripted_tick_after_fatal_changes_nothing() -> void:
	var battle: Battle = TestBattles.build()
	battle.flow.start_wave()
	battle.tick(battle.sim_time.dt)
	var before: String = Probe.digest(battle)

	await assert_error(battle.report_fatal.bind(CAUSE_A)).is_push_error(CAUSE_A)
	for i in range(5):
		battle.tick(battle.sim_time.dt)
	var after: String = Probe.digest(battle)

	assert_int(battle.ticks_run()).is_equal(1)
	# Only the phase differs (FATAL); every other field is the same.
	var before_data: Dictionary = JSON.parse_string(before) as Dictionary
	var after_data: Dictionary = JSON.parse_string(after) as Dictionary
	assert_int(int(after_data["phase"])).is_equal(int(Flow.Phase.FATAL))
	before_data.erase("phase")
	after_data.erase("phase")
	assert_dict(after_data).is_equal(before_data)
