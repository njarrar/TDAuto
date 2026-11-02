# Cross-GDD Review Report (seventh run)

Date: 2026-11-02
GDDs Reviewed: 8 of 8 present (data-config-pipeline, input-gesture-resolver, game-state-stage-flow, combat-damage, enemy-wave, tower-system, hero-system, battle-hud)
Not read: none
Focus: full (consistency, design theory, scenarios)
Systems Covered: the 8 MVP battle systems, against `game-concept.md`, `systems-index.md`, `design/art/art-bible.md` and `prototypes/hero-pin-concept/`
Specialists: 7 agents (regression of the sixth run's fixes; rules of Data, Input, Flow, Combat; rules of Enemy & Wave, Tower, Hero, Battle HUD; Acceptance Criteria, Open Questions and Edge Cases; dependencies and cross-references; design theory; scenarios)
Workflow tier: standard for every system GDD (system overrides).
Prior reviews: `gdd-cross-review-2026-11-02.md` and `-02b` to `-02f`, each FAIL and resolved the same day.
Severity rule for this run: Blocking only when two rules contradict so an implementer must pick one, a criterion cannot pass, a gate cannot be measured from what is logged, or behaviour the player sees is undefined.

> Entity registry is empty, so consistency checks rely on GDD reads only.

> **Coverage.** This run read the criteria, open questions and edge cases of Combat, Enemy & Wave, Input and Tower that the sixth run missed. Not reached: Flow and Data criteria, open questions and edge cases, and Input and HUD edge cases (all read in runs 5 and 6); the 2c element check (every target file exists; every element was confirmed in runs 5 and 6). No fixture other than Hero criterion 32 places a press inside the hero's disc and expects a non-hero result.

---

## Regression check of the sixth run

17 of 18 items FIXED (R1 to R9, S1 to S8). S9 is PARTIAL (see B2). No file gained an em dash.

---

## Blocking

🔴 **B1. Instructed attempts cannot be told apart in the log.** Hero's "Always-call, humans" row (`hero-system.md:430`) analyses instructed attempts apart from free ones and leaves them out of the never-call rate and the First run row; Battle HUD's never-call question (`battle-hud.md:415`) counts "only free attempts". Rule 19's records (`:106`) hold a launch ID, the build hash and `attempt_seq`, with no field that marks an attempt as instructed. Three gates depend on a split the log cannot make.
Change (recommended): add an `instructed` field (true or false) to the attempt record, set from a debug toggle the tester is told to turn on for the extension.

🔴 **B2. One Reduce Motion rule was missed.** `hero-system.md:354`: the Locked button's press nudge is "skipped under Reduce Motion". HUD `:335` and Tower `:338` make the nudge a 120 ms alpha blink so "every refused tap still answers on the next frame". After the first pin, the prompt pulse no longer applies, so a Locked press under Reduce Motion gets no response, against Game Feel (`battle-hud.md:328`).
Change: Hero's Locked nudge becomes the same 120 ms alpha blink, citing HUD's Reduce Motion line.

🔴 **B3. The separate Call prompt slot is undefined.** The S5 fix made it "a separate slot" (`battle-hud.md:70`, `:170`, `:415`), but it has no screen position (the layout has one Prompt panel, `:119`), no rule for when prompt 2 also applies, no trigger counter ("after the first burst": `bursts_started` or a release?), and no hide rule; Rule 13's title is "One prompt line" (`:63`); and the code-review check "Start/Call has no pulse or advice once armed" (`:408`) forbids advice shown while Call is armed. Telling a player with no towers to call early is also poor advice.
Change (recommended): the Call prompt shares the one Prompt panel and shows only when no Rule 13 prompt applies (so prompt 2 wins), triggers on `bursts_started` of at least 1 and at least one tower built, hides on the first call ("on the act") and is final after; `:408` is limited to the button itself. Add a criterion.

---

## Warnings

### Consistency
⚠️ **W1. Rule 19's own text and criteria lag the rule.** Its headline (`:106`), criterion 23 (`:383`) and the Deferred row (`:402`) do not list the wave 1 record, the Fatal record, the Paused exclusion or the per-tick cache. "Gold spent per wave" does not say which wave gets spending done in Build or an Intermission (needed by Tower's wave-6 check, `tower-system.md:415`; recommended: spending before wave N counts to wave N). A per-call record and a per-wave record both key on `wave_index`, so the reader's "last per key" drops one (give the per-call record its own kind field). Seconds to first pin or burst that never happen are undefined (recommended: null). Burst readiness at a call has no type or capture time (recommended: the burst state at the call).
⚠️ **W2. A Fatal during `build` (after Retry) has no defined record.** There is no completed tick and maybe no HUD. Recommended: it writes one Fatal record with empty counters under a new `attempt_seq` (a failed build still raises it, so it never overwrites the previous attempt's record).
⚠️ **W3. The alpha blink meets the art bible's "panel opacity never animates"** (`art-bible.md:166`). Say the blink is on the disc or button, not a panel.
⚠️ **W4. HUD Rule 11 says "A phase begins on each `phase` signal into it"** (`:55`), which catches a resume; add "except one that returns from Paused".
⚠️ **W5. Hero Rule 2's "each can always be pressed at its centre"** (`:36`) holds for a pinned hero only; a walking hero can cover Start/Call's centre and silently take a Call tap. Restrict the claim to a pinned hero; the eaten tap needs no extra feedback (the hero's ghost and leash show).
⚠️ **W6. The slow type line has no string** (`battle-hud.md:94`), though Rule 16 fixes every string. Recommended: "Next try: squares slow the fast" once "Slow value" passes.
⚠️ **W7. `slot_positions` has two sources:** Data's Tower row (`:134`) says directly from Stage; Enemy & Wave (`:153`) and Tower (`:172`) say Enemy & Wave serves it. Pick one (recommended: Enemy & Wave serves it, as Tower says; Data's row drops it).
⚠️ **W8. Input asks Hero to keep pins out of the gesture insets** (`input-gesture-resolver.md:71`), but `pin_rect` (`hero-system.md:81`) is a fixed worst case with no insets; a bottom inset over 72 would let a pin into it. Say `pin_rect` is safe for bottom insets up to 72 and larger ones go to the Mobile Platform GDD.
⚠️ **W9. Wording.** Data `:55` words the margin bound differently from Input (`:71`, `:209`); Combat `:41` points to a Data Open Question that no longer exists; Combat `:75` names one targeting helper where Hero uses `nearest_in` and `all_in_radius`; Flow `:49` and `:54` omit Rule 6's Fatal-during-`build` exception; HUD criterion 14 (`:374`) does not say which phase ends.
⚠️ **W10. Interface names missing on one side.** Flow's Tower row (`:178`) lacks `wave_called_early(seconds_left)`; Tower's Dependencies Flow row (`:292`) lacks `enemy_killed(bounty)`; Flow `:177` and Enemy & Wave `:318` lack `wave_cleared`, `waves_complete`, `enemy_leaked`; Enemy & Wave's HUD Interactions row (`:155`) lacks `wave_index()`, `got_through_by_type()`, `targets()`; HUD's Tower row (`:189`) and Tower `:176`, `:298` lack `gold()`, `gold_changed`, `slot_state`; HUD `:190` and Hero `:175`, `:309` say "state" or "Rule 16's reads" for the named reads; Hero's Input row (`:170`) lacks `drag_cancelled`, `idle`; Combat's Enemy & Wave Interactions row (`:76`) lacks the reap, `spawn_id`, test `deliver`; Combat `:74-75` say "helpers" for `first_in`, `nearest_in`, `all_in_radius`, and Tower `:173` lacks its tick slot.
⚠️ **W11. Rows with two owners or duplicates.** Combat `:242` "Bypass" (Tower, Hero) duplicates Tower `:397` and Hero `:435`; Enemy & Wave `:418` and `:420` split owners with Tower, whose halves are Tower CI 28; Enemy & Wave `:421` "Never cache" names no Enemy & Wave owner and duplicates Tower `:399`; L11 and intermission sit in both Enemy & Wave `:416` and Tower `:397`; Combat `:246` adds a `burst_spike` condition Hero's row (`:426`) lacks; Combat `:244` repeats "Hero's Deferred criteria hold the thresholds"; the tick-order question sits in both Combat `:256` and Enemy & Wave `:440`; Tower `:412` names two owners; Tower `:414` (solved build) is gated by Hero's "Dominant build" row. One owner per row, pointers elsewhere.
⚠️ **W12. Stale or unruled rows.** Enemy & Wave `:415` says wave 2's 9 s gap "may fail this" with no fallback (recommended: retune wave 2's packet); Combat `:147` still says "Hero owns whether the cooldown is spent", which Hero has settled (`:278`, criterion 8); closed rows still sit in Enemy & Wave `:433` and Input `:402` (move them under a "Closed" note).

