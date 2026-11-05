extends GdUnitTestSuite
## View models headless (ADR-0011 Validation 1): enemy ordering and pool growth, flash pool and
## clearance, tower and field refresh, Reduce Motion both ways, view_ms 0 freezing clocks.

const TestBattles := preload("res://tests/helpers/test_battles.gd")
const Fakes := preload("res://tests/helpers/fakes.gd")

class Roster extends RefCounted:
	var list: Array[Targetable] = []

	func roster() -> Array[Targetable]:
		return list


func _keys() -> VisualKeys:
	# Built directly: these view tests need only the enemy and hero keys, not a catalogue.
	var keys: VisualKeys = VisualKeys.new()
	keys._enemy = {&"e_h": &"enemy_heavy_1", &"e_n": &"enemy_normal_1", &"e_f": &"enemy_fast_1"}
	keys._hero = &"hero_1"
	return keys


func _enemy(sid: int, def_id: StringName, x: float) -> Enemy:
	var e: Enemy = Enemy.new(sid, def_id)
	e.pos_x = x
	return e


func test_enemy_order_heavy_normal_fast_then_spawn_id() -> void:
	var rec: Roster = Roster.new()
	rec.list.append(_enemy(5, &"e_f", 1.0))
	rec.list.append(_enemy(9, &"e_n", 2.0))
	rec.list.append(_enemy(3, &"e_n", 3.0))
	rec.list.append(_enemy(7, &"e_h", 4.0))
	var m: EnemyViewModel = EnemyViewModel.new()
	m._roster = rec.roster
	m._visual_keys = _keys()
	m._resize(ViewStyles.ENEMY_POOL)
	assert_bool(m.refresh(16.0)).is_true()
	assert_int(m.count).is_equal(4)
	assert_array(Array(m.spawn_ids.slice(0, 4))).is_equal([7, 3, 9, 5])


func test_enemy_pool_growth_reports_once() -> void:
	var rec: Roster = Roster.new()
	for i: int in range(50):
		rec.list.append(_enemy(i, &"e_n", float(i)))
	var errs: Fakes.DevErrors = Fakes.DevErrors.new()
	var m: EnemyViewModel = EnemyViewModel.new()
	m._roster = rec.roster
	m._visual_keys = _keys()
	m._dev_error = errs.report
	m._resize(ViewStyles.ENEMY_POOL)
	m.refresh(16.0)
	m.refresh(16.0)
	assert_int(m.count).is_equal(50)
	assert_int(errs.messages().size()).is_equal(1)


func test_enemy_bob_off_under_reduce_motion_and_frozen_at_zero_ms() -> void:
	var rec: Roster = Roster.new()
	rec.list.append(_enemy(1, &"e_n", 10.0))
	var m: EnemyViewModel = EnemyViewModel.new()
	m._roster = rec.roster
	m._visual_keys = _keys()
	m._resize(ViewStyles.ENEMY_POOL)
	m._reduce_motion = true
	m.refresh(16.0)
	assert_float(m.positions[0].y).is_equal(0.0)
	m._reduce_motion = false
	m.refresh(0.0)
	var y0: float = m.positions[0].y
	m.refresh(0.0)
	assert_float(m.positions[0].y).is_equal(y0)


func _combat_model() -> CombatViewModel:
	var b: Battle = TestBattles.build()
	var m: CombatViewModel = CombatViewModel.new()
	var rec: Roster = Roster.new()
	m._roster = rec.roster
	m.attach(b.combat, b.enemy_wave, b.accessor, b.halted, _keys(), false, Callable())
	m._roster = rec.roster
	return m


func test_core_fraction_reads_combat_max_hp() -> void:
	var b: Battle = TestBattles.build()
	var m: CombatViewModel = CombatViewModel.new()
	var rec: Roster = Roster.new()
	m.attach(b.combat, b.enemy_wave, b.accessor, b.halted, _keys(), false, Callable())
	m._roster = rec.roster
	var e: Enemy = _enemy(1, &"e_n", 10.0)
	assert_bool(b.combat.attach(e, 20.0)).is_true()
	rec.list.append(e)
	e.health.hp = 5.0

	m.refresh(16.0)

	assert_int(m.core_n).is_equal(1)
	assert_float(m.core_frac[0]).is_equal(0.25)


func test_flash_marker_retrigger_keeps_higher_alpha_and_one_marker() -> void:
	var m: CombatViewModel = _combat_model()
	m._on_damage_applied(Combat.SourceKind.TOWER, &"t", 1.0, Vector2(1, 1), false, 4)
	m._on_damage_applied(Combat.SourceKind.HERO, &"h", 1.0, Vector2(1, 1), false, 4)
	assert_int(m.flash_count()).is_equal(1)
	assert_bool(m.flash_is_hero(4)).is_true()
	m._on_damage_applied(Combat.SourceKind.TOWER, &"t", 1.0, Vector2(1, 1), false, 4)
	# _f_alpha is a PackedFloat32Array, so 0.9 comes back as the nearest 32-bit value.
	assert_float(m._f_alpha[m._flash_slot(4)]).is_equal_approx(ViewStyles.FLASH_ALPHA_HERO, 1e-6)


