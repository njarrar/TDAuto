# Systems Index: TowerRiot

> **Status**: Draft
> **Created**: 2026-11-01
> **Last Updated**: 2026-11-02
> **Source Concept**: design/gdd/game-concept.md (design-review 2026-11-01: NEEDS REVISION — this index follows the *confirmed* hero model from `prototypes/hero-pin-concept/REPORT.md`, not the concept's stale tap-to-move text)
> **TD-SYSTEM-BOUNDARY**: CONCERNS 2026-11-01 — applied inline (see Dependency Map notes)
> **CD-SYSTEMS**: CONCERNS (accepted) 2026-11-01 — recorded beneath Priority Tiers
> **PR-SCOPE**: OPTIMISTIC 2026-11-01 — user chose "Defer, merge, standard": 8 MVP GDDs at `workflow: standard` (`project.yaml` → `workflow_overrides.system_overrides`), `full` from Vertical Slice

---

## Overview

TowerRiot is a portrait, one-thumb tower defense in which towers hold ground and a single hero decides fights. The 30-second loop is: tap a slot to build, tap a tower to upgrade, drag the hero to **pin** it to a lane (it fights only inside a leash), and drag from one large button to **aim** its burst. Tapping ground does nothing. The session loop adds waves, gold and a win/lose screen; the long loop adds three skill trees, hero weapons, stars and 20 authored stages.

The system set therefore splits into three groups. **The battle** (MVP): data-driven config, a gesture resolver that owns the tap/drag priority, a battle composition root that wires every other battle system by signals, a combat core that tags every damage event with its source, enemies walking a stage path in waves, towers with gold and upgrades, and the hero with its leash and aimed burst, all shown on a HUD. **Growth** (Vertical Slice): a small pure stat resolver that MVP code already reads through one accessor, skill points, one tree, hero weapons, stars, save/load, menus, the phone build, and one cheap cross-tree buff so the hook is tested before the content spend. **Finish** (Alpha): audio, settings and accessibility, and the full cross-tree lattice.

Relationship analysis: three systems are bottlenecks and must be designed first and kept small — Data & Config (everything reads it), Combat & Damage (every fight and every metric passes through DamageEvent) and Game State & Stage Flow (the only place systems are connected). The hero and burst are one system by design: the burst is the hero's signature moment (Pillar 2) and shares its input, stats and feedback. Damage attribution is not a system; it is a `source` field and per-source counters on DamageEvent, because the hero-share question (Pillar 2's 25–30% target) must be answerable from the first build. Pathfinding does not exist: the pinned hero needs no navigation.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Data & Config Pipeline (inferred) | Core | MVP | In Review | design/gdd/data-config-pipeline.md | — |
| 2 | Input & Gesture Resolver | Core | MVP | In Review | design/gdd/input-gesture-resolver.md | Data & Config |
| 3 | Game State & Stage Flow (inferred) | Core | MVP | Needs Revision | design/gdd/game-state-stage-flow.md | Data & Config, Input |
| 4 | Combat & Damage (inferred) | Gameplay | MVP | Designed | design/gdd/combat-damage.md | Game State; Data & Config (soft, `max_hp` passed in at spawn) |
| 5 | Enemy & Wave (incl. Stage & Path) | Gameplay | MVP | Designed | design/gdd/enemy-wave.md | Data & Config, Combat, Game State |
| 6 | Tower System (incl. Gold Economy) | Gameplay | MVP | Designed | design/gdd/tower-system.md | Enemy & Wave, Combat, Input, Data & Config, Game State |
| 7 | Hero System (incl. Burst Skill, Pin & Aim Feedback) | Gameplay | MVP | In Review | design/gdd/hero-system.md | Input, Combat, Enemy & Wave, Data & Config, Game State, Tower (soft, bot gates and `burst_spike`) |
| 8 | Battle HUD & Build UI (inferred) | UI | MVP | Needs Revision | design/gdd/battle-hud.md | Game State, Tower, Hero, Input, Data & Config, Combat (soft), Enemy & Wave (soft) |
| 9 | Stat & Modifier Resolution (inferred) | Core | Vertical Slice | Not Started | — | Data & Config |
| 10 | Skill Point Economy (inferred) | Progression | Vertical Slice | Not Started | — | Stage Progression, Game State |
| 11 | Skill Tree System | Progression | Vertical Slice | Not Started | — | Skill Point Economy, Stat & Modifier, Data & Config |
| 12 | Hero Weapons | Progression | Vertical Slice | Not Started | — | Hero, Stage Progression, Stat & Modifier |
| 13 | Stage Progression & Stars (incl. End-of-Stage Report, Stage Preview) | Progression | Vertical Slice | Not Started | — | Game State, Enemy & Wave, Combat, Data & Config |
| 14 | Save/Load (inferred) | Persistence | Vertical Slice | Not Started | — | Skill Tree, Skill Point Economy, Stage Progression, Hero Weapons |
| 15 | Menu & Screen Flow (inferred) | UI | Vertical Slice | Not Started | — | Stage Progression, Skill Tree, Save/Load |
| 16 | Mobile Platform & Performance (inferred) | Core | Vertical Slice | Not Started | — | — |
| 17 | Onboarding Prompts (inferred) | Meta | Vertical Slice | Not Started | — | Game State, Battle HUD |
| 18 | Cross-Tree Synergy Hook (one buff) | Progression | Vertical Slice | Not Started | — | Skill Tree, Stat & Modifier |
| 19 | Visual Feedback & VFX (inferred) | UI | Vertical Slice | Not Started | — | Combat, Hero, Tower |
| 20 | Audio (inferred) | Audio | Alpha | Not Started | — | Game State, Combat, Hero |
| 21 | Settings & Accessibility (inferred) | Meta | Alpha | Not Started | — | Save/Load, Input, Battle HUD |
| 22 | Cross-Tree Synergies (full lattice) | Progression | Alpha | Not Started | — | Synergy Hook, Skill Tree, Stat & Modifier |

