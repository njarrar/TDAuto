# Cross-GDD Review Report (third run)

Date: 2026-11-02
GDDs Reviewed: 8 of 8 present (data-config-pipeline, input-gesture-resolver, game-state-stage-flow, combat-damage, enemy-wave, tower-system, hero-system, battle-hud)
Not read: none
Focus: full (consistency, design theory, scenarios)
Systems Covered: the 8 MVP battle systems, against `game-concept.md`, `systems-index.md`, `design/art/art-bible.md` and `prototypes/hero-pin-concept/`
Specialists: game-designer x7 (regression of the warning batch; rules of Data, Input, Flow, Combat; rules of Enemy & Wave, Tower, Hero, Battle HUD; Edge Cases, Acceptance Criteria and Open Questions; dependencies and cross-references; design theory 3a to 3g; scenarios)
Workflow tier: standard for every system GDD (system overrides).
Prior reviews: `gdd-cross-review-2026-11-02.md` and `gdd-cross-review-2026-11-02b.md`, both FAIL, both resolved the same day.

> Entity registry is empty, so consistency checks rely on GDD reads only.

> **Coverage.** Every section of every GDD was read by at least one agent across the three runs. This run did not reach: Input Formulas 173 to 210 (two lines grepped), the Edge Cases of Hero, HUD, Tower, Combat, Enemy & Wave, Input and Data (read in run 2, only spot-checked here), Data's Acceptance Criteria, Tower's slow formulas, and L10's 223 per slot. The warning batch's own regression agent had no shell, so the main session checked the diff for em dashes before committing (none added).

---

## Regression check of the warning batch

All applied items hold except where noted. PARTIAL: R10 (39% is still a current figure at `game-concept.md:143` and `systems-index.md:169`) and R11 (the splash-vs-burst question now names Hero, which has no such row). Every "TAP 200" list carries the chip, `edge_reject_margin` is 0 to 36 everywhere, `cancel()` is an end-of-frame request everywhere, and Tower's and Hero's citations of HUD Rule 7 and Flow Rule 8 are correct.

---

## Consistency Issues

### Blocking

🔴 **B1. Flow Rules 15 and 18 disagree on when an outcome takes effect, and the warning batch caused it.**
`game-state-stage-flow.md:49` (Rule 15): an outcome "committed mid-tick makes the remaining systems skip that tick". `:62` (Rule 18, added today): "After [the tick] returns, Flow commits the outcome (Won, Lost or Fatal), stops the clock and emits `phase(...)`". Enemy & Wave (`:73`), Combat Rule 11 (`:44`) and Hero (`:281`) need `halted()` true at the leak itself. Read literally, Rule 18 lets a burst release after a fatal leak. Rule 15 also says phase changes "do none of this", yet Flow AC 2 (`:235`) expects `phase(Intermission)`, and whether resuming emits `phase` is unstated.
Change: split the steps in both rules. The latch, which makes `halted()` true, happens mid-tick. Stopping the clock, emitting `phase` and the `cancel()` request happen after the tick returns. Say which transitions emit `phase`.

### Warnings

