# PROTOTYPE - NOT FOR PRODUCTION. ADR-0011 V3.
extends RefCounted
## Prototype of ADR-0011 Decision 5: a mitred quad strip, four points per
## segment, neighbours share one edge. No fold check (the starter path passes).


## points: x and y interleaved. Returns 4 points per segment, or empty.
static func bake(points: PackedFloat64Array, width: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	var count: int = points.size() / 2
	if count < 2 or width <= 0.0:
		return out
	var p: PackedVector2Array = []
	for i in count:
		p.append(Vector2(points[2 * i], points[2 * i + 1]))
	var normals: PackedVector2Array = []
	for i in count - 1:
		var d: Vector2 = (p[i + 1] - p[i]).normalized()
		normals.append(Vector2(-d.y, d.x))
	var half: float = width * 0.5
	var offs: PackedVector2Array = []
	for k in count:
		if k == 0:
			offs.append(normals[0] * half)
		elif k == count - 1:
			offs.append(normals[k - 1] * half)
		else:
			var m: Vector2 = (normals[k - 1] + normals[k]).normalized()
			var c: float = m.dot(normals[k])
			if c <= 0.001:
				return PackedVector2Array()
			offs.append(m * (half / c))
	for i in count - 1:
		out.append(p[i] + offs[i])
		out.append(p[i + 1] + offs[i + 1])
		out.append(p[i + 1] - offs[i + 1])
		out.append(p[i] - offs[i])
	return out
