extends GdUnitTestSuite
## EnemyWave movement, targets, leaks, reaping, halting, ownership and
## lifetime: Enemy & Wave Acceptance 1 to 22, 28, 29, 51 to 55 and ADR-0009
## Validation 2, 4, 5, 6, 10 and 11. Combat is the real class; the accessor is
## a spy over a code-built catalogue.

const WaveFixtures := preload("res://tests/helpers/wave_fixtures.gd")


func _ids(list: Array[Targetable]) -> Array[int]:
	var out: Array[int] = []
	for t: Targetable in list:
		out.append(t.spawn_id)
	return out


func _pos(t: Targetable) -> Vector2:
	return Vector2(t.pos_x, t.pos_y)


# Acceptance 1, 2, 3, 7

func test_positions_and_targets_follow_the_path_each_tick() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	var expected: Array[Vector2] = [Vector2(-10, 950), Vector2(0, 950), Vector2(10, 950),
			Vector2(10, 960), Vector2(10, 970)]
	var in_field: Array[bool] = [false, true, true, true, false]
	rig.wave.start_next_wave()

	for n: int in 5:
		WaveFixtures.step(rig)
		assert_int(rig.wave.roster().size()).is_equal(1)
		var e: Targetable = rig.wave.roster()[0]
		assert_vector(_pos(e)).is_equal(expected[n])
		assert_bool(rig.wave.targets().has(e)).is_equal(in_field[n])
		assert_float(e.distance).is_equal(10.0 * float(n + 1))


# Acceptance 4

func test_field_edge_is_inclusive_on_the_right() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.make_rig(
			WaveFixtures.path([560, 950, 530, 950, 530, 980]), WaveFixtures.default_waves())
	rig.wave.start_next_wave()

	WaveFixtures.step(rig)
	assert_float(rig.wave.roster()[0].pos_x).is_equal(550.0)
	assert_int(rig.wave.targets().size()).is_equal(0)
	WaveFixtures.step(rig)
	assert_float(rig.wave.roster()[0].pos_x).is_equal(540.0)
	assert_int(rig.wave.targets().size()).is_equal(1)


# Acceptance 6

func test_a_step_across_two_corners_lands_at_10_5() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.make_rig(
			WaveFixtures.path([0, 0, 5, 0, 5, 5, 25, 5]), WaveFixtures.default_waves(), 4, 60.0)
	rig.wave.start_next_wave()

	rig.wave.advance()

	assert_vector(_pos(rig.wave.roster()[0])).is_equal(Vector2(10, 5))


# Acceptance 8 and 9

func test_slow_halves_the_step() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	assert_bool(rig.wave.add_enemy(WaveFixtures.GRUNT, 0.0)).is_true()
	var e: Targetable = rig.wave.roster()[0]
	rig.combat.apply_slow(e, 0.5, 10.0)

	rig.wave.advance()

	assert_float(e.distance).is_equal(5.0)


func test_leak_boundary_at_the_path_end() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.add_enemy(WaveFixtures.GRUNT, 55.0)
	rig.wave.add_enemy(WaveFixtures.GRUNT, 54.5)
	rig.combat.apply_slow(rig.wave.roster()[0], 0.5, 10.0)
	rig.combat.apply_slow(rig.wave.roster()[1], 0.5, 10.0)

	rig.wave.advance()

	assert_array(rig.rec.lines).contains_exactly(["leaked(1)"])
	assert_int(rig.wave.roster().size()).is_equal(1)
	assert_float(rig.wave.roster()[0].distance).is_equal(59.5)


# Acceptance 10, 11, 12, 13: values are read at use time

func test_move_speed_is_read_each_tick() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()
	WaveFixtures.step(rig)
	rig.accessor.float_overrides[StatKeys.MOVE_SPEED] = 80.0

	WaveFixtures.step(rig)

	assert_float(rig.wave.roster()[0].distance).is_equal(30.0)


