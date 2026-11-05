class_name BattleWrapper extends Node
## Presentation shell around one Battle (ADR-0001 Decision 6, ADR-0004 Decision 5,
## ADR-0006 Decision 2, ADR-0010, ADR-0011). Holds no gameplay logic. AppRoot
## loads the scene, calls add_child, then attach(). The only per-frame code in
## the battle subtree is _process. Absent in headless runs.

## Upper bound of the view clock step in milliseconds (ADR-0011 Decision 8).
const MAX_VIEW_MS: float = 100.0
const ADAPTER_NAME: String = "InputAdapter"

## Top band height above the top inset, in field units (Battle HUD layout table).
const TOP_BAND_BASE_HEIGHT: float = 72.0

var _battle: Battle = null
var _reduce_motion: bool = false
var _was_paused: bool = false
var _clock: BattleClock = null
var _adapter: InputAdapter = null
var _hud_logic: HudLogic = null
var _hero_input: HeroInput = null
var _tower_input: TowerInput = null
var _backdrop_model: FieldBackdropModel = null
var _tower_model: TowerViewModel = null
var _enemy_model: EnemyViewModel = null
var _combat_model: CombatViewModel = null
var _hero_model: HeroViewModel = null
var _gesture_log: GestureLog = null
var _run_log: RunLog = null
## The session root, when the wrapper sits under one. Only its request_retry is used.
var _app_root: AppRoot = null

@onready var _field_backdrop: FieldBackdrop = $FieldBackdrop
@onready var _tower_view: TowerView = $TowerView
@onready var _enemy_view: EnemyView = $EnemyView
@onready var _combat_view: CombatView = $CombatView
@onready var _hero_view: HeroView = $HeroView
@onready var _hud_field: HudField = $HudField
@onready var _hud_top_band: HudTopBand = $HudTopBand
@onready var _result_screen: ResultScreen = $ResultScreen
@onready var _paused_screen: PausedScreen = $PausedScreen


## Builds the presentation around `battle` and wires every listener. Returns
## false on any failure (AppRoot treats false as fatal). A second call while
## attached changes nothing and returns false. `dev_logs` is null in release.
## The Retry button reaches AppRoot.request_retry through the parent node (ADR-0001:
## the call only sets a latch and never frees the wrapper); with no AppRoot parent
## the button does nothing.
func attach(battle: Battle, reduce_motion: bool, dev_logs: DevLogs = null) -> bool:
	if _battle != null or battle == null:
		return false
	if _field_backdrop == null or _hud_top_band == null:
		return false
	if _result_screen == null or _paused_screen == null:
		return false
	if not _battle_complete(battle):
		return false
	_battle = battle
	_reduce_motion = reduce_motion
	_was_paused = false
	_app_root = get_parent() as AppRoot
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _build(dev_logs):
		detach()
		return false
	_connect_signals()
	_on_display_changed()
	set_process(true)
	return true


## Stops processing, cancels input, disconnects every connection, detaches every
## node and model, and clears every reference to the Battle and its systems.
## Safe on a partly attached wrapper and safe to call twice.
func detach() -> void:
	set_process(false)
	var battle: Battle = _battle
	if battle != null:
		battle.set_input_canceller(Callable())
		if _adapter != null:
			_adapter.cancel_all()
		elif battle.resolver != null:
			battle.resolver.cancel()
		_disconnect_signals()
	if _result_screen != null:
		_result_screen.clear_press()
		_result_screen.close()
	if _paused_screen != null:
		_paused_screen.clear_press()
		_paused_screen.close()
	if _gesture_log != null:
		_gesture_log.detach()
		_remove_child_node(_gesture_log)
		_gesture_log = null
	if _run_log != null:
		_run_log.detach()
		_remove_child_node(_run_log)
		_run_log = null
	if _tower_input != null:
		_tower_input.detach()
		_tower_input = null
	if _hero_input != null:
		_hero_input.detach()
		_hero_input = null
	if _hud_logic != null:
		_hud_logic.detach()
		_hud_logic = null
	if _backdrop_model != null:
		_backdrop_model.detach()
		_backdrop_model = null
	if _tower_model != null:
		_tower_model.detach()
		_tower_model = null
	if _enemy_model != null:
		_enemy_model.detach()
		_enemy_model = null
	if _combat_model != null:
		_combat_model.detach()
		_combat_model = null
	if _hero_model != null:
		_hero_model.detach()
		_hero_model = null
	if _adapter != null:
		_adapter.detach()
		_remove_child_node(_adapter)
		_adapter = null
	_clock = null
	_app_root = null
	_battle = null