func test_flash_eviction_order() -> void:
	var m: CombatViewModel = _combat_model()
	for i: int in range(ViewStyles.FLASH_POOL):
		m._on_damage_applied(Combat.SourceKind.TOWER, &"t", 1.0, Vector2.ZERO, false, i)
	m._on_damage_applied(Combat.SourceKind.HERO, &"h", 1.0, Vector2.ZERO, false, 100)
	assert_bool(m.has_flash(100)).is_true()
	assert_bool(m.has_flash(0)).is_false()
	assert_int(m.flash_count()).is_equal(ViewStyles.FLASH_POOL)
	# Fill with hero flashes; a tower flash never evicts one.
	var m2: CombatViewModel = _combat_model()
	for i: int in range(ViewStyles.FLASH_POOL):
		m2._on_damage_applied(Combat.SourceKind.HERO, &"h", 1.0, Vector2.ZERO, false, i)
	m2._on_damage_applied(Combat.SourceKind.TOWER, &"t", 1.0, Vector2.ZERO, false, 100)
	assert_bool(m2.has_flash(100)).is_false()
	m2._on_damage_applied(Combat.SourceKind.HERO, &"h", 1.0, Vector2.ZERO, false, 101)
	assert_bool(m2.has_flash(101)).is_true()
	assert_bool(m2.has_flash(0)).is_false()


func test_clearance_suppresses_tower_flash_and_splash_ring_until_tail_ends() -> void:
	var m: CombatViewModel = _combat_model()
	m._on_burst_started(Vector2.ZERO, 15)
	assert_bool(m.clearance_active()).is_true()
	m._on_damage_applied(Combat.SourceKind.TOWER, &"t", 1.0, Vector2.ZERO, false, 1)
	assert_int(m.flash_count()).is_equal(0)
	m._on_attack_fired(Combat.SourceKind.TOWER, &"t", Vector2.ZERO, Vector2(5, 5), 50.0)
	assert_int(m.tracer_count()).is_equal(1)
	m._on_attack_fired(Combat.SourceKind.BURST, &"b", Vector2.ZERO, Vector2(5, 5), 70.0)
	m.refresh(100.0)
	assert_bool(m.clearance_active()).is_true()
	m.refresh(60.0)
	assert_bool(m.clearance_active()).is_false()


func test_zero_view_ms_freezes_clocks_and_tracers_expire_on_view_time() -> void:
	var m: CombatViewModel = _combat_model()
	m._on_attack_fired(Combat.SourceKind.HERO, &"h", Vector2.ZERO, Vector2(5, 5), 0.0)
	m.refresh(0.0)
	m.refresh(0.0)
	assert_int(m.tracer_count()).is_equal(1)
	m.refresh(100.0)
	assert_int(m.tracer_count()).is_equal(0)


func test_death_and_tracer_pools_drop_oldest() -> void:
	var m: CombatViewModel = _combat_model()
	for i: int in range(ViewStyles.DEATH_POOL + 5):
		m._on_damage_applied(Combat.SourceKind.TOWER, &"t", 1.0, Vector2(float(i), 0.0), true, i)
	assert_int(m.death_count()).is_equal(ViewStyles.DEATH_POOL)
	for i: int in range(ViewStyles.TRACER_POOL + 5):
		m._on_attack_fired(Combat.SourceKind.HERO, &"h", Vector2.ZERO, Vector2.ONE, 0.0)
	assert_int(m.tracer_count()).is_equal(ViewStyles.TRACER_POOL)


func test_tower_view_model_polls_slots() -> void:
	var b: Battle = TestBattles.build()
	var m: TowerViewModel = TowerViewModel.new()
	var vk: VisualKeys = b.visual_keys
	assert_bool(m.attach(b.tower_sim, b.accessor, b.halted, vk, false, Callable())).is_true()
	assert_bool(m.refresh(16.0)).is_false()
	b.tower_sim.build(0, &"tower_single")
	assert_bool(m.refresh(16.0)).is_true()
	assert_int(m.present[0]).is_equal(1)
	assert_int(m.levels[0]).is_equal(1)
	m.detach()


func test_field_backdrop_model_changes_only_on_change_and_rejects_bad_look() -> void:
	var b: Battle = TestBattles.build()
	var m: FieldBackdropModel = FieldBackdropModel.new()
	assert_bool(m.attach(b.stage_record, b.flow, b.enemy_wave, b.tower_sim, b.hero_sim, 90.0, 0.1, 0, false,
			Callable())).is_false()
	var ok: FieldBackdropModel = FieldBackdropModel.new()
	assert_bool(ok.attach(b.stage_record, b.flow, b.enemy_wave, b.tower_sim, b.hero_sim, 220.0, 0.1, 15, false,
			Callable())).is_true()
	assert_bool(ok.refresh(16.0)).is_true()
	assert_bool(ok.refresh(16.0)).is_false()
	b.tower_sim.build(0, &"tower_single")
	assert_bool(ok.refresh(16.0)).is_true()
	assert_int(ok.slot_free[0]).is_equal(0)


func test_modal_tap_guard() -> void:
	var g: ModalTapGuard = ModalTapGuard.new()
	g.press(0)
	assert_bool(g.release(0, false)).is_false()
	g.set_armed(true)
	g.press(0)
	assert_bool(g.release(0, true)).is_false()
	g.press(0)
	g.clear()
	assert_bool(g.release(0, false)).is_false()
	g.press(1)
	assert_bool(g.release(1, false)).is_true()


func test_view_styles_stroke_floor_and_bias() -> void:
	assert_float(ViewStyles.stroke(0.0)).is_equal(ViewStyles.MIN_STROKE)
	assert_float(ViewStyles.stroke(4.0)).is_equal(4.0 + ViewStyles.LINE_BIAS)
	assert_bool(ViewStyles.has_style(&"tower_splash_2")).is_true()
	assert_bool(ViewStyles.has_style(&"zzz")).is_false()
