extends GdUnitTestSuite
## Tests of the recording fake itself (ADR-0007 Validation 6).

const RecordingFake := preload("res://tests/helpers/recording_fake.gd")
const FakeEmitter := preload("res://tests/unit/harness/helpers/fake_emitter.gd")

var _fake: RefCounted = null
var _emitter: RefCounted = null


func before_test() -> void:
	_fake = RecordingFake.new()
	_emitter = FakeEmitter.new()


func after_test() -> void:
	_fake.stop()
	_fake = null
	_emitter = null


func test_two_signals_record_one_ordered_log() -> void:
	_fake.watch_all(_emitter)
	_emitter.emit_moved(&"a", 1)
	_emitter.emit_ticked()
	_emitter.emit_moved(&"b", 2)

	var problems: PackedStringArray = _fake.expect([
		["moved", [&"a", 1]],
		["ticked", []],
		["moved", [&"b", 2]],
	])

	assert_array(Array(problems)).is_empty()


func test_zero_one_and_six_arguments_are_recorded() -> void:
	_fake.watch_all(_emitter)
	_emitter.emit_ticked()
	_emitter.emit_moved(&"a", 1)
	_emitter.emit_many()

	var entries: Array[Dictionary] = _fake.entries()

	assert_int(entries.size()).is_equal(3)
	assert_int((entries[0]["args"] as Array).size()).is_equal(0)
	assert_int((entries[1]["args"] as Array).size()).is_equal(2)
	assert_int((entries[2]["args"] as Array).size()).is_equal(6)
	assert_array(Array(_fake.type_errors())).is_empty()


func test_string_into_stringname_parameter_is_a_type_error() -> void:
	_fake.watch_all(_emitter)
	_emitter.emit_moved_with_string()

	var problems: PackedStringArray = _fake.expect([["moved", [&"a", 1]]])

	assert_int(_fake.type_errors().size()).is_equal(1)
	assert_bool(problems.size() >= 2).is_true()


func test_missing_argument_is_reported() -> void:
	_fake.watch_all(_emitter)
	_emitter.emit_moved_short()

	var problems: PackedStringArray = _fake.expect([["moved", [&"a"]]])

	assert_int(_fake.type_errors().size()).is_equal(1)
	assert_bool(problems.size() >= 1).is_true()


func test_extra_entry_is_reported_as_unlisted() -> void:
	_fake.watch_all(_emitter)
	_emitter.emit_ticked()
	_emitter.emit_ticked()

	var problems: PackedStringArray = _fake.expect([["ticked", []]])

	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("unlisted")


func test_missing_entry_is_reported() -> void:
	_fake.watch_all(_emitter)
	_emitter.emit_ticked()

	var problems: PackedStringArray = _fake.expect([["ticked", []], ["ticked", []]])

	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("missing")


func test_wrong_order_is_reported() -> void:
	_fake.watch_all(_emitter)
	_emitter.emit_ticked()
	_emitter.emit_moved(&"a", 1)

	var problems: PackedStringArray = _fake.expect([["moved", [&"a", 1]], ["ticked", []]])

	assert_int(problems.size()).is_equal(2)


func test_any_matches_any_value_of_the_declared_type() -> void:
	_fake.watch_all(_emitter)
	_emitter.emit_moved(&"zzz", 99)

	var problems: PackedStringArray = _fake.expect([["moved", [_fake.ANY, _fake.ANY]]])

	assert_array(Array(problems)).is_empty()


func test_any_does_not_hide_a_wrong_declared_type() -> void:
	_fake.watch_all(_emitter)
	_emitter.emit_moved_with_string()

	var problems: PackedStringArray = _fake.expect([["moved", [_fake.ANY, _fake.ANY]]])

	assert_bool(problems.is_empty()).is_false()


func test_untyped_and_object_parameters_are_errors() -> void:
	_fake.watch_all(_emitter)
	_emitter.emit_untyped()
	_emitter.emit_object()

	assert_int(_fake.type_errors().size()).is_equal(2)


func test_stop_disconnects_every_listener() -> void:
	_fake.watch_all(_emitter)
	_fake.stop()
	_emitter.emit_ticked()

	assert_int(_fake.entries().size()).is_equal(0)


func test_clear_forgets_log_and_errors() -> void:
	_fake.watch_all(_emitter)
	_emitter.emit_moved_with_string()
	_fake.clear()

	assert_int(_fake.entries().size()).is_equal(0)
	assert_int(_fake.type_errors().size()).is_equal(0)
