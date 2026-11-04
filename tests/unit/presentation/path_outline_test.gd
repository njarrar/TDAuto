extends GdUnitTestSuite
## PathOutline bake (ADR-0011 Decision 5 and Validation 1).

const STARTER: Array[float] = [-40.0, 200.0, 400.0, 200.0, 400.0, 400.0, 100.0, 400.0, 100.0, 600.0,
		300.0, 600.0, 300.0, 980.0]


func _pts(values: Array[float]) -> PackedFloat64Array:
	return PackedFloat64Array(values)


func _near(a: Vector2, x: float, y: float) -> bool:
	return absf(a.x - x) < 0.000000001 and absf(a.y - y) < 0.000000001


func test_starter_path_has_exact_square_corner() -> void:
	var q: PackedVector2Array = PathOutline.bake(_pts(STARTER), 72.0)
	assert_int(q.size()).is_equal(24)
	# Segment 0: butt start, miter at (400, 200): outer (436, 164), inner (364, 236).
	assert_bool(_near(q[0], -40.0, 236.0)).is_true()
	assert_bool(_near(q[1], 364.0, 236.0)).is_true()
	assert_bool(_near(q[2], 436.0, 164.0)).is_true()
	assert_bool(_near(q[3], -40.0, 164.0)).is_true()


func test_adjacent_quads_share_one_edge() -> void:
	var q: PackedVector2Array = PathOutline.bake(_pts(STARTER), 72.0)
	assert_bool(q[1] == q[4]).is_true()
	assert_bool(q[2] == q[7]).is_true()


func test_rejects_120_degree_deflection() -> void:
	var p: Array[float] = [0.0, 0.0, 200.0, 0.0, 100.0, 173.2050807568877]
	assert_bool(PathOutline.bake(_pts(p), 20.0).is_empty()).is_true()


func test_miter_length_rule() -> void:
	# Two square turns need a middle segment of at least w; 72 passes at w 72, 71.9 fails.
	var ok: Array[float] = [0.0, 0.0, 200.0, 0.0, 200.0, 72.0, 400.0, 72.0]
	var bad: Array[float] = [0.0, 0.0, 200.0, 0.0, 200.0, 71.9, 400.0, 71.9]
	assert_bool(PathOutline.bake(_pts(ok), 72.0).is_empty()).is_false()
	assert_bool(PathOutline.bake(_pts(bad), 72.0).is_empty()).is_true()


func test_quarter_circle_bakes() -> void:
	var p: Array[float] = []
	for i: int in range(16):
		var a: float = (PI * 0.5) * float(i) / 15.0
		p.append(200.0 * sin(a))
		p.append(200.0 - 200.0 * cos(a))
	assert_bool(PathOutline.bake(_pts(p), 96.0).is_empty()).is_false()


func test_bad_inputs_return_empty() -> void:
	assert_bool(PathOutline.bake(PackedFloat64Array([0.0, 0.0]), 10.0).is_empty()).is_true()
	assert_bool(PathOutline.bake(_pts(STARTER), 0.0).is_empty()).is_true()
	assert_bool(PathOutline.bake(_pts(STARTER), NAN).is_empty()).is_true()
