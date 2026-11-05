extends GdUnitTestSuite
## Tests of the small harness helpers: Fakes, battle_probe.alive and error_capture.

const BattleProbe := preload("res://tests/helpers/battle_probe.gd")
const ErrorCapture := preload("res://tests/helpers/error_capture.gd")
const Fakes := preload("res://tests/helpers/fakes.gd")


func test_fatal_fake_records_causes_and_sets_halted() -> void:
	var halted: Fakes.Halted = Fakes.Halted.new()
	var fatal: Fakes.Fatal = Fakes.Fatal.new()
	fatal.halted_fake = halted

	fatal.fatal("cause one")

	assert_array(Array(fatal.causes())).contains_exactly(["cause one"])
	assert_bool(halted.halted()).is_true()


func test_dev_errors_fake_records_messages_in_order() -> void:
	var sink: Fakes.DevErrors = Fakes.DevErrors.new()

	sink.report("a")
	sink.report("b")

	assert_array(Array(sink.messages())).contains_exactly(["a", "b"])


func test_canceller_fake_counts_calls() -> void:
	var canceller: Fakes.Canceller = Fakes.Canceller.new()

	canceller.cancel()
	canceller.cancel()

	assert_int(canceller.count()).is_equal(2)


func test_in_build_fake_defaults_to_true() -> void:
	var in_build: Fakes.InBuild = Fakes.InBuild.new()

	assert_bool(in_build.in_build()).is_true()


func test_alive_names_a_ref_that_still_resolves() -> void:
	var held: RefCounted = RefCounted.new()
	var refs: Array[WeakRef] = [weakref(held)]

	var names: PackedStringArray = BattleProbe.alive(refs)

	assert_array(Array(names)).contains_exactly(["ref 0"])


func test_alive_is_empty_after_the_object_is_released() -> void:
	var held: RefCounted = RefCounted.new()
	var refs: Array[WeakRef] = [weakref(held)]
	held = null

	var names: PackedStringArray = BattleProbe.alive(refs)

	assert_array(Array(names)).is_empty()


func test_pusher_error_is_asserted_by_message() -> void:
	var pusher: ErrorCapture.Pusher = ErrorCapture.Pusher.new("expected failure")

	await assert_error(pusher.push_error_once).is_push_error("expected failure")
