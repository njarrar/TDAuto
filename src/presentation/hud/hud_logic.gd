class_name HudLogic extends RefCounted
## Plain, testable HUD model (Battle HUD Rules 1 to 16, ADR-0010 Decision 11): the build arc,
## the Start/Call arm model, prompt choice, ring requests, burst button state and the
## result snapshot. Changes battle state only through TowerSim.build, Flow.start_wave and
## Flow.call_early. HudField and HudTopBand draw from its plain fields only.

enum Arm { HIDDEN, ARMING, ARMED }
enum ButtonMode { NONE, START, CALL }
enum Prompt { NONE, DRAG_HERO, TAP_SLOT, DRAG_BUTTON }
enum BurstButton { LOCKED, READY, TELEGRAPH, COOLING }

const ARM_MS: float = 300.0
const MAX_FRAME_MS: float = 100.0
const ARC_GUARD_MS: float = 200.0
const NUDGE_MS: float = 300.0
const INSPECT_RING_MS: float = 1500.0
const GROUND_RING_LIMIT: int = 3
const GROUND_RING_MS: float = 400.0
const LOST_TEXT_DELAY_MS: float = 400.0
const WON_TEXT_DELAY_MS: float = 1000.0

const START_CENTRE: Vector2 = Vector2(186.0, 800.0)
const START_RADIUS: float = 48.0
const START_PRIORITY: int = 350
const BACKDROP_CENTRE: Vector2 = Vector2(270.0, 480.0)
const BACKDROP_RADIUS: float = 700.0
const BACKDROP_PRIORITY: int = 250
const ARC_RADIUS: float = 76.0
const ARC_DISC_RADIUS: float = 36.0
const ARC_PRIORITY: int = 300
## Fan angles in degrees: triangle, hexagon, square, left to right.
const ARC_ANGLES: Array[float] = [-60.0, 0.0, 60.0]
const BURST_X_RIGHT: float = 456.0
const BURST_X_LEFT: float = 84.0
const BURST_Y_MAX: float = 888.0
const BURST_Y_MIN: float = 816.0

const ROLE_WORDS: Array[String] = ["Single", "Splash", "Slow"]
const PROMPT_DRAG_HERO: String = "Drag the hero"
const PROMPT_TAP_SLOT: String = "Tap a slot to build"
const PROMPT_DRAG_BUTTON: String = "Drag from the big button"
const NEXT_PIN: String = "Next try: drag the hero"
const NEXT_BUILD: String = "Next try: tap a slot to build"
const NEXT_BURST: String = "Next try: drag from the big button"
## Enemy types in the Next-try tie order, with the hint and the role tag that makes it moot.
const TYPE_ORDER: Array[StringName] = [&"heavy", &"normal", &"fast"]
const TYPE_HINT: Dictionary = {
	&"heavy": "Next try: Triangles hit heavies",
	&"normal": "Next try: Hexagons hit groups",
	&"fast": "Next try: Squares slow fast enemies",
}
const TYPE_ROLE: Dictionary = {
	&"heavy": &"single_target",
	&"normal": &"splash",
	&"fast": &"slow",
}
const ROLE_SLOW: StringName = &"slow"

# injected reads and commands (dropped in detach)
var _resolver: InputResolver = null
var _tower_sim: TowerSim = null
var _hero_sim: HeroSim = null
var _flow: Flow = null
var _enemy_wave: EnemyWave = null
var _combat: Combat = null
var _accessor: StatAccessor = null
var _halted: Callable = Callable()
var _to_ticks: Callable = Callable()
var _dev_error: Callable = Callable()
var _ticks_source: Callable = Callable()
var _snapshot_taken: Callable = Callable()
var _call_made: Callable = Callable()
var _tower_input: TowerInput = null
var _hero_input: HeroInput = null

