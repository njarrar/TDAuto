# PROTOTYPE - NOT FOR PRODUCTION. ADR-0001 V2.
extends RefCounted
## Stand-in for Battle: holds five sims and a resolver, nothing else.

var sims: Array[RefCounted] = []
var resolver: RefCounted


func _init() -> void:
	for i in 5:
		sims.append(RefCounted.new())
	resolver = RefCounted.new()
