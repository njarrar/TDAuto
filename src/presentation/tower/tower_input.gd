class_name TowerInput extends RefCounted
## Slot and tower discs, and the tower panel (Tower Rules 4, 8 and 17, ADR-0010 Decision 8).
## A tap on a tower opens its panel: an Upgrade button (when below the last level) and a
## Sell button, side by side above the tower. The panel has no time limit; it closes on
## a button that ends it, a second tap on the tower, or a press elsewhere (first
## playable, user 2026-11-05). Changes battle state only through TowerSim.upgrade and
## TowerSim.sell. Built by BattleWrapper.attach; listeners are connected only in
## BattleWrapper._connect_signals() and undone in detach().

## An empty slot was tapped (the HUD opens the build arc).
signal slot_tapped(slot_index: int)
## A tower's panel opened (the HUD shows its range ring).
signal tower_inspected(slot_index: int)

const SLOT_RADIUS: float = 36.0
const SLOT_PRIORITY: int = 200
## Radius of each panel button.
const CHIP_RADIUS: float = 36.0
const CHIP_PRIORITY: int = 300
## Panel buttons sit this far above the tower's centre.
const CHIP_OFFSET_Y: float = 76.0
## Upgrade sits this far left of the tower's x, Sell this far right.
const PANEL_DX: float = 44.0


## One reused value object for the HUD. Callers never keep it.
class ChipState extends RefCounted:
	var open: bool = false
	var slot_index: int = -1
	var elapsed_ms: float = 0.0
	var level: int = 0
	## True when the tower is below its last level, so the Upgrade button shows.
	var can_upgrade: bool = false
	## Gold a sell pays now.
	var sell_value: int = 0


var _resolver: InputResolver = null
var _tower_sim: TowerSim = null
var _accessor: StatAccessor = null
var _halted: Callable = Callable()
var _dev_error: Callable = Callable()
var _window: ChipWindow = ChipWindow.new()
var _state: ChipState = ChipState.new()
var _slot_n: int = 0
var _slot_disc: PackedInt32Array = PackedInt32Array()
var _tower_disc: PackedInt32Array = PackedInt32Array()
var _chip_disc: int = InputResolver.NONE
var _sell_disc: int = InputResolver.NONE


## Registers one TAP disc per slot (a tower disc for a slot already built).
## Returns false if the resolver rejects a registration.
func attach(resolver: InputResolver, tower_sim: TowerSim, accessor: StatAccessor,
		halted: Callable, dev_error: Callable) -> bool:
	if resolver == null or tower_sim == null or accessor == null:
		return false
	_resolver = resolver
	_tower_sim = tower_sim
	_accessor = accessor
	_halted = halted
	_dev_error = dev_error
	_slot_n = tower_sim.slot_count()
	_slot_disc.resize(_slot_n)
	_tower_disc.resize(_slot_n)
	for i: int in range(_slot_n):
		_slot_disc[i] = InputResolver.NONE
		_tower_disc[i] = InputResolver.NONE
		var centre: Vector2 = tower_sim.slot_position(i)
		if tower_sim.slot_tower(i) == &"":
			_slot_disc[i] = _resolver.register(centre, SLOT_RADIUS, InputResolver.Accepts.TAP, SLOT_PRIORITY)
			if _slot_disc[i] == InputResolver.NONE:
				return false
		else:
			_tower_disc[i] = _resolver.register(centre, SLOT_RADIUS, InputResolver.Accepts.TAP, SLOT_PRIORITY)
			if _tower_disc[i] == InputResolver.NONE:
				return false
	return true


## Unregisters every disc and drops every reference.
func detach() -> void:
	if _resolver != null:
		for i: int in range(_slot_n):
			if _slot_disc[i] != InputResolver.NONE:
				_resolver.unregister(_slot_disc[i])
			if _tower_disc[i] != InputResolver.NONE:
				_resolver.unregister(_tower_disc[i])
		_unregister_chip()
	_window.close()
	_slot_disc = PackedInt32Array()
	_tower_disc = PackedInt32Array()
	_slot_n = 0
	_resolver = null
	_tower_sim = null
	_accessor = null
	_halted = Callable()
	_dev_error = Callable()


## Frame step 1: advances the panel's bounce-guard clock in real time.
func advance(ms: float) -> void:
	_window.advance(ms)


## The panel's state for the HUD. One reused instance; never keep it.
func chip_state() -> ChipState:
	_state.open = _window.is_open()
	_state.slot_index = _window.slot()
	_state.elapsed_ms = _window.elapsed_ms()
	_state.level = 0
	_state.can_upgrade = false
	_state.sell_value = 0
	if _state.open and _tower_sim != null:
		_state.level = _tower_sim.slot_level(_state.slot_index)
		_state.can_upgrade = _upgrade_left(_state.slot_index)
		_state.sell_value = _tower_sim.sell_value(_state.slot_index)
	return _state


## True while a panel is open (wired as GestureLog's chip_open).
func is_chip_open() -> bool:
	return _window.is_open()


## The id of the panel's Upgrade disc, or InputResolver.NONE. For tests and logs.
func chip_disc_id() -> int:
	return _chip_disc


## The id of the panel's Sell disc, or InputResolver.NONE. For tests and logs.
func sell_disc_id() -> int:
	return _sell_disc


## Centre of the Upgrade button for a slot (the HUD draws it there).
static func upgrade_centre(tower_centre: Vector2) -> Vector2:
	return Vector2(tower_centre.x - PANEL_DX, tower_centre.y - CHIP_OFFSET_Y)


