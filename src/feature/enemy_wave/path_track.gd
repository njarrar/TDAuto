class_name PathTrack extends RefCounted
## Position along the one path from a distance (ADR-0009 Decision 7). Built
## through `make`, which rejects unusable points. Scalars only.

var _points: PackedFloat64Array = PackedFloat64Array()
var _seg_len: PackedFloat64Array = PackedFloat64Array()
var _cum: PackedFloat64Array = PackedFloat64Array()
var _count: int = 0
var _total: float = 0.0


## Returns null if the points are unusable: an odd float count, fewer than two
## points, any non-finite coordinate, or any segment whose length is not above 0.
static func make(path_points: PackedFloat64Array) -> PathTrack:
	if path_points.size() % 2 != 0 or path_points.size() < 4:
		return null
	for v: float in path_points:
		if not is_finite(v):
			return null
	var n: int = path_points.size() >> 1
	var track: PathTrack = PathTrack.new()
	track._points = path_points.duplicate()
	track._count = n
	track._cum.append(0.0)
	var i: int = 0
	while i < n - 1:
		var dx: float = path_points[2 * i + 2] - path_points[2 * i]
		var dy: float = path_points[2 * i + 3] - path_points[2 * i + 1]
		var seg: float = sqrt(dx * dx + dy * dy)
		if not is_finite(seg) or not (seg > 0.0):
			return null
		track._seg_len.append(seg)
		track._cum.append(track._cum[i] + seg)
		i += 1
	track._total = track._cum[n - 1]
	return track


## Total path length.
func path_length() -> float:
	return _total


## Sets `e.pos_x` and `e.pos_y` from `e.distance`, by the GDD formula from the
## cumulative lengths. At or past the end it is the last point.
func place(e: Enemy) -> void:
	var d: float = e.distance
	var n: int = _count
	if d >= _total:
		e.segment = n - 2
		e.pos_x = _points[2 * (n - 1)]
		e.pos_y = _points[2 * (n - 1) + 1]
		return
	var k: int = clampi(e.segment, 0, n - 2)
	while k > 0 and _cum[k] > d:
		k -= 1
	while k + 2 < n and _cum[k + 1] <= d:
		k += 1
	e.segment = k
	var f: float = (d - _cum[k]) / _seg_len[k]
	var x0: float = _points[2 * k]
	var y0: float = _points[2 * k + 1]
	e.pos_x = x0 + f * (_points[2 * k + 2] - x0)
	e.pos_y = y0 + f * (_points[2 * k + 3] - y0)
