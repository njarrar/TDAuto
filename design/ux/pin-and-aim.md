# UX Spec: Hero Pin and Burst Aim

> **Status**: In Design (autonomous draft, 2026-11-04; revised after the first `/ux-review` the same day)
> **Author**: ux-designer (autonomous mode; user to review)
> **Last Updated**: 2026-11-04
> **Journey Phase(s)**: none recorded; `design/player-journey.md` does not exist (PAQ-14). Pin and aim are used in every battle, from the first wave onward
> **Platform Target**: iOS and Android, portrait, touch only. The desktop development build uses the mouse as touch. No keyboard, gamepad or hover input exists (technical preferences)
> **Template**: UX Spec
> **Source of truth**: `design/gdd/hero-system.md` (Core Rules 1 to 17, Formulas, Visual/Audio, UI Requirements, Open Questions) and `design/gdd/input-gesture-resolver.md` (hit targets, drags, cancel) own every rule and number. `design/gdd/battle-hud.md` owns the burst button's look and the prompts. This spec organises them as a screen-level UX spec and settles the points the Hero GDD flags for this pass. A value marked **(proposal)** is mine, not the GDDs'; a value marked **(derived)** is computed from GDD numbers, with the arithmetic shown. If this spec and a GDD ever differ, the GDD is right and this file is stale.
> **Related**: `design/ux/hud.md`, `design/ux/arc-and-chip.md`, `design/ux/interaction-patterns.md` (patterns P-nn), `design/accessibility-requirements.md`, `design/art/art-bible.md` sections 2, 3, 5, 7

---

## Purpose & Player Need

Pin and aim are the hero's two verbs, and the only way the player acts on the field with their hands rather than their gold. Neither is a screen. Both are drags, and everything they draw is in the field, anchored to the hero or to the aim point.

**The player arrives at the hero wanting to put it where the leak is. The player arrives at the corner button wanting to drop the burst into the bunched wave, exactly, with one thumb, and never to fire it by accident.**

What goes wrong without them, or when they are hard to use:
- Until the first pin the hero does nothing (Hero Rule 1), so a battle without a pin is a towers-only battle. The first drag has to be found and has to work.
- A burst cannot be cancelled once released, and it costs a 10 s cooldown even if it lands on nobody (Hero Rules 6, 8, 9). A mis-aimed or accidental burst is the second most expensive input in the game after a wrong tower.
- The thumb covers what it points at. The design's answer is to draw the pin from the hero and the aim above the finger, so the player reads the result from the field, not from under their own thumb.
- Pillar 2 (One Hero, Not an Army) needs the burst to feel like the best moment of a stage, and Pillar 4 (Thumb-First) needs every action to be one drag with no target under 48 dp.

**Design stance.** Nothing should happen on a brush. A pin is cheap to redo, so it commits on release. A burst is dear, so it starts in a cancelling state and fires only after a deliberate drag away from the button; the player sees which state they are in.

---

## Player Context on Arrival

| Question | Answer |
|---|---|
| When does the player first meet this? | In the first battle. The hero stands at `hero_start` (350, 800) with a dashed ring at its grab radius and the prompt "Drag the hero". The burst button is dotted (Locked) until the first pin. In Wave, once the burst is Ready and none has fired, the prompt "Drag from the corner button" appears |
| What were they just doing? | Pin: reading the board in Build (calm, clock stopped) or reacting to a leak in Wave (hurried). Burst: watching a packet bunch up on the path |
| Emotional state to design for | Pin: deliberate in Build, hurried in Wave. Aim: the most focused moment, with a 10 s cooldown behind it. The cost of a mistake must feel fair and small for a pin, and the player must never fire a burst they did not mean |
| Voluntary or sent? | Voluntary. Nothing moves the hero or fires the burst for the player |
| Prior knowledge | None assumed. Three prompts teach the verbs; nothing teaches where or when (Battle HUD Rule 13) |

The pin works in every phase. In Build it places the hero at once, so the first drag visibly works while the clock is stopped (Hero Rule 2). In Wave and Intermission the hero walks to the pin at 240 units per second (160 dp per second) and attacks nothing while it walks. The burst is refused in Build.

---

## Navigation Position

This is an in-battle interaction, not a navigable screen.

`App Root` → `Battle` → (press the hero) → **Pin drag**
`App Root` → `Battle` → (press the burst button, Ready, pinned, not Build) → **Burst aim**

