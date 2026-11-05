class_name ChipWindow extends RefCounted
## The tower panel's open state and bounce guard (Tower Rule 8, ADR-0010 Decision 8).
## Pure: no engine. Since first playable (user, 2026-11-05) the panel has no time limit:
## it stays open until a button is used or a press lands elsewhere.

## A button tap earlier than this after opening is ignored (bounce guard).
const MIN_COMMIT_MS: float = 200.0

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


## Advances real time. Ignores non-finite or negative ms. Never closes the window.
func advance(ms: float) -> void:
	if not _open:
		return
	if not is_finite(ms) or ms < 0.0:
		return
	_elapsed += ms


## True while the window is open.
func is_open() -> bool:
	return _open


## The slot the window is open on, or -1.
func slot() -> int:
	return _slot


## Milliseconds since opening (0 when closed).
func elapsed_ms() -> float:
	return _elapsed


## True when a button tap would commit: open and at least MIN_COMMIT_MS since opening.
func can_commit() -> bool:
	return _open and _elapsed >= MIN_COMMIT_MS
