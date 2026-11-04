class_name Validator extends RefCounted
## Schema-driven catalogue validator (ADR-0002 Decision 4).
##
## Works on parsed dictionaries, never on built records. Three entry points:
## `check_manifest` and `check_files` are tier 1 (any error stops the record
## checks), `check_records` collects every record error. Stateless: all
## functions are static.
##
## Where the ADR names "the segment index" for `path_segment_too_short`, the
## error field is `path_points[j]`, with j the index of the segment's first point.

const MANIFEST_SOURCE: String = "manifest"
## Tolerance for float comparisons in the path rule.
const _EPS: float = 1e-9
## Largest whole float that converts to int exactly.
const _WHOLE_LIMIT: float = 9.0e15


## Collects the errors of one validation pass.
class Context extends RefCounted:
	var errors: Array[ValidationError] = []
	var source: String = ""
	## id String -> Array of record type Strings that hold it.
	var id_types: Dictionary = {}
	## id String -> number of records holding it, across all types.
	var id_counts: Dictionary = {}

	func add(code: StringName, record_id: StringName, field: String, detail: String = "") -> void:
		errors.append(ValidationError.make(code, source, record_id, StringName(field), detail))


## Tier 1: the parsed manifest. Returns manifest_shape, manifest_empty and
## manifest_repeat_path errors. `manifest` is the parsed JSON value.
static func check_manifest(manifest: Variant) -> Array[ValidationError]:
	var errors: Array[ValidationError] = []
	if not (manifest is Dictionary):
		errors.append(ValidationError.make(&"manifest_shape", MANIFEST_SOURCE))
		return errors
	var dict: Dictionary = manifest
	if dict.size() != 1 or not dict.has("files") or not (dict["files"] is Array):
		errors.append(ValidationError.make(&"manifest_shape", MANIFEST_SOURCE))
		return errors
	var files: Array = dict["files"]
	for item: Variant in files:
		if typeof(item) != TYPE_STRING or String(item) == "":
			errors.append(ValidationError.make(&"manifest_shape", MANIFEST_SOURCE))
			return errors
	if files.is_empty():
		errors.append(ValidationError.make(&"manifest_empty", MANIFEST_SOURCE))
		return errors
	var seen: Dictionary = {}
	for item: Variant in files:
		var path: String = item
		if seen.has(path):
			if seen[path] == 1:
				errors.append(ValidationError.make(
						&"manifest_repeat_path", MANIFEST_SOURCE, &"", StringName(path)))
			seen[path] = int(seen[path]) + 1
		else:
			seen[path] = 1
	return errors


## Tier 1: the parsed data files. Each entry is a Dictionary with "source"
## (String) and "data" (the parsed value). `check_empty_types` is false when an
## earlier tier 1 error already exists, so a missing file does not also report
## every type it would have held.
static func check_files(entries: Array, check_empty_types: bool) -> Array[ValidationError]:
	var errors: Array[ValidationError] = []
	var counts: Dictionary = {}
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		var source: String = entry["source"]
		var data: Variant = entry["data"]
		if not (data is Dictionary):
			errors.append(ValidationError.make(&"file_shape", source))
			continue
		var obj: Dictionary = data
		if obj.is_empty():
			errors.append(ValidationError.make(&"file_empty", source))
			continue
		for key: Variant in obj.keys():
			var type_name: String = String(key)
			if not CatalogueSchema.TYPE_ORDER.has(StringName(type_name)):
				errors.append(ValidationError.make(
						&"unknown_record_type", source, &"", StringName(type_name)))
				continue
			if not (obj[key] is Array):
				errors.append(ValidationError.make(&"file_shape", source, &"", StringName(type_name)))
				continue
			var list: Array = obj[key]
			for i: int in range(list.size()):
				if not (list[i] is Dictionary):
					errors.append(ValidationError.make(
							&"file_shape", source, &"", StringName("%s[%d]" % [type_name, i])))
			counts[type_name] = int(counts.get(type_name, 0)) + list.size()
	if check_empty_types and errors.is_empty():
		for type_name: StringName in CatalogueSchema.TYPE_ORDER:
			if int(counts.get(String(type_name), 0)) == 0:
				errors.append(ValidationError.make(
						&"type_has_no_records", MANIFEST_SOURCE, &"", type_name))
	return errors


## Record checks over entries that passed tier 1. Collects every error.
static func check_records(entries: Array) -> Array[ValidationError]:
	var ctx: Context = Context.new()
	_collect_ids(ctx, entries)
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		var data: Dictionary = entry["data"]
		ctx.source = entry["source"]
		for type_name: StringName in CatalogueSchema.TYPE_ORDER:
			if not data.has(String(type_name)):
				continue
			var list: Array = data[String(type_name)]
			for record_value: Variant in list:
				_check_record(ctx, String(type_name), record_value)
	return ctx.errors


