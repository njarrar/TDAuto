<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: With the hero pinned to a lane and the burst aimed by the player, is TOWERS + HERO better than TOWERS ONLY and than a hero nobody touches? -->
<!-- Date: 2026-11-01 -->
# Concept Prototype Report: hero-pin

> **Date**: 2026-11-01
> **Prototype Path**: Engine (Godot 4.7.2, GDScript)
> **Concept File**: design/gdd/game-concept.md
> **Pivot chain**: hero-plus-towers (PIVOT, 2026-11-01) → **hero-pin** (this report). Carry-forward: `../hero-plus-towers-concept/PIVOT-NOTE.md`.

---

## Hypothesis

If the player's only hero inputs are **pinning the hero to a lane** (one drag) and **aiming its burst** (one drag), the player will prefer TOWERS + HERO over TOWERS ONLY in the mode switch and will not describe the hero as a chore — evidenced by that stated preference, a clear score gap between the full mode and a TOWERS + HERO NEVER TOUCHED mode (the pet test), player-aimed bursts landing on 3+ enemies, and zero reported mis-taps.

---

## Riskiest Assumption Tested

That the hero still feels like *commanding* once its movement is reduced to a pin — that removing tap-to-move removes the chore without removing the fantasy. **It proved out.** The tester named re-pinning to a leaking lane and aiming a burst into a bunched wave as the moments where it worked.

---

## Approach

A copy (not an import) of the first prototype's single-file Godot project with the control model replaced, ~330 lines of GDScript, built and bot-tested in under an hour, then played by the developer in two sessions.

**Path chosen:** Engine
**Reason for path:** drag gestures and hold-position feel are the hypothesis.

**Shortcuts taken (intentional):**
- One tower type plus one lvl-2 upgrade (a placeholder for depth, per CD-PLAYTEST on the previous report), no trees, no stars, no menus, no audio
- Fixed path, 6 fixed slots, enemy position is a distance along the path
- Hero holds its pin and only steps toward enemies inside a 90 px leash; no pin = idle at a default spot off the path
- Burst aimed by drag from the button; release on the button = burst at the pin
- Four-way mode switch including the never-touched pet test; headless bot (`-- --auto`) that re-pins every 1.5 s to the densest path point and bursts at 3+ enemies
- Mouse standing in for touch; never run on a phone

---

## Result

**Bot run (after one tuning pass: upgrade dmg 20→16, burst 45→38):**

| Mode | Result | Hero + skill share | Bursts (3+ hit) |
|---|---|---|---|
| Towers + hero (driven) | WON, 10/10 lives | 39% | 9 (9) |
| Towers only | WON, 3/10 lives | — | — |
| Hero only | LOST, wave 4 | 100% | 13 (13) |
| Towers + hero, never touched | WON, 3/10 lives — identical to towers only | 0% | 0 |

Pet test: the driven hero ends at 10 lives against 3 for the untouched one — a clear gap, so an unpinned hero contributes nothing and a pinned one is decisive. Towers-only now *wins* (narrowly) because the upgrade exists; the hypothesis's "towers-only fails" clause did not hold on numbers, and the judgement rests on the human comparison.

**Human playtest (1 tester, the developer, two sessions, all four modes, desktop mouse):**

- Hypothesis: **CONFIRMED.** Preferred mode: *"towers + hero, where you control hero."*
- Best moments (all three named): **aiming a burst into a bunched wave**, **re-pinning the hero to a leaking lane**, **upgrading a tower at the right time.**
- Worst moment: **"still too basic / nothing to decide"** — one tower type and one upgrade. No drag fired the wrong thing; the pin was not reported fiddly.
- Surprise: none.

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | Engine |
| Iterations to playable | 1 (imported clean; one tuning pass after the bot run) |
| Prototype duration | ~1 hour build + bot; two play sessions |
| Playtesters | 1 internal (developer), 0 external |
| Feel assessment | Pin + leash read as commanding, not babysitting; aimed burst is the hero's signature moment; zero mis-fires between pin, burst and slot taps on a mouse |
| Hypothesis verdict | **CONFIRMED** (human comparison and pet test); the "towers-only fails" sub-clause REFUTED on numbers once an upgrade exists |