## Frame order of ADR-0004 Decision 5, steps 0 to 4.
func _process(delta: float) -> void:
	var battle: Battle = _battle
	if battle == null:
		return
	# Step 0: queued input to the resolver, then its signals and commands.
	_adapter.flush()
	# Step 1: real-time models.
	var ms: float = 0.0
	if is_finite(delta) and delta > 0.0:
		ms = delta * 1000.0
	_hud_logic.advance(ms)
	_tower_input.advance(ms)
	# Steps 2 and 3: clock, then ticks.
	var ticks: int = _clock.advance(delta)
	var dt: float = battle.sim_time.dt
	for _i in ticks:
		if battle.halted():
			break
		battle.tick(dt)
	# Step 4: HeroInput sync, then views.
	_hero_input.update()
	var view_ms: float = clampf(ms, 0.0, MAX_VIEW_MS)
	if battle.flow.phase() == Flow.Phase.PAUSED:
		view_ms = 0.0
	if _backdrop_model.refresh(view_ms):
		_field_backdrop.queue_redraw()
	if _tower_model.refresh(view_ms):
		_tower_view.queue_redraw()
	if _enemy_model.refresh(view_ms):
		_enemy_view.queue_redraw()
	if _combat_model.refresh(view_ms):
		_combat_view.queue_redraw()
	if _hero_model.refresh(view_ms):
		_hero_view.queue_redraw()
	_hud_field.queue_redraw()
	_hud_top_band.queue_redraw()
	var phase: Flow.Phase = battle.flow.phase()
	if phase == Flow.Phase.WON or phase == Flow.Phase.LOST:
		_result_screen.refresh_view()


func _battle_complete(battle: Battle) -> bool:
	return battle.resolver != null and battle.flow != null and battle.combat != null \
			and battle.enemy_wave != null and battle.tower_sim != null and battle.hero_sim != null \
			and battle.sim_time != null and battle.accessor != null and battle.input_record != null \
			and battle.stage_record != null and battle.visual_keys != null


