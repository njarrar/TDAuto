extends GdUnitTestSuite
## DevErrorSink (ADR-0001 Decision 4): push_error plus an in-memory record.

const MSG_A: String = "dev error a"
const MSG_B: String = "dev error b"


func test_new_sink_has_no_messages() -> void:
	var sink: DevErrorSink = DevErrorSink.new()

	assert_int(sink.count()).is_equal(0)
	assert_int(sink.messages().size()).is_equal(0)


func test_report_calls_push_error_and_records_message() -> void:
	var sink: DevErrorSink = DevErrorSink.new()

	await assert_error(sink.report.bind(MSG_A)).is_push_error(MSG_A)

	assert_int(sink.count()).is_equal(1)
	assert_str(sink.messages()[0]).is_equal(MSG_A)


func test_two_reports_are_recorded_in_order() -> void:
	var sink: DevErrorSink = DevErrorSink.new()

	await assert_error(sink.report.bind(MSG_A)).is_push_error(MSG_A)
	await assert_error(sink.report.bind(MSG_B)).is_push_error(MSG_B)

	assert_int(sink.count()).is_equal(2)
	assert_str(sink.messages()[0]).is_equal(MSG_A)
	assert_str(sink.messages()[1]).is_equal(MSG_B)