func test_lives_cost_is_read_at_the_leak() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()
	WaveFixtures.steps(rig, 5)
	assert_array(rig.rec.lines).is_empty()
	rig.accessor.int_overrides[StatKeys.LIVES_COST] = 2

	WaveFixtures.step(rig)

	assert_array(rig.rec.lines).contains_exactly(["leaked(2)", "cleared(2.0)"])


func test_bounty_is_read_at_the_reap() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()
	rig.wave.advance()
	rig.accessor.int_overrides[StatKeys.BOUNTY] = 7
	WaveFixtures.kill(rig, rig.wave.roster()[0])

	rig.wave.reap()

	assert_array(rig.rec.lines).contains_exactly(["killed(7)", "cleared(2.0)"])


func test_max_hp_is_read_once_at_spawn() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()
	rig.wave.advance()
	rig.accessor.float_overrides[StatKeys.MAX_HP] = 1.0

	WaveFixtures.step(rig)

	assert_float(rig.combat.hp_left(rig.wave.roster()[0])).is_equal(100.0)
	assert_int(rig.accessor.reads_of(StatKeys.MAX_HP)).is_equal(1)


# Acceptance 14, 15, 16: two stacked leakers

func _stacked_rig() -> WaveFixtures.Rig:
	var waves: Array[WaveRecord] = [
		WaveFixtures.wave_record([WaveFixtures.group(WaveFixtures.GRUNT, 2, 0.0, 0.0)]),
		WaveFixtures.simple_wave(),
	]
	var rig: WaveFixtures.Rig = WaveFixtures.make_rig(WaveFixtures.default_path(), waves)
	rig.accessor.int_by_spawn[StatKeys.LIVES_COST] = {0: 1, 1: 2}
	return rig


func test_two_adjacent_leakers_resolve_in_spawn_order() -> void:
	var rig: WaveFixtures.Rig = _stacked_rig()
	rig.wave.start_next_wave()

	WaveFixtures.steps(rig, 6)

	assert_array(rig.rec.lines).contains_exactly(["leaked(1)", "leaked(2)", "cleared(2.0)"])


func test_a_leaked_enemy_is_off_the_roster_before_its_signal() -> void:
	var rig: WaveFixtures.Rig = _stacked_rig()
	var probe: WaveFixtures.Probe = WaveFixtures.probe(rig)
	rig.wave.start_next_wave()

	WaveFixtures.steps(rig, 6)

	assert_array(probe.roster_sizes_at_leak).contains_exactly([1, 0])
	assert_array(probe.first_id_at_leak).contains_exactly([1])


func test_a_halt_during_the_first_leak_stops_the_second() -> void:
	var rig: WaveFixtures.Rig = _stacked_rig()
	var probe: WaveFixtures.Probe = WaveFixtures.probe(rig)
	probe.halt_on_first_leak = true
	rig.wave.start_next_wave()

	WaveFixtures.steps(rig, 6)

	assert_array(rig.rec.lines).contains_exactly(["leaked(1)"])
	assert_int(rig.wave.roster().size()).is_equal(1)
	assert_int(rig.wave.roster()[0].spawn_id).is_equal(1)


# Acceptance 17 to 22: halting

func test_a_halt_during_the_move_read_changes_nothing() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.add_enemy(WaveFixtures.GRUNT, 50.0)
	rig.accessor.latch_next(StatKeys.MOVE_SPEED)

	rig.wave.advance()

	assert_array(rig.rec.lines).is_empty()
	assert_float(rig.wave.roster()[0].distance).is_equal(50.0)
	assert_vector(_pos(rig.wave.roster()[0])).is_equal(Vector2(10, 970))


func test_reap_does_nothing_while_halted() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.add_enemy(WaveFixtures.GRUNT, 0.0)
	WaveFixtures.kill(rig, rig.wave.roster()[0])
	rig.spy.is_halted = true

	rig.wave.reap()

	assert_array(rig.rec.lines).is_empty()
	assert_int(rig.wave.roster().size()).is_equal(1)


