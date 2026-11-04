# Cross-GDD Review Report

Date: 2026-11-04
GDDs Reviewed: 8 of 8 present
Not read: none
Focus: full (consistency, design theory and cross-system scenarios)
Systems Covered: Data & Config Pipeline, Input & Gesture Resolver, Game State & Stage Flow, Combat & Damage, Enemy & Wave, Tower System, Hero System, Battle HUD & Build UI
Registry: 34 entries (design/registry/entities.yaml), used as the conflict baseline
Method note: the skill asks for GDD sections pasted into the agent prompts. They came to about 300 KB, so each GDD's reviewed sections (Summary, Overview, Detailed Design, Formulas, Dependencies, Game Feel, Cross-References, Acceptance Criteria) were written to one file per GDD and the two agents read those. Battle HUD's references into the siblings' UI Requirements sections, left out of those files, were checked by the main session instead.
Workflow: `standard` for every GDD, so no Player Fantasy or Tuning Knobs sections exist. Pillar alignment (3f) and fantasy coherence (3g) ran against each GDD's Summary, Overview and Game Feel; the knob-ownership scan (2d) ran against the Deferred tables instead.

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

🔴 **Content-test exact ID sets ignore Battle HUD's checks**
- enemy-wave.md, Layout rules: "A new stage must also pass Battle HUD's layout checks (Start/Call clearances and the arc rules), which the same content test runs."
- enemy-wave.md, criterion 20: each copy must report "exactly" its set, for example slot 0 = (270, 303) gives {L1}, slot 3 = (130, 700) gives {L1}, slot 3 = (150, 760) gives {L3}.
- battle-hud.md, Content rules: `hud_slot` (y at least 318), `hud_arc_band` (hexagon panel top at least 174) and `hud_call_slot` (16 clear of Start/Call) run in the same test, so those copies also report HUD IDs (for slot 0 at y 303: `hud_slot` and `hud_arc_band`).
- Both criteria cannot pass as written. Battle HUD's own copies (criterion 33) report no Enemy & Wave ID, so only Enemy & Wave's sets break.
- → Either scope criterion 20's sets to Enemy & Wave's IDs (the HUD IDs have their own copies in Battle HUD criterion 33), or add the HUD IDs each copy trips to its set. `tools/balance-sim/stage_rules.py` implements only Enemy & Wave's rules, which suggests the first.

### Warnings

⚠️ **Flow Rule 1 does not know about the HUD's session flags.** battle-hud.md Rule 13 keeps `pinned_once`, `built_once` and `won_once` on the app root "which survive retry since the root does (Flow Rule 1)"; Flow Rule 1 says "The only things that survive a retry are this root and the catalogue", and its Overview says "nothing carried over". → Flow Rule 1 should name the three presentation flags (and the HUD's Retry-to-Start timer) as root state, and say who writes them.

⚠️ **Missing reverse dependencies from today's edits.**
- combat-damage.md uses Flow's `in_tick()` and Enemy & Wave's `to_ticks`. Flow's Dependencies list Combat only for counters, and Enemy & Wave lists Combat only as upstream.
- Hero criterion 32 uses `speed_factor`, but Hero's Combat interface omits it, and Combat's Hero row says only "`deliver`, helpers".
- data-config-pipeline.md's HUD row omits the level count and the Stage and Wave records.

⚠️ **Bot-gate ownership scattered.** enemy-wave.md's Deferred rows give "Mono-role" and "Always-call" to Tower stories, and its always-call adds "does not beat a driven hero". Its "Pillar 2 bots (Combat's row)" says the thresholds live in Combat. tower-system.md says Hero's deferred table owns them, and so do Flow and Combat ("Hero System's Deferred rows decide"). Enemy & Wave's towers-only row ("best of the seven builds") is broader than Hero's ("the mixed builds"). → Point Enemy & Wave's rows to Hero's.

⚠️ **Stale statements.**
- tower-system.md says "L11 and `burst_spike` wait for the Hero record", but the Hero record exists (196 ≥ 175, 5.78). It also says Combat Rule 6 named a different gate, but Rule 6 has since been amended to match.
- input-gesture-resolver.md and data-config-pipeline.md say none of their downstream systems has a GDD yet.
- battle-hud.md hands Hero "the cooldown's total for the wedge", but Hero Rule 16's reads hold no total.
- game-state-stage-flow.md's UI Requirements hard-code "Broke on wave N of 6", where Battle HUD uses the stage's wave count.

