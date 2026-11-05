extends GdUnitTestSuite
## Combat & Damage acceptance criteria 1 to 18 and ADR-0009 Validation 1 and 6.
## The invariant I is checked after every test.

const CombatFixtures := preload("res://tests/helpers/combat_fixtures.gd")
const TOWER := Combat.SourceKind.TOWER
const HERO := Combat.SourceKind.HERO
const BURST := Combat.SourceKind.BURST

var _sim: SimTime
var _combat: Combat
var _log: CombatFixtures.Log
var _all: Array[Targetable]


func before_test() -> void:
	_sim = SimTime.new(4)
	_combat = CombatFixtures.make_combat(_sim)
	_log = CombatFixtures.Log.new()
	CombatFixtures.listen(_combat, _log)
	_all = []


func after_test() -> void:
	assert_bool(CombatFixtures.invariant_holds(_combat, _log, _all)).is_true()


func _t(spawn_id: int, hp: float, x: float = 0.0, y: float = 0.0, dist: float = 0.0) -> Targetable:
	var t: Targetable = CombatFixtures.target(_combat, spawn_id, hp, x, y, dist)
	_all.append(t)
	return t


func _hit(t: Targetable, amount: float, kind: Combat.SourceKind = TOWER, id: StringName = &"tw") -> float:
	return _combat.deliver(DamageEvent.make(t, amount, kind, id))


func _factors(t: Targetable, ticks: int) -> Array[float]:
	var out: Array[float] = []
	var roster: Array[Targetable] = [t]
	for _i: int in ticks:
		out.append(_combat.speed_factor(t))
		_combat.tick_status(roster)
	return out


func _slowed_count(factors: Array[float]) -> int:
	var n: int = 0
	for f: float in factors:
		if f < 1.0:
			n += 1
	return n


# Criterion 1

func test_deliver_over_hp_applies_hp_and_kills() -> void:
	var t: Targetable = _t(1, 12.0)

	var applied: float = _hit(t, 30.0)

	assert_float(applied).is_equal(12.0)
	assert_float(_combat.hp_left(t)).is_equal(0.0)
	assert_bool(_combat.is_dead(t)).is_true()
	assert_float(_combat.dealt_by_id(&"tw")).is_equal(12.0)
	assert_int(_log.hits.size()).is_equal(1)
	assert_bool(_log.hits[0]["killed"]).is_true()


# Criterion 2

func test_deliver_exact_and_partial_and_zero() -> void:
	var a: Targetable = _t(1, 12.0)
	var b: Targetable = _t(2, 12.0)
	var c: Targetable = _t(3, 12.0)

	assert_float(_hit(a, 12.0)).is_equal(12.0)
	assert_bool(_combat.is_dead(a)).is_true()
	assert_float(_hit(b, 11.5)).is_equal(11.5)
	assert_float(_combat.hp_left(b)).is_equal(0.5)
	assert_bool(_combat.is_dead(b)).is_false()
	var logged: int = _log.hits.size()
	assert_float(_hit(c, 0.0)).is_equal(0.0)
	assert_int(_log.hits.size()).is_equal(logged)
	_combat.apply_slow(c, 0.5, 1.0)
	assert_float(_combat.speed_factor(c)).is_equal(0.5)


func test_deliver_bad_amount_reports_and_changes_nothing() -> void:
	var t: Targetable = _t(1, 12.0)
	for bad: float in [-5.0, NAN, INF, -INF]:
		var ev: DamageEvent = DamageEvent.make(t, bad, TOWER, &"tw")
		await assert_error(_combat.deliver.bind(ev)).is_push_error(Combat.ERR_BAD_AMOUNT)
	assert_float(_combat.hp_left(t)).is_equal(12.0)
	assert_int(_log.hits.size()).is_equal(0)
	assert_float(_combat.dealt_total()).is_equal(0.0)


# Criterion 3

