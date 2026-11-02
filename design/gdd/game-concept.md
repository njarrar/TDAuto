# Game Concept: TowerRiot

*Created: 2026-11-01*
*Status: Approved 2026-11-01 — control model updated from two concept prototypes; see Prototype Evidence*

> **Creative Director Review (CD-PILLARS)**: REVISED 2026-11-01 — CONCERNS applied (respec rule, lopsided-build test, point scarcity, phone-scale readability, tap-collision rule)
> **Art Director Review (AD-CONCEPT-VISUAL)**: STRONG 2026-11-01 — Signal Board chosen as Visual Identity Anchor
> **Technical Director Review (TD-FEASIBILITY)**: CONCERNS (accepted) 2026-11-01 — schedule, not technology; mitigations adopted below
> **Producer Review (PR-SCOPE)**: OPTIMISTIC 2026-11-01 — user kept the MVP content and extended it to 6–7 days; adjusted tier table applied
> **Design Review**: NEEDS REVISION 2026-11-01 → revised the same day (8 blocking items: pin + aimed-burst hero replaces tap-to-move; Pillar 2/4 tests; scarcity per tier; point source; cross-buff tier; stale engine/A*). Re-review 2026-11-01: **APPROVED** (game-designer, systems-designer, ux-designer, creative-director).
> **Prototype Evidence**: `prototypes/hero-plus-towers-concept/` (tap-to-move hero: REFUTED, PIVOT) → `prototypes/hero-pin-concept/` (pin + leash + aimed burst: CONFIRMED, PROCEED, CD-PLAYTEST APPROVE)

---

## Elevator Pitch

> It's a mobile tower defense where you place and upgrade towers on a lane map **and** pin one hero to the lane that is leaking, aiming its burst into the bunched wave, growing towers, tower weapons and the hero on three separate skill trees across 20 stages whose paths and attacks change every level.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Tower defense (lane-based) with a controllable hero unit |
| **Platform** | Mobile (iOS / Android), portrait, one thumb. Desktop build used for development and testing with mouse-as-touch. |
| **Target Audience** | See Target Player Profile |
| **Player Count** | Single-player |
| **Session Length** | 10–25 min (2–3 stages of 5–8 min each) |
| **Monetization** | None decided (premium or none; no IAP/ads in scope) |
| **Estimated Scope** | Large (12–18 months to full vision, solo part-time; Small Ship tier at ~4–5 months) |
| **Comparable Titles** | Kingdom Rush (commander frame, hero unit), Plants vs. Zombies (phone-scale readability), Vampire Survivors (one hero holds the line) |

---

## Core Fantasy

You are the commander who gets stronger **and** smarter — and is on the field, not just above it. Towers are your standing army; the hero is your hands. Every stage asks a new question (a new path, a new kind of attack) and every skill point you spend is a visible answer: shots that chain, a hero skill that reaches further, a tower that now slows. The promise is growth you can see within one wave, not a number going up in a menu.

