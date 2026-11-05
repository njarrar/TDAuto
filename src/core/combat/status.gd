class_name Status extends RefCounted
## The one slow slot of a Targetable (ADR-0009 Decision 3). Holds no
## reference to anything. Only Combat writes these fields.

## Slow strength in the slot; 0.0 when empty.
var strength: float = 0.0
## Whole ticks left; the slot is empty at or below 0.
var ticks_left: int = 0
