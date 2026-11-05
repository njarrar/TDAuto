class_name HeroInput extends RefCounted
## Pin drag, burst aim and cancel hysteresis (Hero Rules 11 to 15, ADR-0010 Decision 8).
## Changes battle state only through HeroSim.pin and HeroSim.burst. Computes in float
## scalars and builds a Vector2 only for the command call (ADR-0010 Decision 5).

enum AimState { NONE, PINNING, CANCELLING, LIVE }

const HERO_RADIUS: float = 56.0
const HERO_PRIORITY: int = 200
const BUTTON_RADIUS: float = 48.0
const BUTTON_PRIORITY: int = 100
const SINK_RADIUS: float = 48.0
const SINK_PRIORITY: int = 400
## Presentation offsets (Hero Rules 12 and 14); bots skip them.
const AIM_OFFSET_Y: float = 100.0
const PIN_OFFSET_Y: float = 0.0
## Cancel hysteresis distances from the button centre (Hero Rule 13).
const CANCEL_OUT: float = 64.0
const CANCEL_IN: float = 48.0
const REACH_MARGIN: float = 0.01

const _PRESS_NONE: int = 0
const _PRESS_HERO: int = 1
const _PRESS_AIM: int = 2

var _resolver: InputResolver = null
var _hero_sim: HeroSim = null
var _accessor: StatAccessor = null
var _halted: Callable = Callable()
var _in_build: Callable = Callable()
var _dev_error: Callable = Callable()
var _geometry: PinGeometry = null
var _burst_ctx: ReadContext = null
var _button_x: float = 0.0
var _button_y: float = 0.0
var _hero_disc: int = InputResolver.NONE
var _button_disc: int = InputResolver.NONE
var _sink_disc: int = InputResolver.NONE
var _ticks_per_second: int = 60
var _state: AimState = AimState.NONE
var _press: int = _PRESS_NONE
var _finger_x: float = 0.0
var _finger_y: float = 0.0
var _aim_x: float = 0.0
var _aim_y: float = 0.0
var _ghost_x: float = 0.0
var _ghost_y: float = 0.0
var _digit: int = 0
var _fired_x: float = 0.0
var _fired_y: float = 0.0


## Registers the hero (DRAG 200, r 56), button (DRAG 100, r 48) and sink (TAP 400, r 48) discs.
## ticks_per_second is an added trailing argument (default 60) for the cooldown digit.
func attach(resolver: InputResolver, hero_sim: HeroSim, accessor: StatAccessor, halted: Callable,
		in_build: Callable, left_handed: bool, stage: StageRecord, burst_button_centre: Vector2,
		dev_error: Callable, ticks_per_second: int = 60) -> bool:
	if resolver == null or hero_sim == null or accessor == null or stage == null:
		return false
	_resolver = resolver
	_hero_sim = hero_sim
	_accessor = accessor
	_halted = halted
	_in_build = in_build
	_dev_error = dev_error
	_ticks_per_second = maxi(1, ticks_per_second)
	_geometry = PinGeometry.new(stage, left_handed)
	_burst_ctx = ReadContext.make(hero_sim.burst_id(), 0)
	_button_x = burst_button_centre.x
	_button_y = burst_button_centre.y
	_hero_disc = _resolver.register(hero_sim.position(), HERO_RADIUS, InputResolver.Accepts.DRAG, HERO_PRIORITY)
	_button_disc = _resolver.register(burst_button_centre, BUTTON_RADIUS, InputResolver.Accepts.DRAG, BUTTON_PRIORITY)
	_sink_disc = _resolver.register(burst_button_centre, SINK_RADIUS, InputResolver.Accepts.TAP, SINK_PRIORITY, true)
	if _hero_disc == InputResolver.NONE or _button_disc == InputResolver.NONE or _sink_disc == InputResolver.NONE:
		return false
	return true


## Moves the burst button, its sink disc and the cancel-ring centre after an inset change
## (ADR-0010 Decision 8, ADR-0003 Decision 5). A non-finite centre is ignored.
func set_button_centre(c: Vector2) -> void:
	if _resolver == null or not (is_finite(c.x) and is_finite(c.y)):
		return
	_button_x = c.x
	_button_y = c.y
	_resolver.set_centre(_button_disc, c)
	_resolver.set_centre(_sink_disc, c)


## Unregisters the discs and drops every reference.
func detach() -> void:
	if _resolver != null:
		for id: int in [_hero_disc, _button_disc, _sink_disc]:
			if id != InputResolver.NONE:
				_resolver.unregister(id)
	_hero_disc = InputResolver.NONE
	_button_disc = InputResolver.NONE
	_sink_disc = InputResolver.NONE
	_clear()
	_resolver = null
	_hero_sim = null
	_accessor = null
	_halted = Callable()
	_in_build = Callable()
	_dev_error = Callable()
	_geometry = null
	_burst_ctx = null


## Frame step 4, first: moves the hero disc, re-clamps a live aim, refreshes the digit.
func update() -> void:
	if _hero_sim == null:
		return
	var pos: Vector2 = _hero_sim.position()
	_resolver.set_centre(_hero_disc, pos)
	var ticks: int = _hero_sim.cooldown_left()
	@warning_ignore("integer_division")
	_digit = (ticks + _ticks_per_second - 1) / _ticks_per_second
	if bool(_halted.call()):
		_clear()
		return
	if _state == AimState.CANCELLING or _state == AimState.LIVE:
		_recompute_aim()
	elif _state == AimState.PINNING:
		_recompute_ghost()