## Creates every node and model in ADR-0010 Decision 1 order. False on any failure.
func _build(dev_logs: DevLogs) -> bool:
	var b: Battle = _battle
	var dev_error: Callable = b.dev_error
	_clock = BattleClock.new(b.sim_time.ticks_per_second)

	_adapter = InputAdapter.new()
	_adapter.name = ADAPTER_NAME
	_adapter.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_adapter)
	_adapter.attach(b.resolver, b.input_record.edge_reject_margin, dev_error)
	b.set_input_canceller(_adapter.cancel_all)
	var insets: FieldInsets = _adapter.field_insets()

	var look: StageLook = _load_stage_look(b.stage_record.scene_ref)
	if look == null:
		dev_error.call("battle_wrapper: stage look failed to load: " + b.stage_record.scene_ref)
		return false
	var field_hue: float = look.field_hue
	var base_value: float = look.base_value
	var grid_tilt_deg: int = look.grid_tilt_deg
	look.queue_free()

	if dev_logs != null and OS.is_debug_build():
		_run_log = RunLog.new()
		_run_log.name = "RunLog"
		add_child(_run_log)
		_run_log.attach(b.flow, b.tower_sim, b.hero_sim, b.stage_record.id, b.ticks_run,
				_sink_of(dev_logs.run_sink), dev_logs.launch_id, dev_logs.build_hash, dev_error, b.rng_seed)

	var snapshot_taken: Callable = Callable()
	var call_made: Callable = Callable()
	if _run_log != null:
		snapshot_taken = _run_log.on_snapshot_taken
		call_made = _run_log.on_call_made

	_hud_logic = HudLogic.new()
	if not _hud_logic.attach(b.flow, b.tower_sim, b.hero_sim, b.enemy_wave, b.combat, b.resolver,
			b.accessor, b.stage_record, b.input_record, insets, b.halted, b.sim_time.to_ticks,
			_reduce_motion, dev_error, snapshot_taken, call_made):
		return _fail("hud logic attach failed")
	if not _hud_logic.set_arc_tower_ids(b.arc_tower_ids):
		return _fail("hud arc tower ids rejected")
	_hud_logic.set_ticks_source(b.ticks_run)
	_hud_logic.set_run_seed(b.rng_seed)
	_hud_logic.set_wave_preview(_wave_preview(b.wave_records))
	var burst_centre: Vector2 = _hud_logic.burst_button_centre()

	_hero_input = HeroInput.new()
	_hero_input.attach(b.resolver, b.hero_sim, b.accessor, b.halted, b.in_build,
			b.input_record.left_handed, b.stage_record, burst_centre, dev_error)

	_tower_input = TowerInput.new()
	_tower_input.attach(b.resolver, b.tower_sim, b.accessor, b.halted, dev_error)
	_hud_logic.bind_inputs(_tower_input, _hero_input)

	if dev_logs != null and OS.is_debug_build():
		_gesture_log = GestureLog.new()
		_gesture_log.name = "GestureLog"
		add_child(_gesture_log)
		_gesture_log.attach(b.resolver, _adapter, _sink_of(dev_logs.gesture_sink),
				_tower_input.is_chip_open, dev_error)

	_enemy_model = EnemyViewModel.new()
	if not _enemy_model.attach(b.enemy_wave, b.visual_keys, _reduce_motion, dev_error):
		return _fail("enemy view model attach failed")
	_tower_model = TowerViewModel.new()
	if not _tower_model.attach(b.tower_sim, b.accessor, b.halted, b.visual_keys, _reduce_motion, dev_error):
		return _fail("tower view model attach failed")
	_combat_model = CombatViewModel.new()
	if not _combat_model.attach(b.combat, b.enemy_wave, b.accessor, b.halted, b.visual_keys, _reduce_motion, dev_error):
		return _fail("combat view model attach failed")
	_hero_model = HeroViewModel.new()
	if not _hero_model.attach(b.hero_sim, _hero_input, b.visual_keys, _reduce_motion, dev_error,
			b.accessor, b.enemy_wave, b.combat, b.halted):
		return _fail("hero view model attach failed")
	_backdrop_model = FieldBackdropModel.new()
	if not _backdrop_model.attach(b.stage_record, b.flow, b.enemy_wave, b.tower_sim, b.hero_sim,
			field_hue, base_value, grid_tilt_deg, _reduce_motion, dev_error):
		return _fail("field backdrop model attach failed")

	_field_backdrop.model = _backdrop_model
	_tower_view.model = _tower_model
	_enemy_view.model = _enemy_model
	_combat_view.model = _combat_model
	_hero_view.model = _hero_model
	_tower_model.ring_request = _hud_logic.range_ring_slot
	_hud_field.model = _hud_logic
	_hud_field.tower_input = _tower_input
	_hud_field.tower_view_centres = _tower_model.centres
	_hud_top_band.model = _hud_logic
	return true


## Next-wave line data: one Dictionary (enemy id to total count) per Wave record, in order.
func _wave_preview(records: Array[WaveRecord]) -> Array[Dictionary]:
	var preview: Array[Dictionary] = []
	for record: WaveRecord in records:
		var counts: Dictionary = {}
		for group: WaveGroup in record.groups:
			counts[group.enemy_id] = int(counts.get(group.enemy_id, 0)) + group.count
		preview.append(counts)
	return preview


func _fail(message: String) -> bool:
	_battle.dev_error("battle_wrapper: " + message)
	return false


## `write_line` of the sink, or an invalid Callable when the sink is missing.
func _sink_of(sink: JsonlFileSink) -> Callable:
	if sink == null:
		return Callable()
	return sink.write_line


## Loads the stage look scene, or null if it is missing or has the wrong root.
func _load_stage_look(path: String) -> StageLook:
	if path.is_empty():
		return null
	var scene: PackedScene = ResourceLoader.load(path) as PackedScene
	if scene == null:
		return null
	var instance: Node = scene.instantiate()
	var look: StageLook = instance as StageLook
	if look == null and instance != null:
		instance.queue_free()
	return look


