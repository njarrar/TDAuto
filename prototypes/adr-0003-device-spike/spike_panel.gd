# PROTOTYPE - NOT FOR PRODUCTION. ADR-0003 device spike.
# A coloured Control band that logs every event it receives in _gui_input.
# Positions in these lines are local to the band. The spike makes one band with
# mouse_filter STOP and one with PASS (SP2, SP3). With accept_touch on, the band
# also calls accept_event() on touch events, to test the fallback in SP3.
extends ColorRect

const SpikeLog := preload("res://spike_log.gd")
const SpikeInfo := preload("res://spike_info.gd")

var tag: String = "CTRL"
var spike_log: SpikeLog = null
var info: SpikeInfo = null
var accept_touch: bool = false


func _gui_input(event: InputEvent) -> void:
	if spike_log == null or info == null:
		return
	var on_screen: bool = not (spike_log.hide_hover_on_screen and info.is_hover(event))
	spike_log.entry(tag, info.describe(event) + " local", on_screen)
	if accept_touch and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		accept_event()
