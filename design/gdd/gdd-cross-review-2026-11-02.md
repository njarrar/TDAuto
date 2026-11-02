# Cross-GDD Review Report

Date: 2026-11-02
GDDs Reviewed: 8 of 8 present (data-config-pipeline, input-gesture-resolver, game-state-stage-flow, combat-damage, enemy-wave, tower-system, hero-system, battle-hud)
Not read: none
Focus: full (consistency, design theory, scenarios)
Systems Covered: the 8 MVP battle systems, against `game-concept.md` and `systems-index.md`
Specialists: game-designer x4 (consistency part 1: 2a and 2c; consistency part 2: 2b, 2d, 2e, 2f; design theory: 3a to 3g; scenarios: 4a to 4c)
Workflow tier: standard for every system GDD (system overrides), so Player Fantasy and Tuning Knobs are advisory.

> Entity registry is empty, so consistency checks rely on GDD reads only. Run `/consistency-check` after the registry is filled.

> **Coverage is partial.** Both consistency agents hit their turn limit and reported what they had. Not checked: the Edge Cases sections of every GDD but Combat; Acceptance Criteria of Tower, Flow and Data; Open Questions of all GDDs; the prose of Enemy & Wave Core Rules, Data Rules 1 to 13 (grep only), Battle HUD Rules 13 to 19, Tower lines 22 to 50 and 105 on, Hero lines 22 to 42 and 62 to 148; what `burst_spike`, the bot gates and the Enemy L-rows say; every cross-reference into `game-concept.md`, `art-bible.md` and the prototypes; `systems-index.md`'s Dependency Map. A clean result here says nothing about those parts.

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

🔴 **C1. The left-hand flag has no owner.**
`hero-system.md:169` names Data as owner ("the left-hand flag | Data (values)") and `:145` calls it a data flag. `data-config-pipeline.md` defines no such field; line 61 has only each shape's hand. `battle-hud.md:288` puts the flag under Settings & Accessibility (Alpha). Either Data adds it under its extension rule, or Hero and Battle HUD name another owner. Design choice.

🔴 **C2. The concept's drag priority contradicts Input and Hero.**
`game-concept.md:152` (Pillar 4): "Drag priority: burst > hero." `input-gesture-resolver.md:53-54` and `hero-system.md:56` give hero 200 over burst 100, the user's decision of 2026-11-02, kept with option C in the fifth Hero review. `input-gesture-resolver.md:43` still claims its table "matches the concept's Pillar 4 order". Amend the concept line and the Input claim.

🔴 **C3. An Input deferred criterion cannot pass under Input's own Rule 11.**
`input-gesture-resolver.md:387`: Hero stories pass when "bot acceptance modes run only through the resolver". Rule 11 (`:70`) and `hero-system.md:31`: headless bots call commands directly, and the resolver is not in the headless build. Reword the row to the equivalence test (Hero criterion 28).

### Warnings (should resolve, but won't block)

⚠️ **C4. Who registers the upgrade chip.** `battle-hud.md:181` says the HUD registers it; its own Rule 9 (`:50`), `tower-system.md:67` and `input-gesture-resolver.md:50` say TowerInput. Tower rows `:175`, `:291` and Input rows `:126`, `:273` omit the chip, and `:273` still offers a choice Tower has made.

⚠️ **C5. Stale cross-reference.** `enemy-wave.md:372` answers an Input Open Question on slots that no longer exists (`input-gesture-resolver.md:396-408`).

⚠️ **C6. Input text from before the Hero radius change.** `input-gesture-resolver.md:399` and `:325` say radii 36 / 48; the hero's is 56 (`:37`, art bible §3). Open Question `:402` (instant re-pin or a walk) is answered by Hero Rule 3. The `r` range at `:148` and `:195` says 36 to 48, leaving out 56 and the chip's 40.

⚠️ **C7. "No GDD yet" claims are stale** at `data-config-pipeline.md:175`, `input-gesture-resolver.md:267`, `game-state-stage-flow.md:172`, `enemy-wave.md:320` and `tower-system.md:294`.

