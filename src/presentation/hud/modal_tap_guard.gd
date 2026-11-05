class_name ModalTapGuard extends RefCounted
## The "fires only on a release whose press it saw while Armed" rule for the modal screens
## (Battle HUD Rule 2, ADR-0003 Decision 8). Pure: the screens feed it touch values.

var _armed: bool = false
var _index: int = -1
var _pressed: bool = false


## Armed screens count presses; a screen that is not armed ignores them.
func set_armed(value: bool) -> void:
	_armed = value
	if not value:
		clear()


## True when armed.
func is_armed() -> bool:
	return _armed


## A touch went down. Recorded only while armed and with no press already held.
func press(index: int) -> void:
	if _armed and not _pressed:
		_pressed = true
		_index = index


## A touch went up. True when it is the recorded press, not cancelled, and still armed.
func release(index: int, canceled: bool) -> bool:
	if not _pressed or index != _index:
		return false
	clear()
	return _armed and not canceled


## Clears the held press (lifecycle_paused, display_changed, focus loss).
func clear() -> void:
	_pressed = false
	_index = -1
