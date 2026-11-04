class_name Battle extends RefCounted
## One battle: a plain object with no node (ADR-0001). Created and wired only by
## BattleBuilder, which sets every member. Members are read-only by contract.
## Owns the tick gate and the one tick order (ADR-0004 Decisions 3 and 4).

## Message recorded when tick() is called inside a tick.
const ERR_REENTRANT: String = "battle: tick called inside a tick"
## Message recorded when tick() gets a dt other than sim_time.dt.
const ERR_BAD_DT: String = "battle: tick dt does not equal sim_time.dt"

## Emitter order for emitters() (ADR-0006 Decision 8).
const EMITTER_KEYS: Array[StringName] = [&"flow", &"combat", &"enemy_wave", &"tower_sim", &"hero_sim", &"resolver"]

var flow: Flow = null
var combat: Combat = null
var enemy_wave: EnemyWave = null
var tower_sim: TowerSim = null
## A test may replace this before the first tick (InertHeroSim, ADR-0010 Decision 9).
var hero_sim: HeroSim = null
## Read-only (ADR-0008 Decision 2).
var resolver: InputResolver = null
var sim_time: SimTime = null
var sim_rng: SimRng = null
var accessor: StatAccessor = null
var latch: FatalLatch = null
var relay: FatalRelay = null
## Read-only by contract; set by BattleBuilder (ADR-0003, ADR-0005 Decision 8).
var input_record: InputRecord = null
## Read-only by contract; set by BattleBuilder (ADR-0011).
var stage_record: StageRecord = null
## Read-only by contract; StringNames only; set by BattleBuilder (ADR-0011).
var visual_keys: VisualKeys = null

var _ticking: bool = false
var _ticks_run: int = 0
var _canceller: Callable = Callable()
var _dev_sink: DevErrorSink = DevErrorSink.new()
var _dev_error_fn: Callable = Callable()


func _init() -> void:
	_dev_error_fn = _dev_sink.report


## One fixed tick. Gate in order: not inside a tick, dt equals sim_time.dt, not
## halted, phase WAVE or INTERMISSION. Anything else returns at once.
func tick(dt: float) -> void:
	if _ticking:
		dev_error(ERR_REENTRANT)
		return
	if sim_time == null or dt != sim_time.dt:
		dev_error(ERR_BAD_DT)
		return
	if halted() or flow == null:
		return
	var phase: Flow.Phase = flow.phase()
	if phase != Flow.Phase.WAVE and phase != Flow.Phase.INTERMISSION:
		return
	_ticking = true
	_run_steps()
	_ticking = false
	_ticks_run += 1


## True when Flow is WON, LOST or FATAL, or the battle latch is set. False while PAUSED.
func halted() -> bool:
	if latch != null and latch.is_fatal():
		return true
	if flow == null:
		return false
	var phase: Flow.Phase = flow.phase()
	return phase == Flow.Phase.WON or phase == Flow.Phase.LOST or phase == Flow.Phase.FATAL


## True while Flow is in Build (and before Flow exists).
func in_build() -> bool:
	if flow == null:
		return true
	return flow.in_build()


## True when Flow is WON or LOST.
func is_over() -> bool:
	if flow == null:
		return false
	var phase: Flow.Phase = flow.phase()
	return phase == Flow.Phase.WON or phase == Flow.Phase.LOST


## False only while tick() runs (ADR-0004 Decision 4).
func between_ticks() -> bool:
	return not _ticking


## Ticks that passed the gate (indexes bot scripts and the dev log).
func ticks_run() -> int:
	return _ticks_run


## Reports a fatal cause through the relay. For AppRoot's own InStage failures.
func report_fatal(cause: String) -> void:
	if relay != null:
		relay.fatal(cause)


## Calls the held input canceller; a no-op headless.
func cancel_input() -> void:
	if _canceller.is_valid():
		_canceller.call()


## The wrapper sets this to InputAdapter.cancel_all after build.
func set_input_canceller(c: Callable) -> void:
	_canceller = c


## The injected dev_error sink: calls the held sink (DevErrorSink.report by default).
func dev_error(msg: String) -> void:
	if _dev_error_fn.is_valid():
		_dev_error_fn.call(msg)
	else:
		push_error(msg)


## Replaces the dev-error sink. Tests inject a recording fake before the first tick.
func set_dev_error_sink(sink: Callable) -> void:
	_dev_error_fn = sink


## The battle emitters in EMITTER_KEYS order. Read-only use, for tests and tools.
func emitters() -> Array[Object]:
	var list: Array[Object] = [flow, combat, enemy_wave, tower_sim, hero_sim, resolver]
	return list


## The six steps of ADR-0004 Decision 4. Every early halted() return is here.
func _run_steps() -> void:
	flow.tick()
	if halted():
		return
	enemy_wave.advance()
	if halted():
		return
	combat.tick_status(enemy_wave.roster())
	if halted():
		return
	tower_sim.tick()
	if halted():
		return
	hero_sim.tick()
	if halted():
		return
	enemy_wave.reap()
