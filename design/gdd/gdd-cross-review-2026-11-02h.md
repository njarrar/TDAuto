# Cross-GDD Review Report (eighth run)

Date: 2026-11-02
GDDs Reviewed: 8 of 8 present (data-config-pipeline, input-gesture-resolver, game-state-stage-flow, combat-damage, enemy-wave, tower-system, hero-system, battle-hud)
Not read: none
Focus: full (consistency, design theory, scenarios)
Specialists: 7 agents (regression of the seventh run's fixes; rules of Data, Input, Flow, Combat; rules of Enemy & Wave, Tower, Hero, Battle HUD; Acceptance Criteria, Open Questions and Edge Cases; dependencies and cross-references; design theory; scenarios)
Workflow tier: standard for every system GDD (system overrides).
Prior reviews: `gdd-cross-review-2026-11-02.md` and `-02b` to `-02g`, each FAIL and resolved the same day.
Severity rule: Blocking only for two rules an implementer must choose between, a criterion that cannot pass, a gate that cannot be measured, a pointer to nothing, or undefined behaviour the player sees.

> Entity registry is empty, so consistency checks rely on GDD reads only.

> **Coverage.** Flow's and Data's criteria, open questions and edge cases and Input's and HUD's edge cases, missed in run 7, were read. Every cross-reference target exists. The systems index matches every GDD. No two criteria contradict, and every criterion can pass under its own rule. No file gained an em dash.

---

## Regression check of the seventh run

B2, B3, W1, W2, W4 to W6, W8 to W10 and W12 to W15 are FIXED. B1, W3, W7 and W11 are PARTIAL (see H1, H3 and the warnings).

---

## Blocking

🔴 **H1. `instructed` sits only on the attempt record.** `battle-hud.md:106` puts it on the attempt record, but a quit attempt writes none, while its call and wave records are kept. Hero's "Always-call, humans" row (`hero-system.md:430`) and HUD's never-call question (`:415`) read call and wave records, so a quit instructed attempt leaks into the free data. Change: every record kind carries `instructed`.

🔴 **H2. The Call prompt's switch has no name, owner or log field.** The prompt shows "only if the never-call gate has failed" (`battle-hud.md:70`, `:415`; criterion 16 at `:376`), but no flag or data source exists, and Rule 19 records no field for whether the prompt was on or shown, so prompted calls would mix into Hero's "Always-call, humans" ("by choice") and "First run (challenge)" rows. Change: name a switch (for example `call_prompt_enabled` on the Options record, default false, set by the user after first playable) and log `call_prompt_shown` on attempt and call records; those attempts stay out of both human rows.

🔴 **H3. A pointer names a row that no longer exists.** `combat-damage.md:242` points at Tower's Deferred row "`burst_spike`, L11, intermission, bypass"; that row is now "`burst_spike`, bypass" (`tower-system.md:397`). Change: use the current name.

🔴 **H4. A refused chip tap cannot reach the HUD.** TowerInput owns the chip and calls `upgrade` itself (`tower-system.md:67`, `:72`); the HUD only reads `chip_state()` (slot, elapsed, level; `battle-hud.md:50`). Nothing tells the HUD the tap returned `NO_GOLD`, so the nudge or blink promised at HUD `:50`, `:335` and Tower `:338` cannot fire. Change: add a refusal flag to `chip_state()`, or a signal `upgrade_refused(slot)`, named in both GDDs.

---

## Warnings

### Consistency
⚠️ **J1. Rule 19's schema.** A waited wave is "the same record with `seconds_left` 0", but its `kind` (call or wave) is not stated, and Hero `:430` reads lives lost from "per-wave records" while lives lost is listed on the call record. Spending during Wave N fits no bucket (add "and in Wave N"). Whether the `instructed` toggle persists across a relaunch is unstated. Whether the Call prompt is final per battle or per launch is unstated (`:70`, criterion 16).
⚠️ **J2. The Fatal-at-`build` record and `attempt_seq` have no owner.** On Retry the old HUD is gone and the new one never connects (Flow `:37`, `:54`), so no writer exists; `attempt_seq` and the launch ID must survive Retry, but Flow Rule 1 keeps only the root and the catalogue (`:26`). Recommended: the app root owns the log counters and that record.
⚠️ **J3. The blink and the prompt panel.** Tower `:338` lacks "on the disc or button, never on a panel"; HUD `:335` turns the prompt pulse into a blink while the prompt is a panel (`:119`). Say the prompt blink is on the text only.
⚠️ **J4. `slot_positions` still has two sources.** Tower `:171`, `:288` and Enemy & Wave `:28` say Tower reads it from Data or directly; Data `:134`, Enemy & Wave `:153` and Tower `:172` say Enemy & Wave serves it.
⚠️ **J5. Combat names functions it never defines.** `apply_slow` and `is_dead` are listed as Combat's API (`:74`, `:76`) and Tower relies on `apply_slow(strength, seconds)` (`tower-system.md:89`, `:363`), but Combat Rules 7 and 10 define neither. Who filters "the first unslowed enemy" is unclear (Combat `:43`, Tower `:46`). Combat `:45` cites "Flow's view allowlist", which Flow (`:64`) never lists.
⚠️ **J6. Hero Rule 2 says a swallowed Call tap shows "ghost and leash"** (`:36`), but a tap never becomes a drag, so it shows nothing (Rules 14, 15; the Drag row `:323`). Decide what it shows, and fix Rule 2.
⚠️ **J7. Citations and names.** Input `:213` cites "Hero Rules 14 and 15"; the pin-or-cancel rules are 13 and 14. HUD `:401` says "First run row"; its name is "First run (challenge)". HUD `:273` says "Play again" where Flow calls the action Retry.
⚠️ **J8. One owner per row.** The `drag_slop` floor question sits in Data `:264` and Input `:404`; the re-baseline task in Flow `:265` and `:280`; Flow `:259` "Listener test", Data `:245` "Rule 6 end to end" and Data `:246` "never-cache" name two or more owners. Data `:256` is answered but still open; Input `:413` sits under Closed with no answer.
⚠️ **J9. Interface names on one side only.** Enemy & Wave `:153` lacks `gold_upper_bound`; HUD `:189`, `:284` list `slot_tapped`, which Tower's HUD rows lack; HUD `:285` lists Hero "counters", which Hero's HUD rows lack; Enemy & Wave `:152` lacks `spawn_id`, the reap and test `deliver`; Flow `:178` gives Tower "the bots' `build` command", which Tower and Flow `:106` lack; the tick slot is on one side only for Combat `:74` and Tower, Hero `:171` and Combat, and Flow `:105` and Enemy & Wave `:151` (with `to_ticks`); Flow `:108` and Combat `:77` disagree on "wires" against "builds" and Status ticking; Tower `:177` lacks `burst_spike` and the gates.

### Design
⚠️ **J10. The Call prompt nags on every Retry** if it is final per battle, and it pushes calling while "Always-call, humans" is still open, which may promote a free move. Recommended: switch it on only after that row passes, and make it final per launch.
⚠️ **J11. The aim magnet changes more than Share.** It also changes the "Radius 70" miss rate, `best_victims`, "Burst outcome" and "Pinned once". Re-run those rows too, or mark results non-comparable across the build hash.

### Info
The prompt can say "Tap Call" while Start/Call is Disabled or still Arming; it also leaves when the countdown ends, a quiet exception to "never on a timer".

---

## Cross-System Scenario Issues

Scenarios walked: 5 (the Call prompt re-walk; Retry then a Fatal during `build`; an instructed attempt quit and relaunched; refused presses under Reduce Motion; a walking hero over Start/Call). Blockers: H2 (scenario 1), H4 (scenario 4), H1 (scenario 3). Warnings: J2 (scenario 2), J3 (scenario 4), J6 (scenario 5). Scenario 2's Flow rules hold: no `phase(Build)`, the partial battle is discarded, and the fatal screen absorbs input.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| battle-hud.md | H1, H2, H4; J1, J3, J7, J9, J10 | Consistency, Design Theory | Blocking |
| tower-system.md | H4; J3, J4, J5, J9 | Consistency | Blocking |
| combat-damage.md | H3; J5, J9 | Consistency | Blocking |
| hero-system.md | H1, H2 (row text); J6, J9, J11 | Consistency, Design Theory | Warning |
| game-state-stage-flow.md | J2, J8, J9 | Consistency | Warning |
| data-config-pipeline.md | H2 (Options field); J8 | Consistency | Warning |
| enemy-wave.md | J4, J9 | Consistency | Warning |
| input-gesture-resolver.md | J7, J8 | Consistency | Warning |

---

## Verdict: FAIL

Four blocking issues. Three come from the last two rounds of human-test and Reduce Motion rulings (H1, H2, H4); one is a renamed row (H3). Each is a one-line fix.

### Trend across the eight runs

Blockers per run: 4, 1, 2, 3, 2, 1, 3, 4. The cross-system rule conflicts from the first runs are gone; nearly every blocker since run 5 comes from the machinery added to measure the early-call question with humans (the instructed extension, the Call prompt, the per-wave log) and to cover Reduce Motion. Each round of fixes adds new surface, and the reviews find the edges of it. The design itself (rules, numbers, tick order, input, outcomes) has been stable since run 4.

### Required actions before re-running

1. H1: put `instructed` on every Rule 19 record kind.
2. H2: name the Call prompt switch and log when it is on or shown.
3. H3: correct Combat `:242`'s pointer.
4. H4: give TowerInput a refusal flag or signal the HUD can read.