⚠️ **W1. Hit radii owner.** `data-config-pipeline.md:94`: "owned by the Input GDD and art bible §3"; `input-gesture-resolver.md:68`: "each owner declares", with radii under Not owned (`:74`). Both agree radii are not catalogue values. The source agent tagged this Blocking; it is recorded here as a Warning because only the owner's name differs. Make Data say "declared by each owning GDD from art bible §3".
⚠️ **W2. Retry in the end-of-frame cancel.** Flow `:49` lists retry with outcomes that emit `phase`; retry does not, and Rule 16 (`:54`) and HUD (`:100`) cancel inline. Input `:66`, `:123` cite "Flow Rules 15 and 18" for ends and pauses, leaving out retry and Pause's Rule 17.
⚠️ **W3. Combat Rule 9 still says "Combat depends on nothing"** (`:42`) beside its new upstream list (`:159-161`); and the soft Data line says Data "reads `max_hp`", while Enemy & Wave passes it in at spawn (`enemy-wave.md:68`).
⚠️ **W4. "A wave cannot be called early"** at Flow `:67` and `enemy-wave.md:109` contradicts Flow Rule 9's Call early; the meaning is "while one is running".
⚠️ **W5. Tower `:65` gives the wrong reason taps do nothing while Paused** ("input is cancelled"); the Paused Control blocks them (HUD `:96`, Input `:316`).
⚠️ **W6. Stale wording.** Hero `:31` and Open Question `:455` still "amend Input Rule 11", which Input now states. Tower `:249` argues against a Combat Rule 6 wording that Combat (`:39`) has since changed.
⚠️ **W7. Units.** Data uses "world units" (`:46`, `:53-55`); Input and Combat use "field units".
⚠️ **W8. Input edge case `:254`** still says a slip within the burst button cancels; with the press-point anchor, a slip of over 64 across the 96-wide button fires.
⚠️ **W9. The HUD expects a cooldown total Hero does not expose** (`battle-hud.md:139` against Hero Rule 16 at `:60`).
⚠️ **W10. "Fired" means two moments.** HUD Rule 16 (`:88`): on `burst_started`; Hero `:60` and Combat `:146`: `bursts_fired` per release. A battle that ends mid-telegraph shows the burst as fired on screen and 0 in the log, against HUD Rule 15's "screen and log cannot disagree" (`:76`).
⚠️ **W11. "Ground ring" names two things.** Hero (`:36`, `:346`): the pin marker; HUD Rule 14, Input `:389` and the concept: the rejection ring on a ground tap, capped at three per battle. Rename Hero's (for example "pin ring").
⚠️ **W12. Disabled Start/Call has no phase-end transition** (`battle-hud.md:154`); say it goes Hidden when its phase ends with the arc open.
⚠️ **W13. Dependency direction and interfaces, still mismatched in nine pairs.**
- Data's Hero row `:185` lacks the Options record and Stage fields.
- Hero's Data row `:299` lacks the Options record.
- Data's Combat row is unmarked hard against Combat's soft (`:177`, `:182` vs `combat-damage.md:161`).
- Combat `:170` and Enemy & Wave `:326` list the HUD as hard downstream against the HUD's soft (`battle-hud.md:282`). Enemy & Wave also says it provides the burst button coordinates, which the HUD supplies.
- The HUD lists Hero as hard upstream (`:278`); Hero lists the HUD only as soft (`:302`) and not in its Downstream table.
- Input `:271` and Flow `:176` each call the other downstream (also `systems-index.md:28`, `:89`).
- The HUD's interactions table (`:182-187`) lacks Data, Combat and Enemy & Wave rows.
- Combat's interactions table (`:72-79`) lacks Data.
⚠️ **W14. Cross-reference labels that are not headings.**
- `data-config-pipeline.md:212` cites "CD-PLAYTEST carry-forward 5"; the report's section is "Creative Director Review: CD-PLAYTEST" (`REPORT.md:81`).
- Hero `:364`, Tower `:347` and Enemy & Wave `:373` cite concept "Mastery" and "Onboarding"; the headings are Retention Hooks or Player Motivation Profile, and Flow State Design.
- Input and Flow cite art-bible labels ("Minimum sizes", "Reticle", "Ground tap", "Pinned pose", "LOD") that are not headings under §2, §3, §5 and §7.
- Tower `:314` cites "§3 Accretion"; accretion is §1 (`art-bible.md:23`).
⚠️ **W15. Systems index.** Combat's row and map (`:30`, `:95`) still say no dependencies. The HUD's (`:34`, `:111`) omit its soft Combat and Enemy & Wave reads. The Hero risk row (`:169`) still gives 39% and "towers-only can win once upgrades exist".
⚠️ **W16. 39% still current** at `game-concept.md:143`; Combat calls it history (26.2% now).
⚠️ **W17. Deferred rows with two owners or different fixtures.**
- Enemy & Wave's Always-call row (`:412`) keeps "does not beat a driven hero", which Hero's gate (`:426`) no longer has.
- Its towers-only and driven-margin rows (`:408-409`) use a best-of-set fixture against Hero's per-build fixture (`:419`).
- Mono-role is "Tower stories" at Enemy & Wave `:411` against Hero stories at Hero `:425` and Tower `:396`.
- Splash against burst: Combat `:245` (Tower and Hero stories, share with splash against none) against Hero `:423` (2, 2 and 1 against single-only).
- The burst-state bonus: Flow `:260` (Tower stories) against Tower `:398` and Hero `:432` (Hero stories).
⚠️ **W18. Open-question owners.**
- Enemy & Wave's re-pin row (`:432`) keeps owner "qa-lead + Hero GDD" while saying Hero owns it.
- Splash against burst (Combat `:257`, Enemy & Wave `:436`) names Hero, which has no row; add one.
- The HUD's stretch-mode row (`:414`) does not point at Input's (`:398`).
⚠️ **W19. HUD criterion 9's pin-cancel fixture** says "released under 48 from the press point"; Hero's criteria say "never passed 64 (e.g. at 55)". Not contradictory, but misleading.
⚠️ **W20. Flow Deferred `:261`** words the towers-only gate as "must not beat a driven hero"; Hero `:426` says "flips no loss and gains at most 2 lives". One wording.

