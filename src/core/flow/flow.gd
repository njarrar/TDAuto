class_name Flow extends RefCounted
## Stage flow and lives (Game State GDD, ADR-0004, ADR-0006, ADR-0010).
## A pure object: no scene, no clock. Time enters only through tick().
## Commands (start_wave, call_early, pause, resume) run between ticks only.

enum Phase { BUILD, WAVE, INTERMISSION, PAUSED, WON, LOST, FATAL }
enum StartResult { OK = 0, HALTED = 1, NOT_BUILD = 2 }
enum CallResult { OK = 0, HALTED = 1, NOT_INTERMISSION = 2, NOTHING_LEFT = 3 }

## P1. Each phase change. Outcomes and PAUSED follow Rule 15's commit order
## (state, gate, cancel_input, emit). FATAL comes from enter_fatal.
signal phase_changed(value: Phase)
## P2. Inside the W1 handler, only on a change, before any phase_changed(LOST).
signal lives_changed(current: int)
## W5. Inside call_early, before phase_changed(WAVE).
signal wave_called_early(seconds_left: float)

## Whole ticks left in the intermission. Never float subtraction.
var intermission_left: int = 0

var _phase: Phase = Phase.BUILD
var _resume_phase: Phase = Phase.BUILD
var _lives: int = 0
var _result: StageResult = null
var _dt: float = 0.0
var _halted: Callable
var _between_ticks: Callable
var _fatal: Callable
var _to_ticks: Callable
var _start_next_wave: Callable
var _cancel_input: Callable
var _dev_error: Callable
var _wave_index: Callable
var _dealt_by_kind: Callable
var _dealt_total: Callable


## Lives come from the stage record. The optional Callables default to an empty
## Callable and are called only after is_valid().
func _init(stage: StageRecord, halted: Callable, between_ticks: Callable, fatal: Callable,
		to_ticks: Callable, dt: float, start_next_wave: Callable,
		cancel_input: Callable = Callable(), dev_error: Callable = Callable(),
		wave_index: Callable = Callable(), dealt_by_kind: Callable = Callable(),
		dealt_total: Callable = Callable()) -> void:
	_lives = stage.starting_lives
	_halted = halted
	_between_ticks = between_ticks
	_fatal = fatal
	_to_ticks = to_ticks
	_dt = dt
	_start_next_wave = start_next_wave
	_cancel_input = cancel_input
	_dev_error = dev_error
	_wave_index = wave_index
	_dealt_by_kind = dealt_by_kind
	_dealt_total = dealt_total
	if not to_ticks.is_valid():
		_report_fatal("flow: to_ticks callable is not valid")


## The current phase.
func phase() -> Phase:
	return _phase


## Lives left.
func lives() -> int:
	return _lives


## The outcome record, or null before an outcome. The same object afterwards.
func result() -> StageResult:
	return _result


## True while the stage is in Build.
func in_build() -> bool:
	return _phase == Phase.BUILD


## Tick step 1: the intermission countdown and the wave start. A tick that
## enters Intermission does not decrement (Flow ticks before EnemyWave).
func tick() -> void:
	if _is_halted() or _phase != Phase.INTERMISSION:
		return
	intermission_left = maxi(0, intermission_left - 1)
	if intermission_left > 0:
		return
	_begin_wave()
	if _is_halted():
		return
	phase_changed.emit(Phase.WAVE)


## Start Wave in Build. A second call finds no Build and returns NOT_BUILD.
func start_wave() -> StartResult:
	if _inside_tick("command inside tick: Flow.start_wave"):
		return StartResult.HALTED
	if _is_halted():
		return StartResult.HALTED
	if _phase != Phase.BUILD:
		return StartResult.NOT_BUILD
	_begin_wave()
	if _is_halted():
		return StartResult.HALTED
	phase_changed.emit(Phase.WAVE)
	return StartResult.OK


## Call the next wave during Intermission. Emits wave_called_early(seconds_left)
## then phase_changed(WAVE). A call at 0 ticks left is NOTHING_LEFT, no signal.
func call_early() -> CallResult:
	if _inside_tick("command inside tick: Flow.call_early"):
		return CallResult.HALTED
	if _is_halted():
		return CallResult.HALTED
	if _phase != Phase.INTERMISSION:
		return CallResult.NOT_INTERMISSION
	if intermission_left <= 0:
		return CallResult.NOTHING_LEFT
	var seconds_left: float = float(intermission_left) * _dt
	_begin_wave()
	if _is_halted():
		return CallResult.HALTED
	wave_called_early.emit(seconds_left)
	if _is_halted():
		return CallResult.OK
	phase_changed.emit(Phase.WAVE)
	return CallResult.OK