# structural copies
var _stage_id: StringName = &""
var _wave_count: int = 0
var _starting_lives: int = 0
var _rate_ticks: int = 1
var _ticks_per_second: int = SimTime.TICKS_PER_SECOND
var _run_seed: int = 0
var _reduce_motion: bool = false
var _left_handed: bool = false
var _safe_bottom: float = 0.0
var _tower_ids: Array[StringName] = []
var _arc_ctx: Array[ReadContext] = []
var _burst_ctx: ReadContext = null
var _cost_ctx: ReadContext = null
var _wave_preview: Array[Dictionary] = []

# button model
var _arm: Arm = Arm.HIDDEN
var _arm_ms: float = 0.0
var _mode: ButtonMode = ButtonMode.NONE
var _start_id: int = InputResolver.NONE
var _press_start_armed: bool = false
var _press_hero: bool = false

# arc
var _arc_open: bool = false
var _arc_slot: int = -1
var _arc_ms: float = 0.0
var _backdrop_id: int = InputResolver.NONE
var _arc_ids: PackedInt32Array = PackedInt32Array([-1, -1, -1])
var _arc_cost: PackedInt32Array = PackedInt32Array([0, 0, 0])
var _arc_afford: PackedByteArray = PackedByteArray([0, 0, 0])
var _nudge_ms: float = 0.0

# chip cost cache
var _chip_slot: int = -1
var _chip_level: int = 0
var _chip_cost_value: int = 0
var _chip_affordable: bool = false
var _chip_dirty: bool = true

# rings and prompts
var _inspect_slot: int = -1
var _inspect_ms: float = 0.0
var _ground_points: PackedVector2Array = PackedVector2Array()
var _ground_ages: PackedFloat32Array = PackedFloat32Array()
var _ground_total: int = 0
var _burst_started_seen: bool = false
var _burst_prompt_latched: bool = false

# polled display values
var _gold: int = 0
var _lives: int = 0
var _wave_index: int = 0
var _phase: Flow.Phase = Flow.Phase.BUILD
var _towers_built: int = 0
var _pinned_ever: bool = false
var _burst_button: BurstButton = BurstButton.LOCKED
var _burst_wedge: float = 0.0
var _digit: int = 0
var _intermission_left: int = 0

# result
var _snapshot_pending: bool = false
var _snapshot: ResultSnapshot = null
var _result_open: bool = false
var _result_ms: float = 0.0
var _result_delay: float = 0.0


## Registers the Start/Call disc and reads the first values (wrapper signature).
## snapshot_taken(ResultSnapshot) and call_made(ticks_left: int, burst_state: int) are
## called only after is_valid(). The three arc towers (triangle, hexagon, square) come from
## set_arc_tower_ids, and the seed for the snapshot from set_run_seed (added methods).
func attach(flow: Flow, tower_sim: TowerSim, hero_sim: HeroSim, enemy_wave: EnemyWave, combat: Combat,
		resolver: InputResolver, accessor: StatAccessor, stage: StageRecord, input_record: InputRecord,
		insets: FieldInsets, halted: Callable, to_ticks: Callable, reduce_motion: bool,
		dev_error: Callable, snapshot_taken: Callable, call_made: Callable) -> bool:
	if flow == null or tower_sim == null or hero_sim == null or enemy_wave == null or resolver == null \
			or accessor == null or stage == null:
		return false
	_resolver = resolver
	_tower_sim = tower_sim
	_hero_sim = hero_sim
	_flow = flow
	_enemy_wave = enemy_wave
	_combat = combat
	_accessor = accessor
	_halted = halted
	_to_ticks = to_ticks
	_dev_error = dev_error
	_snapshot_taken = snapshot_taken
	_call_made = call_made
	_reduce_motion = reduce_motion
	_safe_bottom = insets.bottom if insets != null else 0.0
	_left_handed = input_record.left_handed if input_record != null else false
	_stage_id = stage.id
	_wave_count = stage.wave_ids.size()
	_starting_lives = stage.starting_lives
	_rate_ticks = maxi(1, to_ticks.call(stage.early_call_seconds_per_gold) as int)
	_burst_ctx = ReadContext.make(_hero_sim.burst_id(), 0)
	_cost_ctx = ReadContext.make(&"", 1)
	_phase = _flow.phase()
	_poll()
	_apply_phase(_phase)
	return true


