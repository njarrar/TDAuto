# Cross-GDD Review Report

Date: 2026-11-05
GDDs Reviewed: 8 of 8 present
Not read: none. Each GDD was read by section (Grep `^#`, then ranges); no GDD was read whole.
Focus: full (consistency pass and design theory pass)
Systems Covered: Data & Config, Input & Gesture Resolver, Game State & Stage Flow, Combat & Damage, Enemy & Wave, Tower, Hero, Battle HUD
Pillars: Growth You Can See; One Hero, Not an Army; Every Stage Reads Differently; Thumb-First. Anti-pillars: roguelite, idle/clicker, hero action game, multiplayer in v1.

**Status at review time.** All 8 MVP GDDs are Approved, in their headers and in the systems index (2026-11-03 to 2026-11-05). The skill's precondition is met.

**Inputs and limits.**
- The entity registry (`design/registry/entities.yaml`) is still empty, so the checks rest on the GDD text alone. Run `/consistency-check` after this review to fill it.
- No GDD has a Player Fantasy section (advisory at `standard`), so the fantasy check used Summary, Game Feel and the concept.
- Cross-checked against the Accepted ADRs where a GDD rule depends on one (ADR-0001, 0002, 0003, 0004, 0006, 0008, 0011 read by section), `design/accessibility-requirements.md`, `design/ux/interaction-patterns.md` and `design/ux/hud.md`. ADR-0005, 0007, 0009 and 0010 were checked only through the lines the GDDs cite.
- **No specialist agents ran.** This session has no tool to start sub-agents, so both passes ran in this session, written from the game-designer and systems-designer views. They are not marked as run by those agents.
- `tools/balance-sim/hero_bots.py` has not changed since before the 2026-11-03 report (last commit 30b6805), and the Hero GDD's simulated tables are unchanged. So the 2026-11-03 measured tables (D2, D3) still stand and were not re-run. No human has played these values.
- Default report name: `gdd-cross-review-2026-11-05.md` does not overwrite the 2026-11-03 report, so the skill's own name is used.

---

## Status of earlier items (2026-11-03)

### Consistency warnings C1 to C19