func test_dead_target_is_silent_for_deliver_and_slow() -> void:
	var t: Targetable = _t(1, 4.0)
	_hit(t, 4.0)
	var logged: int = _log.hits.size()
	var ev: DamageEvent = DamageEvent.make(t, 5.0, TOWER, &"tw")

	await assert_error(_combat.deliver.bind(ev)).is_success()
	await assert_error(_combat.apply_slow.bind(t, 0.5, 1.0)).is_success()

	assert_int(_log.hits.size()).is_equal(logged)
	assert_float(_combat.dealt_total()).is_equal(4.0)
	assert_float(_combat.speed_factor(t)).is_equal(1.0)


# Criterion 4

func test_share_and_counters() -> void:
	var a: Targetable = _t(1, 1000.0)
	assert_float(_combat.hero_share()).is_equal(0.0)

	_hit(a, 700.0, TOWER, &"tower_x")
	_hit(a, 200.0, HERO, &"hero_a")
	_hit(a, 100.0, BURST, &"burst_a")

	assert_float(_combat.dealt_by_id(&"tower_x")).is_equal(700.0)
	assert_float(_combat.dealt_by_id(&"hero_a")).is_equal(200.0)
	assert_float(_combat.dealt_by_kind(TOWER)).is_equal(700.0)
	assert_float(_combat.dealt_by_kind(HERO)).is_equal(200.0)
	assert_float(_combat.dealt_by_kind(BURST)).is_equal(100.0)
	assert_float(_combat.dealt_total()).is_equal(1000.0)
	assert_float(_combat.hero_share()).is_equal(0.3)
	assert_float(_combat.dealt_by_id(&"unknown")).is_equal(0.0)


# Criterion 5

func test_all_in_radius_edge_is_inclusive() -> void:
	var on_edge: Targetable = _t(1, 10.0, 30.0, 40.0)
	var centre: Targetable = _t(2, 10.0, 0.0, 0.0)
	var outside: Targetable = _t(3, 10.0, 30.0, 40.5)
	var list: Array[Targetable] = [on_edge, centre, outside]

	var hit: Array[Targetable] = _combat.all_in_radius(list, 0.0, 0.0, 50.0)

	assert_int(hit.size()).is_equal(2)
	assert_int(hit[0].spawn_id).is_equal(1)
	assert_int(hit[1].spawn_id).is_equal(2)


# Criterion 6

func test_splash_hits_each_victim_once_in_spawn_order() -> void:
	var target: Targetable = _t(1, 50.0, 0.0, 0.0)
	var edge: Targetable = _t(2, 50.0, 30.0, 40.0)
	var outsider: Targetable = _t(3, 50.0, 100.0, 0.0)
	var corpse: Targetable = _t(4, 5.0, 1.0, 0.0)
	_hit(corpse, 5.0)
	var before: int = _log.hits.size()
	var list: Array[Targetable] = [target, edge, outsider, corpse]

	_do_splash(list, 10.0)

	assert_int(_log.hits.size()).is_equal(before + 2)
	assert_int(_log.hits[before]["spawn_id"]).is_equal(1)
	assert_int(_log.hits[before + 1]["spawn_id"]).is_equal(2)
	assert_float(_log.hits[before]["applied"]).is_equal(10.0)
	assert_float(_log.hits[before + 1]["applied"]).is_equal(10.0)


func test_splash_with_17_in_radius_makes_17_events() -> void:
	var list: Array[Targetable] = []
	for i: int in 17:
		list.append(_t(i + 1, 20.0, float(i), 0.0))

	_do_splash(list, 4.0)

	assert_int(_log.hits.size()).is_equal(17)


func _do_splash(list: Array[Targetable], amount: float) -> void:
	_combat.report_attack(TOWER, &"tw", Vector2.ZERO, Vector2.ZERO, 50.0)
	for v: Targetable in _combat.all_in_radius(list, 0.0, 0.0, 50.0):
		_combat.deliver(DamageEvent.make(v, amount, TOWER, &"tw"))


