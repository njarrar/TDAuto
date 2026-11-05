class_name GestureRecord
extends RefCounted
## Value record of one gesture, kept by InputResolver (ADR-0008 Decision 8).
## Holds values only: no signal, no reference to any other script.
## Callers must not keep a record past their handler; ask last_gesture() again.

## The comparison that last decided a winner of one class.
enum WinRule { NO_CANDIDATE, ONLY, PRIORITY, DISTANCE, ID }

## How the gesture ended. OPEN while it is live.
enum Outcome {
	OPEN, TAPPED, GROUND_TAPPED, ROLLED_OFF, DRAG_WINNER_ONLY, DRAGGED,
	DRAGGED_LOST_MOVES, DEAD, CANCELLED, REPLACED, REPRESSED,
}

## Gesture number, from 1, per resolver.
var serial: int = 0
## Pointer index that owned the gesture.
var pointer: int = 0
## Press position, field units.
var press_pos: Vector2 = Vector2.ZERO
## Last position seen (release position, or the last known position on a cancel).
var end_pos: Vector2 = Vector2.ZERO
## Number of moves accepted for the active pointer.
var moves: int = 0
## Square root of the largest squared travel over the moves and the release.
var max_travel: float = 0.0
## Frozen tap winner id, -1 (NONE) when absent.
var best_tap: int = -1
## Frozen drag winner id, -1 (NONE) when absent.
var best_drag: int = -1
## True when the tap winner is a sink.
var tap_sink: bool = false
## Frozen centre of the tap winner (zero when absent).
var tap_centre: Vector2 = Vector2.ZERO
## Frozen centre of the drag winner (zero when absent).
var drag_centre: Vector2 = Vector2.ZERO
## Number of enabled TAP discs containing the press.
var tap_candidates: int = 0
## Number of enabled DRAG discs containing the press.
var drag_candidates: int = 0
## Rule that decided the tap winner.
var tap_rule: WinRule = WinRule.NO_CANDIDATE
## Rule that decided the drag winner.
var drag_rule: WinRule = WinRule.NO_CANDIDATE
## The slop (not squared) this press used.
var slop: float = 0.0
## How the gesture ended.
var outcome: Outcome = Outcome.OPEN


## Returns a new record with equal values.
func copy() -> GestureRecord:
	var c: GestureRecord = GestureRecord.new()
	c.serial = serial
	c.pointer = pointer
	c.press_pos = press_pos
	c.end_pos = end_pos
	c.moves = moves
	c.max_travel = max_travel
	c.best_tap = best_tap
	c.best_drag = best_drag
	c.tap_sink = tap_sink
	c.tap_centre = tap_centre
	c.drag_centre = drag_centre
	c.tap_candidates = tap_candidates
	c.drag_candidates = drag_candidates
	c.tap_rule = tap_rule
	c.drag_rule = drag_rule
	c.slop = slop
	c.outcome = outcome
	return c