| Item | Status | Evidence |
|---|---|---|
| C1 Cross-invalid Input record | Partly closed | Now guarded twice: the CI content test (Data domain row, ADR-0002 Decision 7) and the Builder's `fatal("input_record_invalid")` when `create` returns null (ADR-0001 Decision 2 step c, Input Rule 9). Left open: Flow Rule 18 lists "a failed catalogue load, a bad accessor call and a broken stage scene" as the causes, and Flow's Boot deferred row tests only a failed load and a broken scene. Neither names the null resolver |
| C2 Who calls `cancel()` | Closed | Input Rule 7 names three callers: the adapter, Flow through its injected `cancel_input()`, and the app root at teardown (ADR-0001, ADR-0003). Flow's Interactions row agrees |
| C3 Top-band input | Closed | Input's HUD Interactions row and UI Requirements both say the top band is display-only and ignores input |
| C4 Reticle and cancel-state drawer | Open, narrowed | ADR-0011 Decision 1 now puts the reticle in `HeroView`, and HUD Rule 1's HudField list omits it, which agree. Input's Visual table still says "Hero System computes, HUD draws" for the reticle and the cancel state, and Input's deferred row gives "visible cancel state" to Battle HUD stories |
| C5 Range rings | Open, narrowed | HUD now has `RangeRingView` (Rule 1) and reads ranges on arc and chip open (Interactions). But HUD specifies only Rule 9's `tower_inspected` ring. Tower's Visual table still lists the arc-open ring per level-1 range, the chip-open current and dashed next ring, and the 400 ms plus 200 ms ring after a build, all "drawn by Battle HUD" |
| C6 Hit-radius ownership | Open, narrowed | ADR-0011 Decision 9 settles it: hit radii "stay with HeroInput, TowerInput and HudLogic". The GDD text still loops: Enemy & Wave Rule 3 "Hit radii come from the Input GDD"; Input Rule 9 "the owners' values from their own records" (no record has the field); Input's `radius` row "from the art bible §3 table" |
| C7 `edge_reject_margin` vs x 84 | Open | Domain is still 0 to 48 (Data, Input). The burst centre must be at least margin + 48 from a side edge (Input Rule 12), which x 84 meets only at 36 or below. No content rule ties them |
| C8 L11 condition | Open | Enemy & Wave L11 applies only "on a stage with `requires_bend`"; Hero's content table row has no condition |
| C9 `requires_bend`, `visual_key` | Partly closed | Data's Stage list now has `requires_bend`. Enemy & Wave's starter Stage table still lacks it, and the Tower and Hero GDDs never mention `visual_key`, though Data makes it a field of Tower levels and of Hero |
| C10 Who caps `max_slow` | Open | Enemy & Wave Formulas: "Combat keeps it well below". Combat reads no data; Tower's content rule caps `slow_strength` at 0.6 |
| C11 Ground rings per battle | Closed | Input Interactions now says "the first three per battle" |
| C12 Input record shape | Closed | Input Rule 9 names the three fields it owns and says the record also holds `left_handed` and `reduce_motion` |
| C13 Path draw-in | Open | Flow Rule 16: "A retried battle opens in Build, skipping the path's draw-in". Enemy & Wave and HUD defer the draw-in |
| C14 Bot-gate owner | Open | Enemy & Wave's Mono-role and three Always-call rows still name Tower stories. Tower and Hero name Hero stories. Flow's "must not beat a driven hero" row is now owned by Hero stories, but Hero's Always-call row does not state that test |
| C15 Unacknowledged criteria | Open | Flow gives Combat stories full determinism and the micro-battle; Combat's deferred table has neither. Input gives Game State stories the injection row; Flow's table has none. Enemy & Wave gives Tower and Hero stories L14; neither GDD names L14. Data gives Flow the bad-accessor Fatal; Flow's Boot row omits it |
| C16 Stale text | Partly closed | Closed: Enemy & Wave's Reduce Motion question is marked answered. Open: HUD line 89 "This amends Combat's deferred row", which already says "no percentage"; Enemy & Wave UI Requirements points the next-wave line to "(Open Questions)", where no such question exists; Enemy & Wave's Cross-References row cites Input's "Open Question on slots", which no longer exists; Input still asks whether re-pinning is instant or a walk, which Hero Rule 3 settled |
| C17 Dependency tables | Partly closed | Closed: HUD now lists Enemy & Wave as hard upstream; Data, Input and Flow no longer say downstream GDDs are missing. Open: Input and Flow each list the other as downstream; Combat and Flow each list the other as downstream; Combat lists `to_ticks` from Enemy & Wave as upstream, and Enemy & Wave's downstream omits Combat. ADR-0004 places `to_ticks` in `TickMath` (Foundation), yet Combat, HUD and Enemy & Wave still attribute it to Enemy & Wave's Formulas |
| C18 Systems index | Partly closed | Closed: "Design docs approved" reads 8; the ProjectileSpawner note says accepted. Open: High-Risk still says "Four-piece decomposition" against Combat's three pieces (and Combat's own Cross-References row says "Four pieces"); "Design docs reviewed" reads 1; the Hero cell omits Game State and the HUD cell omits Enemy & Wave and Data & Config, though both GDDs list them as hard upstream; the Hero High-Risk row still cites "39% (bot)" against today's 25.1%; Next Steps still lists work now done |
| C19 Unwritten targets | Open, no action now | The prompt panel's overlap with the entry lane at insets above 45 dp is still owned by the Mobile Platform GDD (Not Started), due before the first phone build |

### Warnings N1 to N4 (from the 2026-11-03 re-check)

| Item | Status | Evidence |
|---|---|---|
| N1 "(a bot)" in an edge case | Closed | Input Edge Cases now say "(a resolver fixture)", and the next bullet says headless bots never reach the resolver |
| N2 Wedge inputs missing from tables | Closed | HUD Dependencies list Burst `cooldown`, `to_ticks` and the fixed `dt`, and the Burst's ID from the builder; Flow's HUD row and Data's HUD row now carry the ID and `cooldown`. The Vertical Slice note stands: a cooldown modifier that changes mid-cooldown makes the wedge jump |
| N3 Harness names Tower | Closed | Input Rule 13 says the log is the test harness story's; Input Cross-References and Tower Dependencies both list `GestureLog` |
| N4 `wave_index()` readers | Closed | Enemy & Wave's HUD row names `wave_index()` and `got_through_by_type()`; Flow's Enemy & Wave row names the read |

### Design theory warnings D1 to D13

None is closed. The bot script and Hero's tables have not changed, so the measured findings stand.

