# ADR-0003 echo-off probe (throwaway)

Desktop probe run 2026-11-05 on 4.7.2.stable.official by godot-specialist. It repeats the spike's routing rows with the six project keys ADR-0003 adopts.

Key set for this run (all six): `display/window/size/viewport_width=540`, `viewport_height=960`, `display/window/stretch/mode="canvas_items"`, `display/window/stretch/aspect="keep"`, `input_devices/pointing/emulate_touch_from_mouse=true`, `input_devices/pointing/emulate_mouse_from_touch=false`. A second run changed `aspect` to `expand`.

Run: `/Applications/Godot.app/Contents/MacOS/Godot --path prototypes/adr-0003-spike/echo-off-probe --resolution 600x1200 2>&1 | grep 'PROBE|'`

Every device run D1 to D10 in ADR-0003 must state its key set in its log header and use these six keys. The parent spike's `project.godot` still has `emulate_mouse_from_touch=true` and is updated to the six keys before any device run.
