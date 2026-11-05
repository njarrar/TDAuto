# PROTOTYPE - NOT FOR PRODUCTION. ADR-0001 V2.
extends Button
## The Control under the pointer, inside the fake wrapper. Counts callbacks.

const Counter := preload("res://counter.gd")

var tag: String = ""
var counter: Counter
var resolver: RefCounted


func _process(_delta: float) -> void:
	counter.bump(tag + "._process")


func _input(_event: InputEvent) -> void:
	counter.bump(tag + "._input")


func _gui_input(_event: InputEvent) -> void:
	counter.bump(tag + "._gui_input")


## Drops the resolver reference.
func detach() -> void:
	resolver = null