| Item | Status | Evidence |
|---|---|---|
| D1 Bot has no thumb limit | Open | No GDD names a one-thumb bot or an action lock. Tower Rule 6 still states the cost ("the thumb cannot re-pin at the same time") |
| D2 Burst on ready beats holding | Open | Hero's share gate still uses the hold-for-5 trigger. Hero Game Feel still says "A burst every 10 s keeps the thumb busy" |
| D3 Share swings by wave | Open | No per-wave report in Hero's criteria |
| D4 Re-pin is the weakest verb | Open | Hero Open Questions keep it for human logs; accepted at about 2 lives (2026-11-03) |
| D5 Single-only plus always-call | Open | Hero's Always-call row: "Single only gains 3 today, from the gold, and is not gated" |
| D6 Pillar 2 band vs Pillar 3 geometry | Open | Hero's Share row now says a flip "goes to the user rather than a retune". The per-stage question is not settled |
| D7 Arc and chip out of thumb reach | Open, and pushed further by D15 below | |
| D8 Calling early | Open | Hero: "Calling is still close to free for a bot"; kept for human logs |
| D9 Slot 5 and the gold gate | Partly acknowledged | Enemy & Wave Open Questions now ask whether slot 5 "earns its place". The link to "gold never fills the board" (496 < 550) is still unstated |
| D10 Personal number | Open | Hero Rule 17: median kills per burst is "the personal number"; HUD line 89 keeps it in the log only |
| D11 Slow is the risk role | Open | Still 4 of 21 compositions tested |
| D12 Spare lives soften wave 6 | Open, accepted at MVP | |
| D13 Calm against busy | Open | Concept "tactical calm"; Hero "keeps the thumb busy" |

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

None. No GDD cites a mechanic that does not exist, and no two GDDs set rules that cannot both hold. Every open item is a stale phrase, a table row or a wording gap, and the Accepted ADRs already settle the substance of C4, C6 and the C1 route.

### Warnings (should resolve, but won't block)

Carried, still open or partly open: C1 (remainder), C4 to C10, C13 to C19, as in the table above.

New in this run:

- **N5. Enemy & Wave says the accessibility doc does not exist.** `enemy-wave.md` Open Questions: "No entry for this system's cues in `design/accessibility-requirements.md`, which does not exist yet". The file exists, and its matrix row 5, AR-V-12 and the AR-V-10 exit-leak row cover Enemy & Wave. Close the question or point it at those rows. Rule 2c, stale reference.
- **N6. The concept's re-pin question is stale.** `game-concept.md` Open Questions: "The user accepted about 3 for MVP on an earlier run, so the current figure awaits confirmation (Hero GDD)". Hero's Pinned once row: "The user accepted about 2 for MVP (2026-11-03)". Update the concept line.
- **N7. Battle HUD text sizes break AR-V-01, which says it wins.** AR-V-01 sets 16 dp for gold, lives, labels and costs, and calls this "Already decided (Battle HUD UI Requirements)". The HUD GDD says only "Text floor 14 dp", its Visual table draws Start/Call as "two 14 dp lines", and its arc panel (60 x 44, word and cost) cannot hold 16 dp text (`design/ux/hud.md` H-01, H-03, H-10). The Won compact panel cannot hold the result at 16 dp either (H-02). The accessibility doc's header says a conflicting feature changes, not the commitment. The options are in hud.md H-01 to H-03 and need the user. Also: AR-V-01 lists "lives" at 16 dp, but lives are dashes with no text (H-05).
- **N8. Refusal-line handoffs point at specs that will not place it.** HUD UI Requirements, Tower's UX flag and IP-24 say "the arc-and-chip and pin-and-aim UX specs place the line". `design/ux/hud.md` now places it (H-06). The HUD GDD's own UX flag still asks for `/ux-design` on the arc, chip, Start/Call and result, and its Cross-References table cites neither `design/ux/hud.md` nor the accessibility doc, though its rules cite AR- and IP- IDs throughout.
- **N9. Pause control: which build?** AR-C-01 asks for a pause control "from the first phone build", while its change row 6 and the matrix put it at Vertical Slice. The first phone build is MVP+ (Android debug), where back already pauses (ADR-0003 Decision 5), so MVP+ on Android is covered; the first iOS build is Vertical Slice. HUD Rule 4, Flow Rule 17 and Input UI Requirements say no pause button at MVP, and no GDD owns its placement (OI-06, H-08). State the build it applies to, and name the owning GDD.
- **N10. Two Cross-References tables are partial.** Flow's table names Data, Input, the systems index, the concept, the art bible and the prototype, but its rules depend on Enemy & Wave (`wave_index()`, wave signals), Tower (bonus), Hero (`in_build()`, IDs), Combat (counters) and the HUD. Data's table omits Input, which added the Input record. For those rows the prose scan was the only check.
- **N11. The chip window and guard carry two labels.** Tower Rule 8: "Both durations are presentation constants, not catalogue values (Data Rule 1)". HUD Tuning Knobs call the matching arc guard a HudLogic constant because it "changes how a tap resolves", which is ADR-0011 Decision 9's test for a gameplay value kept with its input owner. Same kind of value, two names. Also HUD's `chip_bar` divides by a literal 1500 rather than Tower's window length, so AR-M-07's x1 to x3 window multiplier (Alpha) would desync the bar. Advisory.

