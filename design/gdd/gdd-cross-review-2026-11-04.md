## Cross-GDD Review Report
Date: 2026-11-04
GDDs Reviewed: 8 of 8 present
Not read: none
Focus: full
Systems Covered: Data & Config, Input & Gesture, Game State & Stage Flow, Combat & Damage, Enemy & Wave, Tower, Hero, Battle HUD

Method: three independent readers, at `main` f258c85. The readers took file paths, not pasted text, since the GDDs total about 350 KB. Registry baseline **NOT ASSESSED**: `design/registry/entities.yaml` is an empty stub, so restated values were compared GDD against GDD by hand. Player Fantasy is absent by configuration (workflow `standard`), so pillar and fantasy checks used Overview, "Implements Pillar" and Game Feel. Nothing was run but hand arithmetic. Readers took bot numbers from the GDDs and the 2026-11-03 report, unre-run.

---

### Consistency Issues

#### Blocking
None verified. Every quoted value restated across GDDs matched, and every derived clearance recomputed held.

#### Warnings
- ⚠️ **C1. Stale row.** `combat-damage.md:242` and `:24` say "Four pieces"; `systems-index.md:95` says "the GDD defines three pieces". Reword in the past tense.
- ⚠️ **C2. Tower describes the old Combat rule.** `tower-system.md:278` "none is the one it named"; Combat Rule 6 (`combat-damage.md:41`) now names Tower's part 1.
- ⚠️ **C3. Two owners per deferred criterion.** Micro-battle: `game-state-stage-flow.md:277` against `combat-damage.md:281`. Listener test: `game-state-stage-flow.md:276` against `enemy-wave.md:483`. Flow owns both, so its rows should win.
- ⚠️ **C4. Tick order and clamp routed to different ADRs.** `game-state-stage-flow.md:76`, `:178` and `architecture.md:231` say ADR-0004; `combat-damage.md:297`, `enemy-wave.md:519` and `game-state-stage-flow.md:299` say App Lifecycle ADR.
- ⚠️ **C5. Answered questions still open.** `enemy-wave.md:512` and `:515` against `game-concept.md:132` and `:105`.
- ⚠️ **C6. One-way dependency.** `data-config-pipeline.md:182` lists Combat in a hard table; `combat-damage.md:169` "Combat reads no data".
- ⚠️ **C7. Hard against soft.** `hero-system.md:316` lists Battle HUD as soft; `battle-hud.md:311-317` lists Hero as hard, and HeroInput reads `burst_button_centre()`.
- ⚠️ **C8. Data's interface rows are narrower than the consumers'.** `data-config-pipeline.md:184`, `:185`, `:187` against `tower-system.md:317`, `hero-system.md:313`, `battle-hud.md:319`. Tower IDs and role tags have no named read in Data.
- ⚠️ **C9. Cross-referenced but not in Dependencies.** `input-gesture-resolver.md:333` and `enemy-wave.md:390`.
- ⚠️ **C10. Undefined method.** `set_input_cancel` appears only at `game-state-stage-flow.md:279`, never in a rule.
- ⚠️ **C11. Stale edge case (found by the UX conformance pass).** Battle HUD's second-finger edge case says an "unmoved first press"; Rule 2 and criterion 21 say whatever is held.

---

### Game Design Issues

#### Blocking
None. No anti-pillar is violated, and hero alone loses on wave 3.

Check results: **loops** clean (gold is the only MVP progression resource). **Attention** at the limit, not over: at peak, four verbs across two systems through one thumb, plus a field read. **Gold** bounded with no feedback loop (670 maximum; boards cost 550 to 750; 456 to 496 held before wave 6). **Scaling** compatible (wave HP ×6.1, gold in stock ×4.1; HP per gold 8.3, 9.4, 9.2, 8.4, 10.1, 12.3, so wave 6 is the one steep step). **Pillars:** all 8 systems map to one. **Identity:** a coherent commander, except D10.

