class_name PathOutline extends RefCounted
## Mitred quad strip for the lane (ADR-0011 Decision 5). Pure: floats in, points out.
## Four points per segment, in polygon order. Adjacent quads share one edge exactly.

## Style limit on the turn at an interior point (a square turn).
const MAX_DEFLECTION: float = PI * 0.5
const ANGLE_EPS: float = 0.000000001


## Bakes the path to quads of the given width. Returns an empty array when the points
## or width are unusable, a deflection is over 90 degrees, or a segment is shorter than
## (w / 2) * (tan(d_a / 2) + tan(d_b / 2)).
@warning_ignore("integer_division")
static func bake(points: PackedFloat64Array, width: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if not is_finite(width) or width <= 0.0:
		return out
	if points.size() < 4 or points.size() % 2 != 0:
		return out
	var n: int = points.size() / 2
	var segs: int = n - 1
	var half: float = width * 0.5
	var dx: PackedFloat64Array = PackedFloat64Array()
	var dy: PackedFloat64Array = PackedFloat64Array()
	var seg_len: PackedFloat64Array = PackedFloat64Array()
	for i: int in range(segs):
		var vx: float = points[(i + 1) * 2] - points[i * 2]
		var vy: float = points[(i + 1) * 2 + 1] - points[i * 2 + 1]
		var seg_l: float = sqrt(vx * vx + vy * vy)
		if not is_finite(seg_l) or seg_l <= 0.0:
			return PackedVector2Array()
		dx.append(vx / seg_l)
		dy.append(vy / seg_l)
		seg_len.append(seg_l)
	var defl: PackedFloat64Array = PackedFloat64Array()
	defl.resize(n)
	for k: int in range(1, n - 1):
		var dot: float = dx[k - 1] * dx[k] + dy[k - 1] * dy[k]
		var cross: float = dx[k - 1] * dy[k] - dy[k - 1] * dx[k]
		var angle: float = absf(atan2(cross, dot))
		if angle > MAX_DEFLECTION + ANGLE_EPS:
			return PackedVector2Array()
		defl[k] = angle
	for i: int in range(segs):
		var need: float = half * (tan(defl[i] * 0.5) + tan(defl[i + 1] * 0.5))
		if seg_len[i] < need:
			return PackedVector2Array()
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for k: int in range(n):
		var px: float = points[k * 2]
		var py: float = points[k * 2 + 1]
		var ox: float = 0.0
		var oy: float = 0.0
		if k == 0:
			ox = -dy[0] * half
			oy = dx[0] * half
		elif k == n - 1:
			ox = -dy[k - 1] * half
			oy = dx[k - 1] * half
		else:
			var n0x: float = -dy[k - 1]
			var n0y: float = dx[k - 1]
			var n1x: float = -dy[k]
			var n1y: float = dx[k]
			var denom: float = 1.0 + n0x * n1x + n0y * n1y
			ox = (n0x + n1x) * half / denom
			oy = (n0y + n1y) * half / denom
		left.append(Vector2(px + ox, py + oy))
		right.append(Vector2(px - ox, py - oy))
	for i: int in range(segs):
		out.append(left[i])
		out.append(left[i + 1])
		out.append(right[i + 1])
		out.append(right[i])
	return out