## The three arc towers in order triangle, hexagon, square (single, splash, slow).
## Returns false if there are not three tower ids. Call after attach, before the first tap.
func set_arc_tower_ids(ids: Array[StringName]) -> bool:
	if ids.size() != 3 or _accessor == null:
		return false
	_tower_ids = []
	_arc_ctx = []
	for id: StringName in ids:
		if not _accessor.is_tower(id):
			return false
		_tower_ids.append(id)
		_arc_ctx.append(ReadContext.make(id, 1))
	return true


## Sets the Callable (Battle.ticks_run) the snapshot reads its tick count from.
func set_ticks_source(source: Callable) -> void:
	_ticks_source = source


## Sets the value copied into ResultSnapshot's seed field.
func set_run_seed(value: int) -> void:
	_run_seed = value


## New insets (display_changed): moves the burst button.
func set_insets(insets: FieldInsets) -> void:
	_safe_bottom = insets.bottom if insets != null else 0.0


## Clears the remembered press (lifecycle or focus loss).
func clear_press() -> void:
	_press_start_armed = false
	_press_hero = false


## Flow.lives_changed (P2): the top band polls lives; this only keeps the value fresh.
func _on_lives_changed(current: int) -> void:
	_lives = current


## Gives the HUD the two input halves (built after it). Call once after both exist.
func bind_inputs(tower_input: TowerInput, hero_input: HeroInput) -> void:
	_tower_input = tower_input
	_hero_input = hero_input


## Supplies the next-wave line: one Dictionary (type to count) per wave, in Wave-record order.
func set_wave_preview(per_wave: Array[Dictionary]) -> void:
	_wave_preview = per_wave


## Closes the arc, unregisters every disc and drops every reference.
func detach() -> void:
	if _resolver != null:
		_close_arc()
		_hide_button()
	_resolver = null
	_tower_sim = null
	_hero_sim = null
	_flow = null
	_enemy_wave = null
	_combat = null
	_accessor = null
	_halted = Callable()
	_to_ticks = Callable()
	_dev_error = Callable()
	_snapshot_taken = Callable()
	_ticks_source = Callable()
	_call_made = Callable()
	_tower_input = null
	_hero_input = null
	_arc_ctx = []
	_burst_ctx = null
	_cost_ctx = null


## The one centre for the burst button's disc, Hero's cancel distances and the ring.
func burst_button_centre() -> Vector2:
	var x: float = BURST_X_LEFT if _left_handed else BURST_X_RIGHT
	return Vector2(x, clampf(BURST_Y_MAX - _safe_bottom, BURST_Y_MIN, BURST_Y_MAX))


# ---------------------------------------------------------------- frame

## Frame step 1: advances real-time models. Ignored while Paused; a hitch is clamped to 100 ms.
func advance(ms: float) -> void:
	if _flow == null:
		return
	_poll()
	_read_chip_cost()
	if _snapshot_pending:
		_build_snapshot()
	if _flow.phase() == Flow.Phase.PAUSED:
		return
	if not is_finite(ms) or ms < 0.0:
		return
	var step: float = minf(ms, MAX_FRAME_MS)
	if _arm == Arm.ARMING:
		_arm_ms += step
		if _arm_ms >= ARM_MS:
			_arm = Arm.ARMED
	if _arc_open:
		_arc_ms += step
	_nudge_ms = maxf(0.0, _nudge_ms - step)
	if _inspect_slot >= 0:
		_inspect_ms -= step
		if _inspect_ms <= 0.0:
			_inspect_slot = -1
	for i: int in range(_ground_ages.size()):
		_ground_ages[i] += step
	if _result_open:
		_result_ms += step


