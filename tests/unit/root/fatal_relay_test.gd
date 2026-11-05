extends GdUnitTestSuite
## ADR-0001 Validation 5 and 6 (relay and latch part), Decision 3 step order.
## Battle and Flow are not built here: a fake Flow hook is injected.

const CAUSE_A: String = "cause a"
const CAUSE_B: String = "cause b"


## Records the app handler call and what the latch read at that moment.
class FakeApp extends RefCounted:
	var causes: PackedStringArray = PackedStringArray()
	var latch: FatalLatch = null
	var latch_fatal_at_call: bool = false
	var order: Array[String] = []

	func on_fatal(cause: String) -> void:
		causes.append(cause)
		order.append("app")
		if latch != null:
			latch_fatal_at_call = latch.is_fatal()


## Fake Flow hook. Optionally re-enters the relay, like a phase_changed listener.
class FakeFlow extends RefCounted:
	var calls: int = 0
	var order: Array[String] = []
	var latch_fatal_at_call: bool = false
	var latch: FatalLatch = null
	var relay: FatalRelay = null
	var reenter_cause: String = ""

	func enter_fatal() -> void:
		calls += 1
		order.append("flow")
		if latch != null:
			latch_fatal_at_call = latch.is_fatal()
		if relay != null and reenter_cause != "":
			relay.fatal(reenter_cause)


func test_fatal_sets_latch_calls_handler_and_hook_once() -> void:
	# Arrange
	var latch: FatalLatch = FatalLatch.new()
	var app: FakeApp = FakeApp.new()
	var flow: FakeFlow = FakeFlow.new()
	var relay: FatalRelay = FatalRelay.new(latch, app.on_fatal)
	relay.set_flow_hook(flow.enter_fatal)

	# Act
	await assert_error(relay.fatal.bind(CAUSE_A)).is_push_error(CAUSE_A)

	# Assert
	assert_bool(latch.is_fatal()).is_true()
	assert_str(latch.cause()).is_equal(CAUSE_A)
	assert_int(app.causes.size()).is_equal(1)
	assert_str(app.causes[0]).is_equal(CAUSE_A)
	assert_int(flow.calls).is_equal(1)


func test_fatal_twice_keeps_first_cause_in_both_latches() -> void:
	# ADR-0001 Validation 5.
	var battle_latch: FatalLatch = FatalLatch.new()
	var app_latch: FatalLatch = FatalLatch.new()
	var flow: FakeFlow = FakeFlow.new()
	var relay: FatalRelay = FatalRelay.new(battle_latch, app_latch.fatal)
	relay.set_flow_hook(flow.enter_fatal)

	await assert_error(relay.fatal.bind(CAUSE_A)).is_push_error(CAUSE_A)
	relay.fatal(CAUSE_B)

	assert_str(battle_latch.cause()).is_equal(CAUSE_A)
	assert_str(app_latch.cause()).is_equal(CAUSE_A)
	assert_int(flow.calls).is_equal(1)


func test_second_fatal_does_not_push_error_or_call_handlers_again() -> void:
	var latch: FatalLatch = FatalLatch.new()
	var app: FakeApp = FakeApp.new()
	var flow: FakeFlow = FakeFlow.new()
	var relay: FatalRelay = FatalRelay.new(latch, app.on_fatal)
	relay.set_flow_hook(flow.enter_fatal)
	await assert_error(relay.fatal.bind(CAUSE_A)).is_push_error(CAUSE_A)

	# A second push_error here would fail the test (unasserted error).
	relay.fatal(CAUSE_B)

	assert_int(app.causes.size()).is_equal(1)
	assert_int(flow.calls).is_equal(1)


func test_latch_is_set_before_handler_and_hook_run() -> void:
	var latch: FatalLatch = FatalLatch.new()
	var app: FakeApp = FakeApp.new()
	var flow: FakeFlow = FakeFlow.new()
	app.latch = latch
	flow.latch = latch
	var relay: FatalRelay = FatalRelay.new(latch, app.on_fatal)
	relay.set_flow_hook(flow.enter_fatal)

	await assert_error(relay.fatal.bind(CAUSE_A)).is_push_error(CAUSE_A)

	assert_bool(app.latch_fatal_at_call).is_true()
	assert_bool(flow.latch_fatal_at_call).is_true()


func test_handler_runs_before_flow_hook() -> void:
	var latch: FatalLatch = FatalLatch.new()
	var order: Array[String] = []
	var app: FakeApp = FakeApp.new()
	var flow: FakeFlow = FakeFlow.new()
	var relay: FatalRelay = FatalRelay.new(latch, app.on_fatal)
	relay.set_flow_hook(flow.enter_fatal)

	await assert_error(relay.fatal.bind(CAUSE_A)).is_push_error(CAUSE_A)
	order.append_array(app.order)
	order.append_array(flow.order)

	assert_array(order).is_equal(["app", "flow"])


func test_reentry_from_flow_hook_is_ignored_and_first_cause_kept() -> void:
	var latch: FatalLatch = FatalLatch.new()
	var app: FakeApp = FakeApp.new()
	var flow: FakeFlow = FakeFlow.new()
	var relay: FatalRelay = FatalRelay.new(latch, app.on_fatal)
	flow.relay = relay
	flow.reenter_cause = CAUSE_B
	relay.set_flow_hook(flow.enter_fatal)

	await assert_error(relay.fatal.bind(CAUSE_A)).is_push_error(CAUSE_A)

	assert_str(latch.cause()).is_equal(CAUSE_A)
	assert_int(flow.calls).is_equal(1)
	assert_int(app.causes.size()).is_equal(1)


func test_no_handler_and_no_hook_still_sets_latch() -> void:
	var latch: FatalLatch = FatalLatch.new()
	var relay: FatalRelay = FatalRelay.new(latch)

	await assert_error(relay.fatal.bind(CAUSE_A)).is_push_error(CAUSE_A)

	assert_bool(latch.is_fatal()).is_true()
	assert_str(latch.cause()).is_equal(CAUSE_A)