func test_a_halt_during_the_second_members_max_hp_read_stops_the_spawn() -> void:
	var waves: Array[WaveRecord] = [
		WaveFixtures.wave_record([WaveFixtures.group(WaveFixtures.GRUNT, 3, 0.0, 0.0)]),
	]
	var rig: WaveFixtures.Rig = WaveFixtures.make_rig(WaveFixtures.default_path(), waves)
	rig.accessor.latch_key = StatKeys.MAX_HP
	rig.accessor.latch_on_read = 2
	rig.wave.start_next_wave()

	rig.wave.advance()

	assert_int(rig.wave.roster().size()).is_equal(1)
	assert_float(rig.wave.roster()[0].distance).is_equal(0.0)
	assert_int(rig.accessor.reads_of(StatKeys.MOVE_SPEED)).is_equal(0)
	assert_int(rig.wave.wave_tick()).is_equal(0)


func test_a_halt_during_the_lives_cost_read_emits_nothing() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.add_enemy(WaveFixtures.GRUNT, 59.0)
	rig.accessor.latch_next(StatKeys.LIVES_COST)

	rig.wave.advance()

	assert_array(rig.rec.lines).is_empty()
	assert_int(rig.wave.roster().size()).is_equal(1)
	assert_bool(rig.wave.roster()[0].removed).is_false()


func test_a_halt_during_the_bounty_read_emits_nothing() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.add_enemy(WaveFixtures.GRUNT, 0.0)
	WaveFixtures.kill(rig, rig.wave.roster()[0])
	rig.accessor.latch_next(StatKeys.BOUNTY)

	rig.wave.reap()

	assert_array(rig.rec.lines).is_empty()
	assert_int(rig.wave.roster().size()).is_equal(1)


func test_enemies_freeze_after_an_outcome() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()
	WaveFixtures.step(rig)
	var before: Vector2 = _pos(rig.wave.roster()[0])
	rig.spy.is_halted = true

	WaveFixtures.steps(rig, 10)

	assert_vector(_pos(rig.wave.roster()[0])).is_equal(before)
	assert_array(rig.rec.lines).is_empty()


# Acceptance 28: add_enemy from a kill listener

func test_a_kill_listener_that_adds_an_enemy_keeps_the_wave_open() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	var probe: WaveFixtures.Probe = WaveFixtures.probe(rig)
	probe.add_on_kill = true
	rig.wave.start_next_wave()
	rig.wave.advance()
	WaveFixtures.kill(rig, rig.wave.roster()[0])

	rig.wave.reap()

	assert_array(rig.rec.lines).contains_exactly(["killed(4)"])
	assert_int(rig.wave.roster().size()).is_equal(1)
	assert_int(rig.wave.roster()[0].spawn_id).is_equal(1)
	assert_int(int(rig.wave.wave_state())).is_equal(int(EnemyWave.WaveState.ACTIVE))
	WaveFixtures.steps(rig, 6)
	assert_array(rig.rec.lines).contains_exactly(["killed(4)", "leaked(1)", "cleared(2.0)"])


# Acceptance 29

func test_kills_are_paid_in_spawn_order_and_corpses_do_not_move() -> void:
	var waves: Array[WaveRecord] = [
		WaveFixtures.wave_record([WaveFixtures.group(WaveFixtures.GRUNT, 2, 0.0, 0.0)]),
		WaveFixtures.simple_wave(),
	]
	var rig: WaveFixtures.Rig = WaveFixtures.make_rig(WaveFixtures.default_path(), waves)
	rig.accessor.int_by_spawn[StatKeys.BOUNTY] = {0: 5, 1: 6}
	rig.wave.start_next_wave()
	rig.wave.advance()
	var first: Targetable = rig.wave.roster()[0]
	var second: Targetable = rig.wave.roster()[1]
	var at: Vector2 = _pos(first)
	WaveFixtures.kill(rig, second)
	WaveFixtures.kill(rig, first)

	rig.wave.reap()

	assert_array(rig.rec.lines).contains_exactly(["killed(5)", "killed(6)", "cleared(2.0)"])
	assert_int(rig.wave.roster().size()).is_equal(0)
	assert_bool(first.removed and second.removed).is_true()
	assert_vector(_pos(first)).is_equal(at)