## Frame step 4: polls the sims into the plain fields the drawers read. True when it ran.
func refresh(_view_ms: float = 0.0) -> bool:
	if _flow == null:
		return false
	_poll()
	_read_chip_cost()
	return true


# ---------------------------------------------------------------- listeners

## TowerInput.slot_tapped: opens the build arc on the slot.
func _on_slot_tapped(slot_index: int) -> void:
	if _flow == null or bool(_halted.call()):
		return
	_open_arc(slot_index)


## TowerInput.tower_inspected: shows the tower's range ring for 1.5 s.
func _on_tower_inspected(slot_index: int) -> void:
	_inspect_slot = slot_index
	_inspect_ms = INSPECT_RING_MS


## G1: closes the arc on a non-arc press; remembers what the press named.
func _on_pressed(best_tap: int, best_drag: int, _p: Vector2) -> void:
	if _flow == null:
		return
	_press_start_armed = _start_id != InputResolver.NONE and best_tap == _start_id and _arm == Arm.ARMED
	var hero_id: int = _hero_input.hero_disc_id() if _hero_input != null else InputResolver.NONE
	_press_hero = best_drag != InputResolver.NONE and best_drag == hero_id
	if _arc_open and _arc_ids.find(best_tap) < 0:
		_close_arc()


## G2: a tap on an arc disc builds; a tap on Start/Call starts or calls.
func _on_tapped(best_tap: int, _p: Vector2) -> void:
	if _flow == null or best_tap == InputResolver.NONE or bool(_halted.call()):
		return
	if _arc_open:
		var k: int = _arc_ids.find(best_tap)
		if k >= 0 and _arc_ms >= ARC_GUARD_MS:
			_press_disc(k)
		return
	if best_tap == _start_id and _start_id != InputResolver.NONE:
		if _press_start_armed and not _press_hero:
			_press_button()


## G3: a dim ring for the first three ground taps of a battle.
func _on_ground_tapped(p: Vector2) -> void:
	if _ground_total >= GROUND_RING_LIMIT:
		return
	_ground_total += 1
	_ground_points.append(p)
	_ground_ages.append(0.0)


## G8: InputResolver.became_idle, the last signal of every gesture. Drops what the press
## named, so the next press starts clean. Issues no command (ADR-0006).
func _on_became_idle() -> void:
	clear_press()


## G4: a drag closes the arc.
func _on_drag_started(_best_drag: int, _press_pos: Vector2, _p: Vector2) -> void:
	_close_arc()


## Flow.phase_changed: shows or hides the button, closes the arc, starts the result.
func _on_phase_changed(value: Flow.Phase) -> void:
	if _flow == null:
		return
	_phase = value
	_apply_phase(value)


## TowerSim.gold_changed (P3): refreshes arc costs and the chip cost.
func _on_gold_changed(_current: int) -> void:
	if _flow == null:
		return
	_chip_dirty = true
	if _arc_open:
		_read_arc_costs()


## HeroSim.burst_started (P7): the third prompt is spent.
func _on_burst_started(_aim_point: Vector2, _telegraph_ticks: int) -> void:
	_burst_started_seen = true
	_burst_prompt_latched = false


# ---------------------------------------------------------------- reads for drawers

## True while the arc is open.
func arc_open() -> bool:
	return _arc_open


## The slot the arc is open on, or -1.
func arc_slot() -> int:
	return _arc_slot


## Centre of arc disc k (0 triangle, 1 hexagon, 2 square).
func arc_centre(k: int) -> Vector2:
	var s: Vector2 = _tower_sim.slot_position(_arc_slot)
	var a: float = deg_to_rad(ARC_ANGLES[k])
	return Vector2(s.x + ARC_RADIUS * sin(a), s.y - ARC_RADIUS * cos(a))


## Cost of arc disc k at level 1 (read on open and on gold_changed).
func arc_cost(k: int) -> int:
	return _arc_cost[k]


