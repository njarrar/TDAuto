extends GdUnitTestSuite
## Tower GDD criteria 1 to 12, 45 to 53 and 55 to 56 (build, upgrade, refusal
## order, gold) and ADR-0010 Validation 1 to 4 for TowerSim.

const Rig := preload("res://tests/unit/tower/helpers/tower_rig.gd")
const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")

const BUILT_TYPE: int = TYPE_STRING_NAME


func _built(slot: int, id: StringName) -> String:
	return "built:%d:%s:%d" % [slot, id, BUILT_TYPE]


func test_build_three_towers_pays_in_order_and_logs_gold_before_tower() -> void:
	var rig: Rig = Rig.new()

	var r0: TowerSim.BuildResult = rig.tower.build(0, Rig.A)
	var r1: TowerSim.BuildResult = rig.tower.build(1, Rig.B)
	var r2: TowerSim.BuildResult = rig.tower.build(2, Rig.C)

	assert_int(r0).is_equal(TowerSim.BuildResult.OK)
	assert_int(r1).is_equal(TowerSim.BuildResult.OK)
	assert_int(r2).is_equal(TowerSim.BuildResult.OK)
	assert_int(rig.tower.gold()).is_equal(10)
	assert_array(rig.rec.entries).is_equal([
		"gold:70", _built(0, Rig.A), "gold:40", _built(1, Rig.B), "gold:10", _built(2, Rig.C)])


func test_upgrade_raises_level_and_logs_gold_then_upgraded() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	rig.rec.entries.clear()

	var result: TowerSim.UpgradeResult = rig.tower.upgrade(0)

	assert_int(result).is_equal(TowerSim.UpgradeResult.OK)
	assert_int(rig.tower.gold()).is_equal(30)
	assert_int(rig.tower.slot_level(0)).is_equal(2)
	assert_array(rig.rec.entries).is_equal(["gold:30", "upgraded:0:2"])


func test_build_refusals_follow_check_order_and_change_nothing() -> void:
	var rig: Rig = Rig.new(100)
	rig.tower.build(0, Rig.A)
	rig.rec.entries.clear()
	var before: Dictionary = rig.tower.state_fields()
	var reads: int = rig.spy.reads.size()

	assert_int(rig.tower.build(-1, Rig.A)).is_equal(TowerSim.BuildResult.BAD_SLOT)
	assert_int(rig.tower.build(3, Rig.A)).is_equal(TowerSim.BuildResult.BAD_SLOT)
	assert_int(rig.tower.build(1, &"enemy_grunt")).is_equal(TowerSim.BuildResult.BAD_TOWER)
	assert_int(rig.tower.build(0, Rig.A)).is_equal(TowerSim.BuildResult.SLOT_OCCUPIED)
	assert_int(rig.spy.reads.size()).is_equal(reads)
	rig.tower.on_enemy_killed(0)
	var poor: Rig = Rig.new(29)
	assert_int(poor.tower.build(0, Rig.A)).is_equal(TowerSim.BuildResult.NO_GOLD)

	assert_dict(rig.tower.state_fields()).is_equal(before)
	assert_array(rig.rec.entries).is_empty()
	assert_int(poor.tower.gold()).is_equal(29)
	assert_array(poor.rec.entries).is_empty()
	assert_int(poor.spy.reads.size()).is_equal(1)


func test_halted_is_checked_first_and_before_any_read() -> void:
	var rig: Rig = Rig.new()
	rig.halt.on = true

	assert_int(rig.tower.build(-1, &"bogus")).is_equal(TowerSim.BuildResult.HALTED)
	assert_int(rig.tower.upgrade(-1)).is_equal(TowerSim.UpgradeResult.HALTED)
	assert_int(rig.spy.reads.size()).is_equal(0)


func test_upgrade_refusals_follow_check_order() -> void:
	var rig: Rig = Rig.new(100)

	assert_int(rig.tower.upgrade(-1)).is_equal(TowerSim.UpgradeResult.BAD_SLOT)
	assert_int(rig.tower.upgrade(3)).is_equal(TowerSim.UpgradeResult.BAD_SLOT)
	assert_int(rig.tower.upgrade(0)).is_equal(TowerSim.UpgradeResult.NO_TOWER)
	rig.tower.build(0, Rig.A)
	rig.tower.upgrade(0)
	assert_int(rig.tower.upgrade(0)).is_equal(TowerSim.UpgradeResult.MAX_LEVEL)

	var poor: Rig = Rig.new(30)
	poor.tower.build(0, Rig.A)
	poor.rec.entries.clear()
	assert_int(poor.tower.upgrade(0)).is_equal(TowerSim.UpgradeResult.NO_GOLD)
	assert_int(poor.tower.gold()).is_equal(0)
	assert_array(poor.rec.entries).is_empty()