### Design
⚠️ **W13. The instructed group has no pass rule of its own**, and testers told to call at the first second copy the always-call bot. Recommended: report the instructed group's result without gating; only free attempts gate.
⚠️ **W14. A tester who did the extension knows about Call**, so their later free attempts are not unprompted. Recommended: run the extension last for each tester.
⚠️ **W15. The aim magnet (Hero `:448`) raises share while the victim cap lowers it.** Recommended: re-run the Share row after the magnet goes in, as after the cap.

---

## Cross-System Scenario Issues

Scenarios walked: 5
1. The hero walks across Start/Call during Intermission while the player taps Call
2. A telegraph in flight when wave 5 clears, then an instant call
3. A loss led by fast enemies with one slow built and no burst fired
4. The never-call gate fails, so the Call slot appears while prompt 2 also applies
5. Retry, then a Fatal during the new `build`

Blockers: B3 (scenario 4). Warnings: W5 (scenario 1), W1 (scenarios 2 and 3), W2 (scenario 5).
Info: scenario 2's release always lands before the 300 ms arming ends, so the Call label and the paid bonus agree on +8; scenario 3's next-try order is right (the burst line wins, matching prompt 3).

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| battle-hud.md | B1 `instructed` field; B3 Call slot; W1, W2, W3, W4, W6, W9, W10 | Design Theory, Consistency | Blocking |
| hero-system.md | B1 pass text; B2 Reduce Motion nudge; W5, W10, W13, W14, W15 | Consistency, Design Theory | Blocking |
| combat-damage.md | W9, W10, W11, W12 | Consistency | Warning |
| enemy-wave.md | W7, W10, W11, W12 | Consistency | Warning |
| tower-system.md | W1, W7, W10, W11 | Consistency | Warning |
| game-state-stage-flow.md | W9, W10 | Consistency | Warning |
| input-gesture-resolver.md | W8, W9, W12 | Consistency | Warning |
| data-config-pipeline.md | W7, W9 | Consistency | Warning |
| design/art/art-bible.md | W3 | Consistency | Warning |

