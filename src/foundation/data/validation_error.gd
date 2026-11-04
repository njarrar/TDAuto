class_name ValidationError extends RefCounted
## One catalogue validation error: {code, source, record_id, field}.
##
## `code` comes from the closed list in ADR-0002 Decision 3. `detail` is free
## text for a human (for example a JSON parse message); tests never compare it.

var code: StringName = &""
## File name relative to the manifest, "manifest", or a fixture label.
var source: String = ""
## Empty for manifest and file errors.
var record_id: StringName = &""
## Dotted path inside the record, for example `levels[1].damage`. Empty if none.
var field: StringName = &""
var detail: String = ""


## Builds an error. Strings are converted to StringName once, here.
static func make(
		p_code: StringName, p_source: String, p_record_id: StringName = &"",
		p_field: StringName = &"", p_detail: String = "") -> ValidationError:
	var err: ValidationError = ValidationError.new()
	err.code = p_code
	err.source = p_source
	err.record_id = p_record_id
	err.field = p_field
	err.detail = p_detail
	return err


## Text form used by AppRoot's development report: `<source>: <record_id>.<field>: <code>`.
func to_text() -> String:
	var text: String = "%s: %s.%s: %s" % [source, String(record_id), String(field), String(code)]
	if detail != "":
		text += " (" + detail + ")"
	return text