func test_exact_gold_builds_and_reaches_zero() -> void:
	var rig: Rig = Rig.new(30)

	var result: TowerSim.BuildResult = rig.tower.build(0, Rig.A)

	assert_int(result).is_equal(TowerSim.BuildResult.OK)
	assert_int(rig.tower.gold()).is_equal(0)
	assert_array(rig.rec.entries).is_equal(["gold:0", _built(0, Rig.A)])


func test_cost_is_read_at_use_time_for_each_build() -> void:
	var rig: Rig = Rig.new(1000)
	rig.tower.build(0, Rig.A)
	rig.spy.set_value(Rig.A, 1, &"cost", 60.0)

	rig.tower.build(1, Rig.A)

	assert_int(rig.tower.gold()).is_equal(1000 - 30 - 60)


func test_latch_on_cost_read_gives_halted_and_changes_nothing() -> void:
	var rig: Rig = Rig.new()
	rig.spy.latch_key = &"cost"
	var before: Dictionary = rig.tower.state_fields()

	var result: TowerSim.BuildResult = rig.tower.build(0, Rig.A)

	assert_int(result).is_equal(TowerSim.BuildResult.HALTED)
	assert_dict(rig.tower.state_fields()).is_equal(before)
	assert_array(rig.rec.entries).is_empty()


func test_command_inside_tick_is_fatal_halted_and_mutates_nothing() -> void:
	var rig: Rig = Rig.new()
	rig.between.ok = false
	var before: Dictionary = rig.tower.state_fields()

	var built: TowerSim.BuildResult = rig.tower.build(0, Rig.A)

	assert_int(built).is_equal(TowerSim.BuildResult.HALTED)
	assert_str(rig.fatal.causes[0]).contains("TowerSim.build")
	assert_dict(rig.tower.state_fields()).is_equal(before)
	rig.halt.on = false
	assert_int(rig.tower.upgrade(0)).is_equal(TowerSim.UpgradeResult.HALTED)
	assert_str(rig.fatal.causes[1]).contains("TowerSim.upgrade")


func test_build_is_committed_before_gold_changed_listeners_read_slots() -> void:
	var rig: Rig = Rig.new()
	var seen: Array[String] = []
	rig.tower.gold_changed.connect(func(_current: int) -> void:
		seen.append("%s:%d" % [rig.tower.slot_tower(0), rig.tower.slot_level(0)]))

	rig.tower.build(0, Rig.A)

	assert_array(seen).is_equal(["tower_a:1"])


func test_new_tower_starts_ready_and_empty_slot_reads_are_empty() -> void:
	var rig: Rig = Rig.new()
	assert_str(String(rig.tower.slot_tower(0))).is_equal("")
	assert_int(rig.tower.slot_level(0)).is_equal(0)

	rig.tower.build(0, Rig.A)

	assert_str(String(rig.tower.slot_tower(0))).is_equal("tower_a")
	assert_int(rig.tower.slot_level(0)).is_equal(1)
	assert_int(rig.tower.slot_cooldown_left(0)).is_equal(0)
	assert_int(rig.tower.slot_count()).is_equal(3)
	assert_float(rig.tower.slot_position(1).x).is_equal(200.0)


func test_bad_slot_read_reports_once_and_returns_empty_values() -> void:
	var rig: Rig = Rig.new()

	assert_int(rig.tower.slot_level(9)).is_equal(0)
	assert_str(String(rig.tower.slot_tower(-1))).is_equal("")
	assert_int(rig.tower.slot_cooldown_left(3)).is_equal(0)

	assert_int(rig.devs.messages.size()).is_equal(1)
	assert_array(rig.fatal.causes).is_empty()


func test_gold_starts_at_stage_gold_with_no_signal() -> void:
	var rig: Rig = Rig.new(120)
	assert_int(rig.tower.gold()).is_equal(120)
	assert_array(rig.rec.entries).is_empty()


func test_kill_pays_bounty_and_zero_bounty_or_bonus_emit_nothing() -> void:
	var rig: Rig = Rig.new(100)

	rig.tower.on_enemy_killed(4)
	rig.tower.on_enemy_killed(3)
	assert_array(rig.rec.entries).is_equal(["gold:104", "gold:107"])
	rig.rec.entries.clear()
	rig.tower.on_enemy_killed(0)
	rig.tower.on_wave_called_early(0.0)

	assert_array(rig.rec.entries).is_empty()
	assert_int(rig.tower.gold()).is_equal(107)


func test_halted_pays_nothing_for_a_kill_or_a_call() -> void:
	var rig: Rig = Rig.new(100)
	rig.halt.on = true

	rig.tower.on_enemy_killed(4)
	rig.tower.on_wave_called_early(3.0)

	assert_int(rig.tower.gold()).is_equal(100)
	assert_array(rig.rec.entries).is_empty()


func test_gold_passes_100000_uncapped() -> void:
	var rig: Rig = Rig.new(99999)
	rig.tower.on_enemy_killed(5)
	assert_int(rig.tower.gold()).is_equal(100004)


