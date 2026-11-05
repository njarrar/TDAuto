extends GdUnitTestSuite
## ADR-0004 Validation 1 (clock, headless). Numbers match
## prototypes/adr-checks/check_numerics.gd.

const RATE: int = 60
const DT: float = 1.0 / 60.0
const JITTER: float = 0.0001
const JITTER_FRAMES: int = 600
const LONG_RUN_FRAMES: int = 1800


func test_one_frame_at_60hz_gives_one_tick() -> void:
	var c: BattleClock = BattleClock.new(RATE)

	assert_int(c.advance(DT)).is_equal(1)


func test_one_frame_at_30hz_gives_two_ticks() -> void:
	var c: BattleClock = BattleClock.new(RATE)

	assert_int(c.advance(1.0 / 30.0)).is_equal(2)


func test_long_frame_clamps_to_three_ticks_and_leaves_one_and_a_half_ticks_carry() -> void:
	var c: BattleClock = BattleClock.new(RATE)

	var ran: int = c.advance(0.2)

	assert_int(ran).is_equal(3)
	assert_float(c.accumulated()).is_equal(1.5 * DT)


func test_stall_runs_no_ticks_and_resets_to_half_a_tick() -> void:
	var c: BattleClock = BattleClock.new(RATE)
	c.advance(0.1)

	var ran: int = c.advance(0.6)

	assert_int(ran).is_equal(0)
	assert_float(c.accumulated()).is_equal(0.5 * DT)


func test_delta_exactly_at_stall_limit_is_not_a_stall() -> void:
	var c: BattleClock = BattleClock.new(RATE)

	var ran: int = c.advance(BattleClock.STALL_SECONDS)

	assert_int(ran).is_equal(BattleClock.MAX_TICKS_PER_FRAME)


func test_bad_delta_runs_no_ticks_and_changes_nothing() -> void:
	var c: BattleClock = BattleClock.new(RATE)
	c.advance(0.01)
	var before: float = c.accumulated()

	assert_int(c.advance(0.0)).is_equal(0)
	assert_int(c.advance(-1.0)).is_equal(0)
	assert_int(c.advance(NAN)).is_equal(0)
	assert_int(c.advance(INF)).is_equal(0)
	assert_float(c.accumulated()).is_equal(before)


func test_1800_frames_at_30hz_give_3600_ticks() -> void:
	var c: BattleClock = BattleClock.new(RATE)
	var total: int = 0

	for i in LONG_RUN_FRAMES:
		total += c.advance(1.0 / 30.0)

	assert_int(total).is_equal(3600)


func test_drop_backlog_then_small_delta_gives_one_tick() -> void:
	var c: BattleClock = BattleClock.new(RATE)
	c.advance(0.2)

	c.drop_backlog()

	assert_float(c.accumulated()).is_equal(0.5 * DT)
	assert_int(c.advance(0.01)).is_equal(1)


func test_start_phase_is_half_a_tick() -> void:
	var c: BattleClock = BattleClock.new(RATE)

	assert_float(c.accumulated()).is_equal(0.5 * DT)


func test_jitter_at_half_phase_gives_600_one_tick_frames() -> void:
	var c: BattleClock = BattleClock.new(RATE)
	var counts: Array[int] = [0, 0, 0, 0]

	for i in JITTER_FRAMES:
		var d: float = (DT - JITTER) if i % 2 == 0 else (DT + JITTER)
		counts[c.advance(d)] += 1

	assert_int(counts[1]).is_equal(JITTER_FRAMES)
	assert_int(counts[0]).is_equal(0)
	assert_int(counts[2]).is_equal(0)
