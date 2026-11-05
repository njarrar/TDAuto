extends RefCounted
## HeroSim fixture per the Hero GDD preamble: dt 0.25; damage 4, interval 0.5;
## leash 90; walk 100; burst damage 105, radius 50, cooldown 1.0, telegraph 0.5,
## reach 200; starter pin_rect and pin_exclusion; hero_start (350, 800).

const Fakes := preload("res://tests/helpers/sim_fakes.gd")
const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")

const HERO: StringName = &"hero_a"
const BURST: StringName = &"burst_a"

var sim_time: SimTime = SimTime.new(4)
var halt: Fakes.Halt = Fakes.Halt.new()
var between: Fakes.Between = Fakes.Between.new()
var build: Fakes.Build = Fakes.Build.new()
var fatal: Fakes.FatalLog = Fakes.FatalLog.new()
var roster: Fakes.Roster = Fakes.Roster.new()
var rec: Fakes.Recorder = Fakes.Recorder.new()
var spy: Fakes.SpyAccessor
var combat: Fakes.FakeCombat
var stage: StageRecord
var hero: HeroSim


static func stage_data() -> Dictionary:
	var data: Dictionary = DataFixtures.stage("stage_a")
	data["pin_exclusion"] = [
		{"a": [456, 816], "b": [456, 888], "radius": 60.0, "hand": "right"},
		{"a": [84, 816], "b": [84, 888], "radius": 60.0, "hand": "left"},
		{"a": [186, 800], "b": [186, 800], "radius": 60.0, "hand": "both"},
	]
	return data


func _init(left_handed: bool = false, data: Dictionary = stage_data()) -> void:
	stage = StageRecord.from_dict(data)
	fatal.halt = halt
	spy = Fakes.SpyAccessor.new(fatal.fatal)
	spy.halt = halt
	spy.set_value(HERO, 0, &"damage", 4.0)
	spy.set_value(HERO, 0, &"attack_interval", 0.5)
	spy.set_value(HERO, 0, &"leash_radius", 90.0)
	spy.set_value(HERO, 0, &"walk_speed", 100.0)
	spy.set_value(BURST, 0, &"damage", 105.0)
	spy.set_value(BURST, 0, &"radius", 50.0)
	spy.set_value(BURST, 0, &"cooldown", 1.0)
	spy.set_value(BURST, 0, &"telegraph_duration", 0.5)
	spy.set_value(BURST, 0, &"reach", 200.0)
	combat = Fakes.FakeCombat.new(sim_time.to_ticks)
	hero = HeroSim.new(stage, HERO, BURST, left_handed, spy, halt.is_halted, between.is_between,
			build.is_build, roster.targets, sim_time.to_ticks, sim_time.dt, combat, fatal.fatal)
	hero.hero_pinned.connect(rec.on_pinned)
	hero.burst_started.connect(rec.on_burst)


## Pins at (x, y) and ticks until the walk ends.
func pin_and_settle(x: float, y: float) -> void:
	hero.pin(Vector2(x, y))
	for i: int in range(20):
		if hero.pin_state() == HeroSim.PinState.PINNED:
			break
		hero.tick()
