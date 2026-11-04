class_name RunLog extends Node
## Development run log (ADR-0010 Decision 10). Made by BattleWrapper.attach only
## with a DevLogs. A view listener of P1, P4, P6 and P7: reads queries, issues no
## command, writes no sim field. Writes an attempt record per WON or LOST and a
## call record per early call. Never fatal: a bad sink calls dev_error once.
##
## Layer note: presentation code may not reference Battle, so attach takes the
## sim objects it reads. The wrapper passes the run seed (or -1 when unknown).

## Names read from the ResultSnapshot by `get`, so a renamed field cannot break parsing.
const SNAPSHOT_FIELDS: Array[StringName] = [
	&"slows_applied", &"towers_built", &"hero_pinned_ever", &"hero_share", &"got_through",
	&"repins", &"bursts_fired", &"bursts_hit_0", &"bursts_hit_3", &"bursts_hit_5",
	&"burst_victims", &"burst_kills", &"kills_per_burst", &"kills_on_hit_3", &"best_victims",
]

## JSON key of the run seed, as ADR-0010 names it. Lint MATH-4 bans RNG use in
## presentation, not this data field name.
const SEED_KEY: String = "rng_seed"

var _flow: Flow = null
var _tower_sim: TowerSim = null
var _hero_sim: HeroSim = null
var _stage_id: StringName = &""
var _ticks_run: Callable = Callable()
var _sink: Callable = Callable()
var _launch_id: int = 0
var _build_hash: String = ""
var _dev_error: Callable = Callable()
var _run_seed: int = -1
var _error_reported: bool = false
var _attach_ms: int = 0
var _first_build_ms: int = -1
var _first_pin_ms: int = -1
var _first_burst_ms: int = -1
var _call_pending: bool = false
var _call_ticks_left: int = 0
var _call_burst_state: int = 0
var _call_lives: int = 0


## `sink` is `dev_logs.run_sink.write_line` or an invalid Callable(); tests pass a
## recording fake. `ticks_run` is `battle.ticks_run`.
func attach(flow: Flow, tower_sim: TowerSim, hero_sim: HeroSim, stage_id: StringName,
		ticks_run: Callable, sink: Callable, launch_id: int, build_hash: String,
		dev_error: Callable, run_seed: int = -1) -> void:
	_flow = flow
	_tower_sim = tower_sim
	_hero_sim = hero_sim
	_stage_id = stage_id
	_ticks_run = ticks_run
	_sink = sink
	_launch_id = launch_id
	_build_hash = build_hash
	_dev_error = dev_error
	_run_seed = run_seed
	_error_reported = false
	_attach_ms = Time.get_ticks_msec()
	_first_build_ms = -1
	_first_pin_ms = -1
	_first_burst_ms = -1
	_call_pending = false


## Drops every reference.
func detach() -> void:
	_flow = null
	_tower_sim = null
	_hero_sim = null
	_ticks_run = Callable()
	_sink = Callable()
	_dev_error = Callable()
	_call_pending = false


## Called through HudLogic's injected `snapshot_taken` Callable. Writes the attempt record.
func on_snapshot_taken(snapshot: ResultSnapshot) -> void:
	if snapshot == null:
		return
	var record: Dictionary = _base("attempt")
	var outcome: Variant = Flow.Phase.find_key(_flow.phase()) if _flow != null else null
	record["outcome"] = String(outcome) if outcome != null else ""
	var seed_value: Variant = snapshot.get(SEED_KEY)
	if seed_value != null:
		record[SEED_KEY] = seed_value
	record["seconds_to_first_build"] = _seconds_since_attach(_first_build_ms)
	record["seconds_to_first_pin"] = _seconds_since_attach(_first_pin_ms)
	record["seconds_to_first_burst"] = _seconds_since_attach(_first_burst_ms)
	for field: StringName in SNAPSHOT_FIELDS:
		var value: Variant = snapshot.get(field)
		if value != null:
			record[String(field)] = _json_safe(value)
	_write(record)


## Called by HudLogic on CallResult.OK, with the values it read just before the call.
func on_call_made(ticks_left: int, burst_state: int) -> void:
	_call_pending = true
	_call_ticks_left = ticks_left
	_call_burst_state = burst_state
	_call_lives = _flow.lives() if _flow != null else 0


## P1. Resolves a pending call record at INTERMISSION, WON or LOST.
func _on_phase_changed(value: Flow.Phase) -> void:
	if not _call_pending:
		return
	if value != Flow.Phase.INTERMISSION and value != Flow.Phase.WON and value != Flow.Phase.LOST:
		return
	_call_pending = false
	var record: Dictionary = _base("call")
	record["ticks_left"] = _call_ticks_left
	record["seconds_left"] = float(_call_ticks_left) / float(SimTime.TICKS_PER_SECOND)
	record["burst_state"] = _call_burst_state
	var lives_now: int = _flow.lives() if _flow != null else _call_lives
	record["lives_lost"] = _call_lives - lives_now
	_write(record)


## P4. Stamps the first build.
func _on_tower_built(_slot_index: int, _tower_id: StringName) -> void:
	if _first_build_ms < 0:
		_first_build_ms = Time.get_ticks_msec()


## P6. Stamps the first pin.
func _on_hero_pinned(_position: Vector2) -> void:
	if _first_pin_ms < 0:
		_first_pin_ms = Time.get_ticks_msec()


## P7. Stamps the first burst.
func _on_burst_started(_aim_point: Vector2, _telegraph_ticks: int) -> void:
	if _first_burst_ms < 0:
		_first_burst_ms = Time.get_ticks_msec()


func _base(kind: String) -> Dictionary:
	var ticks: int = 0
	if _ticks_run.is_valid():
		ticks = int(_ticks_run.call())
	var record: Dictionary = {
		"kind": kind,
		"launch_id": _launch_id,
		"build_hash": _build_hash,
		"stage_id": String(_stage_id),
		"ticks_run": ticks,
	}
	record[SEED_KEY] = _run_seed
	return record


func _seconds_since_attach(stamp_ms: int) -> float:
	if stamp_ms < 0:
		return -1.0
	return float(stamp_ms - _attach_ms) / 1000.0


## Converts a value to JSON-native types: String keys, Array for packed arrays.
func _json_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var out: Dictionary = {}
		for key: Variant in source:
			out[String(str(key))] = _json_safe(source[key])
		return out
	if value is PackedInt32Array:
		return Array(value)
	if value is StringName:
		return String(value)
	return value


func _write(record: Dictionary) -> void:
	var line: String = JSON.stringify(record, "", true, true)
	var ok: bool = false
	if _sink.is_valid():
		ok = bool(_sink.call(line))
	if ok or _error_reported:
		return
	_error_reported = true
	if _dev_error.is_valid():
		_dev_error.call("run_log: write failed")