## Enters Paused and remembers the phase left. Does nothing in a terminal
## state or when already paused.
func pause() -> void:
	if _inside_tick("command inside tick: Flow.pause"):
		return
	if _is_halted() or _phase == Phase.PAUSED:
		return
	_resume_phase = _phase
	_phase = Phase.PAUSED
	_call_cancel_input()
	phase_changed.emit(Phase.PAUSED)


## Leaves Paused for the phase it left. Countdowns continue exactly.
func resume() -> void:
	if _inside_tick("command inside tick: Flow.resume"):
		return
	if _phase != Phase.PAUSED or _is_halted():
		return
	_phase = _resume_phase
	phase_changed.emit(_phase)


## Called by FatalRelay after the battle latch is set. Commits FATAL, then
## emits phase_changed(FATAL). Idempotent.
func enter_fatal() -> void:
	if _phase == Phase.FATAL:
		return
	_commit_outcome(Phase.FATAL)
	phase_changed.emit(Phase.FATAL)


## W1 only. Applies lives = max(0, lives - lives_cost).
func on_enemy_leaked(lives_cost: int) -> void:
	if _phase == Phase.WON or _phase == Phase.LOST or _phase == Phase.FATAL:
		return
	if _phase == Phase.BUILD or _phase == Phase.PAUSED:
		_report_dev_error("flow: enemy_leaked in a phase with no wave")
		return
	if _halted.is_valid() and bool(_halted.call()):
		return
	if _phase == Phase.INTERMISSION:
		_report_dev_error("flow: enemy_leaked during Intermission (applied)")
	var after: int = maxi(0, _lives - lives_cost)
	if after == _lives:
		return
	_lives = after
	var lost: bool = _lives == 0
	if lost:
		_commit_outcome(Phase.LOST)
	lives_changed.emit(_lives)
	if not lost and _is_halted():
		return
	if lost:
		phase_changed.emit(Phase.LOST)


## W3 only. Starts the intermission from the wave record's duration.
func on_wave_cleared(intermission_duration: float) -> void:
	if _phase != Phase.WAVE:
		_wrong_phase_event("wave_cleared")
		return
	if _is_halted():
		return
	_phase = Phase.INTERMISSION
	intermission_left = maxi(0, int(_to_ticks.call(intermission_duration)))
	phase_changed.emit(Phase.INTERMISSION)


## W4 only. The last wave is done: Won.
func on_waves_completed() -> void:
	if _phase != Phase.WAVE:
		_wrong_phase_event("waves_completed")
		return
	if _is_halted():
		return
	_commit_outcome(Phase.WON)
	phase_changed.emit(Phase.WON)


func _begin_wave() -> void:
	_phase = Phase.WAVE
	intermission_left = 0
	if _start_next_wave.is_valid():
		_start_next_wave.call()


func _commit_outcome(outcome: Phase) -> void:
	_phase = outcome
	if _result == null:
		_result = _build_result(outcome)
	_call_cancel_input()


func _build_result(outcome: Phase) -> StageResult:
	var built: StageResult = StageResult.new()
	built.outcome = outcome
	built.lives_left = _lives
	if _wave_index.is_valid():
		built.last_wave_started = int(_wave_index.call())
	if _dealt_by_kind.is_valid():
		built.dealt_tower = float(_dealt_by_kind.call(Combat.SourceKind.TOWER))
		built.dealt_hero = float(_dealt_by_kind.call(Combat.SourceKind.HERO))
		built.dealt_burst = float(_dealt_by_kind.call(Combat.SourceKind.BURST))
	if _dealt_total.is_valid():
		built.dealt_total = float(_dealt_total.call())
	return built


func _wrong_phase_event(event_name: String) -> void:
	# After an outcome the event is an expected tie (Rule 14): ignored silently.
	if _phase == Phase.WON or _phase == Phase.LOST or _phase == Phase.FATAL:
		return
	_report_dev_error("flow: %s in phase %d" % [event_name, int(_phase)])


func _is_halted() -> bool:
	if _phase == Phase.WON or _phase == Phase.LOST or _phase == Phase.FATAL:
		return true
	return _halted.is_valid() and bool(_halted.call())


## True (after reporting fatal) when a command runs inside a tick.
func _inside_tick(cause: String) -> bool:
	if not _between_ticks.is_valid():
		return false
	if bool(_between_ticks.call()):
		return false
	_report_fatal(cause)
	return true


func _call_cancel_input() -> void:
	if _cancel_input.is_valid():
		_cancel_input.call()


func _report_fatal(cause: String) -> void:
	if _fatal.is_valid():
		_fatal.call(cause)


func _report_dev_error(msg: String) -> void:
	if _dev_error.is_valid():
		_dev_error.call(msg)