# Acceptance 51, 52, 53, 54, 55

func test_a_path_shorter_than_one_step_leaks_on_the_first_tick() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.make_rig(
			WaveFixtures.path([-20, 950, -15, 950]), WaveFixtures.default_waves())
	rig.wave.start_next_wave()

	WaveFixtures.step(rig)

	assert_array(rig.rec.lines).contains_exactly(["leaked(1)", "cleared(2.0)"])
	assert_int(rig.wave.targets().size()).is_equal(0)


func test_a_zero_cost_enemy_still_leaks_and_leaves() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.accessor.int_overrides[StatKeys.LIVES_COST] = 0
	rig.wave.start_next_wave()

	WaveFixtures.steps(rig, 6)

	assert_array(rig.rec.lines).contains_exactly(["leaked(0)", "cleared(2.0)"])
	assert_int(rig.wave.roster().size()).is_equal(0)


func test_same_tick_spawns_are_ordered_by_spawn_id() -> void:
	var waves: Array[WaveRecord] = [
		WaveFixtures.wave_record([WaveFixtures.group(WaveFixtures.GRUNT, 3, 0.0, 0.0)]),
	]
	var rig: WaveFixtures.Rig = WaveFixtures.make_rig(WaveFixtures.default_path(), waves)
	rig.wave.start_next_wave()

	rig.wave.advance()

	assert_array(_ids(rig.wave.roster())).contains_exactly([0, 1, 2])


func test_a_corpse_stays_on_the_roster_until_the_reap() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()
	rig.wave.advance()
	var e: Targetable = rig.wave.roster()[0]
	WaveFixtures.kill(rig, e)

	assert_int(rig.wave.roster().size()).is_equal(1)
	assert_bool(rig.wave.roster().has(e)).is_true()
	assert_bool(e.removed).is_false()
	rig.wave.reap()
	assert_bool(e.removed).is_true()
	assert_int(rig.wave.roster().size()).is_equal(0)
	assert_int(rig.wave.targets().size()).is_equal(0)


func test_a_leak_never_pays_a_kill() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()

	WaveFixtures.steps(rig, 6)

	assert_array(rig.rec.lines).contains_exactly(["leaked(1)", "cleared(2.0)"])


func test_leaks_are_counted_by_type_and_kept() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()
	WaveFixtures.steps(rig, 6)

	rig.wave.start_next_wave()

	assert_int(rig.wave.wave_index()).is_equal(2)
	assert_int(int(rig.wave.got_through_by_type()[WaveFixtures.GRUNT])).is_equal(1)


# add_enemy and PathTrack failure paths

func test_bad_max_hp_at_spawn_is_fatal_and_adds_nothing() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.accessor.float_overrides[StatKeys.MAX_HP] = 0.0

	await assert_error(rig.wave.add_enemy.bind(WaveFixtures.GRUNT, 0.0)).is_push_error(Combat.ERR_BAD_MAX_HP)

	assert_int(rig.spy.fatals.size()).is_equal(1)
	assert_int(rig.wave.roster().size()).is_equal(0)
	assert_int(rig.wave.targets().size()).is_equal(0)


func test_a_halted_read_in_add_enemy_adds_nothing() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.accessor.latch_next(StatKeys.MAX_HP)

	var ok: bool = rig.wave.add_enemy(WaveFixtures.GRUNT, 0.0)

	assert_bool(ok).is_false()
	assert_int(rig.wave.roster().size()).is_equal(0)


func test_an_unusable_path_is_fatal_at_construction() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.make_rig(
			WaveFixtures.path([0, 0, 0, 0]), WaveFixtures.default_waves())

	assert_int(rig.spy.fatals.size()).is_equal(1)
	assert_str(rig.spy.fatals[0]).contains("stage_fixture")


