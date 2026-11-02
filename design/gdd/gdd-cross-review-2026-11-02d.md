# Cross-GDD Review Report (fourth run)

Date: 2026-11-02
GDDs Reviewed: 8 of 8 present (data-config-pipeline, input-gesture-resolver, game-state-stage-flow, combat-damage, enemy-wave, tower-system, hero-system, battle-hud)
Not read: none
Focus: full (consistency, design theory, scenarios)
Systems Covered: the 8 MVP battle systems, against `game-concept.md`, `systems-index.md`, `design/art/art-bible.md` and `prototypes/hero-pin-concept/`
Specialists: 7 agents (a regression check of the third run's fixes; rules of Data, Input, Flow, Combat; rules of Enemy & Wave, Tower, Hero, Battle HUD; Acceptance Criteria and Open Questions; dependencies and cross-references; design theory; scenarios)
Workflow tier: standard for every system GDD (system overrides).
Prior reviews: `gdd-cross-review-2026-11-02.md`, `-02b.md`, `-02c.md`, each FAIL and resolved the same day.

> Entity registry is empty, so consistency checks rely on GDD reads only.

> **Coverage.** Not reached this run: Data's "Not owned" and Enemy & Wave's "Layout" as cross-reference targets, REPORT.md item 5 and its headings, the `main.gd` names, the art bible's "Minimum sizes" label (all confirmed in run 3), the systems index's Battle HUD Dependency Map row, HUD criteria 9 and 10 against Rules 10 and 11 (lines too long to display), and the Tuning values behind Hero's radius and reach questions. The two rules agents had not reported when this report was written; see the note at the end.

---

## Regression check of the third run

B1, B2, W1 to W13, W15 to W20, D3 and D4 are FIXED. W14 is PARTIAL: `input-gesture-resolver.md:292` still cites "§5 Pinned pose"; the art bible's label is "*Pinned:*" (`:127`). No GDD or the art bible gained an em dash.

---

## Consistency Issues

### Blocking

🔴 **K1. A fresh battle never tells the Battle HUD it is in Build.** Raised from Warning by the main review: the scenario rules call undefined behaviour a blocker, and here it decides whether Start appears. Flow Rule 6 (`game-state-stage-flow.md:37`) opens a stage in Build. Rule 15 now emits `phase` on every phase *change*, and opening in Build is not a change. The HUD's Hidden state moves only when "its phase begins" (`battle-hud.md:151`), and no GDD says the HUD reads the starting phase. On a first launch and after every Retry (Rule 16 builds a new battle), Start/Call's state is undefined.
Change: either the builder emits `phase(Build)` once after the views connect, or the HUD reads the phase when it is built and treats it as an appearance. State it in Flow Rule 15 or 16 and HUD Rule 10 or 11.

🔴 **K2. Start/Call can arm under an open build arc, so a tap meant to close the arc calls a wave.** Raised from Warning by the main review: this is a mis-fire, which Pillar 4 allows zero times. The state table's Hidden row (`battle-hud.md:151`) says Hidden goes to Arming when Intermission begins. HUD Rule 6 (`:44`) and the Edge Cases (`:253`) say Start/Call registers Disabled while the arc is open. If it arms, after 300 ms its priority 350 beats the backdrop's 250, and a tap to dismiss the arc calls the next wave and pays the bonus.
Change: the Hidden row reads "phase begins, arc closed → Arming; phase begins, arc open → Disabled".

### Warnings

⚠️ **K3. The burst button keeps a telegraph look after a halt.** The field telegraph clears on halt (Hero `:282`, `:333`), but the button still draws from `burst_state()`, which stays Telegraphing (HUD `:59`), so an empty wedge sits beside the Lost panel. Add a halted branch to HUD Rule 12 (draw it Locked, or freeze it at the outcome snapshot).
⚠️ **K4. The log can count a resume as a waited wave.** Rule 19 does not say what marks "a wave started after a full wait"; a resume's `phase(Wave)` looks the same. Key the per-wave record on a change of `wave_index()`, not on `phase`.
⚠️ **K5. The grouping key leaves out the launch.** `attempt_seq` "counts from 1 per launch" (HUD `:104`); Hero's "Always-call, humans" row (`:429`) groups by `attempt_seq` and `wave_index` only, so attempts from different launches merge. Group by launch ID plus `attempt_seq`, in both. How the launch ID is made unique is also unstated.
⚠️ **K6. HUD criterion 23 and its deferred row miss the waited-wave records.** Criterion 23 (`:379`), the deferred row (`:398`) and Rule 19's own heading say "one per attempt and per call"; the rule also writes one per waited wave, with `wave_index`, which Hero's gate needs.
⚠️ **K7. No criterion checks the outcome order.** Flow criterion 13 (`:245`) lists no `phase(Fatal)`; criterion 8 does not check that the clock stops before `phase` is emitted and that `cancel()` is not requested inside the tick.
⚠️ **K8. Flow says the towers-only bot "loses every build"** (`:40`, `:261`), but Hero's gate (`:421`) allows it 3 lives or fewer. Base "only mid-skill triggers" on Hero's "Breaking the mixed-build gate" (`:428`), not on a claim that every build loses.
⚠️ **K9. Rule 18 still says Fatal "stops ticks" mid-tick** (`:62`) in its opening, against its own two-step text; and "nothing persists" once Fatal is set, while Rule 19 writes a Fatal record.
⚠️ **K10. Deferred rows with two owners.** "Burst refused in Build" sits in Flow's Tower-stories row (`:259`) against Tower `:398` (Hero stories). L11 and the intermission check are "Tower, Hero stories" at Enemy & Wave `:417` against Tower `:397` (Hero stories); L10 and peak are already Tower CI (criterion 27).
⚠️ **K11. Bot names Hero does not track.** Enemy & Wave `:410` and Combat `:244` name "never-pinned" and "hero-only"; Hero's table has "Hero alone, slow-only", and never-pinned is Hero CI criterion 29. Enemy & Wave `:408` and `:409` carry the same pass text; merge them.
⚠️ **K12. Input's hero fixture uses radius 36** (`:333`, test at `:363`) for the overlap Hero tests at 56 (criterion 32). Use 56, or mark 36 as abstract.
⚠️ **K13. Data contradicts itself on `max_hp`:** `data-config-pipeline.md:182` says Combat "Reads `max_hp` at spawn"; `:132` and Combat `:42` say Enemy & Wave passes it in.
⚠️ **K14. Dependency wording.** Hero `:303` has a bare "**Soft:** Tower System" with no direction. Tower's Downstream heading (`:294`) gives no strength. HUD `:188-189` say "Combat System" and "Enemy & Wave System". Combat's Hero row (`:169`, `:75`) lacks `hp_left` and the tick slot. Flow's Enemy & Wave row (`:176`) describes Enemy & Wave rather than what Flow gives it. The index's Hero rows (`:33`, `:102`) lack the soft Tower link.
⚠️ **K15. Stale citations and units.** Flow `:224` cites "Flow State" for "Flow State Design". Combat `:162` still says it "corrects the systems index", which now agrees. Input `:292` cites "§5 Pinned pose". `game-concept.md:77` still says "world units".

Info: whether `kills_per_burst[]` gets an entry for a burst that started but never released; "seconds to first pin" has no start point; a kill during an append can leave a truncated JSONL line, which the reader should skip; whether a Fatal during build raises `attempt_seq`.

---

## Game Design Issues

### Blocking

None. B2 is resolved: the human pass mark can be computed from Rule 19's records (K5 is the remaining key detail).

### Warnings

⚠️ **E1. Prompt 3 in Intermission invites a wasted first burst.** With D4's latch, prompt 3 can show in Intermission, where the burst is allowed and the field is empty. The first burst then kills nobody and still satisfies next-try 3, against Pillar 2's "the hero keeps the spike" and the "Best moment" row. Options: Wave only (keep the latch hidden in Intermission); keep it and log first-burst victims; accept.
⚠️ **E2. Four rings on screen.** The pin ring, reach ring, ground-tap ring and the burst's ring glyph; a novice who taps where they want the hero sees a ring under the finger, much like a pin landing. The HUD also calls the ground-tap ring two names ("Ground ring", Rule 14; "rejection ring", Input `:64`). For art-director: distinct shapes, and one name.
⚠️ **E3. Flow Rule 9's fallback trigger** ("losing no more lives") is shorter than Hero's row ("same index", "at least 10 attempts"). Point Flow at Hero's row.
⚠️ **E4.** HUD Rule 16 still says the line text "may say 'fired'"; no string does. Delete it.

Still open from earlier runs, unchanged unless noted: D1 human-test bias (no tie rule or minimum per side), D2 first purchase without a role demo, G2 slow's value, G3 attention budget (slightly worse, E1), G4 share gate on one bot, G6 back-loaded economy, G7 no dip in the curve, G8 Flow's Summary "a timer they can beat" and the concept's "each tower type", G9 intermission as dead time, G10 mastery toward hero action, G11 bonus size. Checked clean: D3 is coherent (Paused still resumes exactly); `bursts_started` has no player impact; Input upstream of Flow has no visible effect.

---

## Cross-System Scenario Issues

Scenarios walked: 5
1. A fatal leak in the tick a last-wave burst would release (re-walk)
2. Pause mid-telegraph, resume, then Won in the next tick
3. Retry during the Lost screen's arming window, then a quick first pin
4. The arc open in Intermission with Start/Call Disabled, then the countdown runs out
5. A quit mid-wave, then a new launch

### Blockers
K1 (scenario 3) and K2 (scenario 4), above.

### Warnings
K3 (scenario 1), K4 (scenario 2), K5 (scenario 5), above.

### Info
Scenario 1 is now clean end to end: the latch stops the release, the reap and the bounty, and `phase(Lost)` and the cancel request follow the tick.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| battle-hud.md | K1 initial phase; K2 Hidden row; K3, K4, K5, K6, K14; E1, E2, E4 | Consistency, Design Theory | Blocking |
| game-state-stage-flow.md | K1 initial phase emit; K7, K8, K9, K10, K14, K15; E3 | Consistency | Blocking |
| hero-system.md | K5, K11, K12 (fixture), K14 | Consistency | Warning |
| data-config-pipeline.md | K13 | Consistency | Warning |
| input-gesture-resolver.md | K12, K15 | Consistency | Warning |
| enemy-wave.md | K10, K11 | Consistency | Warning |
| tower-system.md | K14 | Consistency | Warning |
| combat-damage.md | K11, K14, K15 | Consistency | Warning |
| game-concept.md | K15 | Consistency | Warning |
| systems-index.md | K14 | Consistency | Warning |

---

## Verdict: FAIL

Two blocking issues, both one-line rules in Battle HUD and Flow: K1, how a new battle shows Build, and K2, Start/Call under an open arc. The source agent rated both as Warnings, and the main review raised them, for the reasons given. Every earlier blocker is fixed, the dependency graph matches on both sides, and the number of findings fell from run 3.

### Required actions before re-running

1. K1: have the builder emit `phase(Build)` once after the views connect (or have the HUD read the phase when built), stated in Flow and Battle HUD.
2. K2: make the Hidden row arm only with the arc closed, and go Disabled with it open.

---

## Addendum: the two rules agents

Both rules agents reported after the body above was written. Rules slice 2 also found K2 on its own (no state-table entry into Disabled). New findings:

🔴 **K16. A Fatal latched between ticks has no defined emit or cancel time.** Raised from Warning by the main review, for the same reason as K1: it is undefined behaviour on an outcome path. Flow Rules 15 and 18 (`:49`, `:62`) define the second step only "after the tick returns", but the failure handler can fire between ticks: from a command's accessor read (Tower's `build`, `tower-system.md:55`) or from the HUD's cost read when an arc opens (`battle-hud.md:267`). Flow's stage table (`:89-96`) also has no Fatal row, though Tower (`:78`) and HUD Rule 8 close on `phase(Fatal)`. Change: state that a Fatal latched between ticks emits `phase(Fatal)` and requests `cancel()` at the end of that same frame, and add a Fatal row to the stage table.