## True when arc disc k is affordable.
func arc_affordable(k: int) -> bool:
	return _arc_afford[k] != 0


## The word panel text for arc disc k.
func arc_word(k: int) -> String:
	return ROLE_WORDS[k]


## True while the NO_GOLD nudge shows.
func nudge_active() -> bool:
	return _nudge_ms > 0.0


## Start/Call button mode; NONE when hidden.
func button_mode() -> ButtonMode:
	return _mode if _arm != Arm.HIDDEN else ButtonMode.NONE


## Arm state of the Start/Call button.
func button_arm() -> Arm:
	return _arm


## "Start", "Call +N" or "Call"; empty when hidden.
func button_label() -> String:
	if _mode == ButtonMode.START:
		return "Start"
	if _mode == ButtonMode.CALL:
		var bonus: int = call_bonus()
		return "Call +%d" % bonus if bonus > 0 else "Call"
	return ""


## Gold the early call would pay now (Tower's formula: int tick division).
func call_bonus() -> int:
	@warning_ignore("integer_division")
	return maxi(0, _intermission_left) / _rate_ticks


## Whole seconds left in the intermission, rounded up.
func call_seconds() -> int:
	@warning_ignore("integer_division")
	return (maxi(0, _intermission_left) + _ticks_per_second - 1) / _ticks_per_second


## The one prompt line, first match (Battle HUD Rule 13).
func prompt() -> Prompt:
	if _flow == null:
		return Prompt.NONE
	if _phase != Flow.Phase.BUILD and _phase != Flow.Phase.WAVE and _phase != Flow.Phase.INTERMISSION:
		return Prompt.NONE
	if not _pinned_ever:
		return Prompt.DRAG_HERO
	if _towers_built == 0 and (_phase == Flow.Phase.BUILD or _phase == Flow.Phase.INTERMISSION):
		return Prompt.TAP_SLOT
	if _phase == Flow.Phase.WAVE and _burst_prompt_latched:
		return Prompt.DRAG_BUTTON
	return Prompt.NONE


## The prompt text, or an empty string.
func prompt_text() -> String:
	match prompt():
		Prompt.DRAG_HERO:
			return PROMPT_DRAG_HERO
		Prompt.TAP_SLOT:
			return PROMPT_TAP_SLOT
		Prompt.DRAG_BUTTON:
			return PROMPT_DRAG_BUTTON
		_:
			return ""


## Slot whose range ring is requested (an inspected tower), or -1.
func range_ring_slot() -> int:
	return _inspect_slot


## Number of ground rings drawn so far this battle (at most three).
func ground_ring_count() -> int:
	return _ground_points.size()


## Ground ring i: centre.
func ground_ring_point(i: int) -> Vector2:
	return _ground_points[i]


## Ground ring i: alpha from 1 to 0 over GROUND_RING_MS.
func ground_ring_alpha(i: int) -> float:
	return clampf(1.0 - _ground_ages[i] / GROUND_RING_MS, 0.0, 1.0)


## State of the burst button for the drawer.
func burst_button_state() -> BurstButton:
	return _burst_button


## Cooldown wedge, 0 to 1 (cooldown_left over the total, clamped).
func burst_wedge() -> float:
	return _burst_wedge


## Cooldown digit from HeroInput (0 when none).
func burst_digit() -> int:
	return _digit


## The chip's cost for the upgrade, read through the accessor (0 when no chip is open).
func chip_cost() -> int:
	return _chip_cost_value


## True when the chip's upgrade is affordable.
func chip_affordable() -> bool:
	return _chip_affordable


## Chip bar, 1 to 0 over the window (Battle HUD Formulas).
func chip_bar() -> float:
	if _tower_input == null:
		return 0.0
	return clampf(1.0 - _tower_input.chip_state().elapsed_ms / ChipWindow.WINDOW_MS, 0.0, 1.0)


