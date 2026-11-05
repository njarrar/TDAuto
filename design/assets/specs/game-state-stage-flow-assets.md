# Asset Specs: System: game-state-stage-flow

> **Source**: design/gdd/game-state-stage-flow.md, ADR-0001
> **Art Bible**: design/art/art-bible.md
> **Generated**: 2026-11-05
> **Status**: 1 assets specced / 0 approved / 0 in production / 0 done
> **Reviewers**: art-director (description, prompt, anchors); technical-artist (size, format, naming, constraints). Every asset is drawn in code unless the Format row says otherwise; the generation prompt is for concept or mock-up images only.

## ASSET-043: Fatal screen

| Field | Value |
|-------|-------|
| Category | UI (code) |
| Dimensions | Full screen 540 x 960 field units |
| Format | Scene: Control plus Label, no script. Field colour via ColorRect. |
| Naming | ui_fatal_screen (proposed; GDD gives no name) |
| Polycount | n/a (2D) |
| Engine constraints | Script-free by ADR-0001 so it must not use the HUD font loader or any autoload. Uses the engine default font unless ADR-0001 says otherwise (not checked). No material, no shader. |
| LOD | none |
| Source | game-state-stage-flow.md, ADR-0001 |

**Visual Description:**
A plain screen in the field colour #0B1020 with generic neutral #C8D0E0 text at 16 dp or larger, left-aligned, and no catalogue data, art or buttons beyond a Label. It is a Control plus a Label only, with no script, so it works when everything else fails.

**Art Bible Anchors:**
- §4 Color: field #0B1020, neutral #C8D0E0 at 12.2:1
- §7 Typography: 14 dp floor, medium weight sans
- §6 Environment: flat, no props
- §1 Identity: no extra colour or glow

**Generation Prompt:**
Flat vector error screen mock-up, portrait 540x960, solid #0B1020 field, a short two-line message in pale #C8D0E0 medium-weight sans at the upper left, nothing else. Negative: icons, illustrations, buttons, glow, gradient, red, magenta, border, stack trace, 3D, decoration.

**Flags:**
- Bible §7 says neutral text sits on panel only, never on the raw field at small sizes. This screen puts text straight on the field by design (ADR-0001, no scripts). Allowed here at 16 dp or larger, since contrast is 12.2:1; the bible should record the exception.
- Name proposed. Default font may not match the UI font, ADR-0001 not read here.

**Status:** Needed
