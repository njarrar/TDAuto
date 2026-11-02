# Cross-GDD Review Report (second run)

Date: 2026-11-02
GDDs Reviewed: 8 of 8 present (data-config-pipeline, input-gesture-resolver, game-state-stage-flow, combat-damage, enemy-wave, tower-system, hero-system, battle-hud)
Not read: none
Focus: full (consistency, design theory, scenarios)
Systems Covered: the 8 MVP battle systems, against `game-concept.md`, `systems-index.md`, `design/art/art-bible.md` and `prototypes/hero-pin-concept/`
Specialists: game-designer x7 (consistency slices A Edge Cases, B Acceptance Criteria and Open Questions, C rule prose, D references into concept, art bible, prototypes and index; a regression check of the first run; design theory 3a to 3g; five new scenarios)
Workflow tier: standard for every system GDD (system overrides), so Player Fantasy and Tuning Knobs are advisory.
Prior review: `design/gdd/gdd-cross-review-2026-11-02.md` (FAIL, four blockers, fixed the same day).

> Entity registry is empty, so consistency checks rely on GDD reads only.

> **Coverage.** This run read every section the first run left out: all Edge Cases, the Acceptance Criteria of Tower, Flow and Data, every Open Questions table, the prose ranges listed in the first report, every cross-reference into the concept, art bible and prototypes, and the systems index's dependency lists. Still not checked: the art bible's section numbers row by row (terms were sampled), the exact text of Tower Rule 8, Data Rule 10 and Input Rule 2 as cited by Battle HUD and Tower Edge Cases, and `prototypes/hero-plus-towers-concept/` (no GDD cites it).

---

## Regression check of the first run

All four blockers and the two extra fixes are in place, with no leftover "burst > hero", "36–48", "released back on the button" or "only through the resolver" anywhere.

| ID | Status | Current line |
|---|---|---|
| C1 to C3, C6, C15, D1 (text) | FIXED | see the first report's Resolution |
| C4 | Open | `battle-hud.md:181`; Tower `:67`; Input `:50`, `:126`, `:273` |
| C5 | Open | `enemy-wave.md:372` |
| C7 | Open; Data moved | Data `:177`; Input `:267`; Flow `:172`; Enemy `:320`; Tower `:294` |
| C8 | Open | Combat `:158`, `:167`; Flow `:180`; Data `~:182` |
| C9 | Open | Data `~:187`; HUD `:277`, `:279`; Combat `:168` |
| C10 | Open | Input `:68`; no radius field in Data |
| C11 | Open; Data moved | Data `:55`; Input `:209` |
| C12 | Open | Combat `:240`; Enemy `:410`; Hero `:419-420` |
| C13 | Open | `combat-damage.md:145` |
| C14 | Open | `battle-hud.md:359` |
| S1 to S4 | Open | HUD `:66`/`:91`; Flow `:49`, `:103`; HUD `:54`; Input `:66` |

---

## Consistency Issues

### Blocking

None new. Every rule number, function and signal cited across the eight GDDs exists and says what the citing text claims.

### Warnings

⚠️ **R1. The Options record is not in Data's own tables, and the hand has two readers.** `data-config-pipeline.md:35` adds Options for Hero and Battle HUD, but Data's Interactions rows for Hero (`:135`) and HUD (`:137`) and Rule 10's direct-read list (`:103`) leave it out. Hero Rule 2 says the hand "is injected at build" (`hero-system.md:36`); Hero's Interactions row says `left_hand` is read "directly from the Options record" (`:169`); Battle HUD reads it directly (`:288`); Flow's builder lists no such injection. Name `left_hand` in Rule 2, and state one reader: the builder injects one value to HeroSim, HeroInput and the HUD, or each reads it.

⚠️ **R2. Battle HUD `:325` still calls Reduce Motion "a data flag until Settings exists"** without naming the Options record.

