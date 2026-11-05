extends RefCounted
## Recording subclasses of the tick-slot systems (ADR-0007 Decision 5, amended
## 2026-11-05). Each tick entry appends [key, entry] to one shared log, then calls
## super. _init forwards every argument with super (lint INIT-1). No class_name.


class RecordingCombat extends Combat:
	var calls: Array = []

	func _init(p_calls: Array, to_ticks: Callable) -> void:
		super(to_ticks)
		calls = p_calls

	func tick_status(roster: Array[Targetable]) -> void:
		calls.append([&"combat", &"tick_status"])
		super(roster)


class RecordingEnemyWave extends EnemyWave:
	var calls: Array = []

	func _init(p_calls: Array, stage: StageRecord, waves: Array[WaveRecord], accessor: StatAccessor,
			combat: Combat, dt: float, field_w: float, field_h: float, halted: Callable,
			fatal: Callable, dev_error: Callable, to_ticks: Callable) -> void:
		super(stage, waves, accessor, combat, dt, field_w, field_h, halted, fatal, dev_error, to_ticks)
		calls = p_calls

	func advance() -> void:
		calls.append([&"enemy_wave", &"advance"])
		super()

	func reap() -> void:
		calls.append([&"enemy_wave", &"reap"])
		super()


class RecordingFlow extends Flow:
	var calls: Array = []

	func _init(p_calls: Array, stage: StageRecord, halted: Callable, between_ticks: Callable,
			fatal: Callable, to_ticks: Callable, dt: float, start_next_wave: Callable,
			cancel_input: Callable, dev_error: Callable, wave_index: Callable,
			dealt_by_kind: Callable, dealt_total: Callable) -> void:
		super(stage, halted, between_ticks, fatal, to_ticks, dt, start_next_wave, cancel_input,
				dev_error, wave_index, dealt_by_kind, dealt_total)
		calls = p_calls

	func tick() -> void:
		calls.append([&"flow", &"tick"])
		super()


class RecordingTowerSim extends TowerSim:
	var calls: Array = []

	func _init(p_calls: Array, stage: StageRecord, accessor: StatAccessor, halted: Callable,
			between_ticks: Callable, targets: Callable, to_ticks: Callable, combat: Combat,
			fatal: Callable, dev_error: Callable) -> void:
		super(stage, accessor, halted, between_ticks, targets, to_ticks, combat, fatal, dev_error)
		calls = p_calls

	func tick() -> void:
		calls.append([&"tower_sim", &"tick"])
		super()


class RecordingHeroSim extends HeroSim:
	var calls: Array = []

	func _init(p_calls: Array, stage: StageRecord, hero_id: StringName, burst_id: StringName,
			left_handed: bool, accessor: StatAccessor, halted: Callable, between_ticks: Callable,
			in_build: Callable, targets: Callable, to_ticks: Callable, dt: float, combat: Combat,
			fatal: Callable) -> void:
		super(stage, hero_id, burst_id, left_handed, accessor, halted, between_ticks, in_build,
				targets, to_ticks, dt, combat, fatal)
		calls = p_calls

	func tick() -> void:
		calls.append([&"hero_sim", &"tick"])
		super()