#### Warnings
- ⚠️ **D1. Bots have no thumb cost** (Hero, Simulated results; Tower Rule 6). Every strategy table is optimistic. Open since 2026-11-03. Add a one-thumb action lock before first-playable gates bind.
- ⚠️ **D2. Single only is the cheapest tied strategy** (Hero `--calls`; Tower Rule 16): 550 gold against 610 or more, and 9 lives calling. The gap is one heavy leaking, so the gate may measure threshold noise. Report a margin (leak count, heavy HP at exit) and test mono builds across placements.
- ⚠️ **D3. "Mid-skill" is not the good policy** (Hero table; 2026-11-03 D2). Simple human rules likely land outside the 25% to 30% share band; add those runs to Hero's table.
- ⚠️ **D4. Re-pinning is the weakest verb against the concept's named decision** (Hero Rule 7): about 110 re-pins buy 1, 1, 2 and 4 lives over the best pin, and instant retry makes a good pin cheap to find. The lanes trigger has no number.
- ⚠️ **D5. Scarcity leans on a dominated slot.** Slot 5's coverage is a subset of slot 4's. Four upgraded singles cost 440, below 456 held. Differentiate it at first baseline.
- ⚠️ **D6. Slow is unproven.** A floor for low skill, not dominated. Only 4 of 21 compositions were run; run all 21 before keeping "Squares slow".
- ⚠️ **D7. Burst share varies by wave** (6% to 8% on wave 2, up to 52% on wave 3). Report it per wave. Vertical Slice multipliers widen this.
- ⚠️ **D8. Stage length will not scale** (new; hand estimate). About 52 s per wave gives 7 to 10.6 minutes for 8 to 12 waves, against the concept's 5 to 8. Re-derive before Vertical Slice.
- ⚠️ **D9. Lanes fallback meets a one-distance model** (Enemy & Wave Rule 1; Combat Rule 10). The ADR should note what `path_id` would change.
- ⚠️ **D10. "Tactical calm" against "keeps the thumb busy"** (concept; Hero Game Feel). Set the intended cadence after D1 and D3.
- ⚠️ **D11. Pillar 2 against Pillar 3.** The share band clears by 0.1, and 5 units on one slot breaks it, so a per-stage band is unlikely to survive stage 2.

Accepted risks reviewed: re-pinning at about 2 lives, calling as a fast-forward, no selling, the slow-only trap and a leak costing its bounty all hold. **One challenge:** the reader says the mono-role gate blocking at first playable, with no known passing tuning, does not hold, and recommends human logs decide. The user chose blocking at first playable on 2026-11-04, so this needs the user.

---

### Cross-System Scenario Issues

Scenarios walked: 6
1. A burst's kills cross an affordability line while an arc is open
2. A fatal leak or stage clear with a burst in flight
3. An early call with a burst telegraphing and a chip open
4. Focus loss mid-drag, then resume and re-grab
5. An outcome with a press held, then Retry and rebuild
6. A Build pin and first Start tap in a stage's opening seconds

#### Blockers
None as rated. The two warnings below sit close to the skill's wording for a blocker (contradictory messaging; undefined behaviour). They are rated warnings because scenario 1's intent is stated, and scenario 2 affects a result screen's look only. Fix both before the gate.

#### Warnings
- ⚠️ **S1. Scenario 1 — HUD, Tower, Combat.** Rule 7 says "updated live", but Rule 1's redraw key has no affordability. After a tower kill with the burst Ready or Locked, gold rises while a struck-through disc stays drawn, and that disc would buy. Criterion 6 tests only the view model. Add affordability to the key.
- ⚠️ **S2. Scenario 2 — Hero, Combat, Flow, Enemy & Wave.** An outcome mid-telegraph has no presentation rule. "Field restores" and the 1.3× return are defined only at release, so a Won or Lost board can hold a dipped field and an enlarged hero. Combat's clearance waits for a BURST `attack_fired` that never comes. A stage-winning burst's 150 ms ring against "rings removed" is undecided too.

#### Info
- ℹ️ **I1.** Tower's burst clearance over rings has no HUD counterpart.
- ℹ️ **I2.** "Registered but disabled" Start/Call has no look; a press only dismisses the arc.
- ℹ️ **I3.** Rule 19 does not say when a call's burst readiness is sampled. If at write time, it records the wave's end, and Hero's human question rests on this log. Sample at the call.
- ℹ️ **I4.** The call evidence comes from a script where the hero does not walk in Intermission, so re-pin time is unmodelled.
- ℹ️ **I5.** Enemy & Wave's `danger_until` and pulse have no Pause rule.
- ℹ️ **I6.** "Ready, first frame… once" has no trigger after a Build pin; Hero's nudge repeating the prompt has no HUD rule.
- ℹ️ **I7.** Prompt 3 shows from Wave's first frame with enemies off field, so an obedient first burst can land on nobody.

