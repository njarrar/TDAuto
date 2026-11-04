class_name TowerInput extends RefCounted
## Slot, tower and chip discs; the upgrade chip (Tower Rules 8 and 17, ADR-0010 Decision 8).
## Changes battle state only through TowerSim.upgrade. Built by BattleWrapper.attach;
## listeners are connected only in BattleWrapper._connect_signals() and undone in detach().

## An empty slot was tapped (the HUD opens the build arc).
signal slot_tapped(slot_index: int)
## A tower at its last level was tapped (the HUD shows its range ring).
signal tower_inspected(slot_index: int)

const SLOT_RADIUS: float = 36.0
const SLOT_PRIORITY: int = 200
const CHIP_RADIUS: float = 40.0
const CHIP_PRIORITY: int = 300
const CHIP_OFFSET_Y: float = 76.0


## One reused value object for the HUD. Callers never keep it.
class ChipState extends RefCounted:
	var open: bool = false
	var slot_index: int = -1
	var elapsed_ms: float = 0.0
	var level: int = 0


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


## Frame step 1: advances the chip window in real time; unregisters the chip disc on expiry.
func advance(ms: float) -> void:
	var was_open: bool = _window.is_open()
	_window.advance(ms)
	if was_open and not _window.is_open():
		_unregister_chip()


## The chip's state for the HUD. One reused instance; never keep it.
func chip_state() -> ChipState:
	_state.open = _window.is_open()
	_state.slot_index = _window.slot()
	_state.elapsed_ms = _window.elapsed_ms()
	_state.level = 0
	if _state.open and _tower_sim != null:
		_state.level = _tower_sim.slot_level(_state.slot_index)
	return _state


## True while a chip is open (wired as GestureLog's chip_open).
func is_chip_open() -> bool:
	return _window.is_open()


## The id of the chip disc, or InputResolver.NONE. For tests and logs.
func chip_disc_id() -> int:
	return _chip_disc


## P4: the slot's disc is disabled and the tower's disc registered at the same centre.
func _on_tower_built(slot_index: int, _tower_id: StringName) -> void:
	if _resolver == null or slot_index < 0 or slot_index >= _slot_n:
		return
	if _slot_disc[slot_index] != InputResolver.NONE:
		_resolver.set_enabled(_slot_disc[slot_index], false)
	if _tower_disc[slot_index] == InputResolver.NONE:
		_tower_disc[slot_index] = _resolver.register(_tower_sim.slot_position(slot_index),
				SLOT_RADIUS, InputResolver.Accepts.TAP, SLOT_PRIORITY)


## G1: a press on anything other than the chip or its own tower closes the chip.
func _on_pressed(best_tap: int, _best_drag: int, _p: Vector2) -> void:
	if not _window.is_open():
		return
	if best_tap != InputResolver.NONE:
		if best_tap == _chip_disc or best_tap == _tower_disc[_window.slot()]:
			return
	_close_chip()


## G2: a tap completed on a target.
func _on_tapped(best_tap: int, _p: Vector2) -> void:
	if _tower_sim == null or best_tap == InputResolver.NONE:
		return
	if bool(_halted.call()):
		return
	if _chip_disc != InputResolver.NONE and best_tap == _chip_disc:
		if _window.is_open():
			_tap_tower(_window.slot())
		return
	for i: int in range(_slot_n):
		if best_tap == _slot_disc[i]:
			slot_tapped.emit(i)
			return
		if best_tap == _tower_disc[i]:
			_tap_tower(i)
			return


## P-phase: Paused, Won, Lost and Fatal close the chip.
func _on_phase_changed(value: Flow.Phase) -> void:
	if value == Flow.Phase.PAUSED or value == Flow.Phase.WON \
			or value == Flow.Phase.LOST or value == Flow.Phase.FATAL:
		_close_chip()


func _tap_tower(slot_index: int) -> void:
	var def_id: StringName = _tower_sim.slot_tower(slot_index)
	if def_id == &"":
		return
	var level: int = _tower_sim.slot_level(slot_index)
	if level >= _accessor.level_count(def_id):
		tower_inspected.emit(slot_index)
		return
	if _window.is_open() and _window.slot() == slot_index:
		if _window.elapsed_ms() < ChipWindow.MIN_COMMIT_MS:
			return
		if _window.can_commit():
			_commit(slot_index)
			return
	_open_chip(slot_index)


func _commit(slot_index: int) -> void:
	var result: TowerSim.UpgradeResult = _tower_sim.upgrade(slot_index)
	if result == TowerSim.UpgradeResult.NO_GOLD:
		return
	_close_chip()
	if result != TowerSim.UpgradeResult.OK and result != TowerSim.UpgradeResult.HALTED:
		_report("TowerInput: upgrade refused: " + str(TowerSim.UpgradeResult.find_key(result)))


func _open_chip(slot_index: int) -> void:
	_close_chip()
	_window.open(slot_index)
	var centre: Vector2 = _tower_sim.slot_position(slot_index)
	_chip_disc = _resolver.register(Vector2(centre.x, centre.y - CHIP_OFFSET_Y), CHIP_RADIUS,
			InputResolver.Accepts.TAP, CHIP_PRIORITY)


func _close_chip() -> void:
	_window.close()
	_unregister_chip()


func _unregister_chip() -> void:
	if _chip_disc != InputResolver.NONE and _resolver != null:
		_resolver.unregister(_chip_disc)
	_chip_disc = InputResolver.NONE


func _report(msg: String) -> void:
	if _dev_error.is_valid():
		_dev_error.call(msg)