Both are context-dependent (only inside a battle, not after an outcome or Fatal). Only one pointer works at a time (Input Rule 1), so a pin drag and an aim cannot run together. A press inside both the hero's grab disc and the burst button belongs to the hero (Hero Rule 15). A held aim survives a change among Build, Wave and Intermission (Flow Rule 10); an aim armed in Intermission can release in Wave.

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Hero | Press inside the hero's grab disc (DRAG priority 200, radius 56) and move past `drag_slop` | Hero position, whether it has been pinned, the active hand |
| Burst button, Ready | Press inside the button's disc (DRAG priority 100, radius 48) and move past `drag_slop`, with the burst Ready, the hero pinned and the phase not Build | Button position (`burst_button_centre()`), hero position, `reach` and `radius` |
| Burst button, other | Press when Locked or Cooling | Nothing starts: a dead press (see States) |
| Burst button, tap | A tap on the button reaches the sink (TAP 400) | Nothing; it also reaches nothing beneath |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Battle (pinned) | Release of a pin drag | `pin(pin_point)` runs between ticks. The ghost already shows the clamped landing point, so the command returns `OK` for a person |
| Battle (burst fired) | `drag_ended` while not cancelling | `burst(aim_point)` commits at once. **No cancel after release.** A 0.25 s telegraph, then the damage, then a 10 s cooldown |
| Battle (aim cancelled) | `drag_ended` while cancelling, or `drag_cancelled` | Nothing fires, the cooldown is not spent, the thumb starts over |
| Battle (closed by the game) | Paused, which sends `drag_cancelled` through `cancel()`; Won, Lost, Fatal | A held aim never fires. A burst already telegraphing when Won or a fatal leak arrives does not land (Hero edge cases) |

One-way exit: a released burst. A pin is not one-way; it can be redone at once, with no cooldown (Hero Rule 3).

---

## Layout Specification

### ASCII Wireframe

Field units. `H` is the hero, `P` the pin point, `B` the burst button centre, `F` the finger, `A` the aim point. Not to scale.

```
Pin drag (finger F on the pin point P, offset 0 at MVP)

        . . . . . . .            leash: dashed circle, radius 90 around P (2 px, 10 on / 8 off)
      .               .
     .      /\ kite    .         kite: 2 px unfilled ghost at P (the thumb hides it; the leash carries it)
     .     (  F  )     .
      .               .
        . . . . . . .
              H  ----> walks to P at 240 u/s after release
After release: ground ring (2 px solid, radius 30) at P; leash snaps to P.

Burst aim (Ready press on B, dragging up and left toward the packet)

        . . . . reach ring: dotted, radius 160 around H (neutral, alpha 0.6)
      .               .
     .      ( A )      .         A = reticle: 3 px ring with four ticks, alpha 0.7, 100 units ABOVE F
     .    preview r70  .         preview: solid 2 px circle around A; kill marks inside it
      .       H        .
        . . . . . . .

                         F       finger, 100 units below A
                    (B) ring radius 64 around B: the cancel boundary (inside it, releasing cancels)
```

### Layout Zones

| Zone | Rect / position | Holds | Input |
|---|---|---|---|
| Pin area (`pin_rect`) | x 48 to 492, y 174 to 888 (Stage record) | Where a pin may land | none |
| Pin exclusion | Per hand: segment (456, 816) to (456, 888) right, (84, 816) to (84, 888) left, radius 60; both hands: the point (186, 800), radius 60 | Forbidden zones for a pin | none |
| Hero grab disc | Centre on the hero, radius 56 (follows every position change) | The hero's drag target | DRAG, priority 200 |
| Burst button | Centre `B` = `burst_button_centre()`: x 456 (84 left-handed), y = clamp(888 - `I_bottom`, 816, 888). 84 px visible, 96 px hit, drag disc radius 48 | Button art, digit | DRAG priority 100; sink TAP priority 400, radius 48 |
| Cancel ring | Radius 64 around `B` | Shown on a Ready press | none |
| Leash | Radius 90 around the pin or the hero | 2 px dashed, alpha 0.5, never filled | none |
| Ground ring | Radius 30 at the pin on release | 2 px solid | none |
| Reach ring | Radius 160 around the hero | Neutral, dotted 3 on / 13 off, 2 px, alpha 0.6, two-tone over the path | none |
| Reticle | `A` = F + (0, -100), clamped to the field, then to 159.99 from the hero | 3 px solid ring, four ticks, alpha 0.7 | none |
| Radius preview | Radius 70 around `A` | Solid 2 px outline, unfilled | none |
| Ready ticks | Four ticks, 3 px thick, 8 long, radius 40 around the hero | Shown once pinned, in Wave and Intermission | none |
| Digit | 24 dp (floor 18 dp), on a panel above the thumb on a cooling press | Seconds left | none |

**Geometry checks (derived from the GDD numbers; 1.5 units = 1 dp at a 360 dp width; the art bible puts a fingertip at about 100 units across, so a fingertip radius of 50).**

- **Cancel ring.** The ring (radius 64) is only 16 units (10.7 dp) outside the button's hit disc (48). Beyond a fingertip of radius 50 it shows as a band 14 units (9.3 dp) wide. It does not clip: its right edge is at x 520 (20 inside the field) and its left edge at x 20 for the left hand. It is inside the 36-unit edge-reject margin, which only affects presses, not a drag already under way.
- **Leash.** Radius 90 minus a fingertip of 50 leaves a 40-unit (26.7 dp) band visible around the thumb, which is why the leash, not the 2 px kite, carries the pin.
- **Reticle offset.** The reticle is 100 units above the finger. A fingertip (top at 50 above the finger) leaves a 50-unit clear gap below the reticle. The preview (radius 70) is covered by the thumb in its lowest 20 units, so a kill mark in that sliver can be hidden.
- **Preview overhang.** An aim at the reach limit sits 160 from the hero, and the preview extends 70 further, so a burst can hit enemies up to 230 from the hero. The reach ring limits where the reticle can go, not where the blast can reach. This is by design (Hero Rule 7); the drawing must not suggest otherwise.
- **Hero grab.** The hero is 44 units across (visible); the grab disc is 112 across, so 34 units of grab margin on each side. It is 74.7 dp across at 360 dp.
- **Walk.** 240 units per second is 160 dp per second; crossing the starter hairpin takes about 2 s (Hero Rule 3).