func test_added_enemies_attach_and_join_in_spawn_order() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()

	rig.wave.add_enemy(WaveFixtures.GRUNT, 0.0)
	rig.wave.add_enemy(WaveFixtures.OTHER, 40.0)

	assert_array(_ids(rig.wave.roster())).contains_exactly([0, 1])
	assert_float(rig.combat.hp_left(rig.wave.roster()[1])).is_equal(100.0)
	assert_str(String((rig.wave.roster()[1] as Enemy).def_id)).is_equal("enemy_b")
	assert_vector(_pos(rig.wave.roster()[1])).is_equal(Vector2(10, 960))
	assert_array(_ids(rig.wave.targets())).contains_exactly([1])


# Validation 11: ownership check

func test_a_caller_appending_to_targets_is_reported_at_the_next_advance() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	var rogue: Targetable = Targetable.new(99)
	rig.wave.targets().append(rogue)

	rig.wave.advance()

	assert_int(rig.spy.dev_errors.size()).is_equal(1)
	assert_str(rig.spy.dev_errors[0]).contains("targets")


func test_a_caller_removing_from_the_roster_is_reported_at_the_next_reap() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.add_enemy(WaveFixtures.GRUNT, 0.0)
	rig.wave.add_enemy(WaveFixtures.GRUNT, 0.0)
	rig.wave.roster().remove_at(0)

	rig.wave.reap()

	assert_int(rig.spy.dev_errors.size()).is_equal(1)


func test_normal_play_raises_no_ownership_report() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()

	WaveFixtures.steps(rig, 12)

	assert_array(rig.spy.dev_errors).is_empty()


# Validation 5: attack steps leave the buffers alone

func test_a_tower_style_attack_step_leaves_roster_and_targets_unchanged() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.add_enemy(WaveFixtures.GRUNT, 25.0)
	rig.wave.add_enemy(WaveFixtures.GRUNT, 30.0)
	rig.wave.advance()
	var roster_before: Array[int] = _ids(rig.wave.roster())
	var targets_before: Array[int] = _ids(rig.wave.targets())

	var victim: Targetable = rig.combat.first_in(rig.wave.targets(), 10.0, 955.0, 60.0)
	rig.combat.report_attack(Combat.SourceKind.TOWER, &"tower_fixture", Vector2(10, 955), Vector2(10, 955), 20.0)
	for v: Targetable in rig.combat.all_in_radius(rig.wave.targets(), victim.pos_x, victim.pos_y, 20.0):
		rig.combat.deliver(DamageEvent.make(v, 10.0, Combat.SourceKind.TOWER, &"tower_fixture"))

	assert_array(_ids(rig.wave.roster())).contains_exactly(roster_before)
	assert_array(_ids(rig.wave.targets())).contains_exactly(targets_before)
	rig.wave.reap()
	assert_array(rig.spy.dev_errors).is_empty()


# Validation 4: lifetime

func _kill_and_reap(rig: WaveFixtures.Rig) -> void:
	WaveFixtures.kill(rig, rig.wave.roster()[0])
	rig.wave.reap()


func test_a_reaped_enemy_and_its_parts_are_freed() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()
	rig.wave.advance()
	var refs: Array[WeakRef] = []
	var e: Targetable = rig.wave.roster()[0]
	refs.append(weakref(e))
	refs.append(weakref(e.health))
	refs.append(weakref(e.status))
	refs.append(weakref(rig.wave._contexts[e.spawn_id]))
	e = null

	_kill_and_reap(rig)

	for r: WeakRef in refs:
		assert_object(r.get_ref()).is_null()


func test_dropping_the_wave_frees_every_enemy() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.add_enemy(WaveFixtures.GRUNT, 0.0)
	rig.wave.add_enemy(WaveFixtures.GRUNT, 10.0)
	var refs: Array[WeakRef] = []
	for t: Targetable in rig.wave.roster():
		refs.append(weakref(t))
		refs.append(weakref(t.health))
		refs.append(weakref(rig.wave._contexts[t.spawn_id]))
	rig = null

	for r: WeakRef in refs:
		assert_object(r.get_ref()).is_null()