## Gold for the top band.
func gold() -> int:
	return _gold


## Lives left for the top band.
func lives() -> int:
	return _lives


## Starting lives (dash count).
func starting_lives() -> int:
	return _starting_lives


## Waves in the stage (pip count).
func wave_count() -> int:
	return _wave_count


## Zero-based index of the current wave as EnemyWave reports it.
func wave_index() -> int:
	return _wave_index


## Next-wave counts for the line: type to count, or an empty Dictionary.
func next_wave_counts() -> Dictionary:
	if _wave_index >= 0 and _wave_index < _wave_preview.size():
		return _wave_preview[_wave_index]
	return {}


## True from the outcome on: the modal result Control is mounted and input is dead.
func result_open() -> bool:
	return _result_open


## True once the result text shows (400 ms after a Lost, 1000 ms after a Won).
func result_text_visible() -> bool:
	return _result_open and _result_ms >= _result_delay


## The snapshot, or null until the frame after the outcome.
func snapshot() -> ResultSnapshot:
	return _snapshot


## True while the Paused screen is shown.
func paused_open() -> bool:
	return _phase == Flow.Phase.PAUSED


# ---------------------------------------------------------------- internals

func _apply_phase(value: Flow.Phase) -> void:
	match value:
		Flow.Phase.BUILD:
			_show_button(ButtonMode.START)
		Flow.Phase.INTERMISSION:
			_show_button(ButtonMode.CALL)
		Flow.Phase.WAVE:
			_hide_button()
		Flow.Phase.PAUSED:
			_close_arc()
		Flow.Phase.WON, Flow.Phase.LOST:
			_close_arc()
			_hide_button()
			if not _result_open:
				_result_open = true
				_result_ms = 0.0
				_result_delay = WON_TEXT_DELAY_MS if value == Flow.Phase.WON else LOST_TEXT_DELAY_MS
				_snapshot_pending = true
		_:
			_close_arc()
			_hide_button()


func _show_button(mode: ButtonMode) -> void:
	if _arm != Arm.HIDDEN and _mode == mode:
		return
	_mode = mode
	_arm = Arm.ARMING
	_arm_ms = 0.0
	if _start_id == InputResolver.NONE:
		_start_id = _resolver.register(START_CENTRE, START_RADIUS, InputResolver.Accepts.TAP, START_PRIORITY)
	if _arc_open and _start_id != InputResolver.NONE:
		_resolver.set_enabled(_start_id, false)


func _hide_button() -> void:
	_arm = Arm.HIDDEN
	_mode = ButtonMode.NONE
	if _start_id != InputResolver.NONE and _resolver != null:
		_resolver.unregister(_start_id)
	_start_id = InputResolver.NONE


func _press_button() -> void:
	if _mode == ButtonMode.START:
		_flow.start_wave()
	elif _mode == ButtonMode.CALL:
		var ticks_left: int = _flow.intermission_left
		var burst_state: int = int(_hero_sim.burst_state())
		var result: Flow.CallResult = _flow.call_early()
		if result == Flow.CallResult.OK and _call_made.is_valid():
			_call_made.call(ticks_left, burst_state)


func _open_arc(slot_index: int) -> void:
	_close_arc()
	if slot_index < 0 or slot_index >= _tower_sim.slot_count():
		return
	if _tower_ids.size() != 3:
		if _dev_error.is_valid():
			_dev_error.call("HudLogic: arc tower ids not set")
		return
	_arc_open = true
	_arc_slot = slot_index
	_arc_ms = 0.0
	_backdrop_id = _resolver.register(BACKDROP_CENTRE, BACKDROP_RADIUS, InputResolver.Accepts.TAP,
			BACKDROP_PRIORITY, true)
	for k: int in range(3):
		_arc_ids[k] = _resolver.register(arc_centre(k), ARC_DISC_RADIUS, InputResolver.Accepts.TAP, ARC_PRIORITY)
	if _start_id != InputResolver.NONE:
		_resolver.set_enabled(_start_id, false)
	_read_arc_costs()


