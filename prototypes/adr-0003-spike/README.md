# ADR-0003 verification spike (throwaway)

Desktop-only probe of the engine behaviour ADR-0003 depends on (architecture QQ-06, QQ-02): callback order within a frame, whether a `mouse_filter = STOP` Control swallows the moves and releases of a gesture already under way, touch and mouse emulation duplicates, 4.7 device IDs, stretch and letterbox conversion, safe area and lifecycle constants. Android and iOS behaviour is NOT covered; see the ADR for what still needs a device.

Run: `/Applications/Godot.app/Contents/MacOS/Godot --path prototypes/adr-0003-spike --resolution 600x1200 | grep 'SPIKE|'`

Results and their reading are recorded in `docs/architecture/adr-0003-*.md` (Engine Compatibility) and `docs/engine-reference/godot/modules/input.md`.

## Key set per run (ADR-0003 Decision 10)

The tables in `docs/engine-reference/godot/modules/input.md` were recorded with this
folder's `project.godot` (`emulate_mouse_from_touch` on). ADR-0003 adopted the six
keys in `echo-off-probe/project.godot` (`emulate_mouse_from_touch` off); every device
run D1 to D10 uses that key set, so copy those six keys into this `project.godot`
before a device run and state the key set in each log.