func _remove_child_node(node: Node) -> void:
	if node.get_parent() == self:
		remove_child(node)
	node.queue_free()


## ADR-0006 Decision 2: the one place the wrapper makes connections. Flags 0.
## Keep this list and _disconnect_signals in step.
func _connect_signals() -> void:
	var b: Battle = _battle
	b.flow.phase_changed.connect(_on_phase_changed)
	_adapter.lifecycle_paused.connect(b.flow.pause)
	_adapter.display_changed.connect(_on_display_changed)
	_adapter.lifecycle_paused.connect(_result_screen.clear_press)
	_adapter.lifecycle_paused.connect(_paused_screen.clear_press)
	_paused_screen.resume_requested.connect(b.flow.resume)
	if _app_root != null:
		_result_screen.retry_requested.connect(_app_root.request_retry)
	if _hud_logic != null:
		b.flow.phase_changed.connect(_hud_logic._on_phase_changed)
		b.flow.lives_changed.connect(_hud_logic._on_lives_changed)
		b.tower_sim.gold_changed.connect(_hud_logic._on_gold_changed)
		b.resolver.pressed.connect(_hud_logic._on_pressed)
		b.resolver.tapped.connect(_hud_logic._on_tapped)
		b.resolver.ground_tapped.connect(_hud_logic._on_ground_tapped)
		b.resolver.drag_started.connect(_hud_logic._on_drag_started)
		b.resolver.became_idle.connect(_hud_logic._on_became_idle)
		b.hero_sim.burst_started.connect(_hud_logic._on_burst_started)
		_adapter.lifecycle_paused.connect(_hud_logic.clear_press)
		_tower_input.slot_tapped.connect(_hud_logic._on_slot_tapped)
		_tower_input.tower_inspected.connect(_hud_logic._on_tower_inspected)
	if _tower_input != null:
		b.flow.phase_changed.connect(_tower_input._on_phase_changed)
		b.tower_sim.tower_built.connect(_tower_input._on_tower_built)
		b.resolver.pressed.connect(_tower_input._on_pressed)
		b.resolver.tapped.connect(_tower_input._on_tapped)
	if _hero_input != null:
		b.resolver.pressed.connect(_hero_input._on_pressed)
		b.resolver.drag_started.connect(_hero_input._on_drag_started)
		b.resolver.drag_moved.connect(_hero_input._on_drag_moved)
		b.resolver.drag_ended.connect(_hero_input._on_drag_ended)
		b.resolver.drag_cancelled.connect(_hero_input._on_drag_cancelled)
		b.resolver.became_idle.connect(_hero_input._on_became_idle)
	if _combat_model != null:
		b.hero_sim.burst_started.connect(_combat_model._on_burst_started)
		b.combat.attack_fired.connect(_combat_model._on_attack_fired)
		b.combat.damage_applied.connect(_combat_model._on_damage_applied)
	if _run_log != null:
		b.flow.phase_changed.connect(_run_log._on_phase_changed)
		b.tower_sim.tower_built.connect(_run_log._on_tower_built)
		b.hero_sim.hero_pinned.connect(_run_log._on_hero_pinned)
		b.hero_sim.burst_started.connect(_run_log._on_burst_started)
	if _gesture_log != null:
		b.resolver.pressed.connect(_gesture_log._on_pressed)
		b.resolver.became_idle.connect(_gesture_log._on_became_idle)
		b.tower_sim.tower_upgraded.connect(_gesture_log._on_tower_upgraded)


