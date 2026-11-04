extends RefCounted
## Builds fixture battles through the production Builder. No class_name.

const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")
const Runner := preload("res://tests/helpers/battle_runner.gd")

const STAGE: StringName = &"stage_a"
const MAX_TICKS: int = 6000


## A Ready fixture catalogue (minimal data).
static func catalogue() -> Catalogue:
	return DataFixtures.ready(DataFixtures.minimal(), "battle")


## A battle on the fixture catalogue; the handler may be empty.
static func build(cat: Catalogue = null, handler: Callable = Callable()) -> Battle:
	var use_cat: Catalogue = cat if cat != null else catalogue()
	return BattleBuilder.build(use_cat, STAGE, 1, handler)


## A battle whose HeroSim is replaced by InertHeroSim before the first tick.
static func with_inert_hero(cat: Catalogue = null) -> Battle:
	var battle: Battle = build(cat)
	var real: HeroSim = battle.hero_sim
	battle.hero_sim = InertHeroSim.new(battle.stage_record, real.hero_id(), real.burst_id(),
			battle.input_record.left_handed, battle.accessor, battle.halted, battle.between_ticks,
			battle.in_build, battle.enemy_wave.targets, battle.sim_time.to_ticks,
			battle.sim_time.dt, battle.combat, battle.relay.fatal)
	return battle


## Starts the wave (if in Build) and ticks until the battle halts or MAX_TICKS.
static func finish(battle: Battle) -> void:
	if battle.in_build():
		battle.flow.start_wave()
	Runner.run(battle, MAX_TICKS)