# ---------------------------------------------------------------------------
# Records

static func _collect_ids(ctx: Context, entries: Array) -> void:
	for entry_value: Variant in entries:
		var data: Dictionary = (entry_value as Dictionary)["data"]
		for type_name: StringName in CatalogueSchema.TYPE_ORDER:
			if not data.has(String(type_name)):
				continue
			for record_value: Variant in (data[String(type_name)] as Array):
				var record: Dictionary = record_value
				var id_value: Variant = record.get("id")
				if typeof(id_value) != TYPE_STRING:
					continue
				var id_text: String = id_value
				ctx.id_counts[id_text] = int(ctx.id_counts.get(id_text, 0)) + 1
				var types: Array = ctx.id_types.get(id_text, [])
				types.append(String(type_name))
				ctx.id_types[id_text] = types


static func _check_record(ctx: Context, record_type: String, record: Dictionary) -> void:
	var record_id: StringName = &""
	var id_value: Variant = record.get("id")
	if typeof(id_value) == TYPE_STRING:
		record_id = StringName(String(id_value))
	var ok: Dictionary = _check_object(ctx, record_type, record, "", record_id, record_type)
	if record_type == "tower":
		_check_tower_roles(ctx, record, record_id)
	elif record_type == "stage":
		_check_stage_geometry(ctx, record, ok, record_id)


## Checks one object against its schema entry. Returns field name -> bool
## (true when that field raised no error), used by the geometry checks.
static func _check_object(
		ctx: Context, spec_name: String, obj: Dictionary, prefix: String,
		record_id: StringName, record_type: String) -> Dictionary:
	var fields: Dictionary = CatalogueSchema.FIELDS[spec_name]
	var optional: Array = CatalogueSchema.OPTIONAL_FIELDS.get(spec_name, [])
	var ok: Dictionary = {}
	for key: Variant in obj.keys():
		if not fields.has(key):
			ctx.add(&"unknown_property", record_id, prefix + String(key))
	for field_key: Variant in fields.keys():
		var field_name: String = field_key
		if not obj.has(field_name):
			if not optional.has(field_name):
				ctx.add(&"missing_field", record_id, prefix + field_name)
			ok[field_name] = false
			continue
		var spec: Array = fields[field_name]
		ok[field_name] = _check_value(
				ctx, obj[field_name], spec, prefix + field_name, record_id, record_type)
	return ok


static func _check_value(
		ctx: Context, value: Variant, spec: Array, path: String,
		record_id: StringName, record_type: String) -> bool:
	var kind: String = spec[CatalogueSchema.SPEC_KIND]
	if kind == "int":
		return _check_number(ctx, value, spec, path, record_id, true)
	if kind == "float":
		return _check_number(ctx, value, spec, path, record_id, false)
	if kind == "bool":
		if typeof(value) != TYPE_BOOL:
			ctx.add(&"wrong_type", record_id, path)
			return false
		return true
	if kind == "string":
		if typeof(value) != TYPE_STRING:
			ctx.add(&"wrong_type", record_id, path)
			return false
		return true
	if kind == "id":
		return _check_id(ctx, value, path, record_id)
	if kind.begins_with("id_ref:"):
		if typeof(value) != TYPE_STRING:
			ctx.add(&"wrong_type", record_id, path)
			return false
		return _check_ref(ctx, String(value), kind.substr(7), path, record_id)
	if kind.begins_with("id_refs:"):
		return _check_ref_list(ctx, value, kind.substr(8), path, record_id)
	if kind == "tags":
		return _check_tags(ctx, value, path, record_id, record_type)
	if kind == "point":
		return _check_point(ctx, value, path, record_id)
	if kind == "points":
		return _check_points(ctx, value, path, record_id)
	if kind == "rect":
		return _check_rect(ctx, value, path, record_id)
	if kind == "shapes":
		return _check_shapes(ctx, value, path, record_id)
	if kind.begins_with("list:"):
		return _check_list(ctx, value, kind.substr(5), path, record_id)
	return false


# ---------------------------------------------------------------------------
# Numbers

static func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


static func _is_whole(number: float) -> bool:
	return absf(number) >= _WHOLE_LIMIT or float(int(number)) == number


