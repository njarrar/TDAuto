extends GdUnitTestSuite
## RunLog writes the per-source damage list from the snapshot (ADR-0010 Decision 11).

class Sink extends RefCounted:
	var lines: Array[String] = []

	func write_line(line: String) -> bool:
		lines.append(line)
		return true


func test_attempt_record_carries_dealt_by_source() -> void:
	var sink: Sink = Sink.new()
	var log: RunLog = auto_free(RunLog.new())
	log.attach(null, null, null, &"stage_a", Callable(), sink.write_line, 1, "hash", Callable())
	var snapshot: ResultSnapshot = ResultSnapshot.new()
	snapshot.dealt_by_source = {&"tower_single": 3.0, &"hero_1": 1.5}

	log.on_snapshot_taken(snapshot)

	assert_int(sink.lines.size()).is_equal(1)
	var parsed: Dictionary = JSON.parse_string(sink.lines[0])
	var dealt: Dictionary = parsed["dealt_by_source"]
	assert_float(float(dealt["tower_single"])).is_equal(3.0)
	assert_float(float(dealt["hero_1"])).is_equal(1.5)