---

## Verdict: FAIL

Three blocking issues, all from the sixth fix's design rulings and each a short addition: a log field (B1), one missed Reduce Motion line (B2), and a full spec for the Call prompt slot (B3). No rule in one system contradicts a rule in another, the dependency graph matches, and every other criterion can pass.

### Required actions before re-running

1. B1: add an `instructed` field to Rule 19's attempt record.
2. B2: make Hero's Locked nudge a 120 ms alpha blink under Reduce Motion.
3. B3: give the Call prompt a position, priority, trigger, hide rule and criterion, and limit `:408` to the button.

## Resolution, 2026-11-02: the three blockers and every warning applied, re-run pending

- **B1:** Rule 19's attempt record carries `instructed` (true or false), set from a debug toggle. Free attempts gate first; only if they are inconclusive does the instructed group gate, on its own and labelled as scheduled calls; the never-call rate and First run use `instructed` false only; each tester runs the extension last.
- **B2:** Hero's Locked nudge is a 120 ms alpha blink on the button under Reduce Motion.
- **B3:** the Call prompt shares the one Prompt panel, shows only when no other prompt applies, needs `bursts_started` of at least 1, a built tower and a failed never-call gate, and hides for good on the first call; the "no advice once armed" check covers the button only; criterion 16 tests it.
- **W1 to W15:** applied as listed: every Rule 19 record has a `kind` field in the reader's key, spending before wave N counts to wave N, a failed build raises `attempt_seq` and writes an empty Fatal record, the blink is never on a panel (art bible §7 says so too), Rule 11 excludes a resume, Rule 2's centre promise holds for a pinned hero, the slow type line has its string, `slot_positions` comes from Enemy & Wave only, `pin_rect` covers bottom insets up to 72, interface names match on both sides, and each duplicated row has one owner.