static func _check_number(
		ctx: Context, value: Variant, spec: Array, path: String,
		record_id: StringName, is_int: bool) -> bool:
	if not _is_number(value):
		ctx.add(&"wrong_type", record_id, path)
		return false
	var number: float = float(value)
	if not is_finite(number):
		ctx.add(&"non_finite", record_id, path)
		return false
	if is_int and not _is_whole(number):
		ctx.add(&"fractional_int", record_id, path)
		return false
	return _check_bounds(ctx, number, spec, path, record_id)


static func _check_bounds(
		ctx: Context, number: float, spec: Array, path: String, record_id: StringName) -> bool:
	var lower: Variant = spec[CatalogueSchema.SPEC_MIN]
	var upper: Variant = spec[CatalogueSchema.SPEC_MAX]
	var bad: bool = false
	if lower != null:
		var lower_value: float = float(lower)
		if number < lower_value or (number == lower_value and not bool(spec[CatalogueSchema.SPEC_MIN_INCL])):
			bad = true
	if upper != null:
		var upper_value: float = float(upper)
		if number > upper_value or (number == upper_value and not bool(spec[CatalogueSchema.SPEC_MAX_INCL])):
			bad = true
	if bad:
		ctx.add(&"out_of_bounds", record_id, path)
	return not bad


# ---------------------------------------------------------------------------
# Identity, references, tags

static func _valid_id_format(text: String) -> bool:
	if text.is_empty():
		return false
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		if i == 0:
			if not is_lower:
				return false
		elif not (is_lower or is_digit or code == 95):
			return false
	return true


static func _check_id(ctx: Context, value: Variant, path: String, record_id: StringName) -> bool:
	if typeof(value) != TYPE_STRING:
		ctx.add(&"wrong_type", record_id, path)
		return false
	var text: String = value
	if not _valid_id_format(text):
		ctx.add(&"id_format", record_id, path)
		return false
	if int(ctx.id_counts.get(text, 0)) > 1:
		ctx.add(&"id_duplicate", record_id, path)
		return false
	return true


static func _check_ref(
		ctx: Context, target: String, expected_type: String, path: String,
		record_id: StringName) -> bool:
	var types: Array = ctx.id_types.get(target, [])
	if types.is_empty():
		ctx.add(&"dangling_reference", record_id, path)
		return false
	if not types.has(expected_type):
		ctx.add(&"wrong_reference_type", record_id, path)
		return false
	return true


static func _check_ref_list(
		ctx: Context, value: Variant, expected_type: String, path: String,
		record_id: StringName) -> bool:
	if not (value is Array):
		ctx.add(&"wrong_type", record_id, path)
		return false
	var list: Array = value
	if list.is_empty():
		ctx.add(&"empty_list", record_id, path)
		return false
	var ok: bool = true
	for i: int in range(list.size()):
		var item_path: String = "%s[%d]" % [path, i]
		if typeof(list[i]) != TYPE_STRING:
			ctx.add(&"wrong_type", record_id, item_path)
			ok = false
		elif not _check_ref(ctx, String(list[i]), expected_type, item_path, record_id):
			ok = false
	return ok


static func _check_tags(
		ctx: Context, value: Variant, path: String, record_id: StringName,
		record_type: String) -> bool:
	if not (value is Array):
		ctx.add(&"wrong_type", record_id, path)
		return false
	var list: Array = value
	var vocabulary: Array = CatalogueSchema.TAGS.get(record_type, [])
	var ok: bool = true
	for i: int in range(list.size()):
		var item_path: String = "%s[%d]" % [path, i]
		if typeof(list[i]) != TYPE_STRING:
			ctx.add(&"wrong_type", record_id, item_path)
			ok = false
		elif not vocabulary.has(String(list[i])):
			ctx.add(&"unknown_tag", record_id, item_path)
			ok = false
	return ok


## Role checks for one tower. Skipped when the tags are malformed or unknown,
## so one typo gives one error.
static func _check_tower_roles(ctx: Context, tower: Dictionary, record_id: StringName) -> void:
	var tags_value: Variant = tower.get("tags")
	if not (tags_value is Array):
		return
	var vocabulary: Array = CatalogueSchema.TAGS["tower"]
	var roles: Array[String] = []
	for tag_value: Variant in (tags_value as Array):
		if typeof(tag_value) != TYPE_STRING or not vocabulary.has(String(tag_value)):
			return
		if CatalogueSchema.ROLE_FIELDS.has(String(tag_value)):
			roles.append(String(tag_value))
	if roles.size() != 1:
		ctx.add(&"role_tag_count", record_id, "tags")
		return
	var levels_value: Variant = tower.get("levels")
	if not (levels_value is Array):
		return
	var required: Array = CatalogueSchema.ROLE_FIELDS[roles[0]]
	var all_role_fields: Array[String] = []
	for field_list: Variant in CatalogueSchema.ROLE_FIELDS.values():
		for role_field: Variant in (field_list as Array):
			all_role_fields.append(String(role_field))
	var levels: Array = levels_value
	for i: int in range(levels.size()):
		if not (levels[i] is Dictionary):
			continue
		var level: Dictionary = levels[i]
		for role_field: String in all_role_fields:
			var present: bool = level.has(role_field)
			var needed: bool = required.has(role_field)
			if needed and not present:
				ctx.add(&"role_field_missing", record_id, "levels[%d].%s" % [i, role_field])
			elif present and not needed:
				ctx.add(&"role_field_without_tag", record_id, "levels[%d].%s" % [i, role_field])