# Criterion 7

func test_slow_replace_equal_and_weaker_rules() -> void:
	var t: Targetable = _t(1, 10.0)
	_combat.apply_slow(t, 0.5, 1.0)
	_combat.apply_slow(t, 0.75, 0.25)
	assert_array(_factors(t, 2)).contains_exactly([0.25, 1.0])

	_combat.apply_slow(t, 0.5, 1.0)
	_combat.apply_slow(t, 0.5, 0.5)
	assert_array(_factors(t, 4)).contains_exactly([0.5, 0.5, 0.5, 0.5])

	_combat.apply_slow(t, 0.5, 1.0)
	_combat.apply_slow(t, 0.5, 2.0)
	assert_int(_slowed_count(_factors(t, 12))).is_equal(8)

	_combat.apply_slow(t, 0.5, 1.0)
	_combat.apply_slow(t, 0.25, 8.0)
	assert_int(_slowed_count(_factors(t, 12))).is_equal(4)


func test_slow_bad_values_report_and_keep_the_slot() -> void:
	var t: Targetable = _t(1, 10.0)
	_combat.apply_slow(t, 0.5, 1.0)
	for bad: float in [0.0, 1.0, 1.5, -0.5, NAN]:
		await assert_error(_combat.apply_slow.bind(t, bad, 1.0)).is_push_error(Combat.ERR_BAD_SLOW)
	for bad: float in [0.0, -1.0, NAN, INF, -INF]:
		await assert_error(_combat.apply_slow.bind(t, 0.5, bad)).is_push_error(Combat.ERR_BAD_SLOW)

	assert_array(_factors(t, 4)).contains_exactly([0.5, 0.5, 0.5, 0.5])


# Criterion 8

func test_speed_factor_values() -> void:
	var t: Targetable = _t(1, 10.0)
	assert_float(_combat.speed_factor(t)).is_equal(1.0)
	_combat.apply_slow(t, 0.25, 1.0)
	assert_float(_combat.speed_factor(t)).is_equal(0.75)

	var u: Targetable = _t(2, 10.0)
	_combat.apply_slow(u, 0.4, 1.0)
	assert_float(_combat.speed_factor(u)).is_equal_approx(0.6, 1e-12)

	var v: Targetable = _t(3, 10.0)
	_combat.apply_slow(v, 1.0 - 1.1102230246251565e-16, 1.0)
	assert_float(_combat.speed_factor(v)).is_greater(0.0)


# Criterion 9

func test_slow_duration_counts_whole_ticks() -> void:
	var t: Targetable = _t(1, 10.0)
	_combat.apply_slow(t, 0.5, 1.0)
	assert_int(_slowed_count(_factors(t, 8))).is_equal(4)

	var u: Targetable = _t(2, 10.0)
	_combat.apply_slow(u, 0.5, 0.625)
	assert_int(_slowed_count(_factors(u, 8))).is_equal(3)

	var fine_sim: SimTime = SimTime.new(60)
	var fine: Combat = CombatFixtures.make_combat(fine_sim)
	var w: Targetable = CombatFixtures.target(fine, 9, 10.0)
	fine.apply_slow(w, 0.5, 0.5)
	var roster: Array[Targetable] = [w]
	var reads: int = 0
	for _i: int in 40:
		if fine.speed_factor(w) < 1.0:
			reads += 1
		fine.tick_status(roster)
	assert_int(reads).is_equal(30)

	var x: Targetable = _t(3, 10.0)
	_combat.apply_slow(x, 0.5, 1.0 / 60.0)
	assert_array(_factors(x, 3)).contains_exactly([0.5, 1.0, 1.0])