Merged by PR-SCOPE: Burst Skill and Pin & Aim Feedback → Hero; Stage & Path → Enemy & Wave; Gold Economy → Tower; End-of-Stage Report → Stage Progression; Damage Attribution → a `source` field and per-source counters in Combat. Dropped: pathfinding (the pinned hero needs none); analytics (no network).

---

## Categories

| Category | Description | Systems here |
|----------|-------------|--------------|
| **Core** | Foundation everything depends on | Data & Config, Input, Game State, Stat & Modifier, Mobile Platform |
| **Gameplay** | The systems that make the game fun | Combat, Enemy & Wave, Tower, Hero |
| **Progression** | How the player grows | Skill Points, Skill Tree, Hero Weapons, Stage Progression, Synergies |
| **Persistence** | Save state | Save/Load |
| **UI** | Player-facing displays | Battle HUD, Menu & Screen Flow, Visual Feedback |
| **Audio** | Sound | Audio |
| **Meta** | Outside the core loop | Onboarding, Settings & Accessibility |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Core loop on desktop, one stage, 3 towers, hero pin + burst, 6 waves | MVP build (6–7 days after GDDs) | Design FIRST, at `standard` |
| **Vertical Slice** | 3 stages, Hero tree, 2 weapons, save, phone build, one cross-buff | Vertical slice (+4–6 weeks) | Design SECOND, at `full` |
| **Alpha** | All systems present in rough form | Small Ship (+3–4 months) | Design THIRD |
| **Full Vision** | Content expansion only: 20 stages, 6–8 towers, 4+ weapons, full tree lattice | Release / post-launch | No new systems |

> **Creative Director Note** (MVP): the end-of-stage report is deferred, so add an MVP acceptance criterion that a plain-text towers-vs-hero damage share is shown or logged at stage end (concept MVP item 5). The Hero GDD owns a placeholder burst telegraph and impact flash so Pillar 2 is judged on a burst players can see. Pillar 2's fail cases (towers-only, max-hero) and "the lvl-2 upgrade changes the tower's shape within one wave" (Pillar 1 stand-in) are MVP bot/acceptance criteria, not tuning notes.
> **Creative Director Note** (Vertical Slice): design Visual Feedback & VFX alongside Skill Tree, not after it, because tree nodes cannot pass "visible within one wave" without a VFX contract (design order adjusted). VS has only the Hero tree, so the Synergy Hook is a Hero node that buffs nearby towers. The stage preview (Pillar 3) is owned by Stage Progression & Stars; free unlimited respec is stated in Skill Tree's rules. The ~60% scarcity rule is still undefined and must be settled in the concept revision.
> **Creative Director Note** (Alpha): the concept puts cross-buffs in Full Vision and says Small Ship has none; this index puts the lattice at Alpha. The concept revision must settle the tier or the hook slips back to Full Vision unnoticed.
> **Creative Director Note** (all tiers, Pillar 4): the 44 pt / 48 dp minimum target is an acceptance criterion of Input & Gesture Resolver and Battle HUD.

