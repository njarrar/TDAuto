# PROTOTYPE - NOT FOR PRODUCTION. ADR-0001 V2.
extends Node2D
## Child of the fake wrapper. Holds a sim until detach() and counts callbacks.

const Counter := preload("res://counter.gd")

var tag: String = ""
var counter: Counter
var sim: RefCounted


func _process(_delta: float) -> void:
	counter.bump(tag + "._process")


func _input(_event: InputEvent) -> void:
	counter.bump(tag + "._input")


func _unhandled_input(_event: InputEvent) -> void:
	counter.bump(tag + "._unhandled_input")


## Drops the sim reference.
func detach() -> void:
	sim = null
