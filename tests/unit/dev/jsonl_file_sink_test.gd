extends GdUnitTestSuite
## ADR-0010 Decision 10 / ADR-0008 V8: append mode, one handle, flush per line.
## Uses a temp user:// file this test deletes. The one place the brief allows file I/O.

const PATH: String = "user://test_jsonl_sink.jsonl"


func before_test() -> void:
	_remove()


func after_test() -> void:
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _read_lines() -> PackedStringArray:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	return text.strip_edges().split("\n")


func test_open_creates_the_file_and_writes_lines() -> void:
	var sink: JsonlFileSink = JsonlFileSink.open(PATH)
	assert_object(sink).is_not_null()

	assert_bool(sink.write_line("{\"a\":1}")).is_true()
	assert_bool(sink.write_line("{\"a\":2}")).is_true()

	# flush per line: readable before close
	assert_array(_read_lines()).is_equal(PackedStringArray(["{\"a\":1}", "{\"a\":2}"]))
	sink.close()


func test_reopen_appends_instead_of_truncating() -> void:
	var first: JsonlFileSink = JsonlFileSink.open(PATH)
	first.write_line("one")
	first.close()

	var second: JsonlFileSink = JsonlFileSink.open(PATH)
	second.write_line("two")
	second.close()

	assert_array(_read_lines()).is_equal(PackedStringArray(["one", "two"]))


func test_write_after_close_returns_false_and_close_twice_is_safe() -> void:
	var sink: JsonlFileSink = JsonlFileSink.open(PATH)
	sink.close()
	sink.close()

	assert_bool(sink.is_open()).is_false()
	assert_bool(sink.write_line("late")).is_false()