⚠️ **R3. Two re-pin times.** `enemy-wave.md:124`: "two fronts cost about 2 s"; `hero-system.md:37`: "about 1.5 s". Cite Hero Rule 3 from Enemy & Wave.

⚠️ **R4. Battle HUD Rule 10 states the pin cancel loosely.** `battle-hud.md:54`: "a drag back to its press point cancels"; Hero Rule 14 (`:55`) cancels at 48 or less and also when the drag never passes 64. Cite the thresholds or say "cancels as Hero Rule 14".

⚠️ **R5. Two gold totals for the same point.** `enemy-wave.md:283`: 456 through wave 5, 630 through wave 6; `tower-system.md:129-130`: 496 and 670. The gap is the 40 early-call bonus; neither says so.

⚠️ **R6. Content checks restated in Hero.** The intermission bound (`enemy-wave.md:111`, `hero-system.md:128`), L11 (`enemy-wave.md:44`, `hero-system.md:130`) and `burst_spike` (`tower-system.md:136`, `hero-system.md:129`) agree today but are separate copies. Enemy & Wave says it "owns the layout rules" (`:28`). One owner per bound; the others reference it.

⚠️ **R7. Fatal on a bad accessor call has no criterion owner.** `data-config-pipeline.md:248` gives it to Flow; Flow's Boot row (`game-state-stage-flow.md:258`) lists only a failed load and a broken scene.

⚠️ **R8. The always-call gate has two owners.** Flow `:261` and Tower `:396` say Hero stories; `enemy-wave.md:412` says Tower stories.

⚠️ **R9. Open questions asked twice or three times with different owners.**
- Calling nearly free: `tower-system.md:412`, `hero-system.md:449`, `game-state-stage-flow.md:274`.
- Re-pinning's worth: `enemy-wave.md:432`, `hero-system.md:446`.
- Pin finger offset: `input-gesture-resolver.md:401`, `hero-system.md:450`.
- Stretch mode, three deadlines: Input `:398`, Enemy `:439`, HUD `:411`.
Keep one row with one owner; the others link to it.

⚠️ **R10. Stale open questions.** Combat `:253` (and `:106`) still cite the prototype's 39% hero share; Hero `:111` reports the re-run (median 26.2%). `enemy-wave.md:434` (and `:124`) still asks to revisit "bursts hitting 3 or more"; Hero Rule 17 answered it.

⚠️ **R11. Questions owned by a GDD that does not track them.** Splash against burst (`combat-damage.md:254`, `enemy-wave.md:436`) names Tower, which has no such row. The `drag_slop` floor (`input-gesture-resolver.md:405`) names Data, which has no row.

⚠️ **R12. Retry tapped twice.** `game-state-stage-flow.md:159`: the second tap may reach the new Build; `battle-hud.md:251`: one rebuild, silent on the second tap. Say whether HUD Rule 11's arming blocks it.

⚠️ **R13. A rule cited for what it does not say.** `hero-system.md:288` cites Combat Rule 11 for towers keeping credit; Rule 11 is the tick order, and the credit is Combat's edge case at `:143`.

⚠️ **R14. Flow's `starting_lives` 1 edge case** (`:150`) reads as a live case; Enemy & Wave (`:104`) requires at least 2 on real stages. Mark it fixture-only, as `:149` does.

⚠️ **R15. Input depends on a slot rule not found in Tower.** `input-gesture-resolver.md:260`: a built slot is disabled, and Tower re-enables it when a tower is removed. Tower has no selling at MVP and no stated slot-disable rule was found.

⚠️ **R16. Systems index dependency lists.** Hero's row and map (`systems-index.md:33`, `:102`) leave out Game State; Battle HUD's (`:34`, `:111`) leave out Data & Config. Both GDDs list them as hard upstream.

⚠️ **R17. Two stale citations to evidence.** `hero-system.md:372` credits "walk 240" to the prototype report, which has no 240. `enemy-wave.md:373` sends "stage length" to Pillar 2, MVP and Onboarding; the concept now states it in Core Loop (Short-Term).

