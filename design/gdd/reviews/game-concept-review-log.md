## Review — 2026-11-01 — Verdict: NEEDS REVISION
Review mode: full · Workflow: full
Scope signal: L (producer should verify before sprint planning)
Specialists: game-designer, systems-designer, ux-designer, creative-director (senior)
Blocking items: 8 | Recommended: 6
Summary: Concept doc is a concept template, not a system GDD, so the missing 8 GDD sections are a category mismatch, not a defect. Verdict is NEEDS REVISION because the refuted tap-to-move hero model is still the doc's central verb, while pin + leash + aimed burst was confirmed by hero-pin. Pillars, hook, tiers and evidence base hold; this is one mechanic rewrite plus consistency fixes.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Pitch/Core Mechanics #2/Core Loop/Pillar 4/Orientation/Technical/MVP: replace steer + tap-to-move + grid A* with pin + leash + aimed burst; delete A*; close answered open question; refresh stale next steps
- [BLOCKING] Pillar 4: rewrite design test with input priority skill drag > tower > slot > hero drag > ground (ground tap does nothing); flag UNTESTED on phone with numeric pass/fail; name skill button position
- [BLOCKING] Pillar 2: drop falsified "idle-hero build clears only early stages"; name what keeps the hero necessary late; mark 25-30% unproven
- [BLOCKING] Progression: restate ~60% scarcity per tier (breadth not depth); pick one skill-point source (first-clear grant or stars)
- [BLOCKING] Scope tiers: add a leash/burst node in the VS Hero tree and one cheap cross-buff at Small Ship; reserve stat-source tags now
- [BLOCKING] Contradictions: engine says Undecided (Godot 4.7.2 pinned); stage-1 two slots vs MVP 3-5; confirm popup vs one-tap; hero-share personal metric vs Pillar 2 cap; stale review banners
- [RECOMMENDED] Defer to system GDDs: node costs, point income, enemy curve, gold, stars, modifier precedence, respec cost, damage attribution, hit areas, drag slop, reticle offset, accessibility
- [RECOMMENDED] Move or rename the concept doc out of design/gdd/ structure checks, or accept the mismatch note
Reviewed-Content-Hash: design/gdd/game-concept.md cba86afa75957366eba3d970f042bc62467a6ff5
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43

## Review — 2026-11-01 — Verdict: APPROVED
Review mode: full · Workflow: full
Scope signal: L (producer should verify before sprint planning)
Specialists: game-designer, systems-designer, ux-designer, creative-director (senior)
Blocking items: 0 | Recommended: 4 (wording leftovers, applied same day)
Summary: Re-review after the same-day revision. The pin + leash + aimed-burst hero now carries every section; Pillar 2 and 4 tests rewritten with bot and phone criteria; scarcity restated as "always one full tree, never two" (60% is illustration only); one-time flat first-clear point grant; one cross-buff at Vertical Slice, lattice at Small Ship; engine, slots, popup, metric and banner contradictions cleared. Hero, Input and Tree GDDs unblocked.
Prior verdict resolved: Yes — all 8 NEEDS REVISION items from the 2026-11-01 morning review
Findings:
- [RECOMMENDED] Pillar 1 / Aesthetics / Design Risks: quote the one-tree rule, not 60% — applied
- [RECOMMENDED] MVP item 3: leash in world units — applied
- [RECOMMENDED] Hero GDD: state that a "walk" re-pin would reintroduce pathfinding
- [RECOMMENDED] Tree GDD: set node costs so two full trees are never affordable
Reviewed-Content-Hash: design/gdd/game-concept.md 2eb89302dc6d316c2f3f8c74c11f10d44219e5b2
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/art/art-bible.md 83386ecd1c2641b152ea5bb9c50a81e17b2fca44
Reviewed-Content-Hash: design/gdd/systems-index.md be3052ce50f27a962ca9eff65e11f8cb50db0ef7