func test_slow_applied_after_tick_status_reads_four_ticks() -> void:
	var t: Targetable = _t(1, 10.0)
	var roster: Array[Targetable] = [t]
	var reads: Array[float] = []
	for tick: int in 7:
		reads.append(_combat.speed_factor(t))
		_combat.tick_status(roster)
		if tick == 0:
			_combat.apply_slow(t, 0.5, 1.0)

	assert_array(reads).contains_exactly([1.0, 0.5, 0.5, 0.5, 0.5, 1.0, 1.0])


func test_equal_slow_reapplied_each_tick_extends_the_slow() -> void:
	var t: Targetable = _t(1, 10.0)
	var roster: Array[Targetable] = [t]
	var reads: Array[float] = []
	for tick: int in 17:
		reads.append(_combat.speed_factor(t))
		_combat.tick_status(roster)
		if tick <= 10:
			_combat.apply_slow(t, 0.5, 1.0)

	assert_float(reads[0]).is_equal(1.0)
	for i: int in range(1, 15):
		assert_float(reads[i]).is_equal(0.5)
	assert_float(reads[15]).is_equal(1.0)


# Criterion 10

func test_first_in_ranks_by_distance_in_any_order() -> void:
	var a: Targetable = _t(1, 10.0, 10.0, 0.0, 50.0)
	var b: Targetable = _t(2, 10.0, 20.0, 0.0, 80.0)
	var c: Targetable = _t(3, 10.0, 200.0, 0.0, 200.0)
	var orders: Array[Array] = [[a, b, c], [c, b, a], [b, a, c], [a, c, b]]

	for o: Array in orders:
		var list: Array[Targetable] = []
		list.assign(o)
		assert_int(_combat.first_in(list, 0.0, 0.0, 100.0).spawn_id).is_equal(2)
	_hit(b, 10.0)
	var rest: Array[Targetable] = [b, a, c]
	assert_int(_combat.first_in(rest, 0.0, 0.0, 100.0).spawn_id).is_equal(1)
	_hit(a, 10.0)
	_hit(c, 10.0)
	assert_object(_combat.first_in(rest, 0.0, 0.0, 100.0)).is_null()
	var empty: Array[Targetable] = []
	assert_object(_combat.first_in(empty, 0.0, 0.0, 100.0)).is_null()


func test_first_in_tie_goes_to_lowest_spawn_id() -> void:
	var three: Targetable = _t(3, 10.0, 30.0, 0.0, 60.0)
	var one: Targetable = _t(1, 10.0, 0.0, 30.0, 60.0)
	var forward: Array[Targetable] = [three, one]
	var backward: Array[Targetable] = [one, three]

	assert_int(_combat.first_in(forward, 0.0, 0.0, 100.0).spawn_id).is_equal(1)
	assert_int(_combat.first_in(backward, 0.0, 0.0, 100.0).spawn_id).is_equal(1)


func test_nearest_in_tie_and_dead_skip() -> void:
	var five: Targetable = _t(5, 10.0, 10.0, 0.0)
	var two: Targetable = _t(2, 10.0, -10.0, 0.0)
	var list: Array[Targetable] = [five, two]
	assert_int(_combat.nearest_in(list, 0.0, 0.0, 100.0).spawn_id).is_equal(2)

	_hit(two, 10.0)

	assert_int(_combat.nearest_in(list, 0.0, 0.0, 100.0).spawn_id).is_equal(5)


func test_all_in_radius_keeps_input_order_and_empty_result() -> void:
	var three: Targetable = _t(3, 10.0, 1.0, 0.0)
	var one: Targetable = _t(1, 10.0, 2.0, 0.0)
	var two: Targetable = _t(2, 10.0, 500.0, 0.0)
	var list: Array[Targetable] = [three, one, two]

	var hit: Array[Targetable] = _combat.all_in_radius(list, 0.0, 0.0, 10.0)
	var none: Array[Targetable] = _combat.all_in_radius(list, -900.0, 0.0, 10.0)

	assert_int(hit.size()).is_equal(2)
	assert_int(hit[0].spawn_id).is_equal(3)
	assert_int(hit[1].spawn_id).is_equal(1)
	assert_int(none.size()).is_equal(0)


