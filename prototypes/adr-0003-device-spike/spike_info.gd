# PROTOTYPE - NOT FOR PRODUCTION. ADR-0003 device spike.
# Names for notification numbers and device IDs, read from the running engine
# through ClassDB, so a constant that does not exist in this build is reported
# as absent instead of breaking the script. Also turns input events into one
# log line each.
extends RefCounted

## Notification number to every Node or MainLoop constant name with that value.
var notification_names: Dictionary[int, String] = {}
## InputEvent device ID constant value to its short name (MOUSE, KEYBOARD, EMULATION).
var device_names: Dictionary[int, String] = {}
## Numbers of the app and window lifecycle notifications that exist in this build.
var lifecycle_values: Dictionary[int, String] = {}


func _init() -> void:
	for cls: String in ["Node", "MainLoop"]:
		for c: String in ClassDB.class_get_integer_constant_list(cls):
			if not c.begins_with("NOTIFICATION_"):
				continue
			var v: int = ClassDB.class_get_integer_constant(cls, c)
			if not notification_names.has(v):
				notification_names[v] = c
			elif not notification_names[v].split("/").has(c):
				notification_names[v] = notification_names[v] + "/" + c
	for n: String in lifecycle_names():
		if ClassDB.class_has_integer_constant("Node", n):
			lifecycle_values[ClassDB.class_get_integer_constant("Node", n)] = n
	for d: String in ["DEVICE_ID_MOUSE", "DEVICE_ID_KEYBOARD", "DEVICE_ID_EMULATION"]:
		if ClassDB.class_has_integer_constant("InputEvent", d):
			device_names[ClassDB.class_get_integer_constant("InputEvent", d)] = d.trim_prefix("DEVICE_ID_")


## The app and window lifecycle notifications ADR-0003 asks about (spike item SP10).
func lifecycle_names() -> PackedStringArray:
	return PackedStringArray([
		"NOTIFICATION_APPLICATION_FOCUS_OUT",
		"NOTIFICATION_APPLICATION_FOCUS_IN",
		"NOTIFICATION_APPLICATION_PAUSED",
		"NOTIFICATION_APPLICATION_RESUMED",
		"NOTIFICATION_WM_WINDOW_FOCUS_OUT",
		"NOTIFICATION_WM_WINDOW_FOCUS_IN",
		"NOTIFICATION_WM_GO_BACK_REQUEST",
		"NOTIFICATION_WM_CLOSE_REQUEST",
		"NOTIFICATION_WM_SIZE_CHANGED",
		"NOTIFICATION_WM_DPI_CHANGE",
		"NOTIFICATION_WM_MOUSE_ENTER",
		"NOTIFICATION_WM_MOUSE_EXIT",
		"NOTIFICATION_OS_MEMORY_WARNING",
	])


## One line per lifecycle name: its number, or "absent" when this build has no such constant.
func lifecycle_report() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for n: String in lifecycle_names():
		if ClassDB.class_has_integer_constant("Node", n):
			parts.append("%s=%d" % [n, ClassDB.class_get_integer_constant("Node", n)])
		else:
			parts.append("%s=absent" % n)
	return " ".join(parts)


## Device constants as the running engine reports them.
func device_report() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for d: String in ["DEVICE_ID_MOUSE", "DEVICE_ID_KEYBOARD", "DEVICE_ID_EMULATION"]:
		if ClassDB.class_has_integer_constant("InputEvent", d):
			parts.append("%s=%d" % [d, ClassDB.class_get_integer_constant("InputEvent", d)])
		else:
			parts.append("%s=absent" % d)
	return " ".join(parts)


## True for the per-frame notifications, which the log leaves out (frames are
## marked by PHYS and PROC lines instead).
func is_spam(what: int) -> bool:
	return what == Node.NOTIFICATION_PROCESS \
		or what == Node.NOTIFICATION_PHYSICS_PROCESS \
		or what == Node.NOTIFICATION_INTERNAL_PROCESS \
		or what == Node.NOTIFICATION_INTERNAL_PHYSICS_PROCESS


## True for the notifications listed in lifecycle_names().
func is_lifecycle(what: int) -> bool:
	return lifecycle_values.has(what)


## "<number> <name>" for a notification, with "LIFE" added for lifecycle ones.
func notification_label(what: int) -> String:
	var name_text: String = notification_names.get(what, "unknown")
	if is_lifecycle(what):
		return "%d %s LIFE" % [what, name_text]
	return "%d %s" % [what, name_text]


## "<id>(<name>)" when the device ID matches a known constant, else "<id>".
func device_name(id: int) -> String:
	if device_names.has(id):
		return "%d(%s)" % [id, device_names[id]]
	return str(id)


## True for mouse motion with no button held (hover).
func is_hover(ev: InputEvent) -> bool:
	if ev is InputEventMouseMotion:
		return (ev as InputEventMouseMotion).button_mask == 0
	return false


## One log line for an input event: class, device, index, position, pressed,
## canceled. Properties that may not exist in this build are read with get(),
## so a missing one prints <null> instead of breaking the script.
func describe(ev: InputEvent) -> String:
	var dev: String = device_name(ev.device)
	if ev is InputEventScreenTouch:
		var t: InputEventScreenTouch = ev as InputEventScreenTouch
		return "TOUCH dev=%s i=%d pos=%s pressed=%s canceled=%s double=%s" % [
			dev, t.index, v2(t.position), str(t.pressed), str(t.get("canceled")), str(t.get("double_tap"))]
	if ev is InputEventScreenDrag:
		var d: InputEventScreenDrag = ev as InputEventScreenDrag
		return "DRAG dev=%s i=%d pos=%s rel=%s" % [dev, d.index, v2(d.position), v2(d.relative)]
	if ev is InputEventMouseButton:
		var b: InputEventMouseButton = ev as InputEventMouseButton
		return "MBTN dev=%s btn=%d pos=%s pressed=%s canceled=%s mask=%d" % [
			dev, int(b.button_index), v2(b.position), str(b.pressed), str(b.get("canceled")), int(b.button_mask)]
	if ev is InputEventMouseMotion:
		var m: InputEventMouseMotion = ev as InputEventMouseMotion
		return "MMOV dev=%s pos=%s mask=%d" % [dev, v2(m.position), int(m.button_mask)]
	if ev is InputEventKey:
		var k: InputEventKey = ev as InputEventKey
		return "KEY dev=%s key=%s pressed=%s echo=%s" % [
			dev, OS.get_keycode_string(k.keycode), str(k.pressed), str(k.echo)]
	return "%s dev=%s %s" % [ev.get_class(), dev, ev.as_text()]


## A position as "(x,y)" with one decimal.
func v2(p: Vector2) -> String:
	return "(%.1f,%.1f)" % [p.x, p.y]