⚠️ **R18. The concept's hero-only figure.** `game-concept.md:144`: "hero-only lost at wave 4" (prototype); `hero-system.md:118`: wave 3 (current values). Pillar 2 also says towers-only "can win narrowly once any upgrade exists", but every MVP build now loses without the hero.

Minor wording, not counted: Hero `:38` and `:138` still describe Combat amendments that Combat now contains; Tower `:341` keeps a UX flag that HUD Rule 9's draining bar answered.

---

## Game Design Issues

### Blocking

🔴 **G1. The D1 resolution leaves the concept contradicting itself, and Flow's fallback can never fire.**
- `game-concept.md:120` (amended today) says always-call bots finish "with no cost", and the same paragraph keeps "at the cost of recovery and preparation time".
- Flow Rule 9 (`game-state-stage-flow.md:40`) makes overlapping waves "the fallback if the always-call bot below shows dominance", and its gate (`:261`) is "a towers-only, always-call bot". That bot loses every build (Hero table, W2 to W5), so it can never trigger. The bot that never does worse by calling is the mid-skill always-call bot (single only 5 lives against 2; 2/1/2 at 9 against 7; the rest equal).
- The human check (`hero-system.md:449`) has no pass mark.
- Options for the user: (a) point Flow's trigger at the mid-skill always-call bot and add a human pass mark, such as lives lost in called waves against uncalled ones from HUD Rule 19's per-call log; (b) strike "at the cost of" from the concept and Flow's Summary until a cost is measured; (c) adopt overlapping waves now. Also: a full-game 8-wave stage called every wave runs about 5.0 min, on the band's floor.

### Warnings

⚠️ **G2 (D2). Slow has no measured value.** 3/1/1 (610 gold) and 3/2/0 (630) both score 9; one slow is neutral and 20 gold cheaper, two cost lives (2/1/2: 7). HUD Rule 16's hint "Squares slow fast enemies" recommends it unproven.

⚠️ **G3 (D3). Attention at the 4-system limit, made worse by calling.** Calling every wave removes about 84 s of intermission and pushes all building into waves.

⚠️ **G4 (D4). The share gate is checked on one bot.** Ceiling bot 27% to 42%, perfect aim 28% to 45%, against "none above 40%".

⚠️ **G5 (D5). "Pinned-once must clearly lose" is ambiguous.** Pinned-once wins every mixed build with 4 or 5 lives. If "lose" means the stage, the test fails today; if fewer lives, it passes. The user should say which.

⚠️ **G6 (D6). Back-loaded economy.** Wave 6 pays 174 of 510 bounty (34%) and holds 36% of stage HP.

⚠️ **G7 (D7, corrected). The curve never dips.** HP rises 1.50, 1.32, 1.26, 1.48, 1.64 times; bounty dips at wave 4 (72 to 64) while HP rises, so wave 4 is tighter, not a release.

⚠️ **G8 (D8). Fantasies pull apart.** Flow's Summary sells "a timer they can beat by calling", while HUD Rule 10 says "the bots show no cost the HUD could honestly claim". The concept's result screen still says "each tower type" against HUD Rule 15's Towers / Hero / Burst.

⚠️ **G9. A free call makes intermission dead time with a skip button.** Neither Build nor the cooldown breaks "no wait timers" as written, but a skilled player taps Call every time. Options: give waiting a value, shorten intermission, or reword the anti-pillar.

⚠️ **G10. Mastery pushes toward a hero action game.** The ceiling bot re-pins every 1.5 s, about 220 times a stage, for 42%; the concept says "tactical calm". "Cannot solo" holds (hero alone loses on wave 3). Options: diminishing returns on burst victims, a share gate on the ceiling bot, or a user-signed amendment to the anti-pillar.

⚠️ **G11. The early-call bonus is small and yet calling still pays.** At most 8 per call and 40 per stage (6.0% of 670), under the cheapest tower (50), yet always-calling gained a mid-skill bot up to 3 lives. Ties to G1.

