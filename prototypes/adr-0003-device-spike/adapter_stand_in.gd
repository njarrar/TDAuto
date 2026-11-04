# PROTOTYPE - NOT FOR PRODUCTION. ADR-0003 device spike.
# Stands where the real InputAdapter will stand: two levels below the scene root
# (AppRoot / BattleWrapper / InputAdapter in the game). It logs every event it
# gets in _input (tag IN) and _unhandled_input (tag UNH), and every notification
# it receives (tag NOTE-DEEP), so the log shows whether lifecycle notifications
# reach a node this deep (SP10). It never marks an event as handled.
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if spike_log == null or info == null:
		return
	if spike_log.last_marker == "PHYS":
		spike_log.events_after_phys += 1
	else:
		spike_log.events_after_proc += 1
	_track(event)
	var on_screen: bool = not (spike_log.hide_hover_on_screen and info.is_hover(event))
	spike_log.entry("IN", info.describe(event), on_screen)


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
		spike_log.flush_now()


func _track(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event as InputEventScreenTouch
		if t.pressed:
			touch_points[t.index] = t.position
			last_press = t.position
			has_press = true
		else:
			touch_points.erase(t.index)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event as InputEventScreenDrag
		touch_points[d.index] = d.position
