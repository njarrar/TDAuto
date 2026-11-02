# Cross-GDD Review Report (fifth run)

Date: 2026-11-02
GDDs Reviewed: 8 of 8 present (data-config-pipeline, input-gesture-resolver, game-state-stage-flow, combat-damage, enemy-wave, tower-system, hero-system, battle-hud)
Not read: none
Focus: full (consistency, design theory, scenarios)
Systems Covered: the 8 MVP battle systems, against `game-concept.md`, `systems-index.md`, `design/art/art-bible.md` and `prototypes/hero-pin-concept/`
Specialists: 7 agents (regression of the fourth run's fixes and rulings; rules of Data, Input, Flow, Combat; rules of Enemy & Wave, Tower, Hero, Battle HUD; Acceptance Criteria, Open Questions and Edge Cases; dependencies and cross-references; design theory; scenarios)
Workflow tier: standard for every system GDD (system overrides).
Prior reviews: `gdd-cross-review-2026-11-02.md`, `-02b.md`, `-02c.md`, `-02d.md`, each FAIL and resolved the same day.

> Entity registry is empty, so consistency checks rely on GDD reads only.

> **Coverage.** Every cross-reference target is now confirmed, including those the fourth run did not reach (Data "Not owned", REPORT.md headings and item 5, the `main.gd` names, the art-bible labels), and the systems index matches every GDD's upstream list. Not reached this run: Data & Config's Acceptance Criteria, Open Questions and Edge Cases; Hero, HUD and Input Edge Cases; a few long lines the tools cut short (Hero 18, 35-36, 55-56, 430; Enemy & Wave 71, 74; Tower 67; HUD 44, 50, 55, 104). Each was read in an earlier run.

---

## Regression check of the fourth run

K1 to K20, E1, E3, E4 and every ruling (D1, D2, G2, G3, G4/G10, G6/G11, G7, G8, G9, X9) are FIXED. K21 holds (Hero cites Input Rules 3 and 4, both relevant). E2 is PARTIAL: see P4. No file gained an em dash.

---

## Consistency Issues

### Blocking

🔴 **P1. A Fatal latched outside a tick still lets Flow's own slot run, and its fix caused this.** The K16 fix stops the clock "at the end of that frame" (`game-state-stage-flow.md:49`, `:62`), and the tick loop checks `halted()` only "between slots" (`:49`). Flow's slot runs first (`combat-damage.md:44`; Flow `:138`), so every tick still owed that frame runs it. In Intermission it counts down, and at 0 it starts the next wave (`:39`), emitting `phase(Wave)` after Fatal, against "no other transition is legal" (`:62`). Rule 15's "later ticks do nothing" covers Won and Lost only.
Change: the tick loop checks `halted()` before the first slot too, and Rule 15's "later ticks do nothing" covers Fatal.

🔴 **P2. Start/Call has no way into Disabled from Arming or Armed, and no named way out.** Rule 6 (`battle-hud.md:44`): Start/Call is disabled "while an arc is open". The state table's Arming (`:152`) and Armed (`:153`) rows have no "arc opens → Disabled"; only Hidden reaches Disabled (`:151`). The Disabled row's exit, "Arc closes → enabled" (`:154`), names no state, so it is undefined whether a closed arc means a new 300 ms arming or a return to Armed. This is the common case: Call is Armed in Intermission and the player taps a slot. Found by rules slice 2 (Blocking) and the scenario walk (Warning).
Change: add "arc opens → Disabled" to the Arming and Armed rows, and give Disabled a named exit ("arc closes → Arming").

### Warnings

⚠️ **P3. HUD Rule 19 writes a per-wave record at two times, and the focus-loss write can drop later leaks.** `:104`: written "when `wave_index()` changes", and the per-call record "at the next `wave_cleared` or outcome", with lives lost. A focus loss writes the pending record at once; after resume, leaks later in that wave are dropped, or the record is written twice. Criterion 23 (`:379`) has the same gap. Open the record on a `wave_index()` change, write it at the clear or outcome, make the focus-loss write provisional, and have the reader keep the last record per launch ID, `attempt_seq` and `wave_index`.
⚠️ **P4. The art bible's line styles still say "Ground ring: 2 px solid, radius 30"** (`art-bible.md:75`). That is the hero's pin marker under its old name (it matches Hero's pin ring exactly). The regression agent rated it Blocking; recorded here as a Warning because it does not contradict the rejection ring's spec, only its name. Rename it "Pin ring". Also, `:176` calls the rejection ring "unanimated" but says it "fades in over 150 ms": say the fade is its only motion.
⚠️ **P5. Flow criterion 1 expects `phase(Build)` from a fixture with no views** (`:234` against Rule 6 at `:37`, which emits it "when its views are connected"). Headless bot battles have no views either. Say that headless, `phase(Build)` is emitted when `build` returns, and start criterion 1 from a built flow. Rule 6 should also say "once per build", since resume in Build emits `phase(Build)` again (`:58`).
⚠️ **P6. Flow Rule 18 still says "every remaining system's `halted()` check skips the rest of that tick"** (`:62`), against Rule 15's tick loop (`:49`) and Combat's "needs no `halted()`" (`:153`). Repeat Rule 15's wording, and add Tower (Rule 9, `tower-system.md:85`) to the systems that also check inside their steps.
⚠️ **P7. The halted burst button's look contradicts itself.** Rule 12 keeps the outcome-snapshot look "so a halted telegraph never shows as an empty wedge" (`battle-hud.md:59`), but the snapshot is built the frame after the outcome (`:76`), when the burst is still Telegraphing, which Rule 10 draws as an empty wedge (`:54`). Name the look: the one from the last tick before the latch.
⚠️ **P8. The Fatal record's snapshot has no builder.** Flow says Rule 19 writes one Fatal record from the outcome snapshot (`:62`), but the fatal screen replaces the HUD (`battle-hud.md:267`) and the snapshot would read Combat counters after Fatal. Say who builds it, and from which reads, before the HUD goes.
⚠️ **P9. Input's re-pin example ignores Hero's 64-unit cancel.** `input-gesture-resolver.md:173`: "A 28-unit move on that tower with a hero parked on it is a re-pin"; under Hero Rules 13 and 14 and criterion 28 (`:410`) a 28-unit drag released there cancels. Say the resolver emits `drag_started(hero)` and the drag pins only past 64; `:62` and `:63` should say "drag", not "pin" or "commit".
⚠️ **P10. Stale deferrals in Tower and Enemy & Wave.** Tower `:139`: "L11 and `burst_spike` wait for the Hero record", which exists (Hero `:78-79`, `:129-130`); Tower `:136` tags `burst_spike` "(Hero stories)" while Hero `:129` says "owned by Tower". Enemy & Wave `:104` defers `peak_alive_ub` to "Hero and Tower stories", but it runs in Tower CI (K10). State one owner for `burst_spike` in both, and match `enemy-wave.md:48`.
⚠️ **P11. "Call +7" at a full countdown.** HUD Rule 10 (`:54`) shows "Call +7"; Tower `:193` pays 8 at 900 ticks, and after the 300 ms arming 882 ticks still pays 8. Use "+8" or "Call +N".
⚠️ **P12. Bot-gate names and pass texts.** Tower `:396` names "hero-only" and omits Pinned once, Slow value and the ceiling gate; use Hero's names or "every row in Hero's Deferred table". Combat `:244` restates pinned-once as "fewer lives than active play", while Hero `:422` says "below mid-skill on at least three of four mixed builds"; point to the row.
⚠️ **P13. Open questions asked more than once.** Re-pins: Hero `:449` (owns it) and `:462`. Early call: Flow `:277`, Tower `:412` and `:417`, Hero `:452`, with no row claiming it; add "This row owns the question" to Hero `:452` and merge Tower's two. The 45% share: Hero `:451` says the user rules on the pillar, `:423` and `:461` say a victim cap runs; say the cap comes first. The HUD's slow-hint row (`:410`, owner "Human logs") disagrees with Hero's Slow value gate (`:424`, Hero stories).
⚠️ **P14. Dependency interface names.** Flow's Hero rows (`:107`, `:179`) omit the injected `halted()` and `in_build()`; its Tower rows (`:106`, `:178`) omit `halted()`, the tick order and `phase`, and "direct build command" reads like the builder. Combat's Tower row (`:168`) lacks its tick slot; Combat (`:170`) and Enemy & Wave (`:317`) list different names for the same link. The HUD's Hero row (`:281`) lacks `hero_target_id()` and holds Flow's `in_build()`; its Interactions Hero row (`:186`) says "reads" for "listens, reads". Data's HUD row (`:137`) and Tower row (`:184`) are shorter than the other side. Combat `:80`'s Direction cell is malformed. The "already do" lists at Combat `:175` and Enemy & Wave `:330` are out of date.
⚠️ **P15. Citations.** "Layout" (HUD `:347`, Hero `:368`) is the bold label "Layout rules" in Enemy & Wave (`:30`). "Priority table" (HUD `:346`, index `:89`) is "Suggested registrations" in Input (`:43`). Data `:212`'s REPORT.md heading should match its dash form or be cited by section number.
⚠️ **P16. Input's burst fixtures are abstract.** `:333` and `:363` place B at (440, 880) with H at (440, 820), a pin the game refuses (Hero criterion 2). Label them abstract or move them to the real layout. The priority result still agrees with Hero criterion 32.
⚠️ **P17. Unchecked "loses every" claims.** HUD Rule 16 (`:88`): "the mid-skill bot loses every mixed build without the burst"; index `:169`: "every MVP build loses without the hero". Cite Hero's simulated results, or soften to match Hero's towers-only gate.

---

## Game Design Issues

### Blocking

None. No ruling contradicts a pillar or another rule.

### Warnings

⚠️ **Q1. Two new gates read values the log does not record.** The attention question (Hero `:462`) needs re-pins per minute in Wave, but Rule 19 logs `repins` per attempt and no Wave time. Tower's wave-6 question (`:416`) needs gold left at Won, but the attempt record has no gold field. Add per-wave `repins` and Wave seconds, and `gold_left` (or gold spent per wave), to Rule 19.
⚠️ **Q2. The human early-call check has no outcome when no index qualifies.** Testers who always or never call fill one side only, so 10 attempts can leave no wave index with 5 a side, and the check neither passes nor fails. Options: treat it as inconclusive and extend the test; ask some testers to call and some to wait; pool across indices when none qualify.
⚠️ **Q3. The countdown counts as "not a wait timer" only if players find Call.** No prompt teaches Call (Rule 13). Options: log the never-call rate (attempts whose per-wave records all have `seconds_left` 0) and gate on it; add a fourth prompt in Intermission; accept.
⚠️ **Q4. A loss to fast enemies now has no hint.** HUD Rule 16.4: "`fast` has no line"; Enemy & Wave (`:61`) says fast "asks for slow or a re-pin". Options: a verb line, "Next try: drag the hero to the leak"; accept and rely on the arc icons.
⚠️ **Q5. The Slow value gate passes on a tie.** Hero `:424` passes on "no fewer lives", and one slow already ties zero slows (Tower `:418`). Require at least one more life before the hint returns, or keep the hint off regardless.
⚠️ **Q6. The 45% ceiling gate has a thin margin, and its fallback is never re-checked.** The ceiling bot reaches 42% and perfect 1 s aim 45% (Hero `:118`), about 3 points under the gate. A victim cap of 5 could break the "Burst outcome" row (median kills of at least 2) or push mid-skill share below 25%, and nothing says to re-run them. The concept's anti-pillar says the gate caps "a skilled player's hero share", but it measures bots. Options: gate on the median or on 2 of 4 builds; re-run Share, Burst outcome and Best moment when the cap goes in; say "bot ceiling" in the concept.
⚠️ **Q7. `bursts_emptied` flatters the phone miss rate.** It counts an enemy walking out of the radius during the telegraph, which is a timing miss. Split it into `emptied_by_kill` (left out) and `walked_out` (counted as a miss), or report both.

---

## Cross-System Scenario Issues

Scenarios walked: 5
1. First launch to the first Start tap
2. Retry from Lost with the arc open
3. A Fatal from the HUD's cost read while the arc opens in Intermission
4. Intermission begins with the arc open; the player closes it and calls
5. Focus loss mid-wave, a quit, then a new launch

### Blockers
P1 (scenario 3) and P2 (scenario 4), above.

### Warnings
P7 (scenario 2), P8 (scenario 3), P3 (scenario 5), above.

### Info
ℹ️ Scenario 1 holds: the early double tap closes the arc and builds nothing, prompt 1 shows before prompt 2, and Start goes Hidden to Arming on `phase(Build)`.
ℹ️ Scenario 2 holds: the arc closes on `phase(Lost)`, Retry rebuilds and emits `phase(Build)` once, and `attempt_seq` rises.
ℹ️ Scenario 5 holds apart from P3: grouping by launch ID plus `attempt_seq` keeps a quit attempt's records apart, and a new launch starts fresh.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| game-state-stage-flow.md | P1 tick loop before the first slot; P5, P6, P8, P13, P14 | Consistency | Blocking |
| battle-hud.md | P2 Disabled transitions; P3, P7, P8, P11, P13, P14, P15, P17; Q1, Q3, Q4 | Consistency, Design Theory | Blocking |
| hero-system.md | P12, P13, P15; Q2, Q5, Q6, Q7 | Consistency, Design Theory | Warning |
| tower-system.md | P10, P12, P13 | Consistency | Warning |
| enemy-wave.md | P10, P14 | Consistency | Warning |
| combat-damage.md | P12, P14 | Consistency | Warning |
| input-gesture-resolver.md | P9, P16 | Consistency | Warning |
| data-config-pipeline.md | P14, P15 | Consistency | Warning |
| design/art/art-bible.md | P4 | Consistency | Warning |
| game-concept.md | Q6 | Design Theory | Warning |
| systems-index.md | P15, P17 | Consistency | Warning |

---

## Verdict: FAIL

Two blocking issues: P1, a Fatal outside a tick still letting Flow's slot run, which the K16 fix caused; and P2, Start/Call's missing Disabled transitions, which K2 left half done. Both are one-line rules. The dependency graph and every cross-reference target now check clean, and no ruling contradicts a pillar.

### Required actions before re-running

1. P1: make Flow's tick loop check `halted()` before the first slot, and make "later ticks do nothing" cover Fatal.
2. P2: add "arc opens → Disabled" to the Arming and Armed rows, and "arc closes → Arming" to Disabled.

## Resolution, 2026-11-02: both blockers and every warning applied, re-run pending

- **P1:** Flow's tick loop checks `halted()` before the first slot as well as between slots, so once an outcome or Fatal is latched, inside or outside a tick, no slot runs, Flow's countdown included; Won, Lost and Fatal are terminal (Rules 15, 18).
- **P2:** Arming and Armed go to Disabled when the arc opens; Disabled goes to Arming (a new 300 ms arming) when it closes, and to Hidden when its phase ends.
- **P3 to P17:** applied. Per-wave records open on a `wave_index()` change and are written at the clear or outcome; a focus-loss write is provisional and the reader keeps the last record per key. `phase(Build)` is once per build, with views after they connect, headless when `build` returns. The halted button keeps its last-tick look. The Fatal record comes from reads held at the latch. The pin marker is the "pin ring" in the art bible too.
- **Q1 to Q7 (recommended options):** per-wave `repins` and Wave seconds and an attempt `gold_left` in the log; an inconclusive early-call result extends the test with testers alternating; the never-call rate is logged, with a fourth prompt if over half never call; a fast-enemy loss gets "Next try: drag the hero to the leak"; the slow hint needs at least one more life; the ceiling gate uses the median of the four mixed builds and the cap's dependent rows are re-run; `bursts_emptied` splits into `bursts_emptied_by_kill` and `bursts_walked_out`, and walk-outs count as misses.