func test_helpers_leave_the_input_list_unchanged() -> void:
	var a: Targetable = _t(4, 10.0, 5.0, 0.0, 5.0)
	var b: Targetable = _t(2, 10.0, 6.0, 0.0, 6.0)
	var c: Targetable = _t(3, 10.0, 7.0, 0.0, 7.0)
	var list: Array[Targetable] = [a, b, c]

	_combat.first_in(list, 0.0, 0.0, 100.0)
	_combat.nearest_in(list, 0.0, 0.0, 100.0)
	_combat.all_in_radius(list, 0.0, 0.0, 100.0)

	assert_int(list.size()).is_equal(3)
	assert_bool(list[0] == a and list[1] == b and list[2] == c).is_true()


func test_helpers_skip_removed_targets() -> void:
	var a: Targetable = _t(1, 10.0, 1.0, 0.0, 99.0)
	var b: Targetable = _t(2, 10.0, 2.0, 0.0, 10.0)
	a.removed = true
	var list: Array[Targetable] = [a, b]

	assert_int(_combat.first_in(list, 0.0, 0.0, 100.0).spawn_id).is_equal(2)
	assert_int(_combat.nearest_in(list, 0.0, 0.0, 100.0).spawn_id).is_equal(2)
	assert_int(_combat.all_in_radius(list, 0.0, 0.0, 100.0).size()).is_equal(1)


# Criterion 11

func test_nearest_in_leash_edge_is_inclusive() -> void:
	var edge: Targetable = _t(1, 10.0, 90.0, 0.0)
	var past: Targetable = _t(2, 10.0, 90.5, 0.0)
	var in_list: Array[Targetable] = [edge]
	var out_list: Array[Targetable] = [past]
	assert_object(_combat.nearest_in(in_list, 0.0, 0.0, 90.0)).is_same(edge)
	assert_object(_combat.nearest_in(out_list, 0.0, 0.0, 90.0)).is_null()

	var far: Targetable = _t(3, 10.0, 40.0, 0.0)
	var near: Targetable = _t(4, 10.0, 30.0, 0.0)
	var two: Array[Targetable] = [far, near]
	assert_int(_combat.nearest_in(two, 0.0, 0.0, 90.0).spawn_id).is_equal(4)


# Criterion 12

func test_listener_does_not_change_results() -> void:
	var quiet_combat: Combat = CombatFixtures.make_combat(_sim)
	var a: Targetable = CombatFixtures.target(quiet_combat, 1, 12.0)
	var b: Targetable = _t(1, 12.0)

	var ra: float = quiet_combat.deliver(DamageEvent.make(a, 5.0, TOWER, &"tw"))
	var rb: float = _hit(b, 5.0)

	assert_float(ra).is_equal(rb)
	assert_float(quiet_combat.dealt_total()).is_equal(_combat.dealt_total())
	assert_float(a.health.hp).is_equal(b.health.hp)


func test_zero_damage_attack_fires_attack_only_and_kill_flag() -> void:
	var t: Targetable = _t(7, 4.0, 3.0, 4.0)
	_combat.report_attack(HERO, &"hero_a", Vector2(1.0, 2.0), Vector2(3.0, 4.0), 0.0)
	_hit(t, 0.0, HERO, &"hero_a")
	assert_int(_log.attacks.size()).is_equal(1)
	assert_float(_log.attacks[0]["radius"]).is_equal(0.0)
	assert_int(_log.attacks[0]["kind"]).is_equal(int(HERO))
	assert_int(_log.hits.size()).is_equal(0)

	_hit(t, 1.0)
	assert_bool(_log.hits[0]["killed"]).is_false()
	_hit(t, 3.0)
	assert_bool(_log.hits[1]["killed"]).is_true()
	assert_int(_log.hits[1]["spawn_id"]).is_equal(7)
	assert_vector(_log.hits[1]["position"]).is_equal(Vector2(3.0, 4.0))
	assert_int(_log.hits[1]["kind"]).is_equal(int(TOWER))
	assert_str(String(_log.hits[1]["id"])).is_equal("tw")