---

## Game Design Issues

### Blocking

🔴 **B2. The human pass mark for early calls cannot be measured from the log as specified, and G1's fix caused it.**
Hero's "Always-call, humans" row compares called and waited waves "of the same index" over "at least 10 attempts". Battle HUD Rule 19's per-wave record holds `seconds_left`, burst readiness and lives lost, with no wave index and no attempt ID. Records carry a launch ID, which is per launch. Order could stand in for the index, but a quit attempt writes no record, so its per-wave records merge into the next attempt.
Options: (a) add `wave_index` and an attempt sequence number to every Rule 19 record; (b) compare per attempt instead of per wave.

### Warnings

⚠️ **D1. The human test leans toward firing the fallback by accident.** Players call when they feel safe, so called waves tend to lose fewer lives whether or not calling costs anything. Most waves lose 0 lives, and a 0-against-0 tie counts as "no more lives", which fails. The rule says nothing of a wave index where the tester never waited. Options: a tester protocol that alternates calling and waiting, a minimum sample on each side, an explicit tie rule.
⚠️ **D2. The first purchase is blind.** With X1's fix, a tower's role first shows on wave 1, so the first tower is bought on its name alone, with no selling, and slow is a trap (G2). Wave 1 now carries the role demos, the first enemies, the hero's first walk and prompt 3. Options: a ghost demo in Build, or a short role loop in the arc.
⚠️ **D3. A telegraph cut short by an outcome has no defined look.** Hero's wind-up runs from T to R (`:331-333`); after Won or Lost mid-telegraph it either shows a landing that dealt nothing or freezes. Recommended: it stops and clears when `halted()` turns true.
⚠️ **D4. Prompt 3's latch** ("In Wave ... latched until `burst_started`", HUD `:66`) does not say whether it survives into Intermission.

Still open from run 2, unchanged: G2 slow's value, G3 attention budget (slightly worse, D2), G4 share gate on one bot, G6 back-loaded economy, G7 no dip in the curve, G8 Flow's Summary "a timer they can beat" and the concept's "each tower type", G9 intermission as dead time, G10 mastery toward hero action, G11 bonus size. Dropped: G5, resolved by the user's ruling. Checked clean: no text now promises the cost of calling as proven; "clearly lose = fewer lives" reads the same in the concept, Hero, Combat and Enemy & Wave; the bot trigger can fire (2/1/2 sits exactly on the 2-life limit).

---

## Cross-System Scenario Issues

