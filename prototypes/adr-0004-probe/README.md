# ADR-0004 probe
Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/adr-0004-probe -s res://probe.gd` (4.7.2, 2026-11-05); prints RNG, float width, roundi and Engine defaults. Results are in ADR-0004 Engine Compatibility.

`review/` is the godot-specialist's windowed probe (2026-11-05): `/Applications/Godot.app/Contents/MacOS/Godot --path prototypes/adr-0004-probe/review` (main.gd: arch, usec reads, jitter and stall models, first-frame delta) and the same with `res://main2.tscn` (JSON versus `var_to_str` round trip, `physics_jitter_fix`, delta versus wall time). Results are in ADR-0004 Engine Compatibility.