func _close_arc() -> void:
	if not _arc_open:
		return
	_arc_open = false
	_arc_slot = -1
	if _resolver != null:
		if _backdrop_id != InputResolver.NONE:
			_resolver.unregister(_backdrop_id)
		for k: int in range(3):
			if _arc_ids[k] != InputResolver.NONE:
				_resolver.unregister(_arc_ids[k])
		if _start_id != InputResolver.NONE:
			_resolver.set_enabled(_start_id, true)
	_backdrop_id = InputResolver.NONE
	for k: int in range(3):
		_arc_ids[k] = InputResolver.NONE


func _read_arc_costs() -> void:
	for k: int in range(3):
		_arc_cost[k] = _accessor.stat_int(_arc_ctx[k], StatKeys.COST)
		if bool(_halted.call()):
			_close_arc()
			return
	var gold_now: int = _tower_sim.gold()
	for k: int in range(3):
		_arc_afford[k] = 1 if gold_now >= _arc_cost[k] else 0


func _press_disc(k: int) -> void:
	var result: TowerSim.BuildResult = _tower_sim.build(_arc_slot, _tower_ids[k])
	match result:
		TowerSim.BuildResult.OK, TowerSim.BuildResult.HALTED:
			_close_arc()
		TowerSim.BuildResult.NO_GOLD:
			_nudge_ms = NUDGE_MS
		_:
			_close_arc()
			if _dev_error.is_valid():
				_dev_error.call("HudLogic: build refused: " + str(TowerSim.BuildResult.find_key(result)))


func _read_chip_cost() -> void:
	if _tower_input == null:
		return
	var state: TowerInput.ChipState = _tower_input.chip_state()
	if not state.open:
		_chip_slot = -1
		_chip_cost_value = 0
		_chip_affordable = false
		return
	if state.slot_index == _chip_slot and state.level == _chip_level and not _chip_dirty:
		return
	var def_id: StringName = _tower_sim.slot_tower(state.slot_index)
	if def_id == &"" or state.level >= _accessor.level_count(def_id):
		return
	_cost_ctx.def_id = def_id
	_cost_ctx.level = state.level + 1
	var cost: int = _accessor.stat_int(_cost_ctx, StatKeys.COST)
	if bool(_halted.call()):
		return
	_chip_slot = state.slot_index
	_chip_level = state.level
	_chip_dirty = false
	_chip_cost_value = cost
	_chip_affordable = _tower_sim.gold() >= cost


func _poll() -> void:
	_gold = _tower_sim.gold()
	_lives = _flow.lives()
	_wave_index = _enemy_wave.wave_index()
	_intermission_left = _flow.intermission_left
	_towers_built = _count_towers()
	_pinned_ever = _hero_sim.pin_state() != HeroSim.PinState.UNPINNED
	if _hero_input != null:
		_digit = _hero_input.cooldown_digit()
	var bstate: HeroSim.BurstState = _hero_sim.burst_state()
	if not _pinned_ever or _flow.in_build():
		_burst_button = BurstButton.LOCKED
	elif bstate == HeroSim.BurstState.READY:
		_burst_button = BurstButton.READY
	elif bstate == HeroSim.BurstState.TELEGRAPHING:
		_burst_button = BurstButton.TELEGRAPH
	else:
		_burst_button = BurstButton.COOLING
	_burst_wedge = 0.0
	if _burst_button == BurstButton.COOLING:
		var total: int = _to_ticks.call(_accessor.stat_float(_burst_ctx, StatKeys.COOLDOWN)) as int
		if not bool(_halted.call()) and total > 0:
			_burst_wedge = clampf(float(_hero_sim.cooldown_left()) / float(total), 0.0, 1.0)
	elif _burst_button == BurstButton.TELEGRAPH:
		_burst_wedge = 0.0
	if _phase == Flow.Phase.WAVE and bstate == HeroSim.BurstState.READY and _pinned_ever \
			and not _burst_started_seen:
		_burst_prompt_latched = true