## Centre of the Sell button for a slot (the HUD draws it there).
static func sell_centre(tower_centre: Vector2) -> Vector2:
	return Vector2(tower_centre.x + PANEL_DX, tower_centre.y - CHIP_OFFSET_Y)


## P4: the slot's disc is disabled and the tower's disc registered at the same centre.
func _on_tower_built(slot_index: int, _tower_id: StringName) -> void:
	if _resolver == null or slot_index < 0 or slot_index >= _slot_n:
		return
	if _slot_disc[slot_index] != InputResolver.NONE:
		_resolver.set_enabled(_slot_disc[slot_index], false)
	if _tower_disc[slot_index] == InputResolver.NONE:
		_tower_disc[slot_index] = _resolver.register(_tower_sim.slot_position(slot_index),
				SLOT_RADIUS, InputResolver.Accepts.TAP, SLOT_PRIORITY)


## G1: a press on anything but the panel's buttons or its own tower closes the panel.
func _on_pressed(best_tap: int, _best_drag: int, _p: Vector2) -> void:
	if not _window.is_open():
		return
	if best_tap != InputResolver.NONE:
		if best_tap == _chip_disc or best_tap == _sell_disc or best_tap == _tower_disc[_window.slot()]:
			return
	_close_chip()


## G2: a tap completed on a target.
func _on_tapped(best_tap: int, _p: Vector2) -> void:
	if _tower_sim == null or best_tap == InputResolver.NONE:
		return
	if bool(_halted.call()):
		return
	if _window.is_open():
		if _chip_disc != InputResolver.NONE and best_tap == _chip_disc:
			_press_upgrade(_window.slot())
			return
		if _sell_disc != InputResolver.NONE and best_tap == _sell_disc:
			_press_sell(_window.slot())
			return
	for i: int in range(_slot_n):
		if best_tap == _slot_disc[i]:
			slot_tapped.emit(i)
			return
		if best_tap == _tower_disc[i]:
			_tap_tower(i)
			return


## P-phase: Paused, Won, Lost and Fatal close the panel.
func _on_phase_changed(value: Flow.Phase) -> void:
	if value == Flow.Phase.PAUSED or value == Flow.Phase.WON \
			or value == Flow.Phase.LOST or value == Flow.Phase.FATAL:
		_close_chip()


## A tap on a tower toggles its panel.
func _tap_tower(slot_index: int) -> void:
	if _tower_sim.slot_tower(slot_index) == &"":
		return
	if _window.is_open() and _window.slot() == slot_index:
		_close_chip()
		return
	_open_chip(slot_index)
	tower_inspected.emit(slot_index)


func _press_upgrade(slot_index: int) -> void:
	if not _window.can_commit():
		return
	var result: TowerSim.UpgradeResult = _tower_sim.upgrade(slot_index)
	if result == TowerSim.UpgradeResult.NO_GOLD:
		return
	if result == TowerSim.UpgradeResult.OK:
		# Stay open on the new level; the Upgrade button goes once the last level is reached.
		if not _upgrade_left(slot_index):
			_unregister(_chip_disc)
			_chip_disc = InputResolver.NONE
		return
	_close_chip()
	if result != TowerSim.UpgradeResult.HALTED:
		_report("TowerInput: upgrade refused: " + str(TowerSim.UpgradeResult.find_key(result)))


func _press_sell(slot_index: int) -> void:
	if not _window.can_commit():
		return
	var result: TowerSim.SellResult = _tower_sim.sell(slot_index)
	_close_chip()
	if result == TowerSim.SellResult.OK:
		# The slot is empty again: drop the tower disc and re-enable the slot disc.
		_unregister(_tower_disc[slot_index])
		_tower_disc[slot_index] = InputResolver.NONE
		if _slot_disc[slot_index] != InputResolver.NONE:
			_resolver.set_enabled(_slot_disc[slot_index], true)
		else:
			_slot_disc[slot_index] = _resolver.register(_tower_sim.slot_position(slot_index),
					SLOT_RADIUS, InputResolver.Accepts.TAP, SLOT_PRIORITY)
	elif result != TowerSim.SellResult.HALTED:
		_report("TowerInput: sell refused: " + str(TowerSim.SellResult.find_key(result)))


func _upgrade_left(slot_index: int) -> bool:
	var def_id: StringName = _tower_sim.slot_tower(slot_index)
	if def_id == &"":
		return false
	return _tower_sim.slot_level(slot_index) < _accessor.level_count(def_id)


func _open_chip(slot_index: int) -> void:
	_close_chip()
	_window.open(slot_index)
	var centre: Vector2 = _tower_sim.slot_position(slot_index)
	if _upgrade_left(slot_index):
		_chip_disc = _resolver.register(upgrade_centre(centre), CHIP_RADIUS,
				InputResolver.Accepts.TAP, CHIP_PRIORITY)
	_sell_disc = _resolver.register(sell_centre(centre), CHIP_RADIUS,
			InputResolver.Accepts.TAP, CHIP_PRIORITY)


func _close_chip() -> void:
	_window.close()
	_unregister_chip()


func _unregister_chip() -> void:
	_unregister(_chip_disc)
	_unregister(_sell_disc)
	_chip_disc = InputResolver.NONE
	_sell_disc = InputResolver.NONE


func _unregister(disc: int) -> void:
	if disc != InputResolver.NONE and _resolver != null:
		_resolver.unregister(disc)


func _report(msg: String) -> void:
	if _dev_error.is_valid():
		_dev_error.call(msg)
