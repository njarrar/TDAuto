class_name PinGeometry extends RefCounted
## Pin rectangle and active-hand exclusion shapes, in float scalars only
## (Hero GDD Rule 14 and the clamp_pin rule; ADR-0004 float policy).
## No Vector2 method is used; a Vector2 is built only for the return value.

const MARGIN: float = 0.01
const TIE_EPS: float = 0.000001
const PARALLEL_EPS: float = 0.000000000001

var _min_x: float = 0.0
var _min_y: float = 0.0
var _max_x: float = 0.0
var _max_y: float = 0.0
## Active shapes, 5 floats each: ax, ay, bx, by, radius.
var _shapes: PackedFloat64Array = PackedFloat64Array()
## Boundary circles, 3 floats each: cx, cy, r.
var _circles: PackedFloat64Array = PackedFloat64Array()
## Boundary parallel lines, 4 floats each: px, py, unit dx, unit dy.
var _lines: PackedFloat64Array = PackedFloat64Array()
var _shape_n: int = 0
var _circle_n: int = 0
var _line_n: int = 0
var _best_x: float = 0.0
var _best_y: float = 0.0
var _best_d2: float = INF


## Keeps the shapes for both hands and for the active hand only.
func _init(stage: StageRecord, left_handed: bool) -> void:
	_min_x = stage.pin_rect[0]
	_min_y = stage.pin_rect[1]
	_max_x = stage.pin_rect[2]
	_max_y = stage.pin_rect[3]
	var active: StringName = &"left" if left_handed else &"right"
	for shape: PinShape in stage.pin_exclusion:
		if shape.hand != &"both" and shape.hand != active:
			continue
		_shape_n += 1
		_circle_n += 1
		_shapes.append_array(PackedFloat64Array([shape.a[0], shape.a[1], shape.b[0], shape.b[1], shape.radius]))
		var edge_r: float = shape.radius + MARGIN
		_circles.append_array(PackedFloat64Array([shape.a[0], shape.a[1], edge_r]))
		var dx: float = shape.b[0] - shape.a[0]
		var dy: float = shape.b[1] - shape.a[1]
		var length: float = sqrt(dx * dx + dy * dy)
		if length > 0.0:
			_circle_n += 1
			_line_n += 2
			_circles.append_array(PackedFloat64Array([shape.b[0], shape.b[1], edge_r]))
			var ux: float = dx / length
			var uy: float = dy / length
			var nx: float = -uy
			var ny: float = ux
			_lines.append_array(PackedFloat64Array([
				shape.a[0] + nx * edge_r, shape.a[1] + ny * edge_r, ux, uy]))
			_lines.append_array(PackedFloat64Array([
				shape.a[0] - nx * edge_r, shape.a[1] - ny * edge_r, ux, uy]))


## OK, OUT_OF_BOUNDS (outside the rect, edges inside) or BUTTON_ZONE (strictly
## inside an active shape; exactly at its radius is OK).
func is_valid(x: float, y: float) -> HeroSim.PinResult:
	if x < _min_x or x > _max_x or y < _min_y or y > _max_y:
		return HeroSim.PinResult.OUT_OF_BOUNDS
	for k: int in range(_shape_n):
		var base: int = k * 5
		var r: float = _shapes[base + 4]
		if _segment_dist2(x, y, _shapes[base], _shapes[base + 1], _shapes[base + 2], _shapes[base + 3]) < r * r:
			return HeroSim.PinResult.BUTTON_ZONE
	return HeroSim.PinResult.OK


## The valid point nearest the finger (fx, fy). Squared distances within
## 0.000001 tie, and a tie goes to the smaller y, then the smaller x. If no
## candidate is valid it returns the hold point.
func clamp_point(fx: float, fy: float, hold_x: float, hold_y: float) -> Vector2:
	_best_x = hold_x
	_best_y = hold_y
	_best_d2 = INF
	# 1. The finger clamped to the rect, and the rect corners.
	_offer(fx, fy, clampf(fx, _min_x, _max_x), clampf(fy, _min_y, _max_y))
	_offer(fx, fy, _min_x, _min_y)
	_offer(fx, fy, _max_x, _min_y)
	_offer(fx, fy, _min_x, _max_y)
	_offer(fx, fy, _max_x, _max_y)
	var circle_n: int = _circle_n
	var line_n: int = _line_n
	# 2. Nearest point on each circle and each parallel line.
	for c: int in range(circle_n):
		var cx: float = _circles[c * 3]
		var cy: float = _circles[c * 3 + 1]
		var r: float = _circles[c * 3 + 2]
		var ddx: float = fx - cx
		var ddy: float = fy - cy
		var dl: float = sqrt(ddx * ddx + ddy * ddy)
		if dl > 0.0:
			_offer(fx, fy, cx + ddx / dl * r, cy + ddy / dl * r)
		else:
			_offer(fx, fy, cx, cy - r)
	for l: int in range(line_n):
		var px: float = _lines[l * 4]
		var py: float = _lines[l * 4 + 1]
		var ux: float = _lines[l * 4 + 2]
		var uy: float = _lines[l * 4 + 3]
		var t: float = (fx - px) * ux + (fy - py) * uy
		_offer(fx, fy, px + ux * t, py + uy * t)
	# 3. Crossings with the rect edges.
	for c: int in range(circle_n):
		var cx: float = _circles[c * 3]
		var cy: float = _circles[c * 3 + 1]
		var r: float = _circles[c * 3 + 2]
		for edge_x: float in [_min_x, _max_x]:
			var ex: float = edge_x - cx
			if absf(ex) <= r:
				var h: float = sqrt(r * r - ex * ex)
				_offer(fx, fy, edge_x, cy + h)
				_offer(fx, fy, edge_x, cy - h)
		for edge_y: float in [_min_y, _max_y]:
			var ey: float = edge_y - cy
			if absf(ey) <= r:
				var h2: float = sqrt(r * r - ey * ey)
				_offer(fx, fy, cx + h2, edge_y)
				_offer(fx, fy, cx - h2, edge_y)
	for l: int in range(line_n):
		var px: float = _lines[l * 4]
		var py: float = _lines[l * 4 + 1]
		var ux: float = _lines[l * 4 + 2]
		var uy: float = _lines[l * 4 + 3]
		for edge_x: float in [_min_x, _max_x]:
			if absf(ux) > PARALLEL_EPS:
				_offer(fx, fy, edge_x, py + (edge_x - px) / ux * uy)
		for edge_y: float in [_min_y, _max_y]:
			if absf(uy) > PARALLEL_EPS:
				_offer(fx, fy, px + (edge_y - py) / uy * ux, edge_y)
	# Crossings of two pieces.
	for a: int in range(circle_n):
		for b: int in range(a + 1, circle_n):
			_cross_circles(fx, fy, a, b)
		for l: int in range(line_n):
			_cross_circle_line(fx, fy, a, l)
	for a: int in range(line_n):
		for b: int in range(a + 1, line_n):
			_cross_lines(fx, fy, a, b)
	return Vector2(_best_x, _best_y)


