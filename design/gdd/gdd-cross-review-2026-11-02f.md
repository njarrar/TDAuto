# Cross-GDD Review Report (sixth run)

Date: 2026-11-02
GDDs Reviewed: 8 of 8 present (data-config-pipeline, input-gesture-resolver, game-state-stage-flow, combat-damage, enemy-wave, tower-system, hero-system, battle-hud)
Not read: none
Focus: full (consistency, design theory, scenarios)
Systems Covered: the 8 MVP battle systems, against `game-concept.md`, `systems-index.md`, `design/art/art-bible.md` and `prototypes/hero-pin-concept/`
Specialists: 7 agents (regression of the fifth run's fixes; rules of Data, Input, Flow, Combat; rules of Enemy & Wave, Tower, Hero, Battle HUD; Acceptance Criteria, Open Questions and Edge Cases; dependencies and cross-references; design theory; scenarios)
Workflow tier: standard for every system GDD (system overrides).
Prior reviews: `gdd-cross-review-2026-11-02.md` and `-02b` to `-02e`, each FAIL and resolved the same day.

> Entity registry is empty, so consistency checks rely on GDD reads only.

> **Coverage.** This run read Data & Config's criteria, open questions and edge cases and the edge cases of Hero, HUD and Input, which the fifth run missed. Not reached: the criteria, open questions and edge cases of Combat and Enemy & Wave, Tower's edge cases and Input's criteria and open questions (all read in earlier runs), the art-bible rows for slot, Start/Call and chip, and a few long lines the tools cut short.

---

## Regression check of the fifth run

All of P1 to P17 and Q1 to Q7 are FIXED. No file gained an em dash. Every scenario touching the new lifecycle rules (a Fatal outside a tick, the Start/Call states, the per-wave log, the halted button, `phase(Build)`) now walks clean.

---

## Consistency Issues

### Blocking

🔴 **R1. Hero criterion 32 cannot pass.** `hero-system.md:414`: "Start/Call at C with the hero's centre at C + (30, 0): ... a press at C calls." C is 30 from the hero, inside its 56-unit grab disc (criterion 15, `:395`), and Hero's edge case (`:271`) and Battle HUD Rule 10 say a press inside the hero's disc calls nothing. HUD criterion 9 (`battle-hud.md:365`) tests the same call with the hero 60 away.
Change: press at C + (−40, 0) (70 from the hero), or put the hero at C + (60, 0), to match HUD criterion 9.

### Warnings

⚠️ **R2. Leftover wording from the fifth fix.**
- Hero `:282` still says the HUD keeps the button's look "from the outcome snapshot"; HUD Rule 12 (`:59`) now says the last completed tick. Rule 12's own reason ("so a halted telegraph never shows as an empty wedge") is false when the last tick was Telegraphing: drop the clause, or name a separate halted look.
- HUD edge case `:253` and criterion 14 (`:370`) say Start/Call "enables" when the arc closes; the table (`:154`) says it re-arms (a new 300 ms). Rule 6 (`:44`) says "an arc open across a phase change keeps it so", against the table's "phase ends → Hidden".
- `phase(Build)`: HUD Rule 11 (`:55`, `:151`) says "the builder emits"; Flow Rule 6 (`:37`) says Flow emits, and Rule 3 (`:28`) says the builder only wires. Flow Rules 15 and 16 (`:49`, `:54`) omit the headless case. Say whether it fires when Fatal latches during `build`.
- Input `:293` still says "unanimated"; `:213` says "a drag from a hero on a slot pins"; `:173` omits the 48 return; `:36` says the hero's centre updates when it re-pins, where Hero says while it walks.
⚠️ **R3. Rule 19 contradicts itself on wave 1.** A per-wave record opens "when `wave_index()` changes", which includes wave 1, yet "Wave 1, started from Build, has no record" (`:104`). Hero's attention measure (`:449`) needs wave 1's `repins` and Wave seconds. Open wave 1's record without call or wait fields. Also: say whether Wave seconds exclude Paused; give the attempt and Fatal records a reader key (they have no `wave_index`); assign who caches the reads the Fatal record uses (Flow `:62`), most likely the HUD after every completed tick; and point the HUD's "Human log" deferred row (`:398`) at criterion 23.
⚠️ **R4. Two comparisons for the slow-hint gate.** HUD `:92` and `:410`: "at least one more life than none"; Hero `:424`: "than the same build with that slow swapped for a single tower". Use Hero's.
⚠️ **R5. `bursts_emptied_by_kill` says leaks "died"** (Hero `:60`); a leak is not a death. Say "died or leaked". The phone formula (`:432`) needs `bursts_emptied_by_kill` to be a subset of `bursts_hit_0`; say so, and test the split (one kill-emptied case, one walk-out case).
⚠️ **R6. Missing criteria for the fifth fix.** Nothing tests Arming or Armed going to Disabled when an arc opens, or the new arming on close (HUD criteria 4, 12 to 14); the halted button look (criterion 15); or the before-first-slot check (Flow: Intermission with 1 tick left, a Fatal from a command's read, then ticks, expecting only `phase(Fatal)` and no new start). Flow criterion 1 (`:234`) should connect the recorder before `build`.
⚠️ **R7. Rows that restate an owner's text.** Flow Deferred `:264` repeats Hero's always-call pass text; the burst-state bonus check sits at Flow `:263`, Tower `:398` and Hero `:435`; Tower's "Is the early-call bonus noticed?" (`:415`) overlaps Tower `:412` and HUD `:411`. Make them pointers.
⚠️ **R8. Data criterion 3 tests none of the slop bounds** that Input's edge case (`:234`) says Data rejects (8 to 30, 16 to 34, `tap_slop` at most `drag_slop`). Add the boundary cases, or say the cross-field check is Input's `validate()`.
⚠️ **R9. Interface names missing on one side.** HUD's Interactions row for Flow (`:190`) lacks `lives_changed`, `in_build()` and `intermission_left`. Tower's for Flow (`:174`) lacks `phase` (chip) and the kills-to-gold wiring. Combat's Tower and Hero rows (`:168-169`, `:74-75`) lack `attack_fired`, and Tower's lacks `speed_factor`. Input's HUD rows (`:127`, `:274`) lack the Start/Call disc and its priority, and `tap`, `drag_started`, `idle`. Input's Hero rows (`:125`, `:272`) lack `idle` and `drag_cancelled`. Flow's HUD row (`:181`) names no interface. Minor: `gold_upper_bound` in Tower's Interactions row for Enemy & Wave, `halted()` in both Flow and Enemy & Wave Interactions rows.

---

## Game Design Issues

### Blocking

None. Every gate added in the fifth run can now be measured from the log or the bots.

### Warnings

⚠️ **S1. The alternating protocol measures a different thing.** Calls made on a fixed schedule show what indiscriminate calling costs, close to the always-call bot, while the check asks whether calling costs a person who chooses. Pooling the two pushes toward a pass, and the row does not say when an instructed tester calls. Options: analyse instructed attempts separately; tell them to call at the first Intermission second; accept and label it.
⚠️ **S2. The extension can come out inconclusive again**, since attempts that lose early never reach later indices. Options: pool across indices on the second run; "inconclusive twice, the user rules".
⚠️ **S3. Instructed testers skew other gates.** Waiting attempts inflate the never-call rate (HUD `:411`), and instructed testers no longer find the pin or Call unprompted (First run). Exclude extension attempts from those gates, or run the extension after they are read.
⚠️ **S4. The never-call rate counts attempts lost in wave 1**, which never saw Intermission. Count only attempts with at least one per-wave record.
⚠️ **S5. The fourth prompt would break HUD Rule 13 and its state table.** The table ends prompts "after the first burst"; Rule 13 teaches "verbs only, never where or when", and "start early" is a when; Rule 16's "same order as Rule 13" has no matching line. Options: pre-write the amendments now; a separate post-burst slot.
⚠️ **S6. The fast-loss line teaches "where"** ("drag the hero to the leak"), against Rule 13; it is unclear whether a built slow suppresses it, and whether the slow type line replaces it once "Slow value" passes; criterion 20 has no fixture for it. Options: exempt next-try lines from "never where"; say it ignores built roles; add the fixture.
⚠️ **S7. Two fallbacks pull share in opposite directions.** The victim cap re-runs "Best moment", and a fail there brings "a wider, weaker burst with share over target" (Hero `:448`, `:461`). Rule which wins before first playable.
⚠️ **S8. Tower's wave-6 question** ("most of wave 6's bounty is never spent", `:416`) cannot be read from `gold_left`, which mixes earlier leftovers. Define it as wave 6 spend under 87 (half of 174), or gate on the median `gold_left` at Won.
⚠️ **S9. Under Reduce Motion, a refused purchase gets no response.** The `NO_GOLD` nudge is skipped (Tower `:338`, Hero `:354`), against Game Feel's "every tap answers on the next frame"; the 120 ms arc collapse and the prompt pulse are not classed. Give the nudge a non-motion substitute (an alpha blink).

---

## Cross-System Scenario Issues

Scenarios walked: 5
1. A Fatal from the HUD's cost read in Intermission with 1 tick left
2. Call Armed, a slot tap opens the arc, close it, tap Call within 300 ms
3. Wave 3's last enemy leaks during a telegraph with the chip open
4. Focus loss in wave 4, resume, two more leaks, Won at wave 6
5. A left-handed first battle with Reduce Motion on

### Blockers
None.

### Warnings
R3 (scenario 4: wave 1, Paused time, reader key, Fatal read cache), R2 (scenario 3: Hero's stale halted-look text), S9 (scenario 5), R6 (scenarios 1 and 2: missing criteria).

### Info
ℹ️ Scenario 1 walks clean: the before-first-slot check stops the countdown, so wave 4 never starts, and one Fatal record is written. It relies on input running before ticks, which the ADR still has to confirm (HUD `:100`).
ℹ️ Scenario 2 walks clean: a disabled target is not a hit candidate, so the closing press goes to the backdrop, and a Call tap within 300 ms is dead.
ℹ️ Scenario 3 walks clean: `lives_changed` comes before `wave_cleared`, so the wave 3 record counts the leak.
ℹ️ Scenario 5 walks clean apart from S9: handedness is read once, the button and digit mirror to x 84, the arc icons are static, and the rejection ring keeps its fade.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| hero-system.md | R1 criterion 32; R2, R4, R5; S1, S2, S7 | Consistency, Design Theory | Blocking |
| battle-hud.md | R2, R3, R4, R6, R9; S3, S4, S5, S6, S9 | Consistency, Design Theory | Warning |
| game-state-stage-flow.md | R2, R6, R7, R9 | Consistency | Warning |
| input-gesture-resolver.md | R2, R8, R9 | Consistency | Warning |
| tower-system.md | R7, R9; S8, S9 | Consistency, Design Theory | Warning |
| combat-damage.md | R9 | Consistency | Warning |
| data-config-pipeline.md | R8 | Consistency | Warning |
| enemy-wave.md | R9 | Consistency | Warning |

---

## Verdict: FAIL

One blocking issue: R1, a single criterion in Hero whose press point sits inside the hero's disc. Everything else is wording left by the fifth fix, missing criteria, or second-order effects of the human-test rulings. No rule contradicts another system's rule, and every gate can be measured.

### Required actions before re-running

1. R1: move the Start/Call press in Hero criterion 32 outside the hero's disc, or move the hero to 60, matching HUD criterion 9.

## Resolution, 2026-11-02: the blocker and every warning applied

- **R1:** Hero criterion 32's call case puts the hero's centre at C + (60, 0), matching Battle HUD criterion 9.
- **R2 to R9:** applied. Hero and the HUD describe the halted button as the last tick's look; Start/Call re-arms when the arc closes; Flow emits `phase(Build)`, headless when `build` returns, and not when a Fatal latches during `build`; Input's ring, drag and centre wording match Hero and the art bible. Wave 1 opens a per-wave record without call fields; Wave seconds exclude Paused; attempt and Fatal records key on launch ID plus `attempt_seq`; the HUD caches the Fatal record's reads after every tick. The slow gate wording matches Hero's swapped-slow comparison. The two emptied counters are subsets of `bursts_hit_0`, with test cases. New criteria cover the Start/Call Disabled path, the halted look and Flow's before-first-slot check. Restated rows became pointers; Data criterion 3 tests the slop bounds; the missing interface names were added on both sides.
- **S1 to S9 (recommended options):** instructed testers call at the first Intermission second and are analysed apart from free attempts; a second inconclusive result pools across indices, then the user rules; instructed attempts stay out of the never-call and First run gates; never-call counts only free attempts that reached a later wave; the Call prompt is a separate slot after the first burst, outside Rule 13's list; next-try lines are exempt from "never where" and the fast line has a fixture; the victim cap comes before any wider burst, and a Best moment fail goes to the user; wave 6 spend under 87 moves bounty; under Reduce Motion the nudge and prompt pulse become alpha blinks and the arc closes at once.

Nothing from this report is left open.
