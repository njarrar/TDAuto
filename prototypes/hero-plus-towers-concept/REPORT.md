<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: Is placing towers while steering one hero into leaks more fun than either alone? -->
<!-- Date: 2026-11-01 -->
# Concept Prototype Report: hero-plus-towers

> **Date**: 2026-11-01
> **Prototype Path**: Engine (Godot 4.7.2, GDScript)
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

If the player places towers **and** steers one hero into the leaks, the combined mode will clear 6 waves that towers-only and hero-only cannot, and the player will use the hero's burst skill on groups — evidenced by (a) a blind three-mode comparison preferring TOWERS + HERO and (b) the skill fired on 3+ enemies rather than mashed.

---

## Riskiest Assumption Tested

That the hero adds *a lot* rather than *a little* — that being on the field is the fun, not a tax. **It did not prove out.** The player found the hero a chore; towers carried the game.

---

## Approach

One Godot project under `prototypes/`, ~250 lines of GDScript in one file, built and bot-tested in under an hour, then played by the developer.

**Path chosen:** Engine
**Reason for path:** tap-to-move and hero control feel are the hypothesis; browser latency would lie about them.

**Shortcuts taken (intentional):**
- One tower type, no upgrades, no trees, no stars, no menus, no audio
- Fixed path and 6 fixed build slots; enemy position is a distance along the path, no pathfinding
- All values hardcoded; placeholder shapes (Signal Board primitives)
- A three-way mode switch (TOWERS + HERO / TOWERS ONLY / HERO ONLY) so the comparison is in the build, not in memory
- A headless bot (`-- --auto`) that plays all three modes and prints damage by source
- Mouse clicks standing in for touch; never run on a phone

---

## Result

**Bot run (after one tuning pass, hero attack 14→6, skill 70→45):**

| Mode | Bot result | Damage share |
|---|---|---|
| Towers + hero | WON, 8/10 lives | hero + skill 48% |
| Towers only | LOST on wave 5 | — |
| Hero only | LOST on wave 4 | — |

The first bot run had the hero at 63% of damage and winning alone — a pillar-2 violation — which the tuning pass corrected. The bot is not a person; it only shows the numbers are not broken.

**Human playtest (1 tester, the developer, all three modes, on desktop with a mouse):**

- Verdict on the modes: **"Towers carried it; hero felt like a chore."**
- Why a chore: **babysitting** ("had to keep tapping to reposition") and **tap confusion** (taps built when a move was meant, or the reverse).
- Overall: *"feels very basic in terms of thinking and mechanics — I couldn't upgrade any tower, just wait till I have more gold and add more towers."* The depth complaint is expected (upgrades and trees were cut on purpose) but it also says the tower side had no decision to make, so the hero was the only thing asking for attention — and that attention read as work.
- Best moment: none named ("I am not sure").
- The hero's burst skill was not singled out as fun or as mashed.
- No crash, no parse error after the one fix below.

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | Engine |
| Iterations to playable | 2 (one GDScript type-inference parse error on first import; one hero-tuning pass after the bot run) |
| Prototype duration | ~1 hour build + bot; one play session |
| Playtesters | 1 internal (developer), 0 external |
| Feel assessment | Tap-to-move hero = constant repositioning with no payoff; tap target collision between "move" and "build" even with the priority order; towers "just worked" |
| Hypothesis verdict | **REFUTED** — the combined mode was not preferred; the hero was experienced as a cost |

---

## Recommendation: PIVOT

> **Creative Director Review (CD-PLAYTEST)**: CONCERNS 2026-11-01 — direction approved; four changes folded into the pivot below (pin as the hero verb, player-aimed skill, a never-touched bot mode as the pet test, upgrade kept a placeholder). Judged from the session summary, not the files on disk.

The towers-plus-growth frame is intact — nothing in the test argued against towers, slots, waves or the Signal Board look — but the concept's hook, *the commander who is on the field*, failed its first contact as implemented: continuous tap-to-move turned the hero into a unit to babysit, and sharing one tap surface with build slots produced mis-taps even with a priority order. The bot numbers say the hero *matters* mechanically (towers-only loses); the human says it does not *feel* like it matters. That gap is a control-model problem, not a concept problem, so the next prototype changes how the hero is driven and tests it again.

---

## If Pivoting

**Pivot direction:** remove continuous hero steering, without handing the fight to an autopilot. The player's hero verbs are exactly two, both one gesture:
1. **Pin** — one drag onto a lane. The hero walks there, holds, and fights only within a leash radius around the pin; small movements inside the leash are automatic. No pin → the hero idles at a default spot and does nothing useful. (The creative director's correction: an auto-walk to the densest cluster would let the autopilot both place the hero *and* aim the skill, turning the hero into a pet.)
2. **Skill** — drag from the skill button to a target spot to burst there; a plain tap fires at the pin. Reading where enemies bunch is the player's "on the field" moment, so the player aims it, not the pathing.

Tap on walkable ground does nothing, which removes the move/build collision outright. Hero + skill damage re-tuned toward the concept's 25–30% share (48% here).

**Pet test (new bot mode):** a fourth mode, *towers + hero, never touched* (no pin, no skill), runs beside the other three. If it scores close to the full mode, the hero is a pet and the pivot fails. Success = a clear gap, and skill bursts landing on 3+ enemies because the player chose the spot.

**What to keep:** the tower/slot/wave loop; the three-mode switch as the test instrument; the bot and its damage-by-source print; the burst skill (area, visible ring, cooldown); Signal Board primitives — hero as the only asymmetric glowing shape read fine at this size.

**Also record for the MVP, not the pivot:** the tester's "basic / nothing to decide" note. Upgrades and a second tower type are the MVP's job and were cut here deliberately, but the next prototype should include **one** tower decision (a lvl-2 upgrade on tap) so the tower side is not a pure wait. It is a **placeholder**: the real answer to "basic" is the cross-buffing trees (the hook), and the upgrade must not grow into a tower-depth project that drifts toward plain Kingdom Rush.

**Next step:** `/prototype hero-pin` (reads `PIVOT-NOTE.md`).

---

## Lessons Learned

- **What assumptions were broken by actually building this?** "The hero is the fun" assumed that *controlling* the hero is fun. Controlling a unit on a tower-defense board with one thumb is management, and management of one unit next to six towers that need nothing is a chore.
- **What surprised us that didn't show up in the brainstorm?** The bot and the human disagreed. Mechanically the hero was decisive (towers-only lost); experientially it was a tax. Balance numbers cannot stand in for a play session.
- **What would we test differently next time?** Put the comparison in the player's hands from the start (the mode switch worked — keep it), give the tower side one decision so the control model is judged against a fair baseline, and test on a phone: tap confusion with a mouse will be worse with a thumb.

---

> *Prototype code location: `prototypes/hero-plus-towers-concept/`*
> *This code is throwaway. Never refactor into production.*