⚠️ **K17. Combat has no `halted()`, though Flow says Combat needs it.** Flow `:49` names Combat Rule 11 among the systems whose `halted()` check skips the rest of the tick; `combat-damage.md` never mentions `halted`, and Combat's Flow row (`:77`) injects nothing, while Combat `:153` says "the rest of the tick is skipped (Flow Rule 15)". Either Combat's Status countdown checks an injected `halted()`, or Flow says `battle.tick` itself skips the remaining slots and drops Combat from its list.
⚠️ **K18. Input's `cancel()` callers leave out retry's inline cancel** (Input `:66`, `:123`) though Flow Rule 16 (`:54`) and HUD `:100` say retry cancels input.
⚠️ **K19. Input's radius list misses Start/Call's 48** (`battle-hud.md:116`), and the arc backdrop's field-covering disc (about 551) falls outside the stated `r` range of 36 to 56 (`:148`, `:195`). Add Start/Call; exempt sinks and the backdrop from the range, or state the backdrop's radius.
⚠️ **K20. A double tap on a slot "dismisses" in Tower** (`tower-system.md:66`) but the HUD ignores an early disc press (`:44`) and closes the arc only on a press whose best tap is not a disc (`:46`), so a second tap near the slot's top edge leaves the arc open. Say whether an ignored early disc press closes the arc.
⚠️ **K21. Hero cites Input Rule 3** for "tap targets still win a tap" (`hero-system.md:56`); that is Input Rule 4 (`:63`).