⚠️ **Rule restated in a different form.**
- hero-system.md's content rule states the intermission floor in seconds ("15 ≥ 10.25"). enemy-wave.md states it in ticks, saying a compare in seconds could miss by one tick. Hero should cite Enemy & Wave's form.
- input-gesture-resolver.md counts ground rings "per session", while battle-hud.md Rule 14 counts three per battle and resets on retry.

⚠️ **Figures disagree.**
- tower-system.md gate part 2 reads "30% against 25%", while hero-system.md reads "27% against 25%". Both pass; one figure is stale.
- input-gesture-resolver.md gives the hit radius `r` as "36–48 at MVP", while live radii include the hero's 56, the chip's 40 and the backdrop sink.

⚠️ **Phone-test thresholds differ.** tower-system.md allows at most 1 wrong disc per 20 builds. input-gesture-resolver.md's P1 gate allows zero mis-fires, and a wrong disc counts as one.

⚠️ **Cross-References incomplete.** data-config-pipeline.md's table names no sibling GDD, although its rules depend on Enemy & Wave and the Input record.

All rule numbers cited across GDDs that were checked resolve to the right rule.

---

## Game Design Issues

### Blocking
None.

### Warnings

⚠️ **Attention budget at the limit, and no bot pays for it (3b).** During a Wave, four systems are active on one thumb:
- re-pinning (Hero Rule 3);
- burst aim (Hero Rules 6 to 13);
- mid-wave building from the arc (Tower Rules 6 and 7);
- the upgrade chip (Tower Rule 8).

Two of them are timed windows. In Intermission, Start/Call and the next-wave line replace the burst. Tower Rule 6 says "the thumb cannot re-pin at the same time", but every bot acts in parallel. Hero's Simulated results already show 3 s reactions dropping the share to 18% to 23%. → Add a one-thumb bot mode, where each gesture has a busy time, and report its share and lives beside greedy. Log whether each build or upgrade happened in Wave or Intermission (Battle HUD Rule 19).

⚠️ **The best burst play lowers the player's mastery number (3c).** Firing whenever Ready wins (10 lives against 9), yet these all reward waiting for a bunch:
- the concept pitch;
- Hero's Summary;
- Enemy & Wave's Game Feel ("a burst opportunity forming, seen seconds ahead");
- the mastery metric, kills per burst (Hero Rule 17).

The gate is settled. → Compare `burst_victims` with `best_victims` and `kills_per_burst` at first playable, and decide before Vertical Slice whether kills per burst survives as the shown metric.

⚠️ **Greedy firing plus calling every wave sits just outside the share band (3c, 3e).** Run on 2026-11-04 with `hero_bots.py`'s greedy bot and every wave called:

| Mixed build | Lives | Hero share | Stage length |
|---|---|---|---|
| 3 single, 1 splash, 1 slow | 10 | 31.0% | 3.4 min |
| 2 single, 2 splash, 1 slow | 10 | 32.7% | 3.7 min |
| 3 single, 2 splash | 10 | 27.2% | 3.4 min |
| 2 single, 1 splash, 2 slow | 10 | 30.6% | 3.6 min |

The median is 30.83%, against the band's top of 30% (greedy without calling: 29.81%). Calling gains no lives, so it is not dominant. But the play a lit button and a free bonus invite lands just outside the band, in a stage well under the concept's 5 minutes. → Add this row to Hero's Simulated results. Decide whether the share gate runs with calls or without them.

⚠️ **Stage length measured on the wrong bot (3e).** enemy-wave.md's stage-length row (5 to 8 minutes) runs on mid-skill. The gate bot runs 4.7 to 4.9 minutes uncalled and 3.4 to 3.7 with calls. → Measure on the greedy bot, or state that 5 to 8 minutes describes mid-skill play.

⚠️ **The share gate is a stage aggregate (3e).** The hero's power is flat (burst 130 every 10 s), while tower power grows about 4 times with gold. Early waves may be hero-carried and late waves hero-light inside a 29.8% median. No GDD reports share per wave. → Report it in `hero_bots.py` and the HUD log.

⚠️ **Wave 6 is a step (3e).** HP per gold available before each wave runs 8.3, 9.4, 9.2, 8.4, 10.1, then 12.3. A finale spike is defensible, but no run reports which wave breaks lost runs. → Report the breaking wave per placement in `--orders`.

⚠️ **Gold invariant headroom spans three GDDs (3d).** The board can't be filled before the last wave with 24 gold of headroom at starter values. That depends on Enemy & Wave's bounties and intermission caps and Tower's costs together. The content test catches a breach, but every new stage will press on it.

