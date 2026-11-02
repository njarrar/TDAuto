# Cross-GDD Review Report (tenth run)

Date: 2026-11-02
GDDs Reviewed: 8 of 8 present (data-config-pipeline, input-gesture-resolver, game-state-stage-flow, combat-damage, enemy-wave, tower-system, hero-system, battle-hud)
Not read: none
Focus: full (consistency, design theory, scenarios)
Specialists: 7 agents (regression of the ninth run's fixes; rules of Data, Input, Flow, Combat; rules of Enemy & Wave, Tower, Hero, Battle HUD; Acceptance Criteria, Open Questions and Edge Cases; dependencies and cross-references; design theory; scenarios)
Workflow tier: standard for every system GDD (system overrides).
Prior reviews: `gdd-cross-review-2026-11-02.md` and `-02b` to `-02i`, each FAIL and resolved the same day.
Severity rule: Blocking only for two rules an implementer must choose between, a criterion that cannot pass, a gate that cannot be measured, a pointer to nothing, or undefined behaviour the player sees.

> Entity registry is empty, so consistency checks rely on GDD reads only.

> **Coverage.** All four sections the ninth run missed were read. Every pointer row resolves, no two criteria contradict, every dependency pair matches on both sides, the systems index matches every GDD, and every view-allowlist member has a named listener. No file gained an em dash.

---

## Regression check of the ninth run

I2, I3 and K1 to K12 FIXED. I1 PARTIAL (see L1).

---

## Blocking

🔴 **L1. The `call_prompt_shown` mark has no record to land on.** The Call prompt shows only in Intermission (`battle-hud.md:70`); a wave record opens on a `wave_index()` change and is written at its `wave_cleared` (`:106`); the index changes only at `start_next_wave()` (`enemy-wave.md:67`). So no wave record is open while the prompt shows, "the open wave record is marked" (`:106`, criterion 23) marks nothing, and Hero's "Always-call, humans" and "First run (challenge)" rows and HUD's never-call question never leave out a prompted attempt. Found by design theory and the regression check. Change (recommended): keep a per-attempt `call_prompt_shown` flag in the HUD that, once set, is stamped on every later wave record and on the attempt record.

🔴 **L2. Flow and the HUD name different setters for `call_prompt_done`, and different events.** Flow `:26`: "Battle HUD sets [it] on the first call after the Call prompt has shown"; HUD `:70`: "the root sets it on the first call". The table (`:168`) and criterion 16 (`:376`, "after a call it never shows again") say any first call. The root has no gameplay references (Flow Rule 1), so it cannot hear a call. Change (recommended): Battle HUD sets it on the app root, on the first call after the prompt has shown, in all four places.

🔴 **L3. "Pins near a button" cannot be measured.** Hero's Deferred row needs a pin that "lands within 40 of the finger", but the gesture log (Input Rule 13) records the finger's position, not where the pin landed after `clamp_pin`, and Rule 19 logs only a `repins` count; "meant for the hero" is known only on prompted trials. Change (recommended): add the landed pin position to Input Rule 13's gesture log record for a hero drag.

---

## Warnings

⚠️ **M1. Nothing handles `lifecycle_changed`'s "quit requested" or "resized".** Input emits them (`:66`, `:123`); Flow Rule 17 (`:58`) handles focus loss and backgrounding only; the HUD does not listen, so nothing writes the provisional record HUD `:106` promises. Route both through Flow Rule 17 to the HUD, and leave whether the quit waits for the write to the App Lifecycle ADR.
⚠️ **M2. A broken stage scene cannot Fatal "during `build`".** The builder runs with no scene (Flow `:27`, Enemy & Wave `:27`); the wrapper loads `scene_ref` after `build` returns, so Flow `:62`'s "during `build`" path never applies to it, and who writes the record for a Fatal before the views connect is unstated.
⚠️ **M3. Chip refresh during `upgrade`.** Tower fires `gold_changed` then `tower_upgraded` (`:63`) before the chip closes (`:72`), and the HUD re-reads chip costs on `gold_changed` (`:181`); whether `chip_state()` reports the current or next level is undefined.
⚠️ **M4. Interface names.** Flow `:171` and Input `:271` omit `lifecycle_changed(state)`; Flow `:105` writes "start next wave" for `start_next_wave()`; HUD `:194` and `:283` omit lives, result and `call_prompt_done`; Tower `:176`, `:298` and HUD `:189` write `tower_inspected` and `slot_tapped` without `(slot_index)`; HUD Rule 9's `chip_state()` fields are not defined in Tower; Tower's "TowerInput wiring" row (`:400`) omits `upgrade_refused` and `tower_inspected`; HUD `:190` omits `bursts_started`; Enemy & Wave `:151` writes "(Rule 4)" for Flow's rule; Flow `:106` and `:110` do not say which `build`; Flow `:108` and Combat `:77` disagree on the owner column; Input `:71` calls `pin_rect` "fixed" though it is a Stage field.
⚠️ **M5. HUD Rule 10 states the pin cancel more loosely than Hero Rule 14** (`:54`): write "is within 48 at release, or never passed 64".
⚠️ **M6. The Paused resume tap has no input route** (Flow `:58`, HUD `:98`; Input's table `:45-54` has no Paused target or sink). Say the overlay is a Control that takes events before the adapter, or add a sink row.
⚠️ **M7. Criteria and questions.** The expired chip tap (HUD `:263` against Tower `:371`); Tower `:420` (chip clock) is answered; the wrong-disc question is asked at Tower `:417` and HUD `:416`; the snapshot question at Flow `:280` and Enemy & Wave `:438`; human hero share at Combat `:259` and Hero `:423`, `:451`; Flow `:263` and `:266` are already Tower and HUD CI criteria; Input `:390` names a Flow Deferred row that does not exist; HUD `:402` and `:415` field lists are stale; Enemy & Wave `:394` "member 3"; ADR names differ ("Input and Game State ADR", "HUD ADR").
⚠️ **M8. "First run (challenge)" cannot order attempts across launches** (`attempt_seq` resets per launch; launch IDs are random); say file order is the timeline, or add a persistent `tester_seq`.

### Design
⚠️ **M9. `call_prompt_done` lasts one launch**, so the prompt returns on every relaunch for the same tester. Persist it per `tester_id`, or accept.
⚠️ **M10. The Call prompt may teach a free move**; make it depend on "Always-call, humans" passing, not only on it being read.
⚠️ **M11. A hero standing still in Build may read as a failed pin** (playtest risk).

---

## Cross-System Scenario Issues

Scenarios walked: 5 (the Call prompt then Retry; a broken first launch; the first pin in Build; build then upgrade in Intermission; a desktop window close then relaunch). Warnings: L2 (scenario 1), M2 (2), M3 (4), M1 (5). Scenario 3 is clean: `hero_pinned` fires after state is set, prompt 1 hides and prompt 2 shows, and the pin ring waits for the first tick.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| battle-hud.md | L1, L2; M1, M3 to M7 | Consistency | Blocking |
| game-state-stage-flow.md | L2; M1, M2, M4, M7 | Consistency | Blocking |
| input-gesture-resolver.md | L3; M1, M4, M6, M7 | Consistency | Blocking |
| hero-system.md | L1, L3 (row text); M8 | Consistency, Design Theory | Blocking |
| tower-system.md | M3, M4, M7 | Consistency | Warning |
| combat-damage.md | M4, M7 | Consistency | Warning |
| enemy-wave.md | M4, M7 | Consistency | Warning |

---

## Verdict: FAIL

Three blocking issues: L1 and L2 from the ninth fix's Call prompt state, and L3, an older human phone-test gate the log was never built to measure. Each is a one-line rule or one log field.

### Trend across ten runs

Blockers per run: 4, 1, 2, 3, 2, 1, 3, 4, 3, 3. Every blocker since run 5 has come from the human-test machinery (the instructed extension, the Call prompt, its switch and flags, the debug log) or from wording added to describe it. The game rules have produced no blocker since run 4.

### Required actions before re-running

1. L1: a per-attempt `call_prompt_shown` flag stamped on every later record.
2. L2: Battle HUD sets `call_prompt_done` on the root, on the first call after the prompt has shown.
3. L3: log the landed pin position for a hero drag.

## Resolution, 2026-11-02: the three blockers applied; warnings tracked here

User decision: fix L1 to L3 only and move on to `/create-architecture`, with M1 to M11 tracked in this report for the stories and ADRs to settle.

- **L1:** the HUD keeps a per-attempt `call_prompt_shown` flag that, once the prompt first shows, is stamped on every later wave record and the attempt record (HUD Rule 19, criterion 23; Hero's "Always-call, humans" row).
- **L2:** Battle HUD sets `call_prompt_done` on the app root, on the first call after the prompt has shown; a call before it ever shows does not set it (Flow Rule 1, HUD Rule 13, the prompt table, criterion 16).
- **L3:** Input Rule 13's gesture log adds the landed pin position for a hero drag, and Hero's "Pins near a button" row measures from it.
