class_name BattleBuilder extends RefCounted
## Builds and wires one Battle (ADR-0001 Decision 5). Static only; never
## instantiated. Wiring only: no gameplay branch. Touches no Node or SceneTree.

const ERR_NO_CATALOGUE: String = "battle_builder: no catalogue"
const ERR_NO_INPUT: String = "battle_builder: catalogue has no Input record"
const ERR_NO_STAGE: String = "battle_builder: unknown stage id"
const ERR_NO_WAVE: String = "battle_builder: stage names an unknown wave"
const ERR_NO_HERO: String = "battle_builder: catalogue has no Hero record"
const ERR_BAD_SLOPS: String = "battle_builder: input slops are out of range"


## Builds one battle from its four inputs. Returns the Battle, or null if a
## fatal fired during the build (the partial battle is dropped).
static func build(catalogue: Catalogue, stage_id: StringName, rng_seed: int, fatal_handler: Callable) -> Battle:
	# Step 1: latch, relay, accessor (ADR-0005).
	var latch: FatalLatch = FatalLatch.new()
	var relay: FatalRelay = FatalRelay.new(latch, fatal_handler)
	var battle: Battle = Battle.new()
	battle.latch = latch
	battle.relay = relay
	if catalogue == null:
		relay.fatal(ERR_NO_CATALOGUE)
		return null
	var accessor: StatAccessor = StatAccessor.new(catalogue, relay.fatal)
	battle.accessor = accessor

	# Step 2: validate stage inputs, create the resolver (ADR-0008 Decision 2).
	var input_record: InputRecord = catalogue.input()
	if input_record == null:
		relay.fatal(ERR_NO_INPUT)
		return null
	var stage: StageRecord = catalogue.stage(stage_id)
	if stage == null:
		relay.fatal(ERR_NO_STAGE)
		return null
	var waves: Array[WaveRecord] = []
	for wave_id: StringName in stage.wave_ids:
		var wave: WaveRecord = catalogue.wave(wave_id)
		if wave == null:
			relay.fatal(ERR_NO_WAVE)
			return null
		waves.append(wave)
	var snap: Dictionary = {}
	var parsed: Variant = JSON.parse_string(catalogue.snapshot())
	if parsed is Dictionary:
		snap = parsed
	var hero_id: StringName = _first_hero_id(snap)
	var hero_record: HeroRecord = null
	if hero_id != &"":
		hero_record = catalogue.hero(hero_id)
	if hero_record == null:
		relay.fatal(ERR_NO_HERO)
		return null
	var resolver: InputResolver = InputResolver.create(input_record.drag_slop, input_record.tap_slop, battle.dev_error)
	if resolver == null:
		relay.fatal(ERR_BAD_SLOPS)
		return null
	battle.input_record = input_record
	battle.stage_record = stage
	battle.visual_keys = VisualKeys.from_snapshot(snap, hero_id)
	battle.resolver = resolver

	# Step 3: construct the systems.
	var sim_time: SimTime = SimTime.new()
	var sim_rng: SimRng = SimRng.new(rng_seed)
	var combat: Combat = Combat.new(sim_time.to_ticks)
	var enemy_wave: EnemyWave = EnemyWave.new(stage, waves, accessor, combat, sim_time.dt,
			FieldBounds.WIDTH, FieldBounds.HEIGHT, battle.halted, relay.fatal, battle.dev_error,
			sim_time.to_ticks)
	var flow: Flow = Flow.new(stage, battle.halted, battle.between_ticks, relay.fatal,
			sim_time.to_ticks, sim_time.dt, enemy_wave.start_next_wave, battle.cancel_input,
			battle.dev_error, enemy_wave.wave_index, combat.dealt_by_kind, combat.dealt_total)
	relay.set_flow_hook(flow.enter_fatal)
	var tower_sim: TowerSim = TowerSim.new(stage, accessor, battle.halted, battle.between_ticks,
			enemy_wave.targets, sim_time.to_ticks, combat, relay.fatal, battle.dev_error)
	var hero_sim: HeroSim = HeroSim.new(stage, hero_id, hero_record.burst_id, input_record.left_handed,
			accessor, battle.halted, battle.between_ticks, battle.in_build, enemy_wave.targets,
			sim_time.to_ticks, sim_time.dt, combat, relay.fatal)
	battle.sim_time = sim_time
	battle.sim_rng = sim_rng
	battle.combat = combat
	battle.enemy_wave = enemy_wave
	battle.flow = flow
	battle.tower_sim = tower_sim
	battle.hero_sim = hero_sim

	# Step 4: every sim-to-sim connection (ADR-0006 W1 to W5), flags 0.
	enemy_wave.enemy_leaked.connect(flow.on_enemy_leaked)
	enemy_wave.enemy_killed.connect(tower_sim.on_enemy_killed)
	enemy_wave.wave_cleared.connect(flow.on_wave_cleared)
	enemy_wave.waves_completed.connect(flow.on_waves_completed)
	flow.wave_called_early.connect(tower_sim.on_wave_called_early)

	# Step 5.
	if latch.is_fatal():
		return null
	return battle


## The first hero id in the snapshot, in sorted order, or &"" if none.
## The catalogue has no hero list yet, so the snapshot is read (see report).
static func _first_hero_id(snap: Dictionary) -> StringName:
	var heroes: Dictionary = snap.get("hero", {}) as Dictionary
	var ids: Array = heroes.keys()
	if ids.is_empty():
		return &""
	ids.sort()
	return StringName(String(ids[0]))