---

## Cross-System Scenario Issues

Scenarios walked: 5 (new; the first run's five are not repeated)
1. First 30 seconds of a fresh battle
2. A slow and a burst on one fast enemy, its bounty enabling an upgrade
3. The last kill and a burst release in one tick, then Intermission
4. A left-handed player pins near the left burst line, then aims
5. A bad accessor call mid-wave

### Blockers

None.

### Warnings

⚠️ **X1. First 30 seconds: the first tower "demonstrates the role" at nothing.** HUD Rule 6 (`battle-hud.md:44`): "the new tower firing at once demonstrates the role"; in Build the clock is stopped and no enemy exists (Flow `:37`, `:41`). Limit it to Wave and Intermission, or give Build its own demonstration.

⚠️ **X2. First 30 seconds: the first pin in Build has no visible response.** The pin sets Walking (`hero-system.md:154`) but walking starts on the first tick (`:36`, Flow `:41`); the ghost is drag-time only (`:54`) and prompt 1 hides on the act. Define a pin marker in Build, or state that the hero waits.

⚠️ **X3. Last kill plus release: the Call glyph has no Telegraphing state.** The glyph has "full ring, wedge or dotted" (`battle-hud.md:54`); a telegraph in flight at wave clear enters Intermission Telegraphing and draws as an empty wedge (`:59`).

⚠️ **X4. The bot script runs a different intermission rule.** `hero-system.md:95`: during intermission "the hero does not walk and a telegraph in flight waits"; Flow (`:39`) and Hero Rule 9 (`:46`) keep the sim ticking, so in the game that telegraph releases on an empty field. Align the script and re-run, or state the gap.

⚠️ **X5. Left hand: Start/Call is 7.2 units (about 5 dp) from the left burst's disc**, against 174.5 for the right hand (`battle-hud.md:121`); Flow wants Start/Call clear of the burst corner (`:216`). "The left hand gives the same table" (`hero-system.md:95`) cannot measure mis-presses. Set a minimum gap for both hands, or place Start/Call per hand.

⚠️ **X6. Bad accessor call: no single ordered Fatal sequence.** Flow Rule 15 (`:49`): Fatal commits, stops the clock, cancels input, emits `phase(Fatal)`; Rule 18's handler (`:62`) lists only latch, stop and skip. Tower (`:78`) and HUD (`:46`) close on `phase(Fatal)`, which would then run inside Tower's accessor call mid-tick. Write one ordered sequence naming who emits and who cancels.

### Info

ℹ️ **X7.** A cancelling drag on an unpinned hero: "keeps its old pin and its walk" (`hero-system.md:55`) has no meaning when Unpinned, and Rule 15 says a mistaken grab shows "ghost and leash" while Rule 1 shows the grab ring only. State what it draws and that it stays Unpinned.
ℹ️ **X8.** A chip tap in the frame the bounty lands returns `NO_GOLD` with no nudge specified (Tower `:72`, `:264`; the arc has one at HUD `:45`).
ℹ️ **X9.** A well-aimed burst beaten to its last enemy by a tower logs `bursts_hit_0` and a 0 in `kills_per_burst[]` (`hero-system.md:60`), lowering the mastery median. Decide whether bursts on an emptied field count.
ℹ️ **X10.** Three readers of the hand (HeroSim, HeroInput, HUD); see R1.
ℹ️ **X11.** Data Rule 7 boot-validates every value, so a mid-wave Fatal comes only from a code defect; in-domain values that break cross-GDD rules (burst damage below fast HP) are caught by CI only.
ℹ️ **X12.** The HUD log writes "one record per finished attempt" (`battle-hud.md:104`); a Fatal attempt is not covered.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| game-concept.md | G1 self-contradiction in Short-Term; R18 hero-only figure and towers-only line; G8 result-screen line | Design Theory, Consistency | Blocking |
| game-state-stage-flow.md | G1 fallback trigger watches a bot that cannot dominate; R7, R8, R9, R12, R14; X6 Fatal sequence | Design Theory, Consistency | Blocking |
| hero-system.md | G1 human pass mark; R1 hand reader; R6, R9, R13, R17; X4 bot script; X7, X9 | Consistency, Design Theory | Warning |
| data-config-pipeline.md | R1 Options missing from Interactions and Rule 10; R7, R11 | Consistency | Warning |
| battle-hud.md | R2, R4, R12; X1, X3, X5; G2 slow hint | Consistency | Warning |
| enemy-wave.md | R3, R5, R8, R9, R10, R11, R17 | Consistency | Warning |
| tower-system.md | R5, R9, R11, R15 | Consistency | Warning |
| combat-damage.md | R10, R11 | Consistency | Warning |
| input-gesture-resolver.md | R9, R11, R15 | Consistency | Warning |
| systems-index.md | R16 | Consistency | Warning |

Plus the first run's open warnings C4, C5 and C7 to C14, and S1 to S4 (see the regression table).

---

## Verdict: FAIL

One blocking issue: G1. The D1 resolution added a contradiction to the concept and left Flow's overlap fallback tied to a bot that can never trigger it. No consistency or scenario blocker remains. The warning count is high (18 new consistency, 10 design, 6 scenario, plus 15 still open from the first run), and most are short text edits.

### Required actions before re-running

1. Rule on G1: re-point Flow Rule 9's trigger at the mid-skill always-call bot and give the human check a pass mark; or strike "at the cost of" from the concept and Flow until a cost is measured; or adopt overlapping waves now.
2. Remove the self-contradiction in `game-concept.md:120` to match that ruling.

---

## Resolution, 2026-11-02: G1 and G5 applied, re-run pending

User decisions: option (a) for G1, and "clearly lose" in Pillar 2 means ending the stage with fewer lives (G5).

- **G1, Flow Rule 9:** the overlap fallback now comes forward if either check fails: the mid-skill always-call bot breaks Hero's Always-call gate (on mixed builds, at most 1 more burst and at most 2 lives gained over mid-skill), or first-playable logs show called waves losing no more lives than waited ones. The towers-only always-call mode stays a gate, and the mid-skill mode joins it. Flow's Deferred row and Open Question now point at Hero's rows.
- **G1, human pass mark:** Hero's "Always-call, humans" row compares lives lost per wave, called against waited at the same wave index, over at least 10 attempts; called waves must lose more on average. Battle HUD Rule 19 now also logs each wave started after a full wait (`seconds_left` 0), so the comparison has data. Hero's Open Question cites the row.
- **G1, concept:** `game-concept.md` Short-Term no longer says "no cost" beside "at the cost of": it calls the cost a target not yet shown and names the two checks. MVP item 7 adds the mid-skill always-call mode.
- **G5:** Pillar 2, Hero's "Pinned once" row and Combat's Pillar 2 row now read "clearly lose" as fewer lives; the Hero row no longer says it may fall short.

The other warnings stay open.

## Resolution, 2026-11-02: Warning batch applied, re-run pending

Applied across all ten design files: R1 to R18 (except R6's ownership is marked, values kept), X1 to X4, X6 to X8, X10 and X12, the first run's C4, C5 and C7 to C14, and S1 to S4. Choices made in autonomous mode, logged: "fired" means `burst_started`; each consumer reads `left_hand` directly at build; outcomes and Pause ask for `cancel()` at the end of the frame, never inside a tick; hit radii are structural constants, not catalogue values; `edge_reject_margin` caps at 36; Combat sits downstream of Flow and takes Data as a soft upstream; a pin in Build keeps its ground ring until the hero walks.

Still open, needing user rulings: G2 to G11 (slow's value, attention load, the share gate's bot, economy pacing, the curve, fantasies, intermission as dead time, mastery toward hero action, the bonus size), X5 (left-hand Start/Call gap, a phone-test question) and X9 (whether a burst on an emptied field counts).
