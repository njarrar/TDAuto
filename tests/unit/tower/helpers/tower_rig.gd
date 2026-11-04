extends RefCounted
## TowerSim fixture per the Tower GDD preamble: dt 0.25, gold 100; A single
## 30/40, damage 10/15, range 100/120, interval 0.5/0.25; B as A with splash
## radius 50; C as A, slow, damage 0, strength 0.5, 1.0 s. Three slots.

const Fakes := preload("res://tests/helpers/sim_fakes.gd")
const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")

const A: StringName = &"tower_a"
const B: StringName = &"tower_b"
const C: StringName = &"tower_c"

var sim_time: SimTime = SimTime.new(4)
var halt: Fakes.Halt = Fakes.Halt.new()
var between: Fakes.Between = Fakes.Between.new()
var fatal: Fakes.FatalLog = Fakes.FatalLog.new()
var devs: Fakes.DevLog = Fakes.DevLog.new()
var roster: Fakes.Roster = Fakes.Roster.new()
var rec: Fakes.Recorder = Fakes.Recorder.new()
var spy: Fakes.SpyAccessor
var combat: Fakes.FakeCombat
var tower: TowerSim


func _init(gold: int = 100, rate_seconds: float = 1.0) -> void:
	var data: Dictionary = DataFixtures.stage("stage_a")
	data["starting_gold"] = gold
	data["early_call_seconds_per_gold"] = rate_seconds
	data["slot_positions"] = [[100, 100], [200, 100], [300, 100]]
	var stage: StageRecord = StageRecord.from_dict(data)
	fatal.halt = halt
	spy = Fakes.SpyAccessor.new(fatal.fatal)
	spy.halt = halt
	for id: StringName in [A, B, C]:
		spy.levels[id] = 2
		spy.set_value(id, 1, &"cost", 30.0)
		spy.set_value(id, 2, &"cost", 40.0)
		spy.set_value(id, 1, &"damage", 10.0)
		spy.set_value(id, 2, &"damage", 15.0)
		spy.set_value(id, 1, &"range", 100.0)
		spy.set_value(id, 2, &"range", 120.0)
		spy.set_value(id, 1, &"attack_interval", 0.5)
		spy.set_value(id, 2, &"attack_interval", 0.25)
	spy.tags[A] = [&"single_target"]
	spy.tags[B] = [&"splash"]
	spy.tags[C] = [&"slow"]
	spy.set_value(B, 1, &"splash_radius", 50.0)
	spy.set_value(B, 2, &"splash_radius", 70.0)
	for level: int in [1, 2]:
		spy.set_value(C, level, &"damage", 0.0)
		spy.set_value(C, level, &"slow_strength", 0.5)
		spy.set_value(C, level, &"slow_duration", 1.0)
	combat = Fakes.FakeCombat.new(sim_time.to_ticks)
	tower = TowerSim.new(stage, spy, halt.is_halted, between.is_between, roster.targets,
			sim_time.to_ticks, combat, fatal.fatal, devs.report)
	tower.gold_changed.connect(rec.on_gold)
	tower.tower_built.connect(rec.on_built)
	tower.tower_upgraded.connect(rec.on_upgraded)