⚠️ **C8. Dependency direction disagrees.** Combat and Flow each list the other as downstream (`combat-damage.md:167`, `game-state-stage-flow.md:180`). Data lists Combat downstream (`:180`) while Combat says "Upstream: none" (`:158`). Tower lists Hero downstream (`:299`), Hero lists Tower as soft (`:302`).

⚠️ **C9. The two sides of three dependencies name different interfaces.** Combat and HUD (`combat-damage.md:168` vs `battle-hud.md:279`); Enemy & Wave and HUD (`enemy-wave.md:326` vs `battle-hud.md:279`); Data and HUD (`data-config-pipeline.md:185` vs `battle-hud.md:277`).

⚠️ **C10. Nobody owns the hit radii as data.** Input `:68` says they are the owners' values from their records; no Data record has a radius field, though Data Rule 1 (`:92`) puts every authored gameplay value in the catalogue, and Hero's content rule depends on 56 (`hero-system.md:133`). Add them to records or declare them structural constants. Design choice.

⚠️ **C11. `edge_reject_margin` allows a value that breaks the layout.** The domain is 0 to 48 (`data-config-pipeline.md:54`, `input-gesture-resolver.md:209`), but Input Rule 12 needs the button's centre at least margin + 48 from the edge, and the HUD puts it 84 in (`battle-hud.md:115`). Cap at 36 or add a content check.

⚠️ **C12. Three GDDs state the Pillar 2 bot gates differently.** `combat-damage.md:240`, `enemy-wave.md:408-410` ("thresholds live in Combat") and `hero-system.md:419-420`. Make Hero the one owner, as `tower-system.md:118` already says.

⚠️ **C13. A burst on nobody.** `combat-damage.md:145`: "no events, no counters"; Hero counts `bursts_fired` and `bursts_hit_0` (`:60`, criterion 8). Qualify Combat to "no damage counters".

⚠️ **C14. Battle HUD criterion 9 expects "Call +7"** (`battle-hud.md:359`) with no seconds left stated; Tower's formula (`tower-system.md:193`) pays 8 at the full 15 s.

⚠️ **C15. The concept's cancel wording is stale.** `game-concept.md:77`: "a drag released back on the button cancels"; Hero now measures from the press point (64 / 48), and a hero drag cancels the same way.

**Checked and consistent:** the Hero pin-cancel amendments across Hero, Input and Battle HUD; the 56 + 4 = 60 exclusion and the 92 slot overlap; tick order in Combat Rule 11, Enemy & Wave Rule 12, Hero's tick and Tower Rule 9; a fatal leak skipping the reap; slow stacking; `to_ticks`; Data's field domains against starter values; every rule number other GDDs cite in Flow, Combat, Input, Data, Enemy & Wave, Hero and Tower. Recomputed: wave HP 1,000 to 6,100 and stage 16,790; gold bounds, bonus 8 per call and 40 per stage, `max_final_gold` 670; board costs 550 to 750; `burst_spike` 5.78; `time_to_exit` 15.6 to 45.3 s; every `clamp_pin` example.

---

## Game Design Issues

### Blocking

🔴 **D1. Calling every wave early is free for bots and takes the stage under the concept's length.**
Hero, Simulated results: always-calling "cost no lives on mixed builds ... cuts the stage to under 4 minutes, below the concept's 5 to 8" (3.7 to 3.8 min called, 5.1 to 5.4 uncalled). Flow Rule 9: "once the burst is ready the cost is small". The concept promises calling costs "recovery and preparation time". Every GDD defers this to human logs at first playable, which the user chose; the stage-length promise fails under the bots now. Options: (a) overlapping waves, Flow's fallback; (b) a real call cost, which Flow Rule 9 forbids tying to burst state, so the user rules; (c) shorter intermissions; (d) longer waves; (e) keep the deferral and amend the concept's stage length. The user decides; this review does not.

### Warnings

