# PROTOTYPE - NOT FOR PRODUCTION. ADR checks stub. (ADR-0008 V6)
class_name FakeResolver
extends InputResolver
## Test fake: forwards two constructor arguments, typed override with return.

var calls: int = 0


func _init(p_min: float, p_max: float) -> void:
	super(p_min, p_max)


func hit_test(_x: float, _y: float) -> int:
	calls += 1
	return 7
