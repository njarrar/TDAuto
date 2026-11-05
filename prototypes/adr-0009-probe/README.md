Throwaway Godot 4.7.2 probes behind ADR-0009 (godot-specialist review, 2026-11-05): cyclic typed references, typed-array invariance, is_finite, signal timing, remove-during-iteration.
Run: `Godot --headless --path prototypes/adr-0009-probe --import` once, then `-s res://probe.gd` (also `cycle_first.gd`, `invariance_static.gd`, `override_ret.gd`; the last two are expected to fail).
