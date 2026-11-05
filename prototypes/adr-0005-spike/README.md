# ADR-0005 spike

Throwaway probes run on Godot 4.7.2.stable.official (headless, debug build) on 2026-11-05 for
`docs/architecture/adr-0005-stat-accessor-and-read-context-contract.md`. Not game code.

Run one with: `Godot --headless --path <folder holding project.godot and the file> -s res://probeN.gd`
(create a minimal `project.godot` with `config_version=5` in a scratch copy; `cat_x.gd` and `keys_x.gd` are fixtures for probe4 and probe8).

- probe.gd: class names vs ClassDB, entity/WeakRef cycle release, subclass override, spy Callable, dictionary read loop.
- probe2.gd: subclass constructor inheritance and `super(...)`.
- probe3.gd: `match` on StringName constants; const dictionary lookups.
- probe4.gd: const dictionary keyed by another class's constant.
- probe5.gd: realistic `stat_float` read cost, `weakref(null)`, const read-only depth, String into a StringName parameter.
- probe6.gd: subclass `_init()` without `super()`.
- probe7.gd: 4.7 typed-return override break (parse error).
- probe8.gd: cross-class const as a `match` pattern.