Minor: Input's ADR note (`:78`) still says "so a pause menu cannot strand a gesture"; there is no pause button (HUD Rule 4).

**Revised verdict: FAIL, three blocking issues (K1, K2, K16).** Required actions add: 3. K16: define the emit and cancel time for a Fatal latched between ticks, and add a Fatal row to Flow's stage table.

## Resolution, 2026-11-02: blockers, warnings and recommended rulings applied, re-run pending

User instruction: apply the recommended option for every open ruling.

- **K1:** Flow emits `phase(Build)` once after a battle is built and its views connect (Rules 6, 15, 16; criteria 1 and 16); Battle HUD Rule 11 and its state table treat it as Build beginning.
- **K2:** the Hidden row arms only with the arc closed and goes Disabled with it open.
- **K16:** a Fatal latched outside a tick stops the clock, emits `phase(Fatal)` and requests `cancel()` at that frame's end (Rules 15, 18; criterion 17); Flow's stage table has a Fatal row.
- **K3 to K21, E3, E4:** applied as listed. Flow's tick loop checks `halted()` between slots, so Combat needs none of its own. Records group by launch ID plus `attempt_seq`, are keyed on a `wave_index()` change, and flush on focus loss.
- **Rulings (recommended options):** D1 at least 5 called and 5 waited waves per index, a 0-against-0 tie ignored; D2 each arc disc shows a looping icon of its role; E1 prompt 3 in Wave only; E2 the ground-tap ring is the "rejection ring", dotted and never solid, in the HUD, Input and the art bible; G2 the slow hint is removed until Hero's new "Slow value" gate passes; G3 human re-pin rate is logged against lives; G4 and G10 a ceiling-bot gate at 45% brings a burst-victim cap forward; G6 and G11 accepted for MVP, with first-playable checks in Tower; G7 accepted as a finale, with a dip tested on stage 2; G8 Flow's Summary and the concept's result line reworded; G9 the countdown is not a wait timer, since Call can always end it; X9 a new `bursts_emptied` counter, taken out of the phone miss rate.

Nothing from the earlier runs is left open.
