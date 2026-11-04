extends InputResolver
## Test subclass of InputResolver (ADR-0008, ADR-0007 NAME-3: no class_name in tests).
## Records reports instead of calling push_error, and exposes a few test seams.

var reports: Array[String] = []


func _init(drag_slop: float = 15.0, tap_slop: float = 28.0, dev_error: Callable = Callable()) -> void:
	super(drag_slop, tap_slop, dev_error)


func _report(msg: String) -> void:
	reports.append(msg)


## Forces the stuck-drain flag, as a release-build script error might leave it.
func force_stuck() -> void:
	_draining = true


func is_draining() -> bool:
	return _draining


func queue_size() -> int:
	return _q_kind.size()


func target_count() -> int:
	return _targets.size()