**NOT ASSESSED premises:** scenarios 1, 3 and 5 rest on input before ticks in a frame (ADR-0004) and modal Controls stopping presses while moves and releases reach the adapter (ADR-0003). No ADR exists yet. If either fails, re-walk them.

---

### GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| battle-hud.md | S1 redraw key; C7; C8; C11; I1, I2, I3, I7 | Consistency, Scenario | Warning |
| hero-system.md | S2; C7; D1, D2, D3; I4, I6 | Scenario, Design Theory | Warning |
| game-state-stage-flow.md | C3; C4; C10 | Consistency | Warning |
| combat-damage.md | C1; C3; C4; S2 | Consistency, Scenario | Warning |
| enemy-wave.md | C3; C4; C5; C9; D5; I5 | Consistency, Design Theory | Warning |
| tower-system.md | C2; C8; D2; D6 | Consistency, Design Theory | Warning |
| data-config-pipeline.md | C6; C8 | Consistency | Warning |
| input-gesture-resolver.md | C9 | Consistency | Warning |

Statuses in `systems-index.md` are unchanged: every item is warning level.

---

### Fixed after this report (2026-11-04)

C1 to C11, S1, S2 and I3 were fixed the same day, on the user's instruction. The findings above stay as written, since their line numbers describe `main` at f258c85. No GDD was re-reviewed after these edits, and the verdict below is the one the review reached.

- **S1:** the redraw key now holds the affordability of each open disc and chip, and HUD criterion 6 tests it.
- **S2:** Hero has two new visual rows. A burst unreleased at an outcome ends with the field and hero restored and nothing landing; a burst on the release tick plays to its end in real time, so a stage-winning burst keeps its payoff. Combat's clearance window now closes on `phase_changed`, or after 0.15 s of real time. These are new rules, chosen as the reading that keeps the payoff.
- **I3:** a call's `seconds_left` and burst readiness are sampled at the call, and criterion 23 tests it.
- **C5:** two Enemy & Wave open questions were removed, because the concept now answers them.
- **C7:** Battle HUD is hard for HeroInput only. HeroSim runs without it.

Left open: D1 to D10, I1, I2 and I4 to I7. The four decisions below were applied separately.

### Owners for what stays open (from the 2026-11-04 gate check)

| Items | Owner | When |
|---|---|---|
| D1 (now a Hero Deferred row), D2, D3, D4, D5, D6, D7 | Hero and Tower stories, with `hero_bots.py` | Before first-playable gates bind |
| D8 | game-designer | Before Vertical Slice |
| D9 | technical-director | ADR-0009 records what `path_id` would change |
| D10 | creative-director | After D1 and D3, before first-playable feel work |
| I1, I2, I6, I7 | ux-designer, in the Battle HUD stories | Before those stories |
| I4 | Hero stories, with D1 | Before first-playable gates bind |
| I5 | Enemy & Wave stories | Before those stories |
| Rule 19 log details left undefined (first-burst seconds when none fired) | ui-programmer, first HUD story | Before that story |
| Concept's towers-only rule: per stage or across the stage set | game-designer, with D8 | Before Vertical Slice |

### Verdict: CONCERNS

No blocking issues. 11 consistency warnings, 11 design warnings and 2 scenario warnings should be resolved or accepted. Scenario premises and the registry baseline stay unverified as noted above.

### Decisions (user, 2026-11-04: all as recommended)
1. Mono-role while calling: bots report, human logs decide. If more than half of won attempts after a tester's first win are mono-role, tuning reopens.
2. Share: reported, not gated. New gate "Burst decides" on `dealt_burst` and lives. `dealt_burst`'s 15% floor is proposed.
3. Pillar 2 against Pillar 3: read across the stage set, one stage 20% to 40% (proposed), burst never tuned per stage.
4. Lanes trigger: testers who re-pin more gain under 1 life. The 5 testers and 4 won attempts are proposed. Changed after the 2026-11-04 gate check, on the user's choice: a firing flags the decision to the user with the logs, rather than moving lanes forward by itself.

These settle D11 and the numbers D3 and D4 asked for, and answer the mono-role challenge. The rest of D2 (a margin and mono builds across placements) stays open. Applied to the GDDs without a re-review.
