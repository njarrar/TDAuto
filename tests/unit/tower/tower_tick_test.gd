extends GdUnitTestSuite
## Tower GDD criteria 3, 4, 10, 31 to 44 and 54: the attack tick.
## Slot 0 is at (100, 100), slot 1 at (200, 100); dt is 0.25.

const Rig := preload("res://tests/unit/tower/helpers/tower_rig.gd")
const Fakes := preload("res://tests/helpers/sim_fakes.gd")


func _deliveries(rig: Rig) -> int:
	var count: int = 0
	for line: String in rig.combat.trace:
		if line.begins_with("deliver"):
			count += 1
	return count


func test_single_tower_fires_attack_then_deliver_at_level_one_damage() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	rig.roster.list.append(Fakes.target(1, 100.0, 150.0, 10.0))

	rig.tower.tick()

	assert_array(rig.combat.trace).is_equal([
		"attack:0:tower_a:0.0:100.0:150.0", "deliver:1:10.0:0:tower_a"])


func test_upgraded_tower_delivers_level_two_damage() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	rig.tower.upgrade(0)
	rig.roster.list.append(Fakes.target(1, 100.0, 150.0, 10.0))

	rig.tower.tick()

	assert_str(rig.combat.trace[1]).is_equal("deliver:1:15.0:0:tower_a")


func test_slow_tower_delivers_zero_then_applies_slow_and_counts_it() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.C)
	rig.tower.build(1, Rig.A)
	rig.roster.list.append(Fakes.target(1, 150.0, 100.0, 10.0))

	rig.tower.tick()

	assert_array(rig.combat.trace).is_equal([
		"attack:0:tower_c:0.0:150.0:100.0", "deliver:1:0.0:0:tower_c", "slow:1:0.5:1.0",
		"attack:0:tower_a:0.0:150.0:100.0", "deliver:1:10.0:0:tower_a"])
	assert_int(rig.tower.slows_applied()).is_equal(1)


func test_constant_target_fires_on_ticks_zero_two_four() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	rig.roster.list.append(Fakes.target(1, 100.0, 150.0, 10.0))
	var fired: Array[int] = []

	for t: int in range(5):
		var before: int = _deliveries(rig)
		rig.tower.tick()
		if _deliveries(rig) > before:
			fired.append(t)

	assert_array(fired).is_equal([0, 2, 4])


func test_target_present_at_tick_zero_and_from_tick_five_holds_at_zero() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	var enemy: Targetable = Fakes.target(1, 100.0, 150.0, 10.0)
	var fired: Array[int] = []

	for t: int in range(7):
		rig.roster.list.clear()
		if t == 0 or t >= 5:
			rig.roster.list.append(enemy)
		var before: int = _deliveries(rig)
		rig.tower.tick()
		if _deliveries(rig) > before:
			fired.append(t)
		if t == 2:
			assert_int(rig.tower.slot_cooldown_left(0)).is_equal(0)

	assert_array(fired).is_equal([0, 5])


func test_cooling_tower_makes_no_reads_and_ready_tower_without_target_reads_range_only() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	rig.roster.list.append(Fakes.target(1, 100.0, 150.0, 10.0))
	rig.tower.tick()
	var reads: int = rig.spy.reads.size()
	var trace: int = rig.combat.trace.size()

	rig.tower.tick()

	assert_int(rig.spy.reads.size()).is_equal(reads)
	assert_int(rig.combat.trace.size()).is_equal(trace)

	var idle: Rig = Rig.new()
	idle.tower.build(0, Rig.A)
	idle.tower.tick()
	assert_array(idle.spy.reads).is_equal(["tower_a|1|cost", "tower_a|1|range"])
	assert_array(idle.combat.trace).is_empty()


func test_built_tower_fires_on_the_first_tick_with_a_target() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(1, Rig.A)
	rig.roster.list.append(Fakes.target(1, 200.0, 150.0, 10.0))

	rig.tower.tick()

	assert_int(_deliveries(rig)).is_equal(1)


func test_slots_fire_in_ascending_order_and_cooldown_is_set_before_attack_fired() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(1, Rig.A)
	rig.tower.build(0, Rig.A)
	rig.roster.list.append(Fakes.target(1, 150.0, 100.0, 10.0))
	var cooldowns: Array[int] = []
	rig.combat.on_trace = func(line: String) -> void:
		if line.begins_with("attack"):
			cooldowns.append(rig.tower.slot_cooldown_left(0) + rig.tower.slot_cooldown_left(1) * 10)

	rig.tower.tick()

	assert_array(rig.combat.trace).is_equal([
		"attack:0:tower_a:0.0:150.0:100.0", "deliver:1:10.0:0:tower_a",
		"attack:0:tower_a:0.0:150.0:100.0", "deliver:1:10.0:0:tower_a"])
	assert_array(cooldowns).is_equal([2, 22])


