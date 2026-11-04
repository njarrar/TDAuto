extends GdUnitTestSuite
## Game State GDD integration criteria on the fixture stage (one wave of four
## grunts, 10 lives, 120 gold, bounty 4): a kill raises gold by the bounty, a
## leak drops lives, clearing all waves wins. Also ADR-0010 Validation 5 and 6.

const TestBattles := preload("res://tests/helpers/test_battles.gd")
const Probe := preload("res://tests/helpers/battle_probe.gd")
const Runner := preload("res://tests/helpers/battle_runner.gd")
const Invariant := preload("res://tests/helpers/combat_invariant.gd")

const TOWER_COST: int = 50
const BOUNTY: int = 4
const GRUNTS: int = 4


## Counts the wiring signals of one battle.
class Tally extends RefCounted:
	var bounties: Array[int] = []
	var leaks: int = 0
	var gold_events: Array[int] = []
	var lives_events: Array[int] = []

	func on_killed(bounty: int) -> void:
		bounties.append(bounty)

	func on_leaked(_cost: int) -> void:
		leaks += 1

	func on_gold(current: int) -> void:
		gold_events.append(current)

	func on_lives(current: int) -> void:
		lives_events.append(current)


func _tally(battle: Battle) -> Tally:
	var tally: Tally = Tally.new()
	battle.enemy_wave.enemy_killed.connect(tally.on_killed)
	battle.enemy_wave.enemy_leaked.connect(tally.on_leaked)
	battle.tower_sim.gold_changed.connect(tally.on_gold)
	battle.flow.lives_changed.connect(tally.on_lives)
	return tally


func test_leaks_drop_lives_and_clearing_the_last_wave_wins() -> void:
	var battle: Battle = TestBattles.build()
	var tally: Tally = _tally(battle)

	TestBattles.finish(battle)

	assert_int(int(battle.flow.phase())).is_equal(int(Flow.Phase.WON))
	assert_int(tally.leaks).is_equal(GRUNTS)
	assert_int(battle.flow.lives()).is_equal(10 - GRUNTS)
	assert_array(tally.lives_events).is_equal([9, 8, 7, 6])
	assert_int(battle.tower_sim.gold()).is_equal(120)
	assert_object(battle.flow.result()).is_not_null()
	assert_int(int(battle.flow.result().outcome)).is_equal(int(Flow.Phase.WON))
	assert_int(battle.flow.result().lives_left).is_equal(6)
	assert_bool(battle.halted()).is_true()


func test_a_kill_raises_gold_by_the_bounty() -> void:
	var battle: Battle = TestBattles.build()
	var tally: Tally = _tally(battle)
	assert_int(int(battle.tower_sim.build(0, &"tower_single"))).is_equal(int(TowerSim.BuildResult.OK))
	assert_int(battle.tower_sim.gold()).is_equal(120 - TOWER_COST)

	TestBattles.finish(battle)

	var kills: int = tally.bounties.size()
	assert_int(kills).is_greater_equal(1)
	assert_int(kills + tally.leaks).is_equal(GRUNTS)
	assert_int(battle.tower_sim.gold()).is_equal(120 - TOWER_COST + kills * BOUNTY)
	assert_int(battle.flow.lives()).is_equal(10 - tally.leaks)
	assert_int(int(battle.flow.phase())).is_equal(int(Flow.Phase.WON))
	assert_float(battle.combat.dealt_by_kind(Combat.SourceKind.TOWER)).is_greater(0.0)
	assert_bool(Invariant.holds(battle)).is_true()
	assert_int(tally.gold_events[0]).is_equal(120 - TOWER_COST)


func test_the_seed_is_never_read_by_the_sim() -> void:
	var a: Battle = BattleBuilder.build(TestBattles.catalogue(), TestBattles.STAGE, 1, Callable())
	var b: Battle = BattleBuilder.build(TestBattles.catalogue(), TestBattles.STAGE, 987654, Callable())
	TestBattles.finish(a)
	TestBattles.finish(b)

	assert_str(Probe.digest(a)).is_equal(Probe.digest(b))
	assert_int(a.sim_rng.draw_count()).is_equal(0)
	assert_int(b.sim_rng.draw_count()).is_equal(0)


func _script(battle: Battle) -> ScriptBot:
	var steps: Array[CommandStep] = [
		CommandStep.new(0, &"start_wave"),
		CommandStep.new(0, &"build", 0, &"tower_single"),
	]
	return ScriptBot.new(battle, steps)


## Runs the script and returns the digest after every tick.
func _digests(battle: Battle, include_hero: bool) -> Array[String]:
	var bot: ScriptBot = _script(battle)
	var list: Array[String] = []
	for i in range(TestBattles.MAX_TICKS):
		bot.between(i)
		battle.tick(battle.sim_time.dt)
		list.append(Probe.digest(battle, include_hero))
		if battle.halted():
			break
	return list


func test_two_script_bot_runs_on_one_input_give_equal_digests() -> void:
	var first: Battle = TestBattles.build()
	var second: Battle = TestBattles.build()

	var a: Array[String] = _digests(first, true)
	var b: Array[String] = _digests(second, true)

	assert_int(a.size()).is_greater(100)
	assert_array(a).is_equal(b)


func test_the_bot_results_are_recorded_in_issue_order() -> void:
	var battle: Battle = TestBattles.build()
	var bot: ScriptBot = _script(battle)

	bot.between(0)

	# start_wave first (Build, OK), then build in Wave: the build is still legal.
	assert_int(bot.results.size()).is_equal(2)
	assert_int(bot.results[0]).is_equal(int(Flow.StartResult.OK))


func test_a_never_pinned_hero_equals_an_absent_hero() -> void:
	var real: Battle = TestBattles.build()
	var inert: Battle = TestBattles.with_inert_hero()

	var a: Array[String] = _digests(real, false)
	var b: Array[String] = _digests(inert, false)

	assert_array(a).is_equal(b)
	assert_dict(real.hero_sim.state_fields()).is_equal(inert.hero_sim.state_fields())
	assert_int(real.hero_sim.repins()).is_equal(0)
	assert_int(real.hero_sim.bursts_fired()).is_equal(0)


func test_runner_stops_when_the_battle_halts() -> void:
	var battle: Battle = TestBattles.build()
	battle.flow.start_wave()

	var ran: int = Runner.run(battle, TestBattles.MAX_TICKS)

	assert_bool(battle.halted()).is_true()
	assert_int(ran).is_less(TestBattles.MAX_TICKS)