func _count_towers() -> int:
	var n: int = 0
	for i: int in range(_tower_sim.slot_count()):
		if _tower_sim.slot_tower(i) != &"":
			n += 1
	return n


func _slow_built() -> bool:
	for i: int in range(_tower_sim.slot_count()):
		var id: StringName = _tower_sim.slot_tower(i)
		if id != &"" and _accessor.has_tag(id, ROLE_SLOW):
			return true
	return false


func _role_built(role: StringName) -> bool:
	for i: int in range(_tower_sim.slot_count()):
		var id: StringName = _tower_sim.slot_tower(i)
		if id != &"" and _accessor.has_tag(id, role):
			return true
	return false


func _build_snapshot() -> void:
	_snapshot_pending = false
	var s: ResultSnapshot = ResultSnapshot.new()
	s.result = _flow.result()
	s.stage_id = _stage_id
	s.rng_seed = _run_seed
	s.ticks_run = (_ticks_source.call() as int) if _ticks_source.is_valid() else 0
	s.got_through = _enemy_wave.got_through_by_type().duplicate()
	s.slows_applied = _tower_sim.slows_applied()
	s.towers_built = _count_towers()
	s.hero_pinned_ever = _hero_sim.pin_state() != HeroSim.PinState.UNPINNED
	s.hero_share = _combat.hero_share() if _combat != null else 0.0
	s.dealt_by_source = _dealt_by_source()
	s.repins = _hero_sim.repins()
	s.bursts_fired = _hero_sim.bursts_fired()
	s.bursts_hit_0 = _hero_sim.bursts_hit_0()
	s.bursts_hit_3 = _hero_sim.bursts_hit_3()
	s.bursts_hit_5 = _hero_sim.bursts_hit_5()
	s.burst_victims = _hero_sim.burst_victims()
	s.burst_kills = _hero_sim.burst_kills()
	s.kills_per_burst = _hero_sim.kills_per_burst()
	s.kills_on_hit_3 = _hero_sim.kills_on_hit_3()
	s.best_victims = _hero_sim.best_victims()
	s.wave_index = _enemy_wave.wave_index()
	s.wave_count = _wave_count
	s.starting_lives = _starting_lives
	s.slow_built = _slow_built()
	s.next_try = _next_try(s)
	_snapshot = s
	if _snapshot_taken.is_valid():
		_snapshot_taken.call(s)


## Damage per source id for the arc towers, the hero and the burst (StringName to float).
func _dealt_by_source() -> Dictionary:
	var out: Dictionary = {}
	if _combat == null:
		return out
	for id: StringName in _tower_ids:
		out[id] = _combat.dealt_by_id(id)
	out[_hero_sim.hero_id()] = _combat.dealt_by_id(_hero_sim.hero_id())
	out[_hero_sim.burst_id()] = _combat.dealt_by_id(_hero_sim.burst_id())
	return out


func _next_try(s: ResultSnapshot) -> String:
	if not s.hero_pinned_ever:
		return NEXT_PIN
	if s.towers_built == 0:
		return NEXT_BUILD
	if s.bursts_fired == 0:
		return NEXT_BURST
	var best_type: StringName = &""
	var best_lost: int = 0
	for t: StringName in TYPE_ORDER:
		if not s.got_through.has(t):
			continue
		var count: int = int(s.got_through[t])
		if count <= 0:
			continue
		var cost: int = _accessor.stat_int(ReadContext.make(t, 0), StatKeys.LIVES_COST)
		if bool(_halted.call()):
			return ""
		var lost: int = count * cost
		if lost > best_lost:
			best_lost = lost
			best_type = t
	if best_type == &"":
		return ""
	if _role_built(TYPE_ROLE[best_type] as StringName):
		return ""
	return TYPE_HINT[best_type] as String