---

## Dependency Map

### Foundation Layer (no dependencies)

1. Data & Config Pipeline — every gameplay value is data-driven (coding standard); all other systems read it.
2. Input & Gesture Resolver — depends on: Data (its Input record; both are Foundation, Data is designed first). **TD note:** owns only a registry of hit targets with a priority value; Hero, Tower, slots and the burst button register themselves. Input never names a feature system. Priority table and gesture rules: `design/gdd/input-gesture-resolver.md`.
3. Mobile Platform & Performance — safe areas, export, tracer and effect pooling, particle caps. Hits are instant, so no projectiles are pooled (Combat GDD; technical-director to confirm).

### Core Layer

1. Game State & Stage Flow — depends on: Data, Input. **TD note:** owns the app root (catalogue, fatal screen) and the one battle builder, a plain function called by the scene and by bots (amended by the Game State GDD, since a scene-owned root cannot run headless; technical-director to confirm), that connects `enemy_killed(bounty)`, `enemy_leaked`, `waves_complete` and friends. No system reaches into another; this is how injection-over-singletons is met.
2. Combat & Damage — depends on: Game State; Data & Config (soft, `max_hp` passed in at spawn). Callers read values and pass them in. **TD note:** God-object risk; the GDD defines three pieces: DamageEvent (dealer kind and id from day one), Health, Status (slow). ProjectileSpawner cut because hits are instant, pending technical-director confirmation. Hit flashes live here (PR-SCOPE).
3. Stat & Modifier Resolution — depends on: Data. **TD/PR note:** VS tier, but every MVP stat read goes through one accessor so the resolver drops in behind it. Pure function base → flat adds → % multipliers (additive within the bucket). No overrides until something needs them. Stat-source tags reserved now for synergies.

### Feature Layer

1. Enemy & Wave — depends on: Data, Combat, Game State. Each emitter declares its own signals (Data owns none, per the Data & Config GDD); the composition root wires them. Path and slots moved from the stage scene to the Stage record, technical-director to confirm.
2. Tower System — depends on: Enemy & Wave, Combat, Input, Data, Game State. Gold income from `enemy_killed(bounty)`. **Split:** TowerSim in the builder and TowerInput in the wrapper, since the chip needs real time while the clock is stopped; technical director to confirm.
3. Hero System — depends on: Input, Combat, Enemy & Wave, Data, Game State, Tower (soft, bot gates and `burst_spike`). **TD note:** Burst depends on Hero inside the GDD; Hero never references Burst; the cooldown display reads from Burst.
4. Stage Progression & Stars — depends on: Game State, Enemy & Wave, Combat (per-source counters for the report), Data. **TD note:** stars are lives-based, not damage-based.
5. Skill Point Economy — depends on: Stage Progression, Game State. One-time first-clear grant (design-review ruling pending in the concept revision).
6. Skill Tree System — depends on: Skill Point Economy, Stat & Modifier, Data.
7. Hero Weapons — depends on: Hero, Stage Progression, Stat & Modifier.
8. Cross-Tree Synergy Hook / Synergies — depends on: Skill Tree, Stat & Modifier. **TD note:** produce modifiers into Stat matched by source tag only; never depend on Tower or Hero classes.

### Presentation Layer

1. Battle HUD & Build UI — depends on: Game State, Tower, Hero, Input, Data & Config, Combat (soft), Enemy & Wave (soft).
2. Visual Feedback & VFX — depends on: Combat, Hero, Tower.
3. Menu & Screen Flow — depends on: Stage Progression, Skill Tree, Save/Load.
4. Onboarding Prompts — depends on: Game State, Battle HUD.
5. Audio — depends on: Game State, Combat, Hero. **TD note:** `AudioStreamPlayer2D.area_mask` defaults to 0 in 4.7 (`docs/engine-reference/godot/breaking-changes.md`).

### Polish Layer