Scenarios walked: 5
1. Re-walk: a fatal leak in the tick a last-wave burst would release
2. Re-walk: Pause during an aim, resume, then an immediate call
3. A re-pin drag released while Cancelling as Intermission begins
4. The last wave, burst Ready, Won during the telegraph
5. A press on a tower inside the hero's disc while its chip is open

### Blockers

None beyond B1, which scenarios 1 and 4 also hit.

### Warnings

⚠️ Scenario 4: the telegraph visual after a halt (D3). Scenario 3: prompt 3's latch across phases (D4).

### Info

ℹ️ The Won panel (x 48 to 492, y 752 to 944) covers the right burst button; harmless, since input is dead after Won.
ℹ️ The chip does not close on a hero `drag_started`, unlike the arc (HUD `:46`); a later tap can still upgrade inside the 1.5 s window. Confirm it is intended.
ℹ️ The chip and tower discs are exactly tangent (76 = 40 + 36); a press on the touching point goes to the chip with the same result.
ℹ️ Scenario 2 (Pause, resume, call) is now fully defined, with no free preparation time.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| game-state-stage-flow.md | B1 outcome timing; W2, W4, W13, W17, W20 | Consistency | Blocking |
| battle-hud.md | B2 log fields (Rule 19); W9 to W12, W13, W18, W19; D3, D4 | Design Theory, Consistency | Blocking |
| hero-system.md | B2 pass mark wording; W6, W9, W10, W11, W13, W18; D1, D3 | Design Theory, Consistency | Warning |
| combat-damage.md | W3, W13, W17, W18 | Consistency | Warning |
| data-config-pipeline.md | W1, W7, W13, W14 | Consistency | Warning |
| input-gesture-resolver.md | W2, W8, W13, W14 | Consistency | Warning |
| enemy-wave.md | W4, W13, W14, W17, W18 | Consistency | Warning |
| tower-system.md | W5, W6, W14 | Consistency | Warning |
| game-concept.md | W16; G8 | Consistency, Design Theory | Warning |
| systems-index.md | W13, W15 | Consistency | Warning |

---

## Verdict: FAIL

Two blocking issues, both caused by today's fixes: B1, the Rule 18 text added in the warning batch, and B2, the pass mark added for G1. Each is a short edit. The warning count fell in kind but not in number: this run read deeper and found mostly reference labels, ownership rows and dependency directions.

### Required actions before re-running

1. B1: split Flow Rules 15 and 18 into a mid-tick latch and an after-tick commit, emit and cancel request; state which transitions emit `phase`.
2. B2: add `wave_index` and an attempt sequence number to every Battle HUD Rule 19 record (or change Hero's pass mark to compare per attempt), and make Hero's row name the fields it compares.

## Resolution — 2026-11-02 — Both blockers and the consistency warnings applied, re-run pending

- **B1:** Flow Rules 15 and 18 now give the same two steps: an outcome is latched mid-tick, so `halted()` turns true at once; after the tick returns, Flow stops the clock, emits `phase`, and asks for `cancel()` at the end of the frame. Every phase change emits `phase`; only outcomes and Paused stop the clock and request a cancel; resume emits `phase` with the phase it returns to. Flow criterion 8 matches.
- **B2:** Battle HUD Rule 19 records carry `attempt_seq`, per-wave records carry `wave_index`, and a quit attempt's per-wave records are kept and grouped by `attempt_seq`. Hero's "Always-call, humans" row names those fields and leaves out a wave index with no waited wave.
- **W1 to W20** applied as listed. Choices logged: the HUD reads Burst `cooldown` through the accessor (no new Hero read); Hero counts `bursts_started` and the HUD's next-try test reads it; Hero's pin marker is now the "pin ring", in Hero and the art bible; Input is upstream of Flow; Data's units are field units.
- **D3, D4:** a telegraph cut short by an outcome stops and clears when `halted()` turns true; prompt 3's latch holds for the whole battle.

Still open, needing user rulings: D1 (the human test's bias), D2 (first purchase without a role demo), and G2 to G4, G6 to G11.