class StateReader extends RefCounted:
	var combat: Combat
	var target: Targetable
	var hp_seen: float = -1.0
	var dead_seen: bool = false
	var total_seen: float = -1.0

	func on_hit(_kind: Combat.SourceKind, _id: StringName, _applied: float, _position: Vector2, _killed: bool, _spawn_id: int) -> void:
		hp_seen = combat.hp_left(target)
		dead_seen = combat.is_dead(target)
		total_seen = combat.dealt_total()


func test_listener_sees_the_committed_hit() -> void:
	var t: Targetable = _t(1, 12.0)
	var reader: StateReader = StateReader.new()
	reader.combat = _combat
	reader.target = t
	_combat.damage_applied.connect(reader.on_hit)

	_hit(t, 12.0)

	assert_float(reader.hp_seen).is_equal(0.0)
	assert_bool(reader.dead_seen).is_true()
	assert_float(reader.total_seen).is_equal(12.0)
	_combat.damage_applied.disconnect(reader.on_hit)


# Criterion 13

func test_removed_target_reports_for_deliver_and_slow() -> void:
	var live: Targetable = _t(1, 12.0)
	var dead: Targetable = _t(2, 3.0)
	_hit(dead, 3.0)
	live.removed = true
	dead.removed = true
	var logged: int = _log.hits.size()
	var total: float = _combat.dealt_total()

	for t: Targetable in [live, dead]:
		for amount: float in [10.0, -5.0]:
			var ev: DamageEvent = DamageEvent.make(t, amount, TOWER, &"tw")
			await assert_error(_combat.deliver.bind(ev)).is_push_error(Combat.ERR_REMOVED)
		await assert_error(_combat.apply_slow.bind(t, 0.5, 1.0)).is_push_error(Combat.ERR_REMOVED)

	assert_int(_log.hits.size()).is_equal(logged)
	assert_float(_combat.dealt_total()).is_equal(total)
	assert_float(_combat.speed_factor(live)).is_equal(1.0)


# Criterion 14

func test_burst_over_nothing_fires_attack_only() -> void:
	var far: Targetable = _t(1, 10.0, 500.0, 500.0)
	var list: Array[Targetable] = [far]

	_combat.report_attack(BURST, &"burst_a", Vector2.ZERO, Vector2.ZERO, 70.0)
	var hit: Array[Targetable] = _combat.all_in_radius(list, 0.0, 0.0, 70.0)

	assert_int(hit.size()).is_equal(0)
	assert_int(_log.attacks.size()).is_equal(1)
	assert_int(_log.hits.size()).is_equal(0)
	assert_float(_combat.dealt_total()).is_equal(0.0)


# Criterion 15 and 16

func test_counters_survive_removal() -> void:
	var t: Targetable = _t(1, 12.0)
	_hit(t, 12.0)
	t.removed = true

	assert_float(_combat.dealt_total()).is_equal(12.0)
	assert_float(_combat.dealt_by_id(&"tw")).is_equal(12.0)


func test_tower_kind_event_counts_under_the_tower_only() -> void:
	var t: Targetable = _t(1, 50.0)
	_hit(t, 8.0, TOWER, &"tower_buffed")

	assert_float(_combat.dealt_by_id(&"tower_buffed")).is_equal(8.0)
	assert_float(_combat.dealt_by_kind(HERO)).is_equal(0.0)
	assert_float(_combat.dealt_by_kind(BURST)).is_equal(0.0)


# Criterion 17 and 18

