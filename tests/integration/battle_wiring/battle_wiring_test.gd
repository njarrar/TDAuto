extends GdUnitTestSuite
## ADR-0006 Decision 8: the headless listener-count test and its self-proof.

const TestBattles := preload("res://tests/helpers/test_battles.gd")
const WiringCheck := preload("res://tests/helpers/wiring_check.gd")
const Contract := preload("res://tests/integration/battle_wiring/battle_signal_contract.gd")


## A stray listener.
class Tap extends RefCounted:
	func on_killed(_bounty: int) -> void:
		pass


func test_built_battle_matches_the_wiring_contract() -> void:
	var battle: Battle = TestBattles.build()

	assert_array(WiringCheck.check(battle)).is_empty()


func test_self_proof_a_disconnected_w2_is_reported_by_name() -> void:
	var battle: Battle = TestBattles.build()
	battle.enemy_wave.enemy_killed.disconnect(battle.tower_sim.on_enemy_killed)

	var problems: PackedStringArray = WiringCheck.check(battle)

	assert_array(problems).is_equal(PackedStringArray(["enemy_wave.enemy_killed: missing tower_sim.on_enemy_killed"]))


func test_an_extra_connection_is_reported() -> void:
	var battle: Battle = TestBattles.build()
	var tap: Tap = Tap.new()
	battle.enemy_wave.enemy_killed.connect(tap.on_killed)

	var problems: PackedStringArray = WiringCheck.check(battle)

	assert_array(problems).is_equal(PackedStringArray(["enemy_wave.enemy_killed: extra foreign.on_killed|0"]))


func test_non_emitters_declare_no_signal() -> void:
	assert_array(WiringCheck.check_non_emitters()).is_empty()


func test_contract_has_five_wiring_and_seventeen_view_keys() -> void:
	assert_int(Contract.WIRING.size()).is_equal(5)
	assert_int(Contract.VIEW_ALLOWLIST.size()).is_equal(17)


func test_every_wiring_connection_has_flags_zero() -> void:
	var battle: Battle = TestBattles.build()

	for sig_info: Dictionary in battle.enemy_wave.get_signal_connection_list("enemy_leaked"):
		assert_int(int(sig_info["flags"])).is_equal(0)