# ---------------------------------------------------------------------------
# Lists and geometry shapes

static func _check_list(
		ctx: Context, value: Variant, sub_name: String, path: String,
		record_id: StringName) -> bool:
	if not (value is Array):
		ctx.add(&"wrong_type", record_id, path)
		return false
	var list: Array = value
	if list.is_empty():
		ctx.add(&"empty_list", record_id, path)
		return false
	var ok: bool = true
	for i: int in range(list.size()):
		var item_path: String = "%s[%d]" % [path, i]
		if not (list[i] is Dictionary):
			ctx.add(&"wrong_type", record_id, item_path)
			ok = false
			continue
		var before: int = ctx.errors.size()
		_check_object(ctx, sub_name, list[i] as Dictionary, item_path + ".", record_id, sub_name)
		if ctx.errors.size() != before:
			ok = false
	return ok


static func _check_point(ctx: Context, value: Variant, path: String, record_id: StringName) -> bool:
	if not (value is Array) or (value as Array).size() != 2:
		ctx.add(&"wrong_type", record_id, path)
		return false
	var pair: Array = value
	if not _is_number(pair[0]) or not _is_number(pair[1]):
		ctx.add(&"wrong_type", record_id, path)
		return false
	var x: float = float(pair[0])
	var y: float = float(pair[1])
	if not is_finite(x) or not is_finite(y):
		ctx.add(&"non_finite", record_id, path)
		return false
	if absf(x) > CatalogueSchema.COORD_LIMIT or absf(y) > CatalogueSchema.COORD_LIMIT:
		ctx.add(&"out_of_bounds", record_id, path)
		return false
	return true


static func _check_points(ctx: Context, value: Variant, path: String, record_id: StringName) -> bool:
	if not (value is Array):
		ctx.add(&"wrong_type", record_id, path)
		return false
	var list: Array = value
	var ok: bool = true
	for i: int in range(list.size()):
		if not _check_point(ctx, list[i], "%s[%d]" % [path, i], record_id):
			ok = false
	return ok


static func _check_rect(ctx: Context, value: Variant, path: String, record_id: StringName) -> bool:
	if not (value is Dictionary):
		ctx.add(&"wrong_type", record_id, path)
		return false
	var rect: Dictionary = value
	var ok: bool = true
	for key: Variant in rect.keys():
		if not CatalogueSchema.RECT_KEYS.has(String(key)):
			ctx.add(&"unknown_property", record_id, "%s.%s" % [path, String(key)])
			ok = false
	for corner: String in CatalogueSchema.RECT_KEYS:
		if not rect.has(corner):
			ctx.add(&"missing_field", record_id, "%s.%s" % [path, corner])
			ok = false
		elif not _check_point(ctx, rect[corner], "%s.%s" % [path, corner], record_id):
			ok = false
	if not ok:
		return false
	var low: Array = rect["min"]
	var high: Array = rect["max"]
	if float(low[0]) >= float(high[0]) or float(low[1]) >= float(high[1]):
		ctx.add(&"pin_rect_inverted", record_id, path)
		return false
	return true


static func _check_shapes(ctx: Context, value: Variant, path: String, record_id: StringName) -> bool:
	if not (value is Array):
		ctx.add(&"wrong_type", record_id, path)
		return false
	var list: Array = value
	var ok: bool = true
	for i: int in range(list.size()):
		var shape_path: String = "%s[%d]" % [path, i]
		if not (list[i] is Dictionary):
			ctx.add(&"wrong_type", record_id, shape_path)
			ok = false
			continue
		var shape: Dictionary = list[i]
		for key: Variant in shape.keys():
			if not CatalogueSchema.SHAPE_KEYS.has(String(key)):
				ctx.add(&"unknown_property", record_id, "%s.%s" % [shape_path, String(key)])
				ok = false
		for shape_key: String in CatalogueSchema.SHAPE_KEYS:
			var key_path: String = "%s.%s" % [shape_path, shape_key]
			if not shape.has(shape_key):
				ctx.add(&"missing_field", record_id, key_path)
				ok = false
			elif shape_key == "a" or shape_key == "b":
				if not _check_point(ctx, shape[shape_key], key_path, record_id):
					ok = false
			elif shape_key == "radius":
				if not _check_shape_radius(ctx, shape[shape_key], key_path, record_id):
					ok = false
			elif not _check_hand(ctx, shape[shape_key], key_path, record_id):
				ok = false
	return ok


