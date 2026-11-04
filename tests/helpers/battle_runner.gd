extends RefCounted
## Headless battle runner (ADR-0007 Decision 5, ADR-0010 Decision 9). The only
## way tests and bots advance a battle. No clock, no scene.


## Calls between(i) before each of up to `ticks` tick calls, then
## battle.tick(sim_time.dt). Stops early once the battle is halted. Build
## runs no ticks, so a script issues start_wave from between(0).
## Returns battle.ticks_run().
static func run(battle: Battle, ticks: int, between: Callable = Callable()) -> int:
	for i in range(ticks):
		if between.is_valid():
			between.call(i)
		battle.tick(battle.sim_time.dt)
		if battle.halted():
			break
	return battle.ticks_run()