**Reticle distance from the thumb (derived; aim `A = F + (0, -100)` clamped to 159.99 from the hero).** To aim at a point, the finger must be 100 units below it. The reticle follows the finger only once the finger is within 160 of `hero + (0, 100)`. Before that the reticle sits on the reach ring, pointing toward the finger's offset position, away from the thumb.

| Hero pinned at | Finger travel from the right button before the reticle follows the finger | Reticle distance from the finger at the start of the drag |
|---|---|---|
| (270, 600) | 104 units (70 dp) | 189 units (126 dp) |
| (270, 480) | 200 units (133 dp) | 290 units (193 dp) |
| (270, 300) | 362 units (241 dp) | 457 units (305 dp) |
| (150, 250) | 459 units (306 dp) | 548 units (365 dp) |
| (270, 174), the top of `pin_rect` | 482 units (321 dp) | 578 units (385 dp) |

Limits of this table: it ignores the clamp to the field (which only matters for a finger above y 100) and any bottom inset (which raises the button and shortens each travel slightly), and the dp figures assume a 360 dp width. The 50-unit fingertip radius used elsewhere is the art bible's "about 100 reference px" across.

The left button gives the same figures for central pins and less for pins on the left. A hero pinned in the top third needs a long thumb drag just to bring the reticle to the thumb. This is the "reticle far from the thumb when clamped" flag, and the table is its measure; the cue and the fallback are in States and Open Questions (PAQ-01, PAQ-03).

### Component Inventory

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Hero (grab ring when unpinned) | Field art | Dashed ring at radius 56 | Yes (drag) | P-09 |
| Leash | Field art | Dashed circle radius 90 | No | P-09 |
| Pin ghost | Field art | 2 px unfilled kite at the pin point | No | P-09 |
| Ground ring (pin landing) | Field art | 2 px solid, radius 30 | No | P-09 |
| Burst button | HUD art | Locked, Ready, Telegraphing, Cooling | Yes (drag, sink) | P-10, P-14, P-15 |
| Cancel ring | Field art | Thin ring at radius 64 around the button | No | P-10 |
| Reticle | Field art | Ring with four ticks | No | P-10 |
| Radius preview | Field art | Solid 2 px circle radius 70 | No | P-10 |
| Reach ring | Field art | Dotted circle radius 160 | No | P-10 |
| Clamped-at-reach cue | Field art | The ±20° of the reach arc facing the finger turns solid, alpha 0.7 | No | none (**new**, from the Hero GDD) |
| Kill preview | Field art | Knocked-out body with a steady 2 px white contour | No | none (**new**, from the Hero GDD) |
| Tether (proposal) | Field art | Thin dotted line from the clamped reticle toward the finger's offset position | No | none (**new**, PAQ-01) |
| Ready ticks | Field art | Four static ticks | No | P-15 |
| Cooling digit | HUD art | Seconds, on a panel above the thumb | No | P-15 |
| Dead-press nudge and prompt repeat | HUD art | 2 px nudge once for 120 ms; the first-pin prompt | No | P-14, P-17 |

### Information Hierarchy

