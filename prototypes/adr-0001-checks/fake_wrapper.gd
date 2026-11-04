# PROTOTYPE - NOT FOR PRODUCTION. ADR-0001 V2.
extends Node
## Stand-in for BattleWrapper: two probe nodes and a large Button.
## detach() follows ADR-0001 Decision 6.

signal retry_pressed

const Counter := preload("res://counter.gd")
const FakeBattle := preload("res://fake_battle.gd")
const ProbeNode := preload("res://probe_node.gd")
const ProbeButton := preload("res://probe_button.gd")

var battle: FakeBattle
var resolver: RefCounted
var button: ProbeButton


## Adds the children. Call before add_child.
func build(gen: int, counter: Counter) -> void:
	for i in 2:
		var p: ProbeNode = ProbeNode.new()
		p.name = "Probe%d" % i
		p.tag = "g%d.probe%d" % [gen, i]
		p.counter = counter
		add_child(p)
	button = ProbeButton.new()
	button.name = "RetryButton"
	button.tag = "g%d.button" % gen
	button.counter = counter
	button.text = "Gen %d. Keep the pointer here.\nPress R, or click to retry." % gen
	button.position = Vector2(20.0, 300.0)
	button.size = Vector2(500.0, 360.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(button)
	button.pressed.connect(_on_button_pressed)


## Hands the battle's objects to the children.
func attach(b: FakeBattle) -> void:
	battle = b
	resolver = b.resolver
	var i: int = 0
	for c: Node in get_children():
		if c is ProbeNode:
			(c as ProbeNode).sim = b.sims[i]
			i += 1
	button.resolver = b.resolver


## Stops processing and drops every reference in the subtree.
func detach() -> void:
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	for c: Node in get_children():
		if c.has_method("detach"):
			c.call("detach")
	if button.pressed.is_connected(_on_button_pressed):
		button.pressed.disconnect(_on_button_pressed)
	battle = null
	resolver = null


func _on_button_pressed() -> void:
	retry_pressed.emit()