## Undoes _connect_signals, same list. Each line checks is_connected first.
func _disconnect_signals() -> void:
	var b: Battle = _battle
	if b == null:
		return
	_drop(b.flow.phase_changed, _on_phase_changed)
	if _adapter != null:
		_drop(_adapter.lifecycle_paused, b.flow.pause)
		_drop(_adapter.display_changed, _on_display_changed)
		if _result_screen != null:
			_drop(_adapter.lifecycle_paused, _result_screen.clear_press)
		if _paused_screen != null:
			_drop(_adapter.lifecycle_paused, _paused_screen.clear_press)
	if _paused_screen != null:
		_drop(_paused_screen.resume_requested, b.flow.resume)
	if _result_screen != null and _app_root != null:
		_drop(_result_screen.retry_requested, _app_root.request_retry)
	if _hud_logic != null:
		_drop(b.flow.phase_changed, _hud_logic._on_phase_changed)
		_drop(b.flow.lives_changed, _hud_logic._on_lives_changed)
		_drop(b.tower_sim.gold_changed, _hud_logic._on_gold_changed)
		_drop(b.resolver.pressed, _hud_logic._on_pressed)
		_drop(b.resolver.tapped, _hud_logic._on_tapped)
		_drop(b.resolver.ground_tapped, _hud_logic._on_ground_tapped)
		_drop(b.resolver.drag_started, _hud_logic._on_drag_started)
		_drop(b.resolver.became_idle, _hud_logic._on_became_idle)
		_drop(b.hero_sim.burst_started, _hud_logic._on_burst_started)
		if _adapter != null:
			_drop(_adapter.lifecycle_paused, _hud_logic.clear_press)
		if _tower_input != null:
			_drop(_tower_input.slot_tapped, _hud_logic._on_slot_tapped)
			_drop(_tower_input.tower_inspected, _hud_logic._on_tower_inspected)
	if _tower_input != null:
		_drop(b.flow.phase_changed, _tower_input._on_phase_changed)
		_drop(b.tower_sim.tower_built, _tower_input._on_tower_built)
		_drop(b.resolver.pressed, _tower_input._on_pressed)
		_drop(b.resolver.tapped, _tower_input._on_tapped)
	if _hero_input != null:
		_drop(b.resolver.pressed, _hero_input._on_pressed)
		_drop(b.resolver.drag_started, _hero_input._on_drag_started)
		_drop(b.resolver.drag_moved, _hero_input._on_drag_moved)
		_drop(b.resolver.drag_ended, _hero_input._on_drag_ended)
		_drop(b.resolver.drag_cancelled, _hero_input._on_drag_cancelled)
		_drop(b.resolver.became_idle, _hero_input._on_became_idle)
	if _combat_model != null:
		_drop(b.hero_sim.burst_started, _combat_model._on_burst_started)
		_drop(b.combat.attack_fired, _combat_model._on_attack_fired)
		_drop(b.combat.damage_applied, _combat_model._on_damage_applied)
	if _run_log != null:
		_drop(b.flow.phase_changed, _run_log._on_phase_changed)
		_drop(b.tower_sim.tower_built, _run_log._on_tower_built)
		_drop(b.hero_sim.hero_pinned, _run_log._on_hero_pinned)
		_drop(b.hero_sim.burst_started, _run_log._on_burst_started)
	if _gesture_log != null:
		_drop(b.resolver.pressed, _gesture_log._on_pressed)
		_drop(b.resolver.became_idle, _gesture_log._on_became_idle)
		_drop(b.tower_sim.tower_upgraded, _gesture_log._on_tower_upgraded)


func _drop(sig: Signal, listener: Callable) -> void:
	if sig.is_connected(listener):
		sig.disconnect(listener)


## P1. Drops the clock backlog on entering and on leaving PAUSED (ADR-0004), and
## opens or closes the two modal screens.
func _on_phase_changed(value: Flow.Phase) -> void:
	var paused: bool = value == Flow.Phase.PAUSED
	if (paused or _was_paused) and _clock != null:
		_clock.drop_backlog()
	if paused and not _was_paused:
		_paused_screen.open()
	elif _was_paused and not paused:
		_paused_screen.close()
	if value == Flow.Phase.WON or value == Flow.Phase.LOST:
		_result_screen.open(_hud_logic)
	_was_paused = paused


## A2. Hands the new insets to the HUD and resizes the top band (ADR-0011 Decision 1).
func _on_display_changed() -> void:
	if _adapter == null:
		return
	var insets: FieldInsets = _adapter.field_insets()
	if _hud_logic != null:
		_hud_logic.set_insets(insets)
		if _hero_input != null:
			_hero_input.set_button_centre(_hud_logic.burst_button_centre())
	_result_screen.clear_press()
	_paused_screen.clear_press()
	_hud_top_band.position = Vector2.ZERO
	# Battle HUD layout: the band runs from y 0 to the top inset plus 72.
	_hud_top_band.size = Vector2(FieldBounds.WIDTH, insets.top + TOP_BAND_BASE_HEIGHT)