1. Save/Load — depends on: Skill Tree, Skill Point Economy, Stage Progression, Hero Weapons. **TD note:** progression systems expose `to_dict()`/`from_dict()` with a version field and never call Save; Save injects loaded state at boot.
2. Settings & Accessibility — depends on: Save/Load, Input, Battle HUD. **TD note:** touch focus is separate from keyboard/gamepad focus in 4.7 (`modules/input.md`). Safe-area APIs are not in the pinned reference; verify against live 4.7 docs when writing the Mobile Platform GDD.

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Data & Config Pipeline | MVP | Foundation | systems-designer, godot-gdscript-specialist | M |
| 2 | Input & Gesture Resolver | MVP | Foundation | ux-designer, gameplay-programmer | M |
| 3 | Game State & Stage Flow | MVP | Core | game-designer, lead-programmer | M |
| 4 | Combat & Damage | MVP | Core | systems-designer, gameplay-programmer | L |
| 5 | Enemy & Wave | MVP | Feature | level-designer, ai-programmer | M |
| 6 | Tower System | MVP | Feature | game-designer, economy-designer | M |
| 7 | Hero System | MVP | Feature | game-designer, ux-designer | M |
| 8 | Battle HUD & Build UI | MVP | Presentation | ux-designer, ui-programmer | M |
| 9 | Stat & Modifier Resolution | VS | Core | systems-designer | M |
| 10 | Stage Progression & Stars | VS | Feature | game-designer | S |
| 11 | Skill Point Economy | VS | Feature | economy-designer | S |
| 12 | Skill Tree System | VS | Feature | game-designer, systems-designer | L |
| 12b | Visual Feedback & VFX (designed alongside Skill Tree) | VS | Presentation | technical-artist, art-director | S |
| 13 | Hero Weapons | VS | Feature | game-designer | M |
| 14 | Mobile Platform & Performance | VS | Foundation | technical-director, performance-analyst | M |
| 15 | Save/Load | VS | Polish | gameplay-programmer | M |
| 17 | Menu & Screen Flow | VS | Presentation | ux-designer | M |
| 18 | Onboarding Prompts | VS | Presentation | ux-designer | S |
| 19 | Cross-Tree Synergy Hook | VS | Feature | game-designer, systems-designer | S |
| 20 | Audio | Alpha | Presentation | audio-director | S |
| 21 | Settings & Accessibility | Alpha | Polish | accessibility-specialist, ux-designer | M |
| 22 | Cross-Tree Synergies (full) | Alpha | Feature | systems-designer, economy-designer | L |

Effort: S = 1 session, M = 2–3, L = 4+. MVP total at `standard`: ~18–24 sessions (PR-SCOPE estimate).

---

## Circular Dependencies

- Gold ↔ Enemy ↔ Game State (kill rewards, lives, waves-complete) — **resolved** by each emitter declaring its own signals and wiring them in the Game State composition root; no system imports another.
- Hero ↔ Burst — **resolved** by merging into one GDD with a one-way internal dependency (Burst → Hero).
- Save ↔ progression — **resolved**: progression owns schemas and never calls Save.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Input & Gesture Resolver | Design | Pin drag vs slot tap vs burst drag at fingertip size; untested on a phone (CD-PLAYTEST) | Hit-target registry; drag slop ~10–12 dp; phone test with a non-developer tester before Pillar 4 is claimed |
| Combat & Damage | Technical | God object; attribution depends on `source` being on every DamageEvent | Four-piece decomposition in the GDD; one unit test per piece |
| Hero System | Design | Hero share median 26.2% (bot, Hero GDD) vs 25–30% target, 33% on one build and up to 45% at ceiling skill; every MVP build loses without the hero | Waves tuned assuming the hero; human share logged from the first build; "pinned once" bot mode as an acceptance criterion |
| Stat & Modifier Resolution | Technical | Deferred to VS; retrofit cost if MVP code reads stats directly | Single stat accessor enforced from MVP day 1 |
| Skill Tree / Synergies | Design | Scarcity rule (~60%) undefined per tier; dominant-build risk | Scarcity restated per tier in the concept revision; one cheap cross-buff at VS tests the hook early |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 22 |
| Design docs started | 8 |
| Design docs reviewed | 1 |
| Design docs approved | 0 |
| MVP systems designed | 8/8 |
| Vertical Slice systems designed | 0/11 |

---

## Next Steps

- [ ] Revise `design/gdd/game-concept.md` per its design review (pin + aim model, Pillar 2 and 4 tests, scarcity, point source)
- [ ] `/design-system data-config-pipeline` — first in design order
- [ ] `/design-review` each GDD; `/consistency-check` after the third
- [ ] `/gate-check technical-setup` when the 8 MVP GDDs are approved