⚠️ **D2. The slow tower has no measured value.** Adding slow never beats leaving it out in Hero's bot table (9 lives without slow, 9 with one, 7 with two), and slow-only is a trap the opening 120 gold can buy with no selling (Tower Rule 4). Options: buff slow, punish no-slow with fast enemies, refuse a slow+slow opening, or accept slow as an expert tool.

⚠️ **D3. The attention budget in a wave sits at the 4-system limit**: burst aim, re-pin, build arc and the 1.5 s upgrade chip. Waves are tuned against a bot that re-pins every 3 s, about 110 times a stage, which is not "tactical calm". Options: tune against a slower bot, or push building toward intermission.

⚠️ **D4. The Pillar 2 share band holds at one skill level.** Perfect aim gives 28% to 45%; the ceiling bot 27% to 42%, over the 40% gate. The hero still cannot solo. Options: victim cap or falloff, more late tower DPS, or a per-skill gate (user ruling, already in Hero's Open Questions).

⚠️ **D5. Re-pinning is worth about 3 lives** (best single pin 6, 7, 4, 6 against 9, 9, 9, 7), while the concept calls it "the decision". The user accepted this for MVP; lanes remain the fallback.

⚠️ **D6. The economy is back-loaded.** Wave 6 pays 174 gold, 26% of income, when spending matters least, and nothing carries over. No snowball (leaks cost at most 68 gold). Options: shift bounty into waves 3 to 5, or show unspent gold on the result screen.

⚠️ **D7. The difficulty curve steepens at the end and never dips.** Wave HP grows 1.50, 1.32, 1.26, 1.48 and 1.64 times; gold about 1.24 to 1.37 times; the hero is flat. Every intermission is 15 s. Accept as a finale, ease wave 4, or vary intermission length.

⚠️ **D8. The systems' fantasies pull apart.** Flow sells calling early as the skilful move, Tower sells scarcity, the HUD sells calm (see D1 and D3). The concept's "hero as a character you grow" has no MVP loop. The concept's result screen shows damage "vs each tower type"; HUD Rule 15 shows Towers / Hero / Burst. Pillar 3 cannot be judged with one stage. Options: reword Flow's Summary, record hero growth as deferred, align the result line.

---

## Cross-System Scenario Issues

Scenarios walked: 5
1. A burst kills the last enemy in the same tick as a leak
2. An early call while cooling, with a press inside both the hero's disc and Start/Call
3. A kill's gold lets a build with the arc open mid-wave
4. Pause mid-aim, mid-telegraph and mid-walk, then resume
5. Retry after Lost with a drag still held

### Blockers

None.

### Warnings

⚠️ **S1. "Fired" means two things** (Battle HUD, Hero). Prompt 3 counts a burst on `burst_started` (`battle-hud.md:66`); the Lost line "No burst fired" (`:91`) uses per-release counters (`hero-system.md:60`). A telegraph cut by a fatal leak counts as never fired, so a player who aimed is told to drag from the big button. Use one definition.

⚠️ **S2. Who calls `cancel()`** (Flow, Input). Flow says Won, Lost and Paused cancel input (`game-state-stage-flow.md:49`, `:103`), and Won happens inside the reap; Input says only the adapter calls `cancel()` (`input-gesture-resolver.md:66`, `:123`), and headless has no resolver. Agree the caller, and whether it runs mid-tick or at frame end. App Lifecycle ADR.

⚠️ **S3. The HUD cannot tell which drag target is the hero** (Battle HUD, Hero). HUD Rule 10 compares `best_drag` with the hero's target ID (`battle-hud.md:54`), but no Hero read exposes it (`hero-system.md:60`, `battle-hud.md:179-184`). HeroInput exposes the ID, or answers "is this my hero?".

⚠️ **S4. A resize cancels input without pausing** (Input, Flow, HUD). `input-gesture-resolver.md:66` cancels on resize; only focus loss pauses (`game-state-stage-flow.md:58`). A desktop resize kills an aim silently. List it in the ADR.

### Info

ℹ️ **S5.** A press held over two phase changes can tap a re-registered Start/Call under its old ID; Input expects owners to ignore stale IDs (`:117`), and the HUD should say so.
ℹ️ **S6.** Tower says a dimmed disc "does nothing" (`tower-system.md:66`); the HUD calls `build` and nudges on `NO_GOLD` (`battle-hud.md:45`). Align Tower's wording.
ℹ️ **S7.** Start/Call registers disabled while the arc is open (`battle-hud.md:44`) but its state table (`:149-153`) has no disabled row.
ℹ️ **S8.** Whether resume emits `phase` again is unstated; the HUD already guards (`battle-hud.md:55`).
ℹ️ **S9.** A touch already down when a modal Control mounts is engine behaviour deferred to the ADR (`input-gesture-resolver.md:78`).
ℹ️ **S10.** A hero drag shows no cancel boundary, only the alpha 0.3 ghost; check at first playtest whether a short first drag that does not pin is clear.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| data-config-pipeline.md | C1 left-hand flag owner (with Hero and Battle HUD); C10 radii; C11 margin domain; C7, C8 | Consistency | Blocking |
| input-gesture-resolver.md | C2 claim at :43; C3 deferred row :387; C4, C6, C7, C11 | Consistency | Blocking |
| game-concept.md | C2 Pillar 4 drag priority; C15 cancel wording; D1 stage length, D8 result line | Consistency, Design Theory | Blocking |
| hero-system.md | C1 owner named; D1 calling; S1, S3 | Consistency, Design Theory | Blocking |
| battle-hud.md | C1, C4, C9, C14; S1, S3, S7 | Consistency | Warning |
| combat-damage.md | C8, C9, C12, C13 | Consistency | Warning |
| enemy-wave.md | C5, C7, C9, C12 | Consistency | Warning |
| tower-system.md | C4, C7, C8; D2; S6 | Consistency, Design Theory | Warning |
| game-state-stage-flow.md | C7, C8; D1, D8; S2, S4 | Consistency, Design Theory | Warning |

---

## Verdict: FAIL

Four blocking issues: C1, C2 and C3 are text fixes, one with a design choice (C1, who owns the left-hand flag); D1 is a design ruling for the user (keep deferring calling's cost to human logs and amend the concept's stage length, or act now). Coverage was partial (see the note at the top), so a re-run after the fixes should read the unchecked sections.

### Required actions before re-running

1. Name the left-hand flag's owner, and write it into that GDD and into Hero `:169` and Battle HUD `:288` (C1).
2. Amend `game-concept.md:152` to hero over burst, citing the 2026-11-02 decision, and fix `input-gesture-resolver.md:43` (C2).
3. Reword `input-gesture-resolver.md:387` to the equivalence test (C3).
4. Rule on D1: amend the concept's stage length and keep the deferral, or pick a call cost or a pacing change.

---

## Resolution, 2026-11-02: Four blockers applied, re-run pending

- **C1:** Data & Config owns a new Options record (`left_hand`, `reduce_motion`, bools defaulting to false, read directly). Settings & Accessibility (Alpha) writes the player's choice over them. Hero's Interactions row and Battle HUD's Dependencies row now cite it. Chosen in autonomous mode as the smallest change that gives the flags one owner.
- **C2:** `game-concept.md` Pillar 4 now reads hero > burst, citing the user decision of 2026-11-02, so `input-gesture-resolver.md:43` holds again.
- **C3:** Input's deferred row says bots call commands directly, and the equivalence test (Hero criterion 28) covers the resolver path.
- **D1:** the deferral stands. The concept's Short-Term loop now gives the MVP stage's measured lengths (5.1 to 5.4 min uncalled, 3.7 to 3.8 always called), keeps 5 to 8 min for the full game's 8 to 12 waves, and names the first-playable measure and Flow's overlap fallback. Chosen in autonomous mode as the one option that needs no new rule or balance run; the user can overrule it.
- Also fixed: C6 (Input's radius range, cross-reference and open question now include 56 and Hero Rule 3) and C15 (the concept's cancel wording).

The other warnings stay open.