Pin, in order of attention: (1) where the hero will end up (the leash and ground ring); (2) what it will cover (the leash, which is the hero's whole reach, Hero Rule 4); (3) whether the spot is allowed (the ghost never refuses a person, it slides to the nearest valid point).
Aim, in order: (1) where the burst will land (reticle and preview); (2) who will die (kill marks); (3) whether releasing will fire or cancel (the reticle's dim state and the preview's presence); (4) the reach limit (the ring and the clamp cue).
Discovered rather than shown: the damage number, the hero's HP, hit counts. None is on screen (Battle HUD Rule 4).

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| Unpinned | Battle start | Hero at `hero_start` (350, 800), fights nothing. A dashed ring at the grab radius 56 (not the leash, so no enemy appears to walk through a hero that does nothing). Prompt "Drag the hero". Burst button Locked |
| Pressed | Press inside the grab disc | The leash appears on the first frame, at the hero |
| Dragging | `drag_started` on the hero | The leash and the kite ghost follow the pin point (finger plus a pin offset, 0 at MVP). The leash carries the pin because the thumb hides the ghost |
| Clamped | The finger is over a forbidden zone or outside `pin_rect` | The ghost slides to the nearest valid point (never refuses a person). It can jump where two valid edges are equally near, and can land well away from the finger (GDD example: finger (492, 888) gives ghost (395.99, 888), 96 units away) |
| Released | `drag_ended` on the hero | Ground ring (2 px, radius 30) lands at the pin; the leash snaps to the pin; the hero walks |
| Walking | After release, in Wave or Intermission | Tip locked on the pin, long axis +6%, no breathing; no attacks; the attack timer still counts |
| Pinned in Build | Release in Build | The hero is at the pin at once, no walk, `hero_pinned` fires; the arrival effect plays at once |
| Arrival | Hero reaches the pin | 6% smaller for 0.1 s, then back |
| Pinned | At the pin | Attacks the nearest enemy inside the leash (4 damage per second); Ready ticks if the burst is Ready, in Wave or Intermission |
| Button Locked | Build, or before a first pin | Dotted neutral outline, no fill, no digit. A press nudges 2 px once for 120 ms (skipped under Reduce Motion); before a first pin it also repeats the prompt. The press is dead |
| Button Ready | Cooldown over; pinned; Wave or Intermission | Gold fill, complete outer ring. First frame: the Ready ticks close in from radius 56 and the button scales from 1.15 to 1 over 120 ms, once |
| Button Cooling | After a release | Neutral outline; gold fill returning as a clockwise sweep; seconds digit in neutral. A press shows the digit above the thumb on a panel, the button bare; on release the digit returns. The press does nothing |
| Button Telegraphing | Between `burst_started` and the release | Draws at fill 0 |
| Button hidden | Won, Lost | Not drawn; nothing can fire |
| Aim, cancelling | Every aim starts here | Ring at radius 64 around the button; reticle at alpha 0.3, no ticks; preview and kill marks hidden. Releasing cancels |
| Aim, live | Finger more than 64 from `B` | Reticle full (alpha 0.7) with ticks, solid preview, kill marks. Back within 48 of `B` it returns to cancelling. Releasing fires |
| Aim, clamped at reach | The reticle's unclamped position is beyond 159.99 from the hero | The reticle stays on the reach limit (159.99 from the hero) and slides around it as the finger's direction from the hero changes; only its distance stops growing. The ±20° of reach arc facing the finger turns solid at alpha 0.7 |
| Kill preview | Live aim only | Each enemy inside the preview with `hp_left` at or below the burst damage (130 in the starter values) has its body knocked out to the field colour, with a steady 2 px white contour; its damaged core is hidden |
| Release, with kills | Telegraph ends (T + 0.25 s) | Field and hero's 1.3× restore in 120 ms. Spokes (3 px white-gold) from the aim to each kill for 100 ms. Ring 3 px plus 1 per kill, up to 9 px, holds 150 ms. Hero pulses by 1 + 0.04 × kills |
| Release, no kills | Telegraph ends | Field and hero's 1.3× restore. A 2 px ring fades in over 80 ms; the burst glow is 40%; no spokes, no pulse |
| Outcome, burst unreleased | Won or Lost during a telegraph | Nothing lands. On the frame clock the field restores and the hero returns to 1× in 120 ms (at once under Reduce Motion); the gold ring, preview and kill marks are removed |
| Paused during an aim | Focus loss | `drag_cancelled`: nothing fires, the thumb starts over |
| Paused during a walk or telegraph | Focus loss | The clock stops; both resume exactly |
| Defeat, Victory | Outcome | Outline with glow 0; idle with glow 1. Leash, rings and ticks removed, except a release still playing |
| Reduce Motion | `reduce_motion` flag | No dip, wind-up, snap or Ready pop; a static ring from T + 0.1 and a 4 px ring at R; spokes stay |
| Left-handed | `left_handed` flag | The button, its digit and the exclusion line mirror to x 84. The kite, the aim offset (still 100 above the finger) and the Start/Call zone do not mirror |
| Loading, empty | n/a | Everything is read synchronously; no data-dependent empty state |
| Error | `HALTED`, or a bad read | The Fatal screen replaces the HUD. A refusal code other than `OK` or `HALTED` from a command here is a development error and is never shown to a person |

---

## Interaction Map

Mapping interactions for: **touch** (the desktop build's mouse stands in for it). Keyboard and gamepad are not supported.

| Component | Action | Input | Immediate feedback | Outcome |
|---|---|---|---|---|
| Hero (unpinned) | Press | Press inside the grab disc | Leash on the first frame | `pressed` names the hero |
| Hero | Drag | `drag_started`, `drag_moved` | Leash and kite follow the clamped pin point | No command yet |
| Hero | Release | `drag_ended` | Ground ring lands; leash snaps; hero walks (or arrives at once in Build) | `pin(pin_point)` returns `OK`; `hero_pinned` |
| Hero | Press released within `tap_slop` of where it began | Tap | Nothing on the hero | It is a tap, so it reaches the tap winner (a tower, slot or nothing), not the hero (Input Rule 3) |
| Burst button, Ready | Press and drag | `drag_started` | Cancel ring; dim reticle | Aim state: cancelling |
| Burst button, Ready | Drag past 64 from `B` | `drag_moved` | Reticle full, preview, kill marks | Aim state: live |
| Burst button, Ready | Drag back to 48 or less | `drag_moved` | Reticle dims; preview and marks hide | Aim state: cancelling |
| Burst button, Ready | Release while live | `drag_ended` | Wind-up, snap, telegraph | `burst(aim_point)` returns `OK`; `burst_started`; cooldown after release |
| Burst button, Ready | Release while cancelling | `drag_ended` | Aim clears | Nothing fires; cooldown not spent |
| Burst button, Cooling | Press | Press | Digit above the thumb, button bare | Dead press; nothing starts |
| Burst button, Locked | Press | Press | 2 px nudge; before a first pin, the prompt repeats | Dead press |
| Burst button | Tap | Tap, sink TAP 400 | None | Reaches the sink; nothing beneath |
| Hero within the button's disc | Press | Press | Leash on the hero | The hero wins the press (priority 200 over 100); the rest of the button still aims |
| Start/Call under the hero | Tap | Tap | None | The HUD ignores the tap when the same press named the hero as `best_drag` |
| Any | Second pointer | Press | None | Ignored (one pointer at a time) |

Navigation targets: none (no screens). Spec dependencies: `design/ux/hud.md` (burst button, Start/Call, prompts) and `design/ux/arc-and-chip.md` (slots and towers a pin may land on; a pin on a slot or tower is allowed and never blocks building).

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|------|--------------|--------------|-------|
| Hero position, pin target, pin state | Hero (`position()`, `pin_target()`, `pin_state()`) | Read | Each frame; the hero's grab disc follows `position()` every `update()` |
| Burst state, cooldown left | Hero (`burst_state()`, `cooldown_left()`) | Read | Each frame, compared in whole ticks; the digit is `display_seconds` of `cooldown_left`, computed on read |
| Aim state, aim point, button press | HeroInput (`aim_state()`, `aim_point()`, `button_press()`, `cooldown_digit()`) | Read | HudField reads them to draw the button and digit (Battle HUD Rule 12) |
| `leash_radius`, `walk_speed` | Data (Hero record, via the accessor) | Read | At use time, never cached |
| Burst `radius`, `reach`, `damage`, `telegraph_duration`, `cooldown` | Data (Burst record, via the accessor) | Read | `cooldown` read when Cooling begins for the fill |
| `hero_start`, `pin_rect`, `pin_exclusion` | Data (Stage record, directly) | Read | Fixed for the battle; the hand selects the active shapes |
| `left_handed`, `reduce_motion` | Data (Input record) | Read | Fixed for the battle; injected |
| Burst button centre | HUD (`burst_button_centre()`) | Read | Read once at registration; one point is the hit disc, the cancel ring, and the 64 and 48 tests |
| Enemy positions, `hp_left` | Enemy & Wave (`targets()`), Combat (`hp_left`) | Read | For the preview and kill marks; recomputed each frame while aiming |
| `pin(position)` and `burst(aim_point)` | Hero | **Write (commands)** | Between ticks, from the input call stack. Results: `HALTED`, `BAD_POSITION`, `OUT_OF_BOUNDS`, `BUTTON_ZONE`, `OK`; and `BUILD_PHASE`, `NOT_PINNED`, `NOT_READY`, `OFF_FIELD`, `OUT_OF_REACH` |

No data element has the UI as owner. HeroInput keeps only the aim state (Idle, Cancelling, Live) and presentation constants (the offsets). The battle does not know a thumb is aiming. No persistent state is read or written.

---

## Events Fired

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| Release a pin | `hero_pinned` | `position` |
| Release a live aim | `burst_started` | `aim_point`, `telegraph_ticks` |
| The hero's auto-attack and the burst's release | Combat's `attack_fired`, `damage_applied` | See Combat; view-only |
| Cancelled aim, dead press, clamped ghost | none | Nothing is emitted (a cancel clears HeroInput's state only) |
| Any | Analytics: none | No network or analytics at MVP |

Debug builds count `repins` (each `OK` pin after the first, mid-walk included), and per burst `bursts_fired`, `bursts_hit_0`, `bursts_hit_3`, `bursts_hit_5`, `burst_victims`, `burst_kills`, `kills_per_burst[]`, `kills_on_hit_3[]`, and log `best_victims`. They feed the human log and the Pillar 2 and 4 checks. None changes a result. No action here modifies persistent state.

---

## Transitions & Animations

Durations are the GDD's. Under Reduce Motion the motion is cut and fades stay; the GDD gives the exact fallback.

| Transition | Normal | Reduce Motion | Source |
|---|---|---|---|
| Press hero | Leash on the first frame | Same | Hero Visual/Audio |
| Drag | Leash and ghost follow the finger each frame; one `drag_moved` per input call | Same | Hero Visual/Audio; Input Rule 6 |
| Release a pin | Ground ring lands, leash snaps; hero follows | Same | Hero Visual/Audio |
| Walking | Tip locked on the pin, long axis +6% | Same | Hero Visual/Audio |
| Arrival | 6% smaller for 0.1 s, then back (also at once on a Build pin) | Same (a scale on a 44 px hero; flagged PAQ-11) | Hero Visual/Audio |
| Ready | Ticks close in from radius 56; button scale 1.15 to 1 over 120 ms, once | No pop; ticks static | Hero Visual/Audio |
| Aim cancelling to live | Reticle alpha 0.3 to 0.7; preview and marks appear | Same (a fade) | Hero Visual/Audio |
| Clamped at reach | The reticle stops; the arc turns solid at alpha 0.7 | Same | Hero Visual/Audio |
| Telegraph | 0.1 s near-circle wind-up, preview holds, field -3% from T; then the hero snaps to 1.3×, the gold ring grows to meet the preview exactly at R | No dip, wind-up or snap; a static ring from T + 0.1; a 4 px ring at R | Hero Visual/Audio |
| Release with kills | Field and 1.3× restore in 120 ms; spokes 100 ms; ring 150 ms; hero pulse | Spokes stay; no pulse | Hero Visual/Audio |
| Release with no kills | Restore; 2 px ring fades in over 80 ms; glow 40% | Same | Hero Visual/Audio |
| Outcome with an unreleased burst | Restore on the frame clock, 120 ms | At once | Hero Visual/Audio |
| Paused | Instant | Instant | Battle HUD |

The burst's dip (field -3%) happens at most once per 10 s cooldown plus 0.25 s telegraph, so it cannot chain faster than every 10.25 s, well within the art bible's rule of no re-dip within 1 s.

---

## Input Method Completeness Checklist

**Touch** (also the desktop build's mouse): the only supported method.

- [x] Pin and aim are each one drag with one pointer; a second finger is ignored.
- [x] Targets: hero grab disc 112 units across (74.7 dp at 360 dp); button drag disc 96 units (64 dp); sink 96 units. Hysteresis 64 out and 48 back.
- [x] Nothing fires on a brush: a tap on the button reaches the sink; a Ready drag starts cancelling; a pin commits only on release.
- [x] Left-handed play is supported by mirroring the button and exclusion line.
- [x] No timing is required of the player; the telegraph (0.25 s) is the game's, not an input window.
- [ ] Android system back (button or gesture) during a drag, an aim or a telegraph is undefined (PAQ-11).
- [ ] Whether the screen-edge back gesture can start inside the cancel ring (a right-hand ring ends at x 520, 20 units from the edge, and inside the 36-unit reject margin) is unverified on devices (PAQ-02).
- [ ] A thumb's reach to the top third of the field, for both re-grabbing a high hero and aiming near it, is untested (PAQ-03).

**Keyboard, gamepad:** not supported. There is no focus order, focus trap or controller-disconnect state, because every action is a disc.

---

## Accessibility

Cross-reference: `design/accessibility-requirements.md` (tier Standard, phased; the Basic subset is the MVP baseline).

| Check | Result |
|---|---|
| Target size | Hero grab 112 units = 74.7 dp across; burst drag disc 96 units = 64 dp at 360 dp, and the visible button 84 px = 56 dp. All at or above 48 dp. Units scale with width: dp per unit = width in dp / 540, so targets grow on wider phones |
| One-handed play | The whole feature is one thumb. Left-handed play is supported (button and digit mirror) |
| Drag required | Pin and aim both need a drag. There is no tap-based alternative at MVP. This is a recorded limitation (accessibility requirements, Known Intentional Limitations; AQ-07) |
| Timed input | None. The telegraph (0.25 s) and the cooldown (10 s) are game timing. An aim can be held as long as the player likes, and survives a change of phase |
| Cancel is forgiving | Cancel is by direction (release within 64 of the button; the boundary is 16 units outside the button's hit disc) and needs no precision. Every aim starts cancelling, so an unintended touch cannot fire |
| Line contrast on the field | (The leash's colour is not set by the art bible; neutral is assumed here, PAQ-17.) Neutral lines at alpha 0.6 (reach ring) measure 4.98:1 on the field and 4.94:1 on a path assumed to be the field with its value raised 3 points; the leash at alpha 0.5 measures 3.82:1 and 3.80:1; the reticle at alpha 0.7 measures 6.38:1. All pass 3:1 (non-text). The art bible still asks for two tones over the path, which is a safe margin since the path colour is an assumption |
| Deliberately low contrast | The cancelling reticle at alpha 0.3 measures 2.14:1, below 3:1. This is intended: it says "releasing will cancel". The non-colour backup is that the preview and kill marks are hidden (PAQ-08) |
| Hero and kill marks | Gold (white-gold `#FFE9A8`) is the hero's alone; it measures 15.75:1 on the field. Kill marks are a shape change (body knocked out, white contour), 18.9:1 against the field colour the body is knocked out to, not a colour change |
| Colour independence | Every state differs by shape, outline or count: dotted vs solid vs filled button; dim vs full reticle with a preview; ticks present vs absent for Ready; fill sweep plus digit for Cooling; spokes counted per kill |
| Reduce Motion | Defined by the Hero GDD: no dip, wind-up, snap or Ready pop; a static ring and a 4 px ring at release; spokes stay. The arrival scale (6% for 0.1 s) is not covered by that fallback (PAQ-11) |
| Photosensitivity | One field dip (-3%) and one gold ring per burst, at most once every 10.25 s. No flash above 3 Hz |
| Thumb coverage | The reticle sits 100 units above the finger, 50 clear of a fingertip; the preview's lowest 20 units are under the thumb. The leash band (40 units) stays visible around the thumb |
| Screen reader | The field cannot be labelled. Known limitation (accessibility requirements) |
| Focus order | Not applicable (touch only) |

---

## Localization Considerations

This feature owns no strings. The prompts ("Drag the hero", "Drag from the corner button") belong to the Battle HUD and are fixed English at MVP. The only text drawn here is the cooldown digit (seconds, tabular numerals, 1 to 2 digits for a 10 s cooldown): no expansion risk, and number formatting is locale-neutral at this size. If the cooldown is ever tuned above 99 s, a 3-digit digit must be checked against the panel above the thumb.

---

## Acceptance Criteria

Each can be checked by a tester with a build and the numbers here. Positions are field units at inset 0 for a right-handed player; "dp" assumes a 360 dp width. The starter values are used (leash 90, walk speed 240, burst radius 70, reach 160, damage 130, telegraph 0.25 s, cooldown 10 s).

- [ ] **Unpinned.** At the start of a battle the hero is at (350, 800), a dashed ring of radius 56 is drawn around it (no leash), the prompt "Drag the hero" shows, and the burst button is dotted.
- [ ] **Press and drag the hero.** Pressing inside 56 units of the hero draws a dashed leash (radius 90, 10 on / 8 off, 2 px) on the first frame. Dragging shows a 2 px unfilled kite at the pin point and moves the leash with the finger.
- [ ] **Release a pin.** On release a 2 px solid ring of radius 30 appears at the pin and the leash snaps to it. In Wave or Intermission the hero walks to the pin at 240 units per second and does not attack while walking. In Build the hero is at the pin at once.
- [ ] **Clamp.** With the finger at (492, 888) the ghost is at (395.99, 888) within 0.1; with the finger at (200, 800) it is at (246.01, 800); the ghost never shows a refusal. A pin never lands inside 60 units of the burst line (x 456, y 816 to 888) or of Start/Call's centre (186, 800), or outside x 48 to 492 and y 174 to 888.
- [ ] **Locked button.** In Build, and in any phase before a first pin, the burst button is dotted with no fill and no digit; pressing it nudges it 2 px once for 120 ms (not under Reduce Motion), repeats the first-pin prompt before a first pin, and starts no aim.
- [ ] **Ready aim, cancelling.** With the burst Ready and the hero pinned, pressing the button and dragging shows a ring of radius 64 around the button's centre and a reticle at alpha 0.3 with no ticks, no preview and no kill marks. Releasing while the finger is within 64 of the button's centre fires nothing and leaves the burst Ready.
- [ ] **Ready aim, live.** Once the finger is more than 64 from the button's centre, the reticle goes to alpha 0.7 with four ticks, 100 units above the finger, with a solid 2 px preview circle of radius 70. Dragging back to within 48 returns it to cancelling.
- [ ] **Reach clamp.** When the unclamped reticle would be more than 160 from the hero, the reticle stops at 160 or less from the hero, and the 40 degrees of the reach ring facing the finger turn solid at alpha 0.7. Moving the finger further does not move the reticle further out.
- [ ] **Fire.** Releasing while live starts a 0.25 s telegraph at the fixed aim point, then every enemy within 70 of it loses 130 HP (or all it has), and the cooldown of 10 s starts at the release. The burst cannot be cancelled after release, and a second aim cannot start until the cooldown ends.
- [ ] **Aim across a phase change.** An aim held while Intermission becomes Wave stays live and fires on release.
- [ ] **Walking hero.** During an aim, if the hero is walking, the reach ring moves with it and the reticle re-clamps every frame; releasing never shows a refusal.
- [ ] **Empty burst.** A burst released with no enemy within 70 of the aim point still starts the 10 s cooldown and draws the no-kill ring.
- [ ] **Kill preview.** During a live aim, an enemy inside the preview with HP at or below 130 is drawn with its body in the field colour and a steady 2 px white contour; enemies above 130 HP are drawn normally. The marks are hidden while cancelling.
- [ ] **Release feedback.** A release with kills shows one spoke per kill from the aim point for 100 ms and a ring whose width is 3 px plus 1 px per kill up to 9 px for 150 ms. A release with no kills shows a 2 px ring fading in over 80 ms and no spokes.
- [ ] **Cooling press.** While Cooling, pressing the button shows the seconds left (digit) above the thumb on a panel with the button bare, starts no aim, and returns the digit to the button on release.
- [ ] **Ready cue.** When the cooldown ends in Wave or Intermission with the hero pinned, four static 3 px ticks (8 long) appear at radius 40 around the hero and the button scales from 1.15 to 1 once over 120 ms (no scale under Reduce Motion).
- [ ] **Hero wins the overlap.** A press inside both the hero's grab disc and the button's disc drags the hero; a tap on the button alone does nothing and reaches nothing beneath; a press on Start/Call inside the hero's grab disc does not call a wave.
- [ ] **Pause and outcome.** Switching away during an aim fires nothing and cancels the aim; during a telegraph or a walk the game resumes exactly where it stopped. If Won or Lost arrives during a telegraph, nothing lands.
- [ ] **Reduce Motion.** With the flag on there is no field dip, wind-up, snap or Ready pop; a static ring shows from 0.1 s after the aim is committed and a 4 px ring at release; spokes still show.
- [ ] **Left-handed.** With `left_handed` on, the button, its digit and the cancel ring are at x 84, the pin exclusion line is on the left, the bottom-right corner can take a pin, and the reticle is still 100 units above the finger.
- [ ] **Targets.** The hero's grab disc and the button's drag disc each measure at least 48 dp across at a 360 dp width.
- [ ] **Performance.** The leash, ghost and reticle follow the finger with no more than one frame of lag (16.6 ms at 60 fps), and the hero view stays inside the project's 60 draw-call budget on a device.
- [ ] **Resolution.** At 540 x 960 and at a 360 x 800 dp phone, the cancel ring (right edge x 520) and the reach ring are not clipped by the screen edge, and no aim state is lost to the edge-reject margin.

---

## Open Questions

| ID | Question | Owner |
|---|---|---|
| PAQ-01 | **Reticle far from the thumb (proposal).** The table shows a reticle up to 578 units (385 dp) from the thumb at the start of a drag, and no cue that says where the finger's aim would be. Proposed: while the reticle is clamped, draw a thin dotted tether from the reticle toward the finger's offset position (`F + (0, -100)`), so the clamp reads as a limit, not as a stuck reticle. The GDD's clamp cue (solid reach arc) stays. Test the GDD cue alone first; the tether is the fallback | Decided 2026-11-04 (recommended setting accepted): ship the GDD's clamp cue alone; the tether stays the fallback if the phone test shows a stuck-looking reticle |
| PAQ-02 | **Cancel ring is a 14-unit band.** Beyond a fingertip of radius 50, the 64-unit ring shows as 14 units (9.3 dp). Check on a device that it is seen, and that the edge-swipe back gesture cannot start inside it (right edge x 520, 20 units from the field edge). Fallback: draw the ring 3 px, or add a second tick mark | art-director, phone test |
| PAQ-03 | **Re-grab and aim near the top.** A hero pinned at y 174 sits 116 dp from the top of a 640 dp field; to aim near it the finger must be 100 units lower, still about 183 dp from the top. Assuming the comfortable one-thumb zone is the lower 60% of the screen (an assumption, not sourced in this repo), the top 40% is hard to grab and to aim into. Options in order: (1) test first (the GDD already asks); (2) raise the top of `pin_rect` (a Stage data change; it affects the top lane); (3) enlarge the hero's grab radius above y 300; (4) allow a pin by dragging from a ghost left at the old pin | game-designer, phone test |
| PAQ-04 | **Pin offset 0 or 100.** The GDD keeps 0 for MVP and tests 100 on the phone. With 0 the ghost is under the thumb and only the leash band (40 units) shows; with 100 a top-half pin needs a lower finger. Record the result of the phone test | game-designer |
| PAQ-05 | **Preview overhang.** The blast reaches 230 from the hero while the ring says 160. The drawing keeps the ring dotted and the preview solid so they read as different things. Confirm in the phone test that players read the ring as "where I can aim", not "where it can hit" | ux-designer, phone test |
| PAQ-06 | **Forbidden zones are invisible while pinning.** The ghost can slide far from the finger when it crosses a zone (96 units in the GDD's example), with no sign of why. Options: do nothing (the GDD), flash the nearest zone edge only while the ghost is clamped away from the finger, or show a faint zone outline for the first three pins | ux-designer |
| PAQ-07 | **Thumb covers the lowest 20 units of the preview**, so a kill mark there may be hidden. Accept, or draw the preview 120 above the finger (the GDD sets 100) | ux-designer |
| PAQ-08 | **Cancelling reticle at 2.14:1.** Intended as "will cancel", but under 3:1. Backup is the hidden preview. Accept, or raise to alpha 0.45 (3.30:1 computed against the field; 0.4 gives 2.88:1, still under 3:1), which makes cancelling look closer to live | art-director |
| PAQ-09 | **Hollow kill mark at 22 px and 0.6-alpha dots on a phone** (Hero Open Questions): is each readable? | art-director, first phone build |
| PAQ-10 | **Exclusion radius 60 or 104.** The GDD fallback is 104 for the active hand's line only. Does a hero pinned beside a button take presses meant for it? | game-designer, phone test |
| PAQ-11 | **Android system back** during a drag, aim or telegraph (PQ-10, HQ-07); and the arrival scale (6% for 0.1 s) under Reduce Motion, which the GDD's fallback does not list | game-designer, accessibility-specialist |
| PAQ-12 | **Reach 160: limit or stuck?** The GDD asks whether players feel the reach as a clear limit or as the reticle getting stuck. The clamp cue and PAQ-01 are the mitigation | game-designer, phone test |
| PAQ-13 | **Drag-free alternative for pin and aim** (AQ-07): not in scope at MVP | game-designer |
| PAQ-14 | **No player-journey document.** Context on arrival is inferred from the GDDs and prompts | ux-designer |
| PAQ-15 | **Aim floor (Hero Open Questions).** The reticle is 100 above the finger, so with the finger at the screen's bottom edge (y 960) the reticle is at y 860 and a radius-70 blast reaches y 930; the last 30 units of the path cannot be hit, and a bottom inset `I_bottom` raises both by that much (derived). Does a player feel this as a lost save? | game-designer, phone test |
| PAQ-16 | **Early thumb on a cooling button (Hero Open Questions).** A press while Cooling is dead today (the digit shows). UX once proposed tracking the press so it becomes an aim the moment the burst is Ready. Keep dead for MVP; test | game-designer, playtest |
| PAQ-17 | **Leash colour and the "in-zone vs out-of-zone" leash state.** The art bible leaves the leash's colour and alpha unset and lists an in-zone/out-of-zone state shown by dash density that no GDD defines. This spec assumes a neutral leash (its contrast figures rest on that) and has no such state; the pattern library and accessibility requirements no longer claim one. Decide the colour and whether the state exists | art-director |
