# Cross-GDD Review Report (ninth run)

Date: 2026-11-02
GDDs Reviewed: 8 of 8 present (data-config-pipeline, input-gesture-resolver, game-state-stage-flow, combat-damage, enemy-wave, tower-system, hero-system, battle-hud)
Not read: none
Focus: full (consistency, design theory, scenarios)
Specialists: 7 agents (regression of the eighth run's fixes; rules of Data, Input, Flow, Combat; rules of Enemy & Wave, Tower, Hero, Battle HUD; Acceptance Criteria, Open Questions and Edge Cases; dependencies and cross-references; design theory; scenarios)
Workflow tier: standard for every system GDD (system overrides).
Prior reviews: `gdd-cross-review-2026-11-02.md` and `-02b` to `-02h`, each FAIL and resolved the same day.
Severity rule: Blocking only for two rules an implementer must choose between, a criterion that cannot pass, a gate that cannot be measured, a pointer to nothing, or undefined behaviour the player sees.

> Entity registry is empty, so consistency checks rely on GDD reads only.

> **Coverage.** Combat's and Tower's criteria, missed in run 8, were read. Every cross-reference target exists, every pointer row resolves, the systems index matches every GDD, and no two criteria contradict. No file gained an em dash. Not read this run: the edge cases of Enemy & Wave, Flow, Data and Input (read in runs 6 to 8).

---

## Regression check of the eighth run

H1 to H4 FIXED. J1 to J4, J6 to J8, J10 and J11 FIXED. J5 and J9 PARTIAL (see K4, K7).

---

## Blocking

🔴 **I1. A wave record cannot know `call_prompt_shown` when it is written.** HUD Rule 19 (`battle-hud.md:106`) defines it as "true if the Call prompt showed at least once in that attempt", but a wave record is written at its wave's `wave_cleared`, before a later prompt can show, and a quit attempt has no attempt record to join. Hero's "Always-call, humans" row (`hero-system.md:430`) cannot leave out prompted attempts. Change (recommended): the reader leaves out an attempt if any of its records has `call_prompt_shown` true, and the first time the prompt shows, the open wave record is marked true.

🔴 **I2. "Final per launch" has no owner across a Retry.** The Call prompt "is final per launch after the first call" (`battle-hud.md:70`, `:168`; criterion 16 at `:376`), but Retry rebuilds the HUD (Rule 3, `:35`), Rule 13 says "nothing has to survive a rebuild" (`:63`), and Flow Rule 1 keeps only the root, the two log counters and the catalogue (`game-state-stage-flow.md:26`). Found by the scenario walk and rules slice 2. Change (recommended): the app root holds a third value, `call_prompt_done`, set on the first call after the prompt has shown; Flow Rule 1 lists it, and HUD Rule 13 names it as the exception.

🔴 **I3. The view allowlist rule excludes signals two GDDs put on it.** Flow (`:64`) now defines the allowlist as the signals a system's Interactions table marks as read by a view. Tower (`:103`) puts `tower_built` and `tower_upgraded` on it and Hero (`:60`) puts `hero_pinned` on it, but no Interactions row marks them as read by a view, and nothing listens to them, so Tower's listener test (criterion 28, `:390`) fails on them. Also, Flow lists TowerInput's `slot_tapped`, `tower_inspected` and `upgrade_refused`, which live only in the wrapper where headless wiring tests cannot see them (Tower `:103`). Change (recommended): add the Battle HUD (and the Vertical Slice VFX system) as listeners of `tower_built`, `tower_upgraded` and `hero_pinned` in both sides' Interactions rows, and mark the TowerInput signals in Flow's list as wrapper-only, proved by Tower's story test (`:400`).

---

## Warnings

⚠️ **K1. Log details.** A provisional wave record (focus loss) has no field saying so, so a quit wave's partial lives look complete (add `final`). A desktop window close without a focus loss is unstated. Flow Rules 1 and 18 say the root writes the Fatal record for any Fatal during `build`; HUD Rule 19 says "after Retry" only (a broken first launch is the open case). The log has no `tester_id`, though First run (challenge) is per tester. The never-call question (HUD `:415`) filters `instructed` but not `call_prompt_shown`.
⚠️ **K2. Turning the Call prompt on can empty First run (challenge)**, since nearly every attempt then shows it. Recommended: close First run before the switch, or drop that exclusion from it.
⚠️ **K3. The chip under Reduce Motion.** HUD `:335` and Tower `:338` say "disc or button"; HUD `:50` says the chip. Write "disc, chip or button".
⚠️ **K4. Tower criterion `:363` still logs `apply_slow(0.5, 1.0)`** with two arguments; Combat Rule 7 defines `apply_slow(enemy, strength, seconds)`.
⚠️ **K5. Hero Rule 2 says a swallowed Call tap "goes to the hero"**; Input Rule 4 sends a tap only to the tap target. The press shows the hero's leash and the tap reaches Start/Call, which the HUD ignores. Align the wording.
⚠️ **K6. Flow `:49` writes "(Rule 13)" for Enemy & Wave's rule**, which reads as Flow's own; write "Enemy & Wave Rule 13". The adapter's lifecycle signal (Flow `:71`, `:104`; Input `:123`) has no name, though Flow's wiring test needs one.
⚠️ **K7. Interface names.** Tower's Flow row (`:174`) lacks the bots' `build` command and "builds, ticks"; Flow's Tower rows (`:106`, `:178`) lack "builds and ticks"; Combat's Flow row (`:77`) and Flow `:108` differ; Tower `:171` lacks `is_tower(id)`; Tower `:176`, `:298` write `upgrade_refused` without its argument; `slot_state` is written three ways (use `slot_state(slot_index)`); Data's Flow rows (`:131`, `:181`) lack the failure handler; HUD's Settings row (`:298`) lacks `call_prompt_enabled` or a reason.
⚠️ **K8. Notes out of date.** "All eight MVP GDDs list this one" (Combat `:175`, Enemy & Wave `:330`) is false for Input; Input `:278` and Flow `:185` still say "already list" or "must list when authored".
⚠️ **K9. Owners and duplicates.** Input `:404` says it owns the `drag_slop` question but its owner column says Data; Flow `:258` and `:260` give Combat two rows Combat lacks; Hero `:451` and `:461` ask the 45% question twice; bypass is checked at Tower `:397` and Hero `:435` (Hero should keep only the burst-state half); Tower `:401` says an unaffordable disc "does nothing" against the nudge; Flow `:280` is answered and should be closed.
⚠️ **K10. Combat `:257`'s median.** It quotes 26%, 33%, 27% and 25% with a median of 26.2%; the median of those rounded figures is 26.5%. Say they are rounded and 26.2% is from the unrounded values.

### Design
⚠️ **K11.** With the prompt off by default, a player may not find that the countdown can be cut short until the gate passes; note it against the anti-idle pillar.
⚠️ **K12.** A level-2 slow tower never picks an enemy carrying a weaker slow while an unslowed one is in range; the "Slow value" bot row should measure it.

---

## Cross-System Scenario Issues

Scenarios walked: 5 (a refused chip tap under Reduce Motion; the Call prompt then a Retry; build, called and waited waves then a quit; a slow tower facing two slowed enemies; a press on a walking hero over Start/Call). Blockers: I2 (scenario 2). Warnings: K1 (scenario 3), K3 (scenario 1), K5 (scenario 5). Scenario 4 is consistent end to end.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| battle-hud.md | I1, I2, I3; K1, K3, K7 | Consistency | Blocking |
| game-state-stage-flow.md | I2, I3; K1, K6, K7, K8, K9 | Consistency | Blocking |
| tower-system.md | I3; K3, K4, K7, K9 | Consistency | Blocking |
| hero-system.md | I1, I3; K2, K5, K9 | Consistency, Design Theory | Blocking |
| combat-damage.md | K7, K8, K9, K10 | Consistency | Warning |
| data-config-pipeline.md | K7 | Consistency | Warning |
| enemy-wave.md | K8 | Consistency | Warning |
| input-gesture-resolver.md | K6, K8, K9 | Consistency | Warning |

---

## Verdict: FAIL

Three blocking issues, all from the eighth fix: the `call_prompt_shown` field (I1), the per-launch Call prompt state (I2), and the new allowlist definition (I3). Each is a one-line rule.

### Trend across nine runs

Blockers per run: 4, 1, 2, 3, 2, 1, 3, 4, 3. Since run 5 every blocker has come from the human early-call test machinery, the Call prompt, the debug log and the allowlist wording, each added by the previous round's fix. The game rules have not produced a blocker since run 4.

### Required actions before re-running

1. I1: the reader leaves out any attempt with a record marked `call_prompt_shown`, and the open wave record is marked when the prompt first shows.
2. I2: the app root holds `call_prompt_done` across Retry.
3. I3: make the allowlist's members and their listeners agree, and mark the TowerInput signals wrapper-only.

## Resolution, 2026-11-02: the three blockers and every warning applied, re-run pending

- **I1:** the open wave record is marked `call_prompt_shown` when the prompt first shows; the reader leaves out an attempt if any record is marked.
- **I2:** the app root holds `call_prompt_done` across Retry (Flow Rule 1), the one exception to HUD Rule 13's "nothing has to survive a rebuild".
- **I3:** Battle HUD listens to `tower_built`, `tower_upgraded` and `hero_pinned` (prompt 1 hides on the first pin), and both sides' rows say so; Flow lists the sim members and marks TowerInput's signals wrapper-only, proved by Tower's "TowerInput wiring" row.
- **K1 to K12:** applied: `final` and `tester_id` on records, a quit request writes provisional records, a broken first launch writes a Fatal record, First run is read before the switch, "disc, chip or button", `apply_slow(enemy, 0.5, 1.0)`, Hero Rule 2 matches Input Rule 4, `lifecycle_changed(state)` named in Input and Flow, interface names and notes aligned, duplicate rows made pointers, Combat's rounded figures labelled, the anti-idle pillar notes Call is always on screen, and the Slow value bot reports skipped weaker slows.
