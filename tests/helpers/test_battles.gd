extends RefCounted
## Builds fixture battles through the production Builder. No class_name.

const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")
const Runner := preload("res://tests/helpers/battle_runner.gd")
const Recording := preload("res://tests/helpers/recording_systems.gd")
const WiringCheck := preload("res://tests/helpers/wiring_check.gd")

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


## The tick-slot seam (ADR-0007 Decision 5, amended 2026-11-05). Builds a battle with
## the Builder, then remakes combat, enemy_wave, flow, tower_sim and hero_sim in
## Builder order from the battle's public members. Each system named in `keys`
## (&"combat", &"enemy_wave", &"flow", &"tower_sim", &"hero_sim") is the recording
## subclass; the others are the real class. Every tick entry appends [key, entry]
## to `log` (entries: flow tick, enemy_wave advance and reap, combat tick_status,
## tower_sim tick, hero_sim tick), then calls super. The Builder's connections and
## the relay's flow hook are remade, and the wiring check must come back empty.
## Call before the first tick. Returns null if the build or the wiring check fails.
static func with_recording(battle: Battle, keys: Array[StringName], log: Array) -> Battle:
	if battle == null:
		return null
	var stage: StageRecord = battle.stage_record
	var halted: Callable = battle.halted
	var fatal: Callable = battle.relay.fatal
	var to_ticks: Callable = battle.sim_time.to_ticks
	var dt: float = battle.sim_time.dt
	var old_hero: HeroSim = battle.hero_sim
	var hero_id: StringName = old_hero.hero_id()
	var burst_id: StringName = old_hero.burst_id()

	var combat: Combat
	if keys.has(&"combat"):
		combat = Recording.RecordingCombat.new(log, to_ticks)
	else:
		combat = Combat.new(to_ticks)
	var enemy_wave: EnemyWave
	if keys.has(&"enemy_wave"):
		enemy_wave = Recording.RecordingEnemyWave.new(log, stage, battle.wave_records, battle.accessor,
				combat, dt, FieldBounds.WIDTH, FieldBounds.HEIGHT, halted, fatal, battle.dev_error, to_ticks)
	else:
		enemy_wave = EnemyWave.new(stage, battle.wave_records, battle.accessor, combat, dt,
				FieldBounds.WIDTH, FieldBounds.HEIGHT, halted, fatal, battle.dev_error, to_ticks)
	var flow: Flow
	if keys.has(&"flow"):
		flow = Recording.RecordingFlow.new(log, stage, halted, battle.between_ticks, fatal, to_ticks, dt,
				enemy_wave.start_next_wave, battle.cancel_input, battle.dev_error, enemy_wave.wave_index,
				combat.dealt_by_kind, combat.dealt_total)
	else:
		flow = Flow.new(stage, halted, battle.between_ticks, fatal, to_ticks, dt,
				enemy_wave.start_next_wave, battle.cancel_input, battle.dev_error, enemy_wave.wave_index,
				combat.dealt_by_kind, combat.dealt_total)
	battle.relay.set_flow_hook(flow.enter_fatal)
	var tower_sim: TowerSim
	if keys.has(&"tower_sim"):
		tower_sim = Recording.RecordingTowerSim.new(log, stage, battle.accessor, halted, battle.between_ticks,
				enemy_wave.targets, to_ticks, combat, fatal, battle.dev_error)
	else:
		tower_sim = TowerSim.new(stage, battle.accessor, halted, battle.between_ticks,
				enemy_wave.targets, to_ticks, combat, fatal, battle.dev_error)
	var hero_sim: HeroSim
	if keys.has(&"hero_sim"):
		hero_sim = Recording.RecordingHeroSim.new(log, stage, hero_id, burst_id, battle.input_record.left_handed,
				battle.accessor, halted, battle.between_ticks, battle.in_build, enemy_wave.targets,
				to_ticks, dt, combat, fatal)
	else:
		hero_sim = HeroSim.new(stage, hero_id, burst_id, battle.input_record.left_handed,
				battle.accessor, halted, battle.between_ticks, battle.in_build, enemy_wave.targets,
				to_ticks, dt, combat, fatal)
	battle.combat = combat
	battle.enemy_wave = enemy_wave
	battle.flow = flow
	battle.tower_sim = tower_sim
	battle.hero_sim = hero_sim

	# The Builder's step 4 connections, flags 0 (ADR-0006 W1 to W5).
	enemy_wave.enemy_leaked.connect(flow.on_enemy_leaked)
	enemy_wave.enemy_killed.connect(tower_sim.on_enemy_killed)
	enemy_wave.wave_cleared.connect(flow.on_wave_cleared)
	enemy_wave.waves_completed.connect(flow.on_waves_completed)
	flow.wave_called_early.connect(tower_sim.on_wave_called_early)

	if not WiringCheck.check(battle).is_empty():
		return null
	return battle


## Starts the wave (if in Build) and ticks until the battle halts or MAX_TICKS.
static func finish(battle: Battle) -> void:
	if battle.in_build():
		battle.flow.start_wave()
	Runner.run(battle, MAX_TICKS)
