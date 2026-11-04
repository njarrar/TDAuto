class_name ChipWindow extends RefCounted
## The upgrade chip's real-time window (Tower Rule 8, ADR-0010 Decision 8). Pure: no engine.

## A tap earlier than this after opening is ignored (bounce guard).
const MIN_COMMIT_MS: float = 200.0
## The chip expires at this elapsed time.
const WINDOW_MS: float = 1500.0

var _open: bool = false
var _slot: int = -1
var _elapsed: float = 0.0


## Opens the window on a slot, restarting the clock.
func open(slot_index: int) -> void:
	_open = true
	_slot = slot_index
	_elapsed = 0.0


## Closes the window.
func close() -> void:
	_open = false
	_slot = -1
	_elapsed = 0.0


## Advances real time. Ignores non-finite or negative ms. Closes at WINDOW_MS.
func advance(ms: float) -> void:
	if not _open:
		return
	if not is_finite(ms) or ms < 0.0:
		return
	_elapsed += ms
	if _elapsed >= WINDOW_MS:
		close()


## True while the window runs.
func is_open() -> bool:
	return _open


## The slot the window is open on, or -1.
func slot() -> int:
	return _slot


## Milliseconds since opening (0 when closed).
func elapsed_ms() -> float:
	return _elapsed


## True when a tap would commit: 200 <= elapsed < 1500.
func can_commit() -> bool:
	return _open and _elapsed >= MIN_COMMIT_MS and _elapsed < WINDOW_MS