⚠️ **"Calm" against "busy thumb" (3g).** Most systems tell one story: towers as "the machine working", the hero as "a person acting", the HUD as "calm", and the concept's "tactical calm punctuated by hero bursts". But hero-system.md's Game Feel says "a burst every 10 s keeps the thumb busy". Under the gate's reference play (17 to 19 bursts, a re-pin every 3 s), the punctuation becomes a drumbeat. → Add a first-playable survey item (calm with spikes, or busy throughout) and align Hero's Game Feel wording with the result.

No progression-loop competition (3a): gold buys towers, and towers make kills. No pillar drift (3f): every system maps to a pillar, and none breaks an anti-pillar. No economic sink without a source (3d): lives are a sink with no source by design, and the hero is the only catch-up mechanism, which serves Pillar 2.

---

## Cross-System Scenario Issues

Scenarios walked: 5
1. Last kill of a wave (Tower → Combat → Enemy & Wave reap → gold → clear → Flow Intermission → HUD Start/Call)
2. Fatal leak while a burst telegraphs, the chip is open and a kill is pending
3. Early call with the burst ready and the hero parked at Start/Call
4. Retry after a loss, with the session flags and the retry timer
5. Burst release in the same tick as tower splash

### Blockers
None. Scenarios 1 to 3 resolve in the documented order:
- **Scenario 1:** bounties pay before the clear, and gold updates before Start/Call arms.
- **Scenario 2:** the fatal leak latches Lost, the chip closes on `phase(LOST)`, the telegraph never lands, no bounty is paid, and the result snapshot is taken on the next frame.
- **Scenario 3:** `wave_called_early` fires before `phase(WAVE)`, the bonus is paid before the first spawn, and a press in the hero's disc goes to the hero.

### Warnings
⚠️ **Retry after a loss: Game State & Stage Flow, Battle HUD.** The session flags and the Retry-to-Start timer live on the app root, but Flow Rule 1 does not name them, and no GDD says who writes them. This is the consistency warning above, seen from play.

### Info
ℹ️ **Fatal leak: Enemy & Wave, Battle HUD.** After a fatal leak the leak loop stops, so leakers not yet processed on that tick are missing from "Got through". This follows the rules (they cost nothing), but the result can show fewer leaks than the player saw reach the exit.

ℹ️ **Burst and splash in one tick: Tower, Hero, Combat.** Towers resolve before the hero, so a kill the preview marked can go to a tower first. The Hero GDD already calls the marks indicative. During burst clearance, tower flashes are suppressed while towers still kill, so enemies die with a death disc but no hit flash.

ℹ️ **Early call with an arc open: Battle HUD, Flow.** Start/Call is disabled while an arc is open, so the first tap closes the arc and a second tap calls. This is intended, but nothing tells the player.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| enemy-wave.md | Criterion 20 exact sets omit Battle HUD's IDs; bot-gate rows point to Tower and Combat instead of Hero; stage length measured on mid-skill | Consistency | Blocking |
| game-state-stage-flow.md | Rule 1 lacks the session flags; `in_tick()` missing from Dependencies; "of 6" in UI Requirements | Consistency | Warning |
| hero-system.md | No cooldown-total read; Combat interface lacks `speed_factor`; intermission rule in seconds; no greedy-plus-calls row; no per-wave share; "thumb busy" wording | Consistency, Design Theory | Warning |
| tower-system.md | Burst share 30% against Hero's 27%; stale L11 and Rule 6 wording; phone threshold against Input; attention cost not modelled | Consistency, Design Theory | Warning |
| input-gesture-resolver.md | "No GDD yet"; ground rings per session; `r` range; phone threshold against Tower | Consistency | Warning |
| data-config-pipeline.md | "No GDD yet"; HUD row; Cross-References omit siblings | Consistency | Warning |
| combat-damage.md | Hero row interface incomplete | Consistency | Warning |
| battle-hud.md | Log lacks per-wave share and Wave-or-Intermission timing; depends on the Hero and Flow fixes | Design Theory | Warning |

---

## Verdict: FAIL

One blocking issue must be resolved before architecture begins. Every phase ran on all 8 GDDs. One claimed blocker was rejected on checking: "bot acceptance modes run only through the resolver" was reported as appearing in no GDD. **Corrected in the re-run below: that rejection was wrong.** The text is in input-gesture-resolver.md, line 387, and the blocker stands.

### Required actions before re-running
1. enemy-wave.md criterion 20: scope its exact ID sets to Enemy & Wave's own rule IDs, or add the Battle HUD IDs each copy trips, and keep `stage_rules.py` in step.


---

# Re-run — 2026-11-04 — Focus: consistency

