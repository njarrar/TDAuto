extends GdUnitTestSuite
## ADR-0001 Validation 3a (weakrefs null one frame after queue_free) and the
## ADR-0006 Decision 8 wrapper wiring test (attach twice: one connection per
## listener; nothing left after detach). Needs the wrapper scene.

const TestBattles := preload("res://tests/helpers/test_battles.gd")
const Contract := preload("res://tests/integration/battle_wiring/battle_signal_contract.gd")
const WRAPPER_SCENE: String = "res://src/root/battle_wrapper.tscn"
const LOOK_SCENE: String = "res://tests/helpers/stage_look_fixture.tscn"


func _battle() -> Battle:
	var battle: Battle = TestBattles.build()
	battle.stage_record.scene_ref = LOOK_SCENE
	return battle


func _wrapper() -> BattleWrapper:
	var scene: PackedScene = load(WRAPPER_SCENE)
	var wrapper: BattleWrapper = scene.instantiate() as BattleWrapper
	add_child(wrapper)
	return wrapper


func _emitter(battle: Battle, key: String) -> Object:
	return battle.emitters()[Battle.EMITTER_KEYS.find(StringName(key))]


func _owned(wrapper: BattleWrapper, target: Object, battle: Battle) -> bool:
	if target == wrapper:
		return true
	if target is Node:
		return wrapper.is_ancestor_of(target as Node)
	for system: Object in battle.emitters():
		if system == target:
			return false
	return target != null


func test_weakrefs_are_null_one_frame_after_queue_free() -> void:
	var battle: Battle = _battle()
	var wrapper: BattleWrapper = _wrapper()
	assert_bool(wrapper.attach(battle, false)).is_true()
	var refs: Array[WeakRef] = [weakref(battle), weakref(battle.resolver), weakref(battle.flow),
			weakref(battle.tower_sim), weakref(battle.hero_sim), weakref(battle.combat),
			weakref(battle.enemy_wave), weakref(wrapper), weakref(wrapper.get_node("InputAdapter"))]

	wrapper.detach()
	remove_child(wrapper)
	wrapper.queue_free()
	wrapper = null
	battle = null
	await get_tree().process_frame

	for ref: WeakRef in refs:
		assert_object(ref.get_ref()).is_null()


func test_attach_twice_gives_one_connection_per_listener() -> void:
	var battle: Battle = _battle()
	var wrapper: BattleWrapper = _wrapper()
	assert_bool(wrapper.attach(battle, false)).is_true()
	assert_bool(wrapper.attach(battle, false)).is_false()

	for key: String in Contract.VIEW_ALLOWLIST:
		var parts: PackedStringArray = key.split(".")
		var emitter: Object = _emitter(battle, parts[0])
		var connections: Array[Dictionary] = emitter.get_signal_connection_list(StringName(parts[1]))
		if Contract.VIEW_ALLOWLIST[key]:
			assert_int(connections.size()).is_greater(0)
		var seen: Dictionary = {}
		for entry: Dictionary in connections:
			var callable: Callable = entry["callable"]
			assert_int(int(entry["flags"])).is_equal(0)
			assert_bool(_owned(wrapper, callable.get_object(), battle)).is_true()
			var id: String = "%d:%s" % [callable.get_object_id(), callable.get_method()]
			assert_bool(seen.has(id)).is_false()
			seen[id] = true

	var adapter: InputAdapter = wrapper.get_node("InputAdapter") as InputAdapter
	# Flow.pause, HudLogic.clear_press, ResultScreen.clear_press, PausedScreen.clear_press.
	assert_int(adapter.lifecycle_paused.get_connections().size()).is_equal(4)
	assert_int(adapter.display_changed.get_connections().size()).is_equal(1)
	wrapper.detach()
	remove_child(wrapper)
	wrapper.queue_free()
	# Let queue_free run before gdUnit4 counts orphan nodes.
	await get_tree().process_frame


