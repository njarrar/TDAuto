# ADR-0003 verification spike (throwaway)

Desktop-only probe of the engine behaviour ADR-0003 depends on (architecture QQ-06, QQ-02): callback order within a frame, whether a `mouse_filter = STOP` Control swallows the moves and releases of a gesture already under way, touch and mouse emulation duplicates, 4.7 device IDs, stretch and letterbox conversion, safe area and lifecycle constants. Android and iOS behaviour is NOT covered; see the ADR for what still needs a device.

Run: `/Applications/Godot.app/Contents/MacOS/Godot --path prototypes/adr-0003-spike --resolution 600x1200 | grep 'SPIKE|'`

Results and their reading are recorded in `docs/architecture/adr-0003-*.md` (Engine Compatibility) and `docs/engine-reference/godot/modules/input.md`.
