# ADR-0002 probe (4.7.2, 2026-11-05)

Throwaway headless probes behind ADR-0002's "Observed on desktop" row: JSON number
types, `JSON.new().parse` vs `parse_string`, repeated keys, `.tres` coercion of a
bad int/float/missing/unknown field, `FileAccess.open` on a missing file,
`Dictionary` equality, `make_read_only`, `Vector2` precision, the `range` shadow
and the `Input` class-name collision.

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/adr-0002-spike -s res://probe.gd`
(and `-s res://probe2.gd`). Desktop only; none of it stands in for the Android export.