func _segment_dist2(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
	var dx: float = bx - ax
	var dy: float = by - ay
	var len2: float = dx * dx + dy * dy
	var t: float = 0.0
	if len2 > 0.0:
		t = clampf(((px - ax) * dx + (py - ay) * dy) / len2, 0.0, 1.0)
	var qx: float = ax + dx * t - px
	var qy: float = ay + dy * t - py
	return qx * qx + qy * qy


## Offers a candidate: kept only if valid and nearer (or a tie that wins).
func _offer(fx: float, fy: float, cx: float, cy: float) -> void:
	if not is_finite(cx) or not is_finite(cy):
		return
	if is_valid(cx, cy) != HeroSim.PinResult.OK:
		return
	var dx: float = cx - fx
	var dy: float = cy - fy
	var d2: float = dx * dx + dy * dy
	var cur: float = _best_d2
	var take: bool = false
	if d2 < cur - TIE_EPS:
		take = true
	elif d2 <= cur + TIE_EPS:
		if cy < _best_y or (cy == _best_y and cx < _best_x):
			take = true
	if take:
		_best_x = cx
		_best_y = cy
		_best_d2 = minf(d2, cur)


func _cross_circles(fx: float, fy: float, a: int, b: int) -> void:
	var x1: float = _circles[a * 3]
	var y1: float = _circles[a * 3 + 1]
	var r1: float = _circles[a * 3 + 2]
	var x2: float = _circles[b * 3]
	var y2: float = _circles[b * 3 + 1]
	var r2: float = _circles[b * 3 + 2]
	var dx: float = x2 - x1
	var dy: float = y2 - y1
	var d2: float = dx * dx + dy * dy
	if d2 <= 0.0:
		return
	var d: float = sqrt(d2)
	var along: float = (r1 * r1 - r2 * r2 + d2) / (2.0 * d)
	var h2: float = r1 * r1 - along * along
	if h2 < 0.0:
		return
	var h: float = sqrt(h2)
	var mx: float = x1 + dx / d * along
	var my: float = y1 + dy / d * along
	_offer(fx, fy, mx - dy / d * h, my + dx / d * h)
	_offer(fx, fy, mx + dy / d * h, my - dx / d * h)


func _cross_circle_line(fx: float, fy: float, c: int, l: int) -> void:
	var cx: float = _circles[c * 3]
	var cy: float = _circles[c * 3 + 1]
	var r: float = _circles[c * 3 + 2]
	var px: float = _lines[l * 4]
	var py: float = _lines[l * 4 + 1]
	var ux: float = _lines[l * 4 + 2]
	var uy: float = _lines[l * 4 + 3]
	var t: float = (cx - px) * ux + (cy - py) * uy
	var foot_x: float = px + ux * t
	var foot_y: float = py + uy * t
	var gx: float = cx - foot_x
	var gy: float = cy - foot_y
	var g2: float = gx * gx + gy * gy
	if g2 > r * r:
		return
	var h: float = sqrt(r * r - g2)
	_offer(fx, fy, foot_x + ux * h, foot_y + uy * h)
	_offer(fx, fy, foot_x - ux * h, foot_y - uy * h)


func _cross_lines(fx: float, fy: float, a: int, b: int) -> void:
	var p1x: float = _lines[a * 4]
	var p1y: float = _lines[a * 4 + 1]
	var u1x: float = _lines[a * 4 + 2]
	var u1y: float = _lines[a * 4 + 3]
	var p2x: float = _lines[b * 4]
	var p2y: float = _lines[b * 4 + 1]
	var u2x: float = _lines[b * 4 + 2]
	var u2y: float = _lines[b * 4 + 3]
	var cross: float = u1x * u2y - u1y * u2x
	if absf(cross) < PARALLEL_EPS:
		return
	var t: float = ((p2x - p1x) * u2y - (p2y - p1y) * u2x) / cross
	_offer(fx, fy, p1x + u1x * t, p1y + u1y * t)