---

## Recommendation: PROCEED

The hook survives its second contact: with a pin and an aimed burst, the hero is the thing the player reaches for, and the pet test shows it is the player's input — not an autopilot — that makes the difference. The remaining complaint, "too basic," is the depth that was cut on purpose and that the concept assigns to the skill trees, tower variety and stage variation; it is a design-documentation problem, not a prototype problem. One tester on a mouse is thin evidence, so the first phone build should repeat the four-mode comparison before the control model is frozen in a GDD.

## Creative Director Review — CD-PLAYTEST: APPROVE (2026-11-01)

Core fantasy present: the named best moments are "the hero is your hands" and "towers are the standing army" in action. Pillar 2 satisfied in structure (hero-only loses); 39% share is a bot ceiling, not a human result. Pillar 4 (Thumb-First) is **untested**, not passed — mouse precision flatters both drag-aims. The pet test shows the hero needs input, not that *repeated* input matters.

Carry into design and the next test:
1. Add a fifth bot mode, "pinned once at wave start, never touched again"; keep the "player's input decides fights" claim only if active play clearly beats it.
2. Log human burst hit counts — the 3+ criterion has only bot evidence.
3. Compute hero damage share from human runs before retuning the 25–30% target.
4. Phone build + a non-developer tester are a hard condition before any Pillar 4 claim.
5. Upgrade 20→16 and burst 45→38 were tuned to the bot; they are not balance values.

Director did not read the prototype code; judged from the report. Main risk: one tester who is also the designer.

---

## If Proceeding

- **Core tuning values discovered:** pin leash 90 px; burst radius 150 px, 38 dmg, 8 s cooldown; hero 6 dmg / 0.4 s; tower 12 (lvl 2: 16) / 0.6 s, range 150; six slots on a 540×960 portrait field; a human-like re-pin cadence of ~1.5 s. Hero + skill share landed at **39%**, above the concept's 25–30% target — one more pass is needed, likely on hero auto-attack rather than the burst (the burst is the fun).
- **Assumptions confirmed:** the hero is the signature moment (pillar 2) *when the player chooses where it stands and where the burst lands*; Signal Board primitives read fine; one tap/drag per action works (pillar 4); the three-/four-mode switch is a reliable test instrument.
- **Assumptions disproved:** "steering the hero" (tap-to-move) is not the fantasy — *positioning* it is. "Towers-only cannot clear the stage" is false once any tower upgrade exists; wave tuning must assume the hero's contribution, or the hero becomes optional.
- **Emergent mechanics:** the leash circle doubles as the hero's "zone of control" and players read it as such — worth formalising as the hero's area stat (a tree node that widens it is a visible, pillar-1 upgrade). Re-pinning is itself a decision cadence: how often you *can* re-pin (instant vs. a short walk) is a tuning knob.

**Next steps:**
1. `/design-review design/gdd/game-concept.md` — update Core Loop and pillar 2/4 text from "steer" to "pin + aim"
2. `/gate-check` — Concept → Systems Design
3. `/art-bible` — from the Signal Board anchor
4. `/map-systems` → `/design-system [mechanic]` with the tuning values above in Tuning Knobs / Formulas

---

## Lessons Learned

- **What assumptions were broken by actually building this?** Pillar 2 said "the hero decides fights"; the first prototype showed the *control model* decides whether that is fun. The same hero with the same numbers went from chore to favourite by changing two gestures.
- **What surprised us that didn't show up in the brainstorm?** Adding one tower upgrade was enough to let towers-only win. Depth on the tower side and relevance of the hero pull against each other; the wave design has to be tuned with the hero in, not added on top.
- **What would we test differently next time?** Run the pet test from the first build — it was the cheapest, clearest signal here. Test on a phone before judging drags. Recruit one tester who is not the designer.

---

> *Prototype code location: `prototypes/hero-pin-concept/`*
> *This code is throwaway. Never refactor into production.*
