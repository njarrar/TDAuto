# PROTOTYPE - NOT FOR PRODUCTION. ADR checks stub. (ADR-0008 V4, V5, V6)
class_name InputResolver
extends RefCounted
## Resolver shape: enum Accepts, inner class Target in a typed array,
## Callable() defaults on _init and the static create().

enum Accepts { TAP = 0, DRAG = 1, BOTH = 2 }


class Target extends RefCounted:
	var id: int = 0
	var radius: float = 0.0

	func _init(p_id: int, p_radius: float) -> void:
		id = p_id
		radius = p_radius


var min_radius: float = 0.0
var max_radius: float = 0.0
var _dev_error: Callable
var _targets: Array[Target] = []


func _init(p_min: float, p_max: float, p_dev_error: Callable = Callable()) -> void:
	min_radius = p_min
	max_radius = p_max
	_dev_error = p_dev_error


static func create(p_min: float, p_max: float, p_dev_error: Callable = Callable()) -> InputResolver:
	return InputResolver.new(p_min, p_max, p_dev_error)


## Returns the accepts value it received, so a caller sees what arrived.
func register(p_id: int, p_accepts: Accepts) -> int:
	_targets.append(Target.new(p_id, min_radius))
	return int(p_accepts)


func remove_target_at(i: int) -> void:
	_targets.remove_at(i)


func target_ids() -> Array[int]:
	var out: Array[int] = []
	for t in _targets:
		out.append(t.id)
	return out


func hit_test(_x: float, _y: float) -> int:
	return -1


func has_dev_error() -> bool:
	return _dev_error.is_valid()
