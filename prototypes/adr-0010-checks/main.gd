# PROTOTYPE - NOT FOR PRODUCTION. ADR-0010 V3 desktop.
extends Control
## Writes one line to user://, prints OS.get_user_data_dir() and the full
## path of the file, and shows both on screen. Close the window when done.

const FILE_PATH := "user://adr0010_v3.txt"


func _ready() -> void:
	var line: String = "ADR-0010 V3 line, written %s" % Time.get_datetime_string_from_system()
	var stored: bool = false
	var open_error: int = OK
	var f: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		open_error = FileAccess.get_open_error()
	else:
		stored = f.store_string(line + "\n")
		f.close()
	var lines: PackedStringArray = [
		"RESULT ADR-0010-V3 user_data_dir=%s" % OS.get_user_data_dir(),
		"RESULT ADR-0010-V3 file=%s" % ProjectSettings.globalize_path(FILE_PATH),
		"RESULT ADR-0010-V3 stored=%s open_error=%d" % [stored, open_error],
		"RESULT ADR-0010-V3 use_custom_user_dir=%s debug=%s os=%s" % [ProjectSettings.get_setting("application/config/use_custom_user_dir", false), OS.is_debug_build(), OS.get_name()],
		"RESULT ADR-0010-V3 line=%s" % line,
	]
	for l: String in lines:
		print(l)
	var label: Label = Label.new()
	label.text = "\n".join(lines)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