func test_bounty_is_spendable_from_the_next_command() -> void:
	var rig: Rig = Rig.new(26)
	assert_int(rig.tower.build(0, Rig.A)).is_equal(TowerSim.BuildResult.NO_GOLD)

	rig.tower.on_enemy_killed(4)

	assert_int(rig.tower.build(0, Rig.A)).is_equal(TowerSim.BuildResult.OK)


func test_early_call_bonus_at_dt_quarter_rate_one() -> void:
	var rig: Rig = Rig.new(0, 1.0)

	rig.tower.on_wave_called_early(3.0)
	rig.tower.on_wave_called_early(2.75)
	rig.tower.on_wave_called_early(0.75)

	assert_int(rig.tower.gold()).is_equal(3 + 2 + 0)


func test_early_call_bonus_at_sixty_ticks_rate_one_point_eight() -> void:
	var sim: SimTime = SimTime.new()
	var rig: Rig = Rig.new(0, 1.8)
	var stage_data: Dictionary = DataFixtures.stage("s")
	stage_data["starting_gold"] = 0
	stage_data["early_call_seconds_per_gold"] = 1.8
	stage_data["slot_positions"] = [[100, 100]]
	var tower: TowerSim = TowerSim.new(StageRecord.from_dict(stage_data), rig.spy,
			rig.halt.is_halted, rig.between.is_between, rig.roster.targets,
			sim.to_ticks, rig.combat, rig.fatal.fatal, rig.devs.report)
	var paid: Array[int] = []

	assert_int(sim.to_ticks(1.8)).is_equal(108)
	for ticks_left: int in [900, 863, 108, 107]:
		var before: int = tower.gold()
		tower.on_wave_called_early(float(ticks_left) * sim.dt)
		paid.append(tower.gold() - before)

	assert_array(paid).is_equal([8, 7, 1, 0])


func test_rate_under_one_tick_is_fatal_at_construction() -> void:
	var rig: Rig = Rig.new(0, 1.0)
	var stage_data: Dictionary = DataFixtures.stage("s")
	stage_data["early_call_seconds_per_gold"] = 0.001

	TowerSim.new(StageRecord.from_dict(stage_data), rig.spy, rig.halt.is_halted,
			rig.between.is_between, rig.roster.targets, rig.sim_time.to_ticks, rig.combat,
			rig.fatal.fatal, rig.devs.report)

	assert_int(rig.fatal.causes.size()).is_equal(1)
	assert_str(rig.fatal.causes[0]).contains("early_call_seconds_per_gold")


func test_listeners_do_not_change_state() -> void:
	var with_listeners: Rig = Rig.new()
	var without: Rig = Rig.new()
	without.tower.gold_changed.disconnect(without.rec.on_gold)
	without.tower.tower_built.disconnect(without.rec.on_built)
	without.tower.tower_upgraded.disconnect(without.rec.on_upgraded)

	for rig: Rig in [with_listeners, without]:
		rig.tower.build(0, Rig.A)
		rig.tower.build(1, Rig.C)
		rig.tower.upgrade(0)

	assert_dict(with_listeners.tower.state_fields()).is_equal(without.tower.state_fields())


# Sell (Tower Rule 4, first playable 2026-11-05): 70% of all spend back, slot freed.

func test_sell_refunds_seventy_percent_of_build_and_upgrade_and_frees_the_slot() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	rig.tower.upgrade(0)
	assert_int(rig.tower.sell_value(0)).is_equal(49)
	rig.rec.entries.clear()

	var result: TowerSim.SellResult = rig.tower.sell(0)

	assert_int(result).is_equal(TowerSim.SellResult.OK)
	assert_int(rig.tower.gold()).is_equal(79)
	assert_str(String(rig.tower.slot_tower(0))).is_equal("")
	assert_int(rig.tower.slot_level(0)).is_equal(0)
	assert_int(rig.tower.sell_value(0)).is_equal(0)
	assert_array(rig.rec.entries).is_equal(["gold:79"])


func test_sell_refusals_change_nothing() -> void:
	var rig: Rig = Rig.new()
	rig.rec.entries.clear()

	assert_int(rig.tower.sell(0)).is_equal(TowerSim.SellResult.NO_TOWER)
	assert_int(rig.tower.sell(-1)).is_equal(TowerSim.SellResult.BAD_SLOT)
	assert_int(rig.tower.sell(99)).is_equal(TowerSim.SellResult.BAD_SLOT)

	assert_int(rig.tower.gold()).is_equal(100)
	assert_array(rig.rec.entries).is_empty()


func test_a_sold_slot_can_be_built_again_with_another_role() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	rig.tower.sell(0)

	var result: TowerSim.BuildResult = rig.tower.build(0, Rig.B)

	assert_int(result).is_equal(TowerSim.BuildResult.OK)
	assert_str(String(rig.tower.slot_tower(0))).is_equal(String(Rig.B))
	assert_int(rig.tower.sell_value(0)).is_equal(21)
