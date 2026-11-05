extends GdUnitTestSuite
## TowerInput and ChipWindow wiring on a headless battle's resolver (Tower Rules 4, 8 and 17,
## ADR-0010 Validation for the input halves). The tower panel: Upgrade and Sell, no time limit.

const TestBattles := preload("res://tests/helpers/test_battles.gd")
const Fakes := preload("res://tests/helpers/fakes.gd")
const SLOT0: Vector2 = Vector2(270.0, 305.0)
const UPG0: Vector2 = Vector2(226.0, 229.0)
const SELL0: Vector2 = Vector2(314.0, 229.0)

class Rec extends RefCounted:
	var taps: Array[int] = []
	var inspected: Array[int] = []

	func on_slot(i: int) -> void:
		taps.append(i)

	func on_inspect(i: int) -> void:
		inspected.append(i)

var _battle: Battle
var _ti: TowerInput
var _rec: Rec
var _halt: Fakes.Halted
var _errs: Fakes.DevErrors


func before_test() -> void:
	_battle = TestBattles.build()
	_halt = Fakes.Halted.new()
	_errs = Fakes.DevErrors.new()
	_rec = Rec.new()
	_ti = TowerInput.new()
	assert_bool(_ti.attach(_battle.resolver, _battle.tower_sim, _battle.accessor, _halt.halted, _errs.report)).is_true()
	_battle.resolver.pressed.connect(_ti._on_pressed)
	_battle.resolver.tapped.connect(_ti._on_tapped)
	_battle.tower_sim.tower_built.connect(_ti._on_tower_built)
	_battle.flow.phase_changed.connect(_ti._on_phase_changed)
	_ti.slot_tapped.connect(_rec.on_slot)
	_ti.tower_inspected.connect(_rec.on_inspect)


func after_test() -> void:
	_ti.detach()


func _tap(p: Vector2) -> void:
	_battle.resolver.press(0, p)
	_battle.resolver.release(0, p)


func test_empty_slot_tap_emits_slot_tapped() -> void:
	_tap(SLOT0)
	assert_array(_rec.taps).is_equal([0])
	assert_bool(_ti.is_chip_open()).is_false()


func test_built_slot_disc_swaps_and_tap_opens_panel_with_two_buttons() -> void:
	_battle.tower_sim.build(0, &"tower_single")
	_tap(SLOT0)
	assert_array(_rec.taps).is_empty()
	assert_bool(_ti.is_chip_open()).is_true()
	var cs: TowerInput.ChipState = _ti.chip_state()
	assert_int(cs.slot_index).is_equal(0)
	assert_int(cs.level).is_equal(1)
	assert_bool(cs.can_upgrade).is_true()
	assert_int(cs.sell_value).is_equal(35)
	assert_bool(_battle.resolver.centre_of(_ti.chip_disc_id()) == UPG0).is_true()
	assert_bool(_battle.resolver.centre_of(_ti.sell_disc_id()) == SELL0).is_true()
	assert_array(_rec.inspected).is_equal([0])


func test_upgrade_before_200ms_is_ignored_then_upgrades_and_stays_open() -> void:
	_battle.tower_sim.build(0, &"tower_single")
	var gold: int = _battle.tower_sim.gold()
	_tap(SLOT0)
	_ti.advance(100.0)
	_tap(UPG0)
	assert_int(_battle.tower_sim.gold()).is_equal(gold)
	_ti.advance(150.0)
	_tap(UPG0)
	assert_int(_battle.tower_sim.slot_level(0)).is_equal(2)
	# Still open on the new level; the fixture's last level removes the Upgrade button.
	assert_bool(_ti.is_chip_open()).is_true()
	assert_int(_ti.chip_disc_id()).is_equal(InputResolver.NONE)


func test_second_tap_on_the_tower_closes_the_panel() -> void:
	_battle.tower_sim.build(0, &"tower_single")
	_tap(SLOT0)
	_ti.advance(300.0)
	_tap(SLOT0)
	assert_bool(_ti.is_chip_open()).is_false()
	assert_int(_battle.tower_sim.slot_level(0)).is_equal(1)


func test_panel_has_no_time_limit() -> void:
	_battle.tower_sim.build(0, &"tower_single")
	_tap(SLOT0)
	_ti.advance(60000.0)
	assert_bool(_ti.is_chip_open()).is_true()
	_tap(UPG0)
	assert_int(_battle.tower_sim.slot_level(0)).is_equal(2)


func test_no_gold_keeps_panel_open() -> void:
	_battle.tower_sim.build(0, &"tower_single")
	_battle.tower_sim.build(1, &"tower_splash")
	assert_int(_battle.tower_sim.gold()).is_less(60)
	_tap(SLOT0)
	_ti.advance(300.0)
	_tap(UPG0)
	assert_bool(_ti.is_chip_open()).is_true()
	assert_int(_battle.tower_sim.slot_level(0)).is_equal(1)


func test_last_level_panel_has_sell_only_and_shows_range() -> void:
	_battle.tower_sim.build(0, &"tower_single")
	_battle.tower_sim.upgrade(0)
	_tap(SLOT0)
	assert_array(_rec.inspected).is_equal([0])
	assert_bool(_ti.is_chip_open()).is_true()
	assert_bool(_ti.chip_state().can_upgrade).is_false()
	assert_int(_ti.chip_disc_id()).is_equal(InputResolver.NONE)
	assert_int(_ti.sell_disc_id()).is_not_equal(InputResolver.NONE)


func test_sell_pays_seventy_percent_of_all_spend_and_frees_the_slot() -> void:
	# Fixture: 120 gold, single 50 then 60. Spend 110; 70% is 77.
	_battle.tower_sim.build(0, &"tower_single")
	_battle.tower_sim.upgrade(0)
	assert_int(_battle.tower_sim.gold()).is_equal(10)
	_tap(SLOT0)
	_ti.advance(300.0)
	_tap(SELL0)
	assert_int(_battle.tower_sim.gold()).is_equal(87)
	assert_str(String(_battle.tower_sim.slot_tower(0))).is_equal("")
	assert_bool(_ti.is_chip_open()).is_false()
	_tap(SLOT0)
	assert_array(_rec.taps).is_equal([0])


func test_sell_before_200ms_is_ignored() -> void:
	_battle.tower_sim.build(0, &"tower_single")
	_tap(SLOT0)
	_ti.advance(50.0)
	_tap(SELL0)
	assert_str(String(_battle.tower_sim.slot_tower(0))).is_equal("tower_single")


func test_pressed_elsewhere_closes_chip() -> void:
	_battle.tower_sim.build(0, &"tower_single")
	_tap(SLOT0)
	_battle.resolver.press(0, Vector2(50.0, 700.0))
	assert_bool(_ti.is_chip_open()).is_false()


func test_phase_closes_chip_and_halted_ignores_taps() -> void:
	_battle.tower_sim.build(0, &"tower_single")
	_tap(SLOT0)
	_ti._on_phase_changed(Flow.Phase.PAUSED)
	assert_bool(_ti.is_chip_open()).is_false()
	_halt.value = true
	_tap(SLOT0)
	assert_bool(_ti.is_chip_open()).is_false()


func test_detach_unregisters_discs() -> void:
	var slot_disc_centre: Vector2 = _battle.resolver.centre_of(1)
	assert_bool(is_nan(slot_disc_centre.x)).is_false()
	_ti.detach()
	assert_bool(is_nan(_battle.resolver.centre_of(1).x)).is_true()
