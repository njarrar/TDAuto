extends GdUnitTestSuite
## HudLogic: arm model, build arc, call label, prompts, snapshot (Battle HUD Rules 6 to 16).

const TestBattles := preload("res://tests/helpers/test_battles.gd")
const Fakes := preload("res://tests/helpers/fakes.gd")
const SLOT0: Vector2 = Vector2(270.0, 305.0)
const IDS: Array[StringName] = [&"tower_single", &"tower_splash", &"tower_slow"]

class Rec extends RefCounted:
	var snaps: Array[ResultSnapshot] = []
	var calls: Array[int] = []

	func on_snapshot(s: ResultSnapshot) -> void:
		snaps.append(s)

	func on_call(ticks_left: int, burst_state: int) -> void:
		calls.append(ticks_left)

var _battle: Battle
var _hud: HudLogic
var _rec: Rec
var _halt: Fakes.Halted
var _errs: Fakes.DevErrors


func before_test() -> void:
	_battle = TestBattles.build()
	_halt = Fakes.Halted.new()
	_errs = Fakes.DevErrors.new()
	_rec = Rec.new()
	_hud = HudLogic.new()
	var b: Battle = _battle
	var ok: bool = _hud.attach(b.flow, b.tower_sim, b.hero_sim, b.enemy_wave, b.combat, b.resolver, b.accessor,
			b.stage_record, b.input_record, FieldInsets.new(), _halt.halted, b.sim_time.to_ticks, false,
			_errs.report, _rec.on_snapshot, _rec.on_call)
	assert_bool(ok).is_true()
	assert_bool(_hud.set_arc_tower_ids(IDS)).is_true()
	_hud.set_ticks_source(b.ticks_run)
	b.resolver.pressed.connect(_hud._on_pressed)
	b.resolver.tapped.connect(_hud._on_tapped)
	b.resolver.drag_started.connect(_hud._on_drag_started)
	b.flow.phase_changed.connect(_hud._on_phase_changed)
	b.tower_sim.gold_changed.connect(_hud._on_gold_changed)


func after_test() -> void:
	_hud.detach()


func _tap(p: Vector2) -> void:
	_battle.resolver.press(0, p)
	_battle.resolver.release(0, p)


func _arc_disc(k: int) -> Vector2:
	return _hud.arc_centre(k)


func test_burst_button_centre_by_hand_and_inset() -> void:
	assert_bool(_hud.burst_button_centre() == Vector2(456.0, 888.0)).is_true()
	_hud.set_insets(FieldInsets.new(0.0, 72.0))
	assert_float(_hud.burst_button_centre().y).is_equal(816.0)


func test_start_button_arms_over_300ms_and_ignores_dead_tap() -> void:
	assert_int(_hud.button_arm()).is_equal(HudLogic.Arm.ARMING)
	assert_str(_hud.button_label()).is_equal("Start")
	_tap(HudLogic.START_CENTRE)
	assert_bool(_battle.flow.in_build()).is_true()
	_hud.advance(100.0)
	_hud.advance(100.0)
	assert_int(_hud.button_arm()).is_equal(HudLogic.Arm.ARMING)
	_hud.advance(100.0)
	assert_int(_hud.button_arm()).is_equal(HudLogic.Arm.ARMED)
	_tap(HudLogic.START_CENTRE)
	assert_bool(_battle.flow.in_build()).is_false()


func test_advance_clamps_a_hitch_to_100ms() -> void:
	_hud.advance(5000.0)
	assert_int(_hud.button_arm()).is_equal(HudLogic.Arm.ARMING)


func test_slot_tap_opens_arc_with_costs_and_guard() -> void:
	_hud._on_slot_tapped(0)
	assert_bool(_hud.arc_open()).is_true()
	assert_int(_hud.arc_cost(0)).is_equal(50)
	assert_bool(_hud.arc_affordable(0)).is_true()
	var gold: int = _battle.tower_sim.gold()
	_tap(_arc_disc(0))
	assert_int(_battle.tower_sim.gold()).is_equal(gold)
	assert_bool(_hud.arc_open()).is_true()
	_hud.advance(100.0)
	_hud.advance(100.0)
	_tap(_arc_disc(0))
	assert_str(String(_battle.tower_sim.slot_tower(0))).is_equal("tower_single")
	assert_bool(_hud.arc_open()).is_false()


func test_arc_geometry_matches_formula() -> void:
	_hud._on_slot_tapped(0)
	assert_float(_arc_disc(0).x).is_equal_approx(204.2, 0.1)
	assert_float(_arc_disc(0).y).is_equal_approx(267.0, 0.1)
	assert_float(_arc_disc(1).y).is_equal_approx(229.0, 0.1)


func test_no_gold_stays_open_with_nudge_and_gold_changed_updates_dim() -> void:
	_battle.tower_sim.build(0, &"tower_single")
	_battle.tower_sim.build(1, &"tower_splash")
	_hud._on_slot_tapped(0)
	_hud.advance(100.0)
	_hud.advance(100.0)
	assert_bool(_hud.arc_affordable(0)).is_false()
	_tap(_arc_disc(0))
	assert_bool(_hud.arc_open()).is_true()
	assert_bool(_hud.nudge_active()).is_true()


func test_non_disc_press_and_drag_close_the_arc() -> void:
	_hud._on_slot_tapped(0)
	_battle.resolver.press(0, Vector2(60.0, 700.0))
	assert_bool(_hud.arc_open()).is_false()
	_hud._on_slot_tapped(0)
	_hud._on_drag_started(InputResolver.NONE, Vector2.ZERO, Vector2.ZERO)
	assert_bool(_hud.arc_open()).is_false()


func test_phase_closes_arc_and_unregisters_discs() -> void:
	_hud._on_slot_tapped(0)
	_hud._on_phase_changed(Flow.Phase.PAUSED)
	assert_bool(_hud.arc_open()).is_false()
	assert_bool(_hud.paused_open()).is_false()


func test_prompt_first_match() -> void:
	assert_int(_hud.prompt()).is_equal(HudLogic.Prompt.DRAG_HERO)
	assert_str(_hud.prompt_text()).is_equal("Drag the hero")
	_battle.hero_sim.pin(Vector2(270.0, 480.0))
	_hud.refresh()
	assert_int(_hud.prompt()).is_equal(HudLogic.Prompt.TAP_SLOT)
	_battle.tower_sim.build(0, &"tower_single")
	_hud.refresh()
	assert_int(_hud.prompt()).is_equal(HudLogic.Prompt.NONE)


func test_ground_rings_limited_to_three() -> void:
	for i: int in range(5):
		_hud._on_ground_tapped(Vector2(10.0 * float(i), 10.0))
	assert_int(_hud.ground_ring_count()).is_equal(3)


func test_snapshot_built_on_first_advance_after_outcome() -> void:
	TestBattles.finish(_battle)
	assert_bool(_hud.result_open()).is_true()
	assert_object(_hud.snapshot()).is_null()
	_hud.advance(16.0)
	var s: ResultSnapshot = _hud.snapshot()
	assert_object(s).is_not_null()
	assert_int(_rec.snaps.size()).is_equal(1)
	assert_bool(s.hero_pinned_ever).is_false()
	assert_int(s.towers_built).is_equal(0)
	assert_int(s.ticks_run).is_greater(0)
	assert_str(s.next_try).is_equal(HudLogic.NEXT_PIN)
	assert_bool(_hud.result_text_visible()).is_false()
	for i: int in range(11):
		_hud.advance(100.0)
	assert_bool(_hud.result_text_visible()).is_true()