func test_hp_left_and_is_dead_queries() -> void:
	var t: Targetable = _t(1, 12.0)
	assert_float(_combat.hp_left(t)).is_equal(12.0)
	assert_bool(_combat.is_dead(t)).is_false()
	assert_int(_log.hits.size()).is_equal(0)

	_hit(t, 12.0)
	t.removed = true

	assert_float(_combat.hp_left(t)).is_equal(0.0)
	assert_bool(_combat.is_dead(t)).is_true()


func test_leaked_target_with_hp_is_not_dead() -> void:
	var t: Targetable = _t(1, 12.0)
	t.removed = true

	assert_bool(_combat.is_dead(t)).is_false()


# ADR-0009 Validation 6: attach

func test_attach_rejects_bad_max_hp_and_writes_nothing() -> void:
	var t: Targetable = Targetable.new(1)
	for bad: float in [0.0, -1.0, NAN, INF]:
		await assert_error(_combat.attach.bind(t, bad)).is_push_error(Combat.ERR_BAD_MAX_HP)

	assert_object(t.health).is_null()
	assert_object(t.status).is_null()


func test_second_attach_reports_already_attached() -> void:
	var t: Targetable = _t(1, 10.0)

	await assert_error(_combat.attach.bind(t, 20.0)).is_push_error(Combat.ERR_ALREADY_ATTACHED)

	assert_float(t.health.hp).is_equal(10.0)
	assert_float(t.health.max_hp).is_equal(10.0)


func test_attach_seeds_health_and_empty_status() -> void:
	var t: Targetable = Targetable.new(1)

	var ok: bool = _combat.attach(t, 7.5)

	assert_bool(ok).is_true()
	assert_float(t.health.hp).is_equal(7.5)
	assert_float(t.health.max_hp).is_equal(7.5)
	assert_float(t.status.strength).is_equal(0.0)
	assert_int(t.status.ticks_left).is_equal(0)


func test_view_position_is_the_scalar_pair() -> void:
	var t: Targetable = _t(1, 5.0, 3.5, -2.0)

	assert_vector(t.view_position()).is_equal(Vector2(3.5, -2.0))


func test_invalid_to_ticks_reports() -> void:
	await assert_error(_make_bad_combat).is_push_error(Combat.ERR_BAD_TO_TICKS)


func _make_bad_combat() -> void:
	var _unused: Combat = Combat.new(Callable())


# Invariant I tamper tests

func test_invariant_fails_when_hp_is_tampered() -> void:
	var t: Targetable = _t(1, 12.0)
	_hit(t, 4.0)
	t.health.hp += 1.0

	assert_bool(CombatFixtures.invariant_holds(_combat, _log, _all)).is_false()
	t.health.hp -= 1.0


func test_invariant_fails_when_the_log_is_tampered() -> void:
	var t: Targetable = _t(1, 12.0)
	_hit(t, 4.0)
	_log.hits.append({"applied": 1.0})

	assert_bool(CombatFixtures.invariant_holds(_combat, _log, _all)).is_false()
	_log.hits.pop_back()


func test_invariant_fails_when_hp_is_lost_without_a_counter() -> void:
	var t: Targetable = _t(1, 12.0)
	_hit(t, 4.0)
	var phantom: Targetable = CombatFixtures.target(_combat, 9, 8.0)
	phantom.health.hp = 7.0

	assert_bool(CombatFixtures.invariant_holds(_combat, _log, _all)).is_true()
	_all.append(phantom)
	assert_bool(CombatFixtures.invariant_holds(_combat, _log, _all)).is_false()
	_all.pop_back()


# ADR-0009 Decision 5: max_hp_of

func test_max_hp_of_is_the_attached_value_and_survives_damage_and_removal() -> void:
	var t: Targetable = _t(1, 12.0)

	_hit(t, 5.0)
	assert_float(_combat.max_hp_of(t)).is_equal(12.0)
	assert_float(_combat.hp_left(t)).is_equal(7.0)
	t.removed = true
	assert_float(_combat.max_hp_of(t)).is_equal(12.0)