GDDs Reviewed: 8 of 8 present
Not read: none
Focus: consistency only (design theory not run; the design-theory findings above stand from the full run)
Change since the full run: enemy-wave.md criterion 20 now compares only Enemy & Wave's IDs, and battle-hud.md criterion 33 only `hud_*` IDs, each pointing to the other (user decision). The agent read the same per-GDD sections, now including UI Requirements, so Battle HUD's references into the siblings' UI Requirements were checked too.

## Blocker status

- **Fixed: content-test ID sets.** The two criteria no longer contradict, and the fix added no new contradiction. A small gap remains: Enemy & Wave says criterion 33 "checks them with its own copies", but only 3 of the 10 `hud_*` IDs have copies so far ("The other IDs get copies in their story").
- 🔴 **Open: bots through the resolver.** The full run rejected this one wrongly. The text exists in two places:
  - input-gesture-resolver.md, Deferred criteria, first row (line 387): "bot acceptance modes run only through the resolver".
  - Its Overview (line 19): bots "drive the hero through the same press, move and release calls".

  Both contradict Input's own Rule 11 and Interactions row ("Call Hero's and Tower's commands; one equivalence test passes through the resolver"). They also contradict hero-system.md, which says the resolver "is not in the headless build" and whose bots call `pin` and `burst` (criteria 28 and 29). The row cannot pass. → Replace the clause with "the equivalence test (Rule 11) passes through the resolver", and fix the Overview sentence.

## New warnings

- ⚠️ **Range ring owner.** tower-system.md UI Requirements ("Battle HUD draws these … shows its range ring for 1.5 s") and its Handed list ("draws … the range ring") contradict battle-hud.md Rule 9 and criterion 8 ("the HUD draws no ring (Tower's view does)"). → Fix Tower's list and Handed line.
- ⚠️ **Top-band input.** input-gesture-resolver.md Interactions says "its top-band Controls consume their own events before the adapter". Input's own UI Requirements and battle-hud.md say the top band ignores input. → Correct Input's row.
- ⚠️ **Prompt retirement.** hero-system.md UI Requirements says "Before a first pin, the nudge also repeats the prompt". battle-hud.md Rule 13 retires prompt 1 once the hero was pinned in an earlier battle this session. → Hero should say the nudge repeats only a prompt still showing.
- ⚠️ **L1's reason.** enemy-wave.md L1 says y at least 304 keeps "its hit disc and build arc … in the field and below the band", with a margin of 16. Battle HUD's cost panel reaches `slot y − 144` (160 at y 304), and `hud_slot` needs 318. → Restate L1 as covering the discs, and point to `hud_slot` for the panels.
- ⚠️ **Tower figures.** tower-system.md's burst-outcome median (3.5 to 4) differs from hero-system.md's (4), in addition to the 30% against 27% share already noted.

## Prior warnings

All thirteen still stand, each verified against the text:
- Flow Rule 1 and the session flags
- the three missing reverse dependencies
- bot-gate ownership
- Tower's stale L11, `burst_spike` and Rule 6 wording
- "no GDD yet" in Input and Data
- the HUD's cooldown total
- Flow's "of 6"
- Hero's intermission rule in seconds
- ground rings per session
- 30% against 27%
- Input's `r` range
- the phone thresholds
- Data's Cross-References

## Not assessed

Battle HUD's reference to enemy-wave.md "Open Questions" was not checked; that section was not in the files the agent read.

## GDDs flagged for revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| input-gesture-resolver.md | Deferred row and Overview require bots through the resolver; top-band row; `r` range; ground rings per session; "no GDD yet" | Consistency | Blocking |
| tower-system.md | Range ring owner; 30% and 3.5 figures; stale L11 and Rule 6 wording; phone threshold | Consistency | Warning |
| enemy-wave.md | L1's reason and margin; bot-gate rows; no reverse Combat row | Consistency | Warning |
| hero-system.md | Prompt nudge after retirement; `speed_factor` in the Combat row; no cooldown total; intermission rule in seconds | Consistency | Warning |
| game-state-stage-flow.md | Rule 1 session flags; `in_tick()` in Dependencies; "of 6" | Consistency | Warning |
| combat-damage.md | Hero row interface incomplete | Consistency | Warning |
| data-config-pipeline.md | HUD row; "no GDD yet"; Cross-References | Consistency | Warning |
| battle-hud.md | "Checks them with its own copies" with 3 of 10 copies | Consistency | Warning |

## Verdict: FAIL (consistency only — design theory not run)

### Required actions before re-running
1. input-gesture-resolver.md: replace the Deferred row's "bot acceptance modes run only through the resolver" with "the equivalence test (Rule 11) passes through the resolver", and make the Overview say bots call Hero's and Tower's commands.
