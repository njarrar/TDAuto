# PROTOTYPE - NOT FOR PRODUCTION. ADR-0003 device spike.
# Stands where the real InputAdapter will stand: two levels below the scene root
# (AppRoot / BattleWrapper / InputAdapter in the game). It logs every event it
# gets in _input (tag IN) and _unhandled_input (tag UNH), and every notification
# it receives (tag NOTE-DEEP), so the log shows whether lifecycle notifications
# reach a node this deep (SP10). It never marks an event as handled.
# Every IN line ends with win_focused (Window.has_focus() when the event
# arrives). At each lifecycle notification it writes a LOSS-ORDER line naming
# the last touch release before it and whether a touch was still down (SP11).
extends Node

const SpikeLog := preload("res://spike_log.gd")
const SpikeInfo := preload("res://spike_info.gd")

var spike_log: SpikeLog = null
var info: SpikeInfo = null
## Touch index to its last position, while the touch is down. Drawn by the field view.
var touch_points: Dictionary[int, Vector2] = {}
## Position of the last touch press, in the coordinates the event carried.
var last_press: Vector2 = Vector2.ZERO
## True once any touch press has been seen.
var has_press: bool = false

var _last_release_seq: int = -1
var _last_release_frame: int = -1
var _last_release_index: int = -1
var _last_release_canceled: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if spike_log == null or info == null:
		return
	if spike_log.last_marker == "PHYS":
		spike_log.events_after_phys += 1
	else:
		spike_log.events_after_proc += 1
	var on_screen: bool = not (spike_log.hide_hover_on_screen and info.is_hover(event))
	spike_log.entry("IN", "%s win_focused=%s" % [info.describe(event), _focus_text()], on_screen)
	_track(event)


func _unhandled_input(event: InputEvent) -> void:
	if spike_log == null or info == null:
		return
	var on_screen: bool = not (spike_log.hide_hover_on_screen and info.is_hover(event))
	spike_log.entry("UNH", info.describe(event), on_screen)


func _notification(what: int) -> void:
	if spike_log == null or info == null or info.is_spam(what):
		return
	spike_log.entry("NOTE-DEEP", info.notification_label(what))
	if info.is_lifecycle(what):
		spike_log.entry("LOSS-ORDER", _loss_order_text())
		spike_log.flush_now()


# Observation only: the last touch release before this notification, whether it
# came in the same process frame, and which touches are still down.
func _loss_order_text() -> String:
	var held: PackedStringArray = PackedStringArray()
	for i: int in touch_points:
		held.append(str(i))
	if _last_release_seq < 0:
		return "no touch release seen yet; touches down=[%s]" % ",".join(held)
	return "last touch release seq=%d i=%d canceled=%s frame=%d same_frame=%s; touches down=[%s]" % [
		_last_release_seq, _last_release_index, _last_release_canceled, _last_release_frame,
		str(_last_release_frame == Engine.get_process_frames()), ",".join(held)]


func _focus_text() -> String:
	var w: Window = get_window()
	if w == null or not w.has_method("has_focus"):
		return "?"
	return str(w.call("has_focus"))


func _track(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event as InputEventScreenTouch
		if t.pressed:
			touch_points[t.index] = t.position
			last_press = t.position
			has_press = true
		else:
			touch_points.erase(t.index)
			_last_release_seq = spike_log.seq()
			_last_release_frame = Engine.get_process_frames()
			_last_release_index = t.index
			_last_release_canceled = str(t.get("canceled"))
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event as InputEventScreenDrag
		touch_points[d.index] = d.position