---

## Game Design Issues

### Blocking

None. As on 2026-11-03, every issue sits in data, bots, gates or content rules, and nothing here changes a system boundary.

### Warnings

Carried: D1 to D13, all open (table above).

New in this run:

- **D14. The attention budget is now over the project's own trigger.** The 2026-11-03 peak table (wave 6: re-pin, burst aim, upgrade and chip, build, plus the field read) is unchanged. `design/accessibility-requirements.md`'s matrix now rates Battle HUD at a load of 5 and Hero at 5 while aiming, and states that a load above 4 is a review trigger. Its note that the aim view hides the rest is a mitigation for Hero alone. Recommended: count the peak in D1's one-thumb bot, and have the first-run test note which of the five a player drops.
- **D15. The text-size fixes trade against thumb reach and Pillar 1.** hud.md H-01's first option is a larger arc spread `R` of about 100 (also AR-M-11's first fallback), which lifts the arc discs about 24 units further from the thumb and deepens D7. H-02's first option grows the Won panel to y 640, which hides more of the finished board that Won's "board visible" reward (Pillar 1) depends on. These are pillar trade-offs inside a text-size decision. Recommended: decide H-01 and H-02 with D7 and Pillar 1 in view, not as layout fixes alone.
- **D16. Alpha assists have no bot-gate column.** The accessibility doc plans a "more lives" assist (AR-C-09, open), an intermission multiplier with the bonus taken from `seconds_left / m` (AR-M-08), and a 0.75x speed (AR-C-08). Pillar 2's gates and D12's cushion are measured only at default settings, and more lives directly loosens D12. Advisory for Alpha: add an assist column to the bot gates when Settings & Accessibility is designed.

### Attention at the peak (unchanged from 2026-11-03)

Four command systems, five with the field read, all in series through one thumb. Matching the bot through wave 6 is about 35% thumb occupancy before travel or gaze cost (estimate). See D14.

### Resource map (unchanged from 2026-11-03)

| Resource | Sources | Sinks | Condition |
|---|---|---|---|
| Gold | Start 120, bounties 510 at most, call bonus 40 at most | Builds, upgrades; no selling or interest | Scarce early, bounded, dead after the last wave |
| Lives | Start 10; no restore | Leaks: 1, heavy 3 | Sole stake at MVP; a cliff, not a spiral (D12); an Alpha assist would add a source (D16) |
| Burst cooldown | Time, not in Build | Every burst | Always restored between waves (15 s against 10.25 s) |
| Slots | 5 | Permanent builds | Fifth is dominated (D9) |
| Time | Build unlimited, Intermission 15 s, wave time | Calling, thumb actions | Thumb time is scarcest and unmodelled (D1) |

### Pillar alignment and fantasy

Every MVP system serves at least one pillar, and none breaks an anti-pillar. No new fantasy conflict: D13 is still the one tension.

---

## Cross-System Scenario Issues

Scenarios walked: 5
1. Focus loss with a chip open, an aim held and a telegraph running (Input, Flow, Tower, Hero, HUD, Enemy & Wave)
2. A bad Input record shipped to a device (Data, Input, Flow, ADR-0001, ADR-0002)
3. Retry after a Lost (Flow, HUD, Enemy & Wave, Combat, ADR-0001, ADR-0006)
4. A refused build under Reduce Motion with the arc open, then a dismiss (HUD, Tower, Input, AR-V-11, hud.md)
5. Call early with the burst cooling, then a mid-wave build (Flow, Tower, Hero, HUD)