## The aim state.
func aim_state() -> AimState:
	return _state


## The clamped aim point (meaningful while an aim is armed).
func aim_point() -> Vector2:
	return Vector2(_aim_x, _aim_y)


## The pin ghost (meaningful while the hero is being dragged).
func ghost_point() -> Vector2:
	return Vector2(_ghost_x, _ghost_y)


## Display seconds of the burst cooldown (0 when ready).
func cooldown_digit() -> int:
	return _digit


## The id of the hero disc, so the HUD can ignore a Start/Call tap that named the hero.
func hero_disc_id() -> int:
	return _hero_disc


## Where the last burst command was aimed (set when burst returned OK).
func last_aim_fired() -> Vector2:
	return Vector2(_fired_x, _fired_y)


## G1: decides what the press means.
func _on_pressed(_best_tap: int, best_drag: int, p: Vector2) -> void:
	_clear()
	if _hero_sim == null or bool(_halted.call()):
		return
	if best_drag == InputResolver.NONE:
		return
	if best_drag == _hero_disc:
		_press = _PRESS_HERO
		return
	if best_drag == _button_disc:
		if _hero_sim.burst_state() != HeroSim.BurstState.READY:
			return
		if _hero_sim.pin_state() == HeroSim.PinState.UNPINNED:
			return
		if bool(_in_build.call()):
			return
		_press = _PRESS_AIM
		_state = AimState.CANCELLING
		_finger_x = p.x
		_finger_y = p.y
		_recompute_aim()


## G4: the first drag move.
func _on_drag_started(_best_drag: int, _press_pos: Vector2, p: Vector2) -> void:
	_follow(p)


## G5: one per drag move.
func _on_drag_moved(_best_drag: int, _press_pos: Vector2, p: Vector2) -> void:
	_follow(p)


## G6: the drag ended; issues pin or burst.
func _on_drag_ended(_best_drag: int, _press_pos: Vector2, release_pos: Vector2) -> void:
	if _hero_sim == null:
		return
	var mode: int = _press
	if mode == _PRESS_HERO:
		_finger_x = release_pos.x
		_finger_y = release_pos.y
		if not bool(_halted.call()) and _recompute_ghost():
			var px: float = _ghost_x
			var py: float = _ghost_y
			var result: HeroSim.PinResult = _hero_sim.pin(Vector2(px, py))
			if result != HeroSim.PinResult.OK and result != HeroSim.PinResult.HALTED:
				_report("HeroInput: pin refused: " + str(HeroSim.PinResult.find_key(result)))
	elif mode == _PRESS_AIM:
		_follow(release_pos)
		if _state == AimState.LIVE and not bool(_halted.call()) and _recompute_aim():
			var ax: float = _aim_x
			var ay: float = _aim_y
			var burst_result: HeroSim.BurstResult = _hero_sim.burst(Vector2(ax, ay))
			if burst_result == HeroSim.BurstResult.OK:
				_fired_x = ax
				_fired_y = ay
			elif burst_result != HeroSim.BurstResult.HALTED:
				_report("HeroInput: burst refused: " + str(HeroSim.BurstResult.find_key(burst_result)))
	_clear()


## G7: a cancel clears the state and never issues a command.
func _on_drag_cancelled(_best_drag: int) -> void:
	_clear()


## G8: back to Idle; clears the state and never issues a command.
func _on_became_idle() -> void:
	_clear()


func _follow(p: Vector2) -> void:
	if _hero_sim == null:
		return
	_finger_x = p.x
	_finger_y = p.y
	if _press == _PRESS_HERO:
		_state = AimState.PINNING
		_recompute_ghost()
	elif _press == _PRESS_AIM:
		var dx: float = _finger_x - _button_x
		var dy: float = _finger_y - _button_y
		var d2: float = dx * dx + dy * dy
		if d2 > CANCEL_OUT * CANCEL_OUT:
			_state = AimState.LIVE
		elif d2 <= CANCEL_IN * CANCEL_IN:
			_state = AimState.CANCELLING
		_recompute_aim()


func _recompute_ghost() -> bool:
	var hold: Vector2 = _hero_sim.pin_target()
	var hx: float = hold.x
	var hy: float = hold.y
	var pt: Vector2 = _geometry.clamp_point(_finger_x, _finger_y - PIN_OFFSET_Y, hx, hy)
	_ghost_x = pt.x
	_ghost_y = pt.y
	return true


func _recompute_aim() -> bool:
	var reach: float = _accessor.stat_float(_burst_ctx, StatKeys.REACH)
	if bool(_halted.call()):
		_clear()
		return false
	var ax: float = clampf(_finger_x, 0.0, FieldBounds.WIDTH)
	var ay: float = clampf(_finger_y - AIM_OFFSET_Y, 0.0, FieldBounds.HEIGHT)
	var hero: Vector2 = _hero_sim.position()
	var hx: float = hero.x
	var hy: float = hero.y
	var dx: float = ax - hx
	var dy: float = ay - hy
	var limit: float = maxf(0.0, reach - REACH_MARGIN)
	var d2: float = dx * dx + dy * dy
	if d2 > limit * limit:
		var d: float = sqrt(d2)
		ax = hx + dx * limit / d
		ay = hy + dy * limit / d
	_aim_x = ax
	_aim_y = ay
	return true


func _clear() -> void:
	_state = AimState.NONE
	_press = _PRESS_NONE


func _report(msg: String) -> void:
	if _dev_error.is_valid():
		_dev_error.call(msg)