static func _check_shape_radius(
		ctx: Context, value: Variant, path: String, record_id: StringName) -> bool:
	if not _is_number(value):
		ctx.add(&"wrong_type", record_id, path)
		return false
	var radius: float = float(value)
	if not is_finite(radius):
		ctx.add(&"non_finite", record_id, path)
		return false
	if radius <= 0.0:
		ctx.add(&"shape_invalid", record_id, path)
		return false
	return _check_bounds(ctx, radius, CatalogueSchema.SHAPE_RADIUS, path, record_id)


static func _check_hand(ctx: Context, value: Variant, path: String, record_id: StringName) -> bool:
	if typeof(value) != TYPE_STRING:
		ctx.add(&"wrong_type", record_id, path)
		return false
	if not CatalogueSchema.HANDS.has(String(value)):
		ctx.add(&"shape_invalid", record_id, path)
		return false
	return true


# ---------------------------------------------------------------------------
# Stage geometry

static func _to_coords(points: Array) -> PackedFloat64Array:
	var coords: PackedFloat64Array = PackedFloat64Array()
	for point_value: Variant in points:
		var pair: Array = point_value
		coords.append(float(pair[0]))
		coords.append(float(pair[1]))
	return coords


## Stage geometry checks that need more than one field. `ok` maps field name to
## "raised no error" from the per-field pass.
static func _check_stage_geometry(
		ctx: Context, stage: Dictionary, ok: Dictionary, record_id: StringName) -> void:
	if bool(ok.get("slot_positions", false)) and (stage["slot_positions"] as Array).is_empty():
		ctx.add(&"empty_list", record_id, "slot_positions")
	if not bool(ok.get("path_points", false)):
		return
	var points: Array = stage["path_points"]
	if points.size() < 2:
		ctx.add(&"path_too_short", record_id, "path_points")
		return
	var coords: PackedFloat64Array = _to_coords(points)
	var count: int = points.size()
	var repeated: bool = false
	for k: int in range(1, count):
		if coords[2 * k] == coords[2 * k - 2] and coords[2 * k + 1] == coords[2 * k - 1]:
			ctx.add(&"path_repeat_point", record_id, "path_points[%d]" % k)
			repeated = true
	if repeated or not bool(ok.get("path_width", false)):
		return
	_check_path_drawable(ctx, record_id, coords, count, float(stage["path_width"]))


## ADR-0011 Decision 5, as a Stage validation rule. With d_k the deflection at
## interior point k (0 at both ends) and w the path width: every d_k is at most
## 90 degrees, and each segment is at least (w / 2) * (tan(d_a / 2) + tan(d_b / 2))
## long. Uses tan(d / 2) = |cross| / (|u| |v| + dot), so no trigonometry is called.
static func _check_path_drawable(
		ctx: Context, record_id: StringName, coords: PackedFloat64Array, count: int,
		width: float) -> void:
	var half_tangents: PackedFloat64Array = PackedFloat64Array()
	half_tangents.resize(count)
	for k: int in range(1, count - 1):
		var ux: float = coords[2 * k] - coords[2 * k - 2]
		var uy: float = coords[2 * k + 1] - coords[2 * k - 1]
		var vx: float = coords[2 * k + 2] - coords[2 * k]
		var vy: float = coords[2 * k + 3] - coords[2 * k + 1]
		var product: float = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
		var dot: float = ux * vx + uy * vy
		var cross: float = ux * vy - uy * vx
		if dot < -_EPS * product:
			ctx.add(&"path_turn_too_sharp", record_id, "path_points[%d]" % k)
			continue
		half_tangents[k] = absf(cross) / (product + dot)
	for j: int in range(count - 1):
		var dx: float = coords[2 * j + 2] - coords[2 * j]
		var dy: float = coords[2 * j + 3] - coords[2 * j + 1]
		var length: float = sqrt(dx * dx + dy * dy)
		var needed: float = (width * 0.5) * (half_tangents[j] + half_tangents[j + 1])
		if length + _EPS * (1.0 + needed) < needed:
			ctx.add(&"path_segment_too_short", record_id, "path_points[%d]" % j)