Alternatives considered: *the lone hero who summons turrets* (Concept 2 alone — drifts into action roguelite, loses the commander frame); *the tactician who re-solves a moving board* (Concept 3 — strong, but adaptation-as-mechanic replaces persistent growth, which was the user's core ask). The chosen fantasy keeps both: towers that hold and a hero that decides.

---

## Unique Hook

Like Kingdom Rush, **and also** your hero and your tower weapons level on separate trees that cross-buff each other — a Weapons node can change tower shot behaviour, a Hero node can buff towers near the hero — so no two players' stage 12 looks the same.

The hook is protected by a scarcity rule (see Pillar 1) stated as a fraction of total tree cost, not a stage number: the constraint is **always one full tree, never two**: at the last stage of any tier with three trees, total points complete any single tree plus part of a second but never two whole trees (~60% of total tree cost is the illustration: ~9 of ~15 nodes at Small Ship stage 8, ~24 of ~40 at Full Vision stage 20; the GDD sets exact costs so the two-tree boundary is never crossed). Scarcity limits **breadth**, not depth. Vertical Slice has one tree and is exempt. Free respec between stages means a counter-stage is adapted to, not ground through. The first cross-buff ships at Vertical Slice (a Hero node that buffs nearby towers) and the full lattice at Small Ship, so the hook is tested before the content spend (see Scope Tiers).

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Challenge** | 1 | Stage layouts and attack patterns that counter a build; the player's attention under pressure; star ratings for replay |
| **Expression** | 2 | Three trees under the one-full-tree-never-two rule; tower specialisation; build identity visible on screen |
| **Sensation** | 3 | Tower auto-fire feedback; hero skill burst VFX (the one place VFX is allowed to escalate) |
| **Discovery** | 4 | Cross-tree synergies found by experiment; stage previews that tease the next layout |
| **Fantasy** | 5 | The on-field commander; the hero as a character you grow |
| **Narrative** | N/A (v1) | No story beyond stage framing |
| **Fellowship** | N/A | Single-player |
| **Submission** | N/A | Not an idle game; no low-stress loop by design |

### Key Dynamics

- Players spend skill points *before* a stage after reading its preview, then re-spend when a stage counters them — the respec loop becomes the "thinking" phase.
- Players position the hero near their weakest lane rather than their strongest, because towers carry sustain and the hero carries the spike.
- Players specialise a few towers deeply rather than many shallowly, because upgrades add visible geometry and specialised towers read as "mine".
- Players replay early stages for stars with late-game builds to feel growth (safe to allow: skill points are a one-time first-clear grant per stage, so replay yields stars, never points).

### Core Mechanics

1. **Tower placement and upgrade** on fixed build slots along a lane path; tap slot → pick a tower from an in-field arc; tap tower → cost chip, second tap commits (no modal popup; the chip is the mis-spend safeguard, per art bible §7).
2. **Hero control (confirmed by hero-pin)**: drag the hero → it **pins** there and fights only enemies inside a leash (~90 world units on the 540×960 reference field; density-independent); drag from one large burst button → **aim** the burst with an offset reticle, within reach of where the hero stands (Hero GDD); a drag that never goes past 64 from its press point, or comes back within 48 of it, cancels, and a hero drag cancels the same way (Hero Rules 13 and 14); a tap on the button does nothing (the burst is drag-only, so a resting thumb never spends the cooldown; Input GDD review 2026-11-01). Tap on ground does nothing. No pathfinding: an unpinned hero idles off the path. Hero auto-attacks inside the leash.
3. **Wave system**: 8–12 waves per stage (MVP: 6) defined in data files; a stage waits for the player to start wave 1, then a timer runs between waves, which the player can beat by calling the next wave early for bonus gold; each stage varies path geometry and/or attack pattern (fast rushers, armoured, flying, splitters, lane-switchers).
4. **Three skill trees** (Towers / Weapons / Hero), persistent, free respec between stages, one full tree, never two, at each tier's last stage (see Unique Hook). Modifiers carry a source tag, a target stat and an optional condition (the first cross-buff is an aura: towers near the hero), resolving in a fixed order: base → flat adds → percent multipliers → overrides, through one pure, unit-testable function. 
5. **Stage progression**: 20 hand-authored stages, stage preview shows path + attack type, 1–3 stars per clear, hero weapons unlock by stage.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Which tree, which tower to specialise, where the hero stands; free respec makes choices reversible but still meaningful per stage | Core |
| **Competence** | Positioning the hero under pressure; clearing a stage that countered your last build; stars | Core |
| **Relatedness** | The hero as a character you grow; no social systems | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — primary. 20 stages, 3 stars each, three trees to fill (partially), weapon unlocks. Served by Kingdom Rush, Bloons TD 6.
- [x] **Explorers** — secondary. Cross-tree synergies are discovered by experiment; stage previews reward reading the board. Served by Bloons TD 6's hero/monkey-knowledge interplay.
- [ ] **Socializers** — not served. No co-op, no sharing in v1.
- [ ] **Killers/Competitors** — not served. No leaderboards or PvP in v1.

Quantic Foundry lens: **Strategy** (planning, decision-making) and **Mastery** (challenge, practice) dominate; **Creativity** (customisation) supports. Low on Action (destruction/excitement), Social and Immersion. Players who want twitch action or a story will bounce.

### Flow State Design

- **Onboarding curve** (from Vertical Slice; the MVP's one stage offers all three towers): Stage 1 has one path, three slots, one tower type, and the hero; the first wave cannot be lost. Stage 2 introduces the slow tower; stage 3 the first skill point. No tutorial text beyond one-line prompts.
- **Difficulty scaling**: each stage introduces one new variable (path shape *or* enemy type *or* attack pattern), never two. Skill-point income is tuned so a reasonable build clears with 1 star; 3 stars needs a build that fits the stage.
- **Feedback clarity**: upgrades add geometry (visible level); the end-of-stage screen shows damage by source (towers vs hero vs each tower type), which is also the balance telemetry.
- **Recovery from failure**: retry is instant; respec is free; a lost stage shows which wave broke and which enemy types got through.

---

## Core Loop

### Moment-to-Moment (30 seconds)
Tap a build slot → tower. Tap a tower → upgrade. Drag the hero → it pins to a lane and holds it. Drag from the big button → aim the burst into the bunched wave. Towers give constant auto-fire feedback (the machine working); the aimed burst is the "I did that" moment and re-pinning to a leaking lane is the decision. Every action is one tap or one drag.

*Primary feel (decided):* tactical calm punctuated by hero bursts. Alternative — hero-forward action pacing — rejected because it makes towers decorative.

### Short-Term (5–8 minutes)
One stage: 8–12 waves in the full game. The MVP stage has 6 waves and runs 5.1 to 5.4 min when no wave is called early; bots that call every wave finish in 3.7 to 3.8 min and lose no lives by it (Hero GDD, Simulated results), so the cost of calling promised below is a target, not yet shown. Two checks guard it: the mid-skill always-call bot must stay within Hero's Always-call gate, and at first playable waves started by a call must lose more lives than waves started after a full wait. If either fails, Flow's overlapping waves come forward (user decisions 2026-11-02, cross-GDD reviews D1 and G1). Between waves a timer runs: place, upgrade, re-pin the hero, or call the next wave early for bonus gold, at the cost of recovery and preparation time. Stage end: a one-time, flat skill-point grant on first clear, not scaled by stars; stars are earned on every clear and unlock nothing in the trees. The unspent point is the "one more stage" hook.

### Session-Level (10–25 minutes)
2–3 stages. Natural stop: a stage won, points spent. Hook back: the next stage's preview shows a path or attack you haven't solved.

### Long-Term Progression
20 stages; three trees of 12–15 nodes (full vision); hero weapons by stage; 3 stars per stage. Done = stage 20 cleared. Replay = stars with late builds.

### Retention Hooks
- **Curiosity**: the next stage preview; untried tree branches; synergies hinted by node descriptions.
- **Investment**: trees and stars are permanent; the hero you built.
- **Social**: none (v1).
- **Mastery**: 3-star clears; kills per burst as a personal metric (hero damage share is a balance metric, not a player goal: Pillar 2 caps it).

---

## Game Pillars

### Pillar 1: Growth You Can See
Every skill point changes something visible on screen within one wave, and readable at phone scale. Growth is a choice, not a checklist: at any tier's last stage the player can complete one full tree but never two (~60% of total tree cost, as an illustration; see Unique Hook).
*Design test*: a "+3% damage" node vs a node that makes shots chain → chain wins. A VFX that hides the hero or a path → cut.

### Pillar 2: One Hero, Not an Army
Towers hold ground; the hero decides fights. Target: hero + burst ≈ 25–30% of stage damage at balanced investment — **unproven** (the prototype's bot measured 39% in hero-pin with bot-fitted values; the Hero GDD's re-run with all three tower roles gives a median of 26.2% (Hero GDD, Simulated results); no human data yet; measured from the damage-by-source log, burst included; damage from towers the hero buffs is counted as tower damage, tagged by the dealing entity).
*Design test*: when hero and tower power compete, towers keep sustained DPS, the hero keeps the spike. A max-Hero, zero-Tower build still fails a stage (confirmed: hero-only lost at wave 4 in hero-pin, and on wave 3 in the Hero GDD's simulation). What keeps the hero necessary late, when trees multiply tower power: waves are tuned **assuming the hero's contribution**, and from Vertical Slice some waves carry leak pressure or tower-resistant enemies that only an aimed burst or a re-pin answers. The hero-pin prototype showed towers-only can win narrowly once any upgrade exists, so this is a wave-design rule, not an assumption. At MVP's current values every build loses without the hero (Hero GDD, Simulated results), so MVP is already stricter than the Vertical Slice rule. Bot acceptance criteria: a *pinned-once, never-touched* hero must clearly lose to active play, meaning it ends the stage with fewer lives (user ruling 2026-11-02); a *never-pinned* hero must equal towers-only; towers-only may win at MVP but must lose from Vertical Slice, once the wave rule is in.

### Pillar 3: Every Stage Reads Differently
Path geometry or attack pattern changes each stage, so a solved build doesn't carry — and the player adapts rather than grinds.
*Design test*: respec is free and unlimited between stages; the stage preview shows path and attack type. A new stage that is a reskinned map → rejected; new path geometry → accepted.

### Pillar 4: Thumb-First
Every action is one tap or one drag; no target under 44 pt (iOS) / 48 dp (Android).
*Design test*: taps and drags are distinct gestures (drag slop ~10–12 dp on phones). Tap priority: Start/Call > build arc > arc backdrop (while an arc is open, so a press outside the discs only dismisses) > tower = slot (nearest wins). Drag priority: hero > burst (user decision 2026-11-02, Hero Rule 15): a press inside both drags the hero, and dragging back to the press point cancels either drag. A tap on the burst button does nothing and reaches nothing beneath. A press with a tap target needs the larger tap slop before it can become a drag, so a thumb roll on a tower never moves a hero parked on it. A ground tap does nothing (a tiny rejection ring, no sound). A drag from a slot or tower alone is not a pin. Minimum supported width: 360 dp. Full rules: `design/gdd/input-gesture-resolver.md`. The burst button sits in the bottom corner on the dominant-hand side, inside the safe area, with a left-handed mirror. **UNTESTED on a phone**: all evidence is one developer on a mouse (CD-PLAYTEST). A tap on the hero does nothing but show its leash. Pass/fail for the first phone build with a non-developer tester, 20 attempts each of slot tap, arc disc tap, tower tap, Start/Call tap, pin drag and burst drag, then five minutes of unprompted play (protocol: Input GDD, Pillar 4 gate P1): for each gesture separately, a *miss* (gesture does nothing) is allowed on ≤5%; a *mis-fire* (gesture triggers a different action, including an accidental upgrade inside the cost-chip window) is allowed zero times. This test is the MVP+ exit criterion. A feature needing two thumbs → cut or redesigned.

Pillars 1 and 4 pull against each other (visible complexity vs one-thumb simplicity). That tension is intended.

### Anti-Pillars (What This Game Is NOT)

- **NOT a roguelite**: trees are permanent and runs do not reset. A reset would compromise *Growth You Can See*.
- **NOT an idle/clicker**: no offline income, no wait timers. Idle play removes the active hero and compromises *One Hero, Not an Army*.
- **NOT a hero action game**: the hero cannot solo a stage. Would compromise *One Hero, Not an Army* by making towers decorative.
- **NOT multiplayer in v1**: scope and *Thumb-First* both suffer.

---

## Visual Identity Anchor

**Direction: Signal Board** (AD-CONCEPT-VISUAL: STRONG; alternatives *Toy Soldiers on a Table* and *Paper Cutout Siege* recorded as later re-skin options once the loop is proven).

**Visual rule:** *Shape is role, colour is state.*

**Supporting principles**
- **Role by primitive** — towers are regular polygons (triangle / square / hexagon), enemies are small circles, the hero is the only irregular, asymmetric shape and the only thing with a glow. *Test:* desaturate a screenshot and shrink to ¼ — can you point to the hero in 1 second?
- **Growth by accretion** — each upgrade adds a visible element (ring, spike, second layer) rather than a recolour. *Test:* can a playtester say which of two towers is higher level without a number on screen?
- **Stage by field, not by props** — stages differ by background colour, path curve and grid tilt; no bespoke scenery. *Test:* two stage thumbnails side by side are told apart in under 2 seconds.

**Colour philosophy:** dark neutral field (near-black blue); pure saturated hues reserved for meaning — hero white/gold, towers cool (cyan/teal), enemies warm (orange/red), danger magenta. One hue per gameplay fact.

**Orientation:** portrait. Enemies enter below the top band and exit at the bottom; the hero is pinned by a drag and holds a leash drawn as a thin dashed ring; the burst is aimed by a drag from a bottom-corner button with the reticle offset from the thumb; slots tapped in the field; panels only in the top band so the thumb never hides the lower lane; UI anchored to safe areas. Full rules: `design/art/art-bible.md` §3, §7.

**Labour:** LOW — engine primitives or 5-minute vector shapes; no textures or animation frames. Risk: can feel sterile; mitigate with hero-burst VFX, not asset count.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Kingdom Rush | Lane TD with fixed build slots and a controllable hero | Three persistent trees with cross-buffs; free respec; the hero is a pinned, aimed unit targeted at ~25–30% of damage (unproven, see Pillar 2), not a side unit | Validates hero + towers on mobile |
| Plants vs. Zombies | Phone-scale readability; one new variable per level | Free-form lane paths instead of a fixed grid; hero unit | Validates "every stage introduces one thing" |
| Vampire Survivors | One hero holding the line; growth you feel immediately | Persistent trees, not per-run drafts; towers carry sustain | Validates immediate visible growth as a retention hook |
| Bloons TD 6 | Hero + tower knowledge trees interplay | Far smaller tree count; free respec; 20 authored stages | Validates cross-tree synergy as an Explorer hook |

**Non-game inspirations**: signal flags and maritime markers (shape = meaning); air-traffic displays (dark field, meaning-only colour).

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 16–40 |
| **Gaming experience** | Mid-core: has finished a tower defense before, comfortable with skill trees |
| **Time availability** | 10–25 minute sessions, commuting or evenings |
| **Platform preference** | Phone, one-handed, often with sound off |
| **Current games they play** | Kingdom Rush series, Bloons TD 6, Plants vs. Zombies |
| **What they're looking for** | A TD where progression changes how fights look, and where they are in the fight, not just watching |
| **What would turn them away** | Wait timers, pay-to-progress, twitch precision, a hero that trivialises towers |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Engine** | **Godot 4.7.2, GDScript, Mobile renderer** (pinned by `/setup-engine` 2026-11-01; `docs/engine-reference/godot/VERSION.md`). Chosen on TD-FEASIBILITY criteria: mobile export maturity, 2D tooling, beginner learning curve, time-to-phone-build. iOS still needs a Mac + Xcode + Apple developer account. Budgets in `project.yaml` → performance (60 fps, 60 draw calls, 256 MB; verify on device). |
| **Key Technical Challenges** | Tap/drag disambiguation at fingertip size (priority order in Pillar 4, hit-target registry); no pathfinding needed (the hero pins); cross-tree modifier stacking (fixed order, pure function, stat-source tags reserved from MVP); projectile pooling and particle caps on low-end Android; save versioning (version field + node IDs from day one); mobile signing pipeline. |
| **Art Style** | 2D, flat geometric primitives (Signal Board) |
| **Art Pipeline Complexity** | Low |
| **Audio Needs** | Minimal in MVP; moderate at Small Ship (SFX per tower/hero action, one loop per stage family) |
| **Networking** | None |
| **Content Volume** | Full vision: 20 stages, 6–8 towers, 4+ hero weapons, ~40 tree nodes, ~3–5 hours. Small Ship: 8 stages, 4 towers, 2 weapons, ~15 nodes, ~1.5 hours. |
| **Procedural Systems** | None. Stages hand-authored as point lists in data files, with their look in the scene (Enemy & Wave GDD); waves and stats in data files. Procedural paths rejected (more work, worse quality). |

---

## Risks and Open Questions

### Design Risks
- The hero may trivialise or be irrelevant to towers: towers-only won narrowly in hero-pin once one upgrade existed; the 25–30% target is unproven until measured from human runs (damage-by-source log from MVP).
- Pin drag, burst drag and slot tap may collide at fingertip size; the priority order needs the 20-attempt phone validation in Pillar 4 with a non-developer tester.
- Cross-tree buffs may create a dominant build that makes the one-tree scarcity rule moot; the lattice waits for Small Ship for that reason, with one buff proven at Vertical Slice.
- Signal Board may read as sterile without careful hero-burst VFX.

### Technical Risks
- First-time developer learning an engine and shipping the MVP loop (HIGH per TD-FEASIBILITY) — mitigated by narrowing days 1–2 to one map, one tower, hero pin + leash, one wave.
- Low-end Android performance under heavy projectile load — pooling, caps, real-device test at vertical slice.
- iOS toolchain cost and friction — Android debug build first; one iOS test build early in the vertical slice.

### Market Risks
- Mobile TD is crowded (Kingdom Rush, Bloons). The hook must be visible in a store screenshot: a hero mid-burst beside geometrically upgraded towers.
- No monetization decided; premium mobile is a hard sell and F2P adds systems that conflict with the anti-pillars.

### Scope Risks
- PR-SCOPE: OPTIMISTIC at every tier; solo first games run 2–3× the first estimate. The user chose to keep the MVP content and extend to 6–7 days.
- Polished art and audio for 20 stages is the largest single cost and is why the 20 stages sit in the last tier.
- Store release work (devices, listing, certification) is not in any estimate yet.

### Open Questions
- Answered 2026-11-01: a driven hero beats an untouched one (10 vs 3 lives, hero-pin bot) and tap-to-move is not the fantasy; *positioning* is. Open: does **repeated** re-pinning matter, or does pinning once suffice? In simulation it is worth about 3 lives on one path, with burst reach limited to 160 units, which the user accepted for MVP (Hero GDD). Re-pin cadence: a straight-line walk at 240, which needs no pathfinding. Does the drag model hold on a phone?
- Is one tree enough to feel the meta loop? — Vertical slice ships the Hero tree alone.
- Portrait confirmed? — First phone build; check thumb coverage of the lower third.
- Monetization — decide before Small Ship; affects store listing and nothing in the loop.

---

## MVP Definition

**Core hypothesis**: "Placing towers while pinning one hero to the leaking lane and aiming its burst is more fun than either alone." (Confirmed on desktop by hero-pin; phone unconfirmed.)

**Required for MVP** (6–7 days, desktop build with mouse-as-touch):
1. 1 map with a fixed path and 3–5 fixed build slots
2. 3 towers: single-target, splash, slow; upgrade level 1 → 2 (adds geometry)
3. 1 hero: drag-to-pin with a ~90 world-unit leash, auto-attack inside the leash, 1 aimed burst dragged from one large button; placeholder telegraph and impact flash so the burst is visible
4. 6 waves from a data file; Start Wave and call-early button; gold, lives, win/lose screen with instant retry
5. Damage-by-source log at stage end (towers vs hero + burst), shown as plain text since the report screen is deferred
6. Input priority per Pillar 4 (ground does nothing); an arc disc builds on its tap, a cost chip + second tap upgrades, no modal popup
7. Bot acceptance modes: towers-only, hero-only, never-pinned, pinned-once, towers-only always-call, mid-skill always-call; the lvl-2 upgrade changes the tower's shape within one wave

Days 1–2: one map, one tower, hero pin + leash, one wave. Towers 2–3, the skill and the upgrade follow only once that runs.

**Explicitly NOT in MVP**: skill trees, meta-progression, save/load, phone build (first item of MVP+), audio beyond stubs, more than one map, stars, stage previews.

### Scope Tiers

| Tier | Content | Features | Timeline (solo, part-time) |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 map, 3 towers + lvl 2 upgrade, hero (pin + leash + aimed burst), 6 waves | core loop on desktop; damage log | 6–7 days |
| **MVP+** | + phone build (Android debug first), safe-area UI | full core loop on a device; exit = Pillar 4 phone test passed | +1 week |
| **Vertical Slice** | 3 stages with different paths, **1** tree (Hero, ~5 nodes incl. a leash-radius or burst node and **one cross-buff**: a Hero node that buffs nearby towers), 2 hero weapons, save/load, phone build | core + progression; the hook's first test; real-device perf check; one iOS test build | +4–6 weeks |
| **Small Ship** | 8 stages, 3 trees ~5 nodes each **with the cross-tree lattice** (first buff proven at VS), 4 towers, 2 weapons, locked Signal Board art, basic SFX/music | shippable, polished | +3–4 months |
| **Full Vision** | 20 stages, trees 12–15 nodes, 6–8 towers, 4+ weapons | content expansion / post-launch updates | +6–9 months more (12–18 months total) |

The cross-tree lattice is the hardest thing to balance and does not carry the core hypothesis, so it waits for Small Ship; but the hook is the game's "and also", so one cheap cross-buff ships at Vertical Slice and stat-source tags are reserved from the first MVP GDD.

---

## Next Steps

- [x] Concept reviewed by creative-director (CD-PILLARS: REVISED), art-director (AD-CONCEPT-VISUAL: STRONG), technical-director (TD-FEASIBILITY: CONCERNS accepted), producer (PR-SCOPE: OPTIMISTIC, tiers applied)
- [x] `/setup-engine` — Godot 4.7.2 pinned
- [x] `/prototype hero-plus-towers` (PIVOT) → `/prototype hero-pin` (PROCEED)
- [x] `/art-bible` — `design/art/art-bible.md`, REVISED
- [x] `/design-review design/gdd/game-concept.md` — NEEDS REVISION, revised; re-review pending
- [x] `/map-systems` — `design/gdd/systems-index.md`, 22 systems
- [x] `/gate-check` Concept → Systems Design — CONCERNS accepted
- [ ] `/design-system data-config-pipeline` — first GDD in design order
- [ ] `/create-architecture` → `/architecture-decision` → `/architecture-review`
- [ ] `/vertical-slice` before committing to sprints
- [ ] `/gate-check technical-setup` when the 8 MVP GDDs are approved