func test_second_tower_finds_nothing_when_first_kills_the_only_target() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	rig.tower.build(1, Rig.A)
	rig.roster.list.append(Fakes.target(1, 150.0, 100.0, 10.0))
	rig.combat.on_trace = func(line: String) -> void:
		if line.begins_with("deliver"):
			rig.combat.dead_ids[1] = true

	rig.tower.tick()

	assert_int(_deliveries(rig)).is_equal(1)
	assert_int(rig.tower.slot_cooldown_left(1)).is_equal(0)


func test_halted_during_a_shot_stops_the_log_and_later_towers() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	rig.tower.build(1, Rig.A)
	rig.roster.list.append(Fakes.target(1, 150.0, 100.0, 10.0))
	rig.combat.on_trace = func(line: String) -> void:
		if line.begins_with("attack"):
			rig.halt.on = true

	rig.tower.tick()

	assert_int(rig.combat.trace.size()).is_equal(1)
	assert_int(rig.tower.slot_cooldown_left(1)).is_equal(0)


func test_latch_on_splash_radius_read_leaves_cooldown_and_log_untouched() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.B)
	rig.roster.list.append(Fakes.target(1, 100.0, 150.0, 10.0))
	rig.spy.latch_key = &"splash_radius"

	rig.tower.tick()

	assert_int(rig.tower.slot_cooldown_left(0)).is_equal(0)
	assert_array(rig.combat.trace).is_empty()


func test_damage_is_read_at_use_time_for_each_shot() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	rig.roster.list.append(Fakes.target(1, 100.0, 150.0, 10.0))
	rig.tower.tick()
	rig.spy.set_value(Rig.A, 1, &"damage", 20.0)
	rig.tower.tick()
	rig.tower.tick()

	assert_str(rig.combat.trace[3]).is_equal("deliver:1:20.0:0:tower_a")


func test_slow_tower_prefers_an_unslowed_enemy_then_falls_back_to_the_leader() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.C)
	var leader: Targetable = Fakes.target(1, 100.0, 150.0, 20.0)
	var follower: Targetable = Fakes.target(2, 100.0, 160.0, 10.0)
	rig.roster.list.append(leader)
	rig.roster.list.append(follower)
	rig.combat.slowed_ids[1] = true

	rig.tower.tick()
	assert_str(rig.combat.trace[1]).is_equal("deliver:2:0.0:0:tower_c")

	var rig2: Rig = Rig.new()
	rig2.tower.build(0, Rig.C)
	rig2.roster.list.append(leader)
	rig2.roster.list.append(follower)
	rig2.combat.slowed_ids[1] = true
	rig2.combat.slowed_ids[2] = true

	rig2.tower.tick()
	assert_str(rig2.combat.trace[1]).is_equal("deliver:1:0.0:0:tower_c")


func test_splash_hits_enemies_beyond_range_inside_radius_but_not_outside_targets() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.B)
	rig.roster.list.append(Fakes.target(1, 100.0, 195.0, 10.0))
	rig.roster.list.append(Fakes.target(2, 100.0, 225.0, 5.0))
	var outside: Targetable = Fakes.target(3, 100.0, 200.0, 1.0)

	rig.tower.tick()

	assert_array(rig.combat.trace).is_equal([
		"attack:0:tower_b:50.0:100.0:195.0", "deliver:1:10.0:0:tower_b",
		"deliver:2:10.0:0:tower_b"])
	assert_bool(outside.removed).is_false()


func test_upgrade_leaves_the_running_timer_and_next_reload_uses_new_interval() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	rig.roster.list.append(Fakes.target(1, 100.0, 150.0, 10.0))
	rig.tower.tick()
	assert_int(rig.tower.slot_cooldown_left(0)).is_equal(2)

	rig.tower.upgrade(0)
	assert_int(rig.tower.slot_cooldown_left(0)).is_equal(2)
	rig.tower.tick()
	rig.tower.tick()

	assert_str(rig.combat.trace[3]).is_equal("deliver:1:15.0:0:tower_a")
	assert_int(rig.tower.slot_cooldown_left(0)).is_equal(1)


func test_tick_does_nothing_once_halted() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	rig.roster.list.append(Fakes.target(1, 100.0, 150.0, 10.0))
	rig.halt.on = true

	rig.tower.tick()

	assert_array(rig.combat.trace).is_empty()


func test_attacks_do_not_change_gold() -> void:
	var rig: Rig = Rig.new()
	rig.tower.build(0, Rig.A)
	var gold: int = rig.tower.gold()
	rig.roster.list.append(Fakes.target(1, 100.0, 150.0, 10.0))

	rig.tower.tick()

	assert_int(rig.tower.gold()).is_equal(gold)