func test_after_detach_only_wiring_connections_remain() -> void:
	var battle: Battle = _battle()
	var wrapper: BattleWrapper = _wrapper()
	assert_bool(wrapper.attach(battle, false)).is_true()

	wrapper.detach()

	for key: String in Contract.VIEW_ALLOWLIST:
		var parts: PackedStringArray = key.split(".")
		var emitter: Object = _emitter(battle, parts[0])
		assert_int(emitter.get_signal_connection_list(StringName(parts[1])).size()).is_equal(0)
	for key: String in Contract.WIRING:
		var parts: PackedStringArray = key.split(".")
		var emitter: Object = _emitter(battle, parts[0])
		var expected: Array = Contract.WIRING[key]
		assert_int(emitter.get_signal_connection_list(StringName(parts[1])).size()).is_equal(expected.size())
	remove_child(wrapper)
	wrapper.queue_free()
	# Let queue_free run before gdUnit4 counts orphan nodes.
	await get_tree().process_frame


func test_wrapper_has_both_screens_hidden_and_above_the_drawers() -> void:
	var battle: Battle = _battle()
	var wrapper: BattleWrapper = _wrapper()
	assert_bool(wrapper.attach(battle, false)).is_true()

	var result: ResultScreen = wrapper.get_node("ResultScreen") as ResultScreen
	var paused: PausedScreen = wrapper.get_node("PausedScreen") as PausedScreen
	assert_object(result).is_not_null()
	assert_object(paused).is_not_null()
	assert_bool(result.visible).is_false()
	assert_bool(paused.visible).is_false()
	var top: int = wrapper.get_node("HudTopBand").get_index()
	assert_int(result.get_index()).is_greater(top)
	assert_int(paused.get_index()).is_greater(top)

	wrapper.detach()
	remove_child(wrapper)
	wrapper.queue_free()
	# Let queue_free run before gdUnit4 counts orphan nodes.
	await get_tree().process_frame


func test_paused_screen_opens_on_pause_and_closes_on_resume() -> void:
	var battle: Battle = _battle()
	var wrapper: BattleWrapper = _wrapper()
	assert_bool(wrapper.attach(battle, false)).is_true()
	var paused: PausedScreen = wrapper.get_node("PausedScreen") as PausedScreen

	battle.flow.pause()
	assert_bool(paused.visible).is_true()
	paused.resume_requested.emit()
	assert_bool(paused.visible).is_false()
	assert_int(int(battle.flow.phase())).is_equal(int(Flow.Phase.BUILD))

	wrapper.detach()
	remove_child(wrapper)
	wrapper.queue_free()
	# Let queue_free run before gdUnit4 counts orphan nodes.
	await get_tree().process_frame


func test_result_screen_opens_when_the_battle_ends() -> void:
	var battle: Battle = _battle()
	var wrapper: BattleWrapper = _wrapper()
	assert_bool(wrapper.attach(battle, false)).is_true()
	var result: ResultScreen = wrapper.get_node("ResultScreen") as ResultScreen

	TestBattles.finish(battle)

	assert_bool(battle.is_over()).is_true()
	assert_bool(result.visible).is_true()

	wrapper.detach()
	assert_bool(result.visible).is_false()
	remove_child(wrapper)
	wrapper.queue_free()
	# Let queue_free run before gdUnit4 counts orphan nodes.
	await get_tree().process_frame


func test_attach_after_detach_works_again() -> void:
	var battle: Battle = _battle()
	var wrapper: BattleWrapper = _wrapper()
	assert_bool(wrapper.attach(battle, false)).is_true()
	wrapper.detach()

	assert_bool(wrapper.attach(battle, true)).is_true()

	wrapper.detach()
	remove_child(wrapper)
	wrapper.queue_free()
	# Let queue_free run before gdUnit4 counts orphan nodes.
	await get_tree().process_frame


func test_missing_stage_look_fails_attach() -> void:
	var battle: Battle = TestBattles.build()
	var wrapper: BattleWrapper = _wrapper()

	# the fixture stage scene_ref does not exist; the failure goes through dev_error
	var sink: Array[String] = []
	battle.set_dev_error_sink(func(msg: String) -> void: sink.append(msg))

	assert_bool(wrapper.attach(battle, false)).is_false()
	assert_int(sink.size()).is_greater(0)
	remove_child(wrapper)
	wrapper.queue_free()
	# Let queue_free run before gdUnit4 counts orphan nodes.
	await get_tree().process_frame
