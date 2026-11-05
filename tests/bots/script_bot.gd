extends "res://tests/bots/bot.gd"
## Issues scripted CommandSteps. Each between() call issues every unfired step
## with at_tick <= battle.ticks_run(), in array order (ADR-0010 Decision 9).

const CommandStep := preload("res://tests/bots/command_step.gd")

## Result code of each issued step, as int, in issue order.
var results: PackedInt32Array = PackedInt32Array()

var _steps: Array[CommandStep] = []
var _cursor: int = 0


func _init(p_battle: Battle, p_steps: Array[CommandStep]) -> void:
	super(p_battle)
	# Stable insertion sort by at_tick.
	for step: CommandStep in p_steps:
		var at: int = _steps.size()
		while at > 0 and _steps[at - 1].at_tick > step.at_tick:
			at -= 1
		_steps.insert(at, step)


func between(_i: int) -> void:
	while _cursor < _steps.size() and _steps[_cursor].at_tick <= battle.ticks_run():
		var step: CommandStep = _steps[_cursor]
		_cursor += 1
		results.append(_issue(step))


func _issue(step: CommandStep) -> int:
	match step.command:
		&"build":
			return int(battle.tower_sim.build(step.slot_index, step.tower_id))
		&"upgrade":
			return int(battle.tower_sim.upgrade(step.slot_index))
		&"pin":
			return int(battle.hero_sim.pin(Vector2(step.x, step.y)))
		&"burst":
			return int(battle.hero_sim.burst(Vector2(step.x, step.y)))
		&"start_wave":
			return int(battle.flow.start_wave())
		&"call_early":
			return int(battle.flow.call_early())
	return -1