### Blockers

None.

### Warnings

- **Scenario 2: Data, Input, Flow.** `drag_slop` 25 with `tap_slop` 20 passes the per-field validator, fails the CI content test, and on a device reaches `fatal("input_record_invalid")` through the Builder (ADR-0001). The route is defined, but only in the ADR and Input: Flow Rule 18's cause list and its Boot deferred row omit it, so no Flow criterion owns the fatal screen for this cause (C1, C15).
- **Scenario 5: Tower, Hero, HUD (D1, D8).** The data flow is correct: "Call +N" shows `call_bonus(ticks_left)`, Flow emits `wave_called_early(seconds_left)` after the next wave starts, and Tower pays `to_ticks(seconds_left) div to_ticks(rate)`, so the shown and paid values match. The cost left unmodelled is the thumb.

### Info

- **Scenario 1.** Now clean, with C2 closed. The adapter's first away notification calls `cancel()`, so the held aim gets `drag_cancelled` and fires nothing; `lifecycle_paused()` enters Paused, whose `phase_changed` closes the chip (Tower Edge Cases, criterion 28) and the arc (HUD criterion 7); `Battle.tick`'s Paused gate freezes the telegraph. The resume tap reaches nothing beneath. The danger timer still uses view time (presentation only, as before).
- **Scenario 3.** Clean. Lost commits, `cancel()` runs, frame step 3 takes the snapshot once, the text shows at 400 ms, Retry arms 300 ms later (`arm_ms`), and `AppRoot.request_retry()` rebuilds the battle: `wave_index()` is 0 and HudLogic equals a fresh instance (HUD criterion 1). The pattern library's IP-23 now puts the latch on the app root, as ADR-0001 does.
- **Scenario 4.** `build` returns `NO_GOLD`, the arc stays open, and the static cue shows for 1 s of real time (HUD Rule 7, hud.md placement table). Not stated: whether the cue stays if the arc closes inside that second (a press outside, `drag_started`, Paused), and whether a second refusal restarts it. Presentation only, with no state at risk, so not a blocker. One line in hud.md settles it.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| input-gesture-resolver.md | C4, C6, C7, C16, C17 | Consistency | Warning |
| enemy-wave.md | C6, C8, C9, C10, C14, C15, C16, C17; N5 | Consistency | Warning |
| game-state-stage-flow.md | C1, C13, C15, C17; N9, N10 | Consistency | Warning |
| battle-hud.md | C5, C16, C17; N7, N8, N9, N11; D15 | Consistency, Design Theory | Warning |
| tower-system.md | C5, C9; N11; D1, D5, D9, D11 | Consistency, Design Theory | Warning |
| hero-system.md | C8, C9, C14; D2 to D4, D6, D10, D13, D14 | Consistency, Design Theory | Warning |
| combat-damage.md | C15, C17, C18 (its "Four pieces" row) | Consistency | Warning |
| data-config-pipeline.md | C7, N10 | Consistency | Warning |
| game-concept.md | N6 | Consistency | Warning |
| systems-index.md | C18 | Consistency | Warning |

Outside `design/gdd/`, for their owners: `design/accessibility-requirements.md` (N7's AR-V-01 wording and H-05, N9's tier, D16), `design/ux/hud.md` (scenario 4, H-01 to H-03 with D15), `design/ux/interaction-patterns.md` (N8's IP-24 handoff).

Systems index statuses were left as they are. Every flag is a warning, and "Needs Revision" would reset eight Approved GDDs over wording and table rows (decision logged).

---

## Verdict: CONCERNS

- Consistency pass: **CONCERNS.** No blocker. Closed since 2026-11-03: C2, C3, C11, C12 and N1 to N4. Partly closed: C1, C9, C16, C17, C18. Still open: C4 to C8, C10, C13 to C15, C19 (C4 to C6 narrowed by the ADRs). New: N5 to N11.
- Design theory pass: **CONCERNS.** No blocker. D1 to D13 all still open (no new simulation since 2026-11-03). New: D14 to D16.
- Scenarios: no blocker; two warnings, three clean or info.

Most open items are one-line wording or table fixes. The substantive ones need the user: N7 with D15 (text sizes against reach and the Won board), N9 (pause control timing), and the D-series, which wait on a one-thumb bot (D1) or human logs.
