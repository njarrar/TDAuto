extends GdUnitTestSuite
## ChipWindow (Tower Rule 8, ADR-0010 Decision 8).


func test_commit_window_bounds() -> void:
	var w: ChipWindow = ChipWindow.new()
	w.open(2)
	w.advance(199.0)
	assert_bool(w.can_commit()).is_false()
	w.advance(1.0)
	assert_bool(w.can_commit()).is_true()
	w.advance(1299.0)
	assert_bool(w.can_commit()).is_true()
	assert_int(w.slot()).is_equal(2)


func test_stays_open_with_no_time_limit() -> void:
	# Since first playable the panel has no expiry; only a close or a press elsewhere ends it.
	var w: ChipWindow = ChipWindow.new()
	w.open(0)
	w.advance(60000.0)
	assert_bool(w.is_open()).is_true()
	assert_bool(w.can_commit()).is_true()
	w.close()
	assert_bool(w.is_open()).is_false()
	assert_bool(w.can_commit()).is_false()


func test_ignores_bad_ms() -> void:
	var w: ChipWindow = ChipWindow.new()
	w.open(0)
	w.advance(NAN)
	w.advance(-5.0)
	w.advance(INF)
	assert_float(w.elapsed_ms()).is_equal(0.0)
	assert_bool(w.is_open()).is_true()


func test_reopen_restarts_clock() -> void:
	var w: ChipWindow = ChipWindow.new()
	w.open(0)
	w.advance(500.0)
	w.open(1)
	assert_float(w.elapsed_ms()).is_equal(0.0)
	assert_int(w.slot()).is_equal(1)
