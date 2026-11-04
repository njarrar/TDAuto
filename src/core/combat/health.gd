class_name Health extends RefCounted
## Current and maximum HP of one Targetable (ADR-0009 Decision 3). Holds no
## reference to anything. Only Combat writes these fields.

## Current HP, never below 0.
var hp: float = 0.0
## The spawn seed. Kept for the invariant check; never re-read as a stat.
var max_hp: float = 0.0
