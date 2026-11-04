# Accessibility Requirements

> **Status**: In Design (tier committed; specialist review owed)
> **Author**: njarrar + ux-designer (authored in session by `/ux-design accessibility`, autonomous mode; see Audit History)
> **Last Updated**: 2026-11-04
> **Accessibility Tier Target**: Standard, adapted for touch, with three Comprehensive items lifted (see Tier Definition)
> **Platform(s)**: iOS, Android (portrait, one thumb). Desktop build for development and testing only, with mouse as touch.
> **External Standards Targeted**:
> - WCAG 2.1 Level AA, for contrast (SC 1.4.3, 1.4.11), target size (SC 2.5.5 AAA used as the floor, since Pillar 4 already demands it), timing (SC 2.2.1), flashes (SC 2.3.1) and motion (SC 2.3.3 as a goal)
> - AbleGamers CVAA Guidelines: reference only. The game has no voice chat or messaging, so CVAA does not apply.
> - Xbox Accessibility Guidelines (XAG): No (no Xbox release). Used as a checklist only.
> - PlayStation Accessibility (Sony Guidelines): No (no PlayStation release)
> - Apple / Google Accessibility Guidelines: Yes, for touch target size, text size and the OS Reduce Motion and Remove Animations settings
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `design/gdd/game-concept.md`, `design/art/art-bible.md`, `design/gdd/battle-hud.md`, `design/gdd/input-gesture-resolver.md`, `design/gdd/hero-system.md`, `design/gdd/tower-system.md`, `docs/architecture/architecture.md`, ADR-0001, ADR-0003. `design/ux/interaction-patterns.md` does not exist yet.
> **Template**: Accessibility Requirements

> **Why this document exists**: per-screen accessibility notes belong in UX
> specs. This document holds the project-wide commitments, the feature matrix
> across all systems, the test plan and the audit history. Every UX spec in
> `design/ux/` must meet the tier set here. If a feature conflicts with a
> commitment made here, this document wins: change the feature, not the
> commitment, unless the producer approves a formal revision.
>
> **When to update**: after each `/gate-check` pass, after any accessibility
> audit, and whenever a system is added to `systems-index.md`.
>
> **How to read a requirement.** Each new requirement has an ID (`AR-` plus an
> area letter and a number), a tier (MVP, Vertical Slice or Alpha, the systems
> index tiers) and an owning system. "Already decided" means a GDD, the art bible
> or an ADR already holds the rule and this document only records it. "GDD change
> needed" means a GDD, the art bible or an ADR would have to change to meet the
> requirement; this document does not edit them. The full list of those is in
> **GDD and ADR Changes Needed**, just before Open Questions.
>
> **Units.** Positions and sizes in field units are on the 540 x 960 reference
> field. At the minimum supported screen, 360 dp wide or 640 dp tall, 1.5 units
> is 1 dp, so 72 units is 48 dp (Input GDD, `field_scale` and `target_ok`;
> ADR-0003 minimum size guard). Every dp figure below is at that minimum screen;
> larger screens only make things bigger.

---

## Accessibility Tier Definition

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical player-facing text is readable at standard resolution. No feature requires color discrimination alone. Volume controls exist for music, SFX, and voice independently. The game is completable without photosensitivity risk. | Low, primarily design constraints |
| **Standard** | All of Basic, plus: full input remapping on all platforms, subtitle support with speaker identification, adjustable text size, at least one colorblind mode, and no timed input that cannot be extended or toggled. | Medium, requires dedicated implementation work |
| **Comprehensive** | All of Standard, plus: screen reader support for menus, mono audio option, difficulty assist modes, HUD element repositioning, reduced motion mode, and visual indicators for all gameplay-critical audio. | High, requires platform API integration and significant UI architecture |
| **Exemplary** | All of Comprehensive, plus: full subtitle customization (font, size, color, background, position), high contrast mode, cognitive load assist tools, tactile/haptic alternatives for all audio-only cues, and external third-party accessibility audit. | Very High, requires dedicated accessibility budget and specialist consultation |

### This Project's Commitment

**Target Tier**: **Standard**, read for a touch-only phone game, reached in full at Alpha (Small Ship), with Reduce Motion, one-thumb play and visual backups for all audio lifted from Comprehensive.

**Rationale**: TowerRiot is a portrait tower defense played with one thumb, often with sound off, by mid-core players aged 16 to 40 on a commute (concept, Target Player Profile). The genre's worst barriers are motor (fast taps, drags and timing under pressure) and visual (small glyphs on a phone, colour-coded units), so the design already answers much of Standard by its own pillars: Pillar 4 makes every action one tap or one drag with no target under 48 dp, and the art bible gives every colour pair a shape or motion backup. Sound-off play means every sound must already have a visual twin, which is a Comprehensive item the game gets almost for free. The team is one part-time developer, so Comprehensive's screen reader and full HUD repositioning are out of reach: the battle field is drawn in one `_draw()` per view with no Control nodes, and AccessKit only reaches Controls (engine reference `modules/ui.md`; ADR-0003 Negative consequences). Dropping to Basic would leave players who cannot drag, cannot read 14 dp text, or cannot act inside a 1.5 s window with no path at all; these are common enough in a phone audience (tremor, low vision, arthritis in the thumb) that the cost of Standard is worth it, and most of it is design rules rather than code.

**How the Standard baseline maps to this game**:

| Standard item | What it means here | Where |
|---|---|---|
| Full input remapping | No bindings exist: touch only, no keyboard or gamepad. The touch equivalent is handedness, hit-area scale, a steadier slop and a two-tap mode in place of drags | Motor, AR-M-03 to AR-M-06 |
| Subtitles with speaker ID | No voice, no dialogue, no narration at any tier. N/A | Auditory |
| Adjustable text size | One "Larger text" step at 125% | Visual, AR-V-03 |
| At least one colorblind mode | Met by design with one shape-redundant palette, not a palette swap. A deliberate substitution, recorded in Known Intentional Limitations | Visual, Colour audit |
| No timed input that cannot be extended | Cost-chip window and intermission get multipliers; the resolver has no tap time limit | Motor, AR-M-07 and AR-M-08 |

**Features explicitly in scope (beyond tier baseline)**:
- **Reduce Motion** (Comprehensive). Already designed: the `reduce_motion` flag sits in the Input record at MVP and reaches views only through `PresentationSettings` (ADR-0001, QQ-09). Lifted because the burst, the danger pulse and hit flashes are the game's motion load, and the flag is nearly free now.
- **One-thumb play everywhere** (Comprehensive "one-hand mode"). A design pillar, not a mode: a feature that needs two thumbs is cut (Pillar 4).
- **Left-handed mirror** (a narrow form of Comprehensive's HUD repositioning). The burst button and its digit mirror; nothing else moves (Battle HUD Edge Cases, Hero UI Requirements).
- **Visual backup for every sound** (Comprehensive). The target player plays with sound off, so no sound may carry what a view does not (Auditory).
- **Hit-area scale and "steady hand" slop** (beyond Standard). Reserved in the Input GDD for Alpha; committed here.

**Features explicitly out of scope** (each also in Known Intentional Limitations):
- Screen reader for the battle field and HUD.
- Palette-swap colour-blind modes.
- High contrast mode.
- Full HUD repositioning, beyond the left-hand mirror.
- Keyboard, gamepad and switch-device play.
- Haptics.
- Subtitle customisation (there is nothing to subtitle).

---

## Visual Accessibility

The game is read at arm's length on a 360 dp phone in daylight. Text sits only on panel, never on the raw field at small sizes (art bible §7). The palette is fixed per meaning: gold is the hero, cyan towers, orange enemies, violet a status, magenta danger, neutral information (art bible §4). The field is near black, so contrast against it is high; the risks are dimmed states, thin lines over the lifted path, and alpha-faded secondary marks.

**Measured contrast.** Ratios below use the WCAG 2.1 relative-luminance formula on the art bible hex values. Panel is #141B30 at 85% over field #0B1020; path is the field lifted about 3% in value. They are computed, not measured on a device.

| Pair | Ratio | Needs | Verdict |
|---|---|---|---|
| Neutral #C8D0E0 text on panel | 11.2:1 | 4.5:1 | Pass |
| Unaffordable cost text, neutral at alpha 0.55 on panel | 4.26:1 | 4.5:1 (14 to 16 dp is not large text) | **Fail.** Alpha 0.6 gives 4.83:1 (AR-V-05) |
| Hero, tower, enemy, danger, status against field | 15.8, 9.0, 7.3, 5.5, 5.8:1 | 3:1 (graphics) | Pass |
| Leash, neutral 2 px dashed at alpha 0.5, on field / on path | 3.8 / 3.8:1 | 3:1 | Pass; two-tone over the path stays (art bible §7) |
| Reach ring dots, alpha 0.6, on path | 4.9:1 | 3:1 | Pass |
| Current range ring, cyan alpha 0.5, on path | 3.05:1 | 3:1 | Pass, with no margin |
| Next-level range ring, cyan alpha 0.25, on path | 1.65:1 | 3:1 | **Fail** (AR-V-06) |
| Slot outline, 1 px at alpha 0.3, on field | 2.1:1 | 3:1 for the mark that says "free" | **Fail** if the outline is the only mark; the free-slot corner mark has no alpha yet (AR-V-07) |
| Ground rejection ring, alpha 0.35 | 2.5:1 | 3:1 | Accepted exception: a hint, not needed to play (Known Intentional Limitations) |
| Dormant danger chevrons, alpha 0.3 | 1.4:1 | None | Ambient. The live danger state animates at full colour |
| Lost life dash, alpha 0.2 | 1.6:1 | None | The count is carried by the full dashes left, which pass |

**Requirements.**

- **AR-V-01 Text floor 14 dp.** Already decided (art bible §7, Battle HUD UI Requirements): 14 dp, or 21 units, for any text; 16 dp for gold, lives, labels and costs; 18 dp floor for the burst digit. Every UX spec cites it. MVP, Battle HUD.
- **AR-V-02 Tabular numerals; digits swap, never bounce.** Already decided (art bible §7). MVP, Battle HUD.
- **AR-V-03 Larger text, 125%.** New. One setting that scales every screen-space string by 1.25 (14 dp becomes about 18 dp). It does not scale field glyphs. Every HUD and menu panel must fit its longest string at 125% in its own language; a panel that cannot grow wraps to a second line or abbreviates by a rule its UX spec names. Alpha, Settings & Accessibility owns the flag; Battle HUD and Menu & Screen Flow own the layouts. **GDD change needed:** Battle HUD's panel sizes (arc panel 60 x 44, Start/Call 88 x 72 with two 14 dp lines, chip 76 x 44, prompt 300 x 34) are sized for 100% only.
- **AR-V-04 Contrast floors.** New, as a rule for every view. Text: 4.5:1 against what it sits on, in every state, dimmed states included. Any graphic a player must see to act (a target, a state ring, a range ring, an aim mark): 3:1 against field and against path. MVP, every view owner; checked by the test plan.
- **AR-V-05 Dimmed cost text at alpha 0.6 or above.** New. The unaffordable state keeps its strike-through and dim, but the text must not fall below 4.5:1. Alpha 0.6 gives 4.83:1. The polygon in the arc may stay at 0.55. MVP, Battle HUD. **GDD change needed:** Battle HUD Visual table, row "Unaffordable".
- **AR-V-06 Next-level range ring at 3:1.** New. The chip's next-level ring is decision information (is the upgrade worth it?). It must reach 3:1 on the path, for example a dashed cyan line at alpha 0.5 so it differs from the current ring by pattern, not by fading. MVP, Tower System. **GDD change needed:** Tower GDD Visual table, row "Range ring" (alpha 0.25).
- **AR-V-07 Free slot mark at 3:1.** New. A free build slot is a tap target, so its mark (the 4-dot corner mark) must reach 3:1 on the field; neutral at alpha 0.45 gives 3.3:1. The 1 px outline at 0.3 may stay as support. MVP, Tower System draws slots; art-director owns the art bible. **Art bible change needed:** §6 Architecture, slot marks.
- **AR-V-08 Photosensitivity.** Already decided in part (art bible §7, UX photosensitivity note): the 2 Hz danger pulse swings at most 25% alpha or runs as travelling chevrons, and the 0.4 s burst field dip never chains within 1 s. New: no element may flash more than 3 times in any 1 s if it covers more than 25% of the screen, and no saturated red flash of any size may repeat above 3 Hz (Harding and WCAG SC 2.3.1). Hit flashes (80 ms, small, per enemy) pass by area; a full-screen effect of any kind needs this check first. No screen shake exists or is planned (Combat, Deferred). MVP for the rule, Visual Feedback & VFX (Vertical Slice) for the automated check.
- **AR-V-09 Photosensitivity notice.** New. A short notice on first launch, before the first stage. Vertical Slice, Menu & Screen Flow. A store build cannot ship without it.
- **AR-V-10 Reduce Motion.** Already decided as a flag (ADR-0001, `PresentationSettings`; Battle HUD UI Requirements; Hero Visual table; Tower UI Requirements; art bible §7). This document gathers what it does, since four documents each hold a part:

  | Element | Normal | Under Reduce Motion | Source |
  |---|---|---|---|
  | Panel slides (12 units) | 200 ms slide | Cut; fades and clock bars stay | Battle HUD |
  | Danger pulse at the exit | 2 Hz, 25% alpha swing | Frozen at full; the chevron shape stays as the colour backup | Art bible §7 |
  | Burst field dip | 0.4 s, 3% darker | Skipped | Art bible §7, Hero |
  | Burst wind-up, snap, Ready pop | Shape transforms | None; a static ring from T+0.1 s, 4 px at release; spokes stay | Hero |
  | Locked burst press nudge, refused build or upgrade nudge | 2 px for 120 ms | Skipped, **with a static cue instead** (AR-V-11) | Hero, Tower |
  | Build and upgrade overlay | Scale 1.15 to 1, 120 ms | No scale; white overlay fades only | New, Tower UX flag asks for it |
  | Arc collapse | 120 ms | Instant | New, Tower UX flag asks for it |
  | Hero idle breathing | 0.5 Hz, 4% scale | Off | New |
  | Enemy motion traits (jitter, bob, lean) | On | **Stay on.** They are gameplay telegraphs; removing them hides information | Art bible §5 |
  | Cooldown sweep, chip drain bar | Linear clock | Stay; a clock is information | Art bible §7 |

  Default off. MVP for the flag and every row above (the flag already exists at MVP); Alpha for the settings toggle (Settings & Accessibility). Where the OS exposes its own Reduce Motion (iOS) or Remove Animations (Android) setting, the first launch should copy it into the default (Open Questions: the Godot 4.7 API for this is unverified).
- **AR-V-11 A non-motion refusal cue.** New. Under Reduce Motion a refused tap (unaffordable disc or chip, locked burst button) has no nudge, so it reads as a missed tap. Each needs a static cue, for example the struck cost thickening its strike for 300 ms, or the locked button's dotted outline turning solid for 300 ms. MVP, Tower System and Hero System supply the state; Battle HUD draws it; the arc-and-chip UX spec picks the cue (the Tower GDD's UX flag already asks for this).
- **AR-V-12 Greyscale legibility.** Already decided as a test (art bible §5: render each enemy at minimum size in grey and name it in one second; Combat: tower and hero hits tell apart in greyscale). Every new glyph, tower or enemy type must pass the same test before it enters content. MVP, art-director; each content GDD.
- **AR-V-13 Hero always readable.** Already decided (Pillar 1 design test; Combat burst clearance): no VFX may hide the hero or a path. Recorded here because it is the low-vision rule that matters most in a fight. MVP, Visual Feedback & VFX and Combat.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Minimum text size: menu UI | Standard | All menus and modal screens | Not Started | 14 dp floor, 16 dp for labels (AR-V-01). Menus do not exist until Vertical Slice (Menu & Screen Flow) |
| Minimum text size: subtitles | N/A | No voiced content | N/A | No voice at any tier |
| Minimum text size: HUD | Standard | Battle HUD | Designed | 14 dp floor; 16 dp gold, lives, costs; 18 dp burst digit (Battle HUD, art bible §7). Not yet rendered |
| Text contrast: UI text on backgrounds | Standard | All UI text | Designed, one fail | 11.2:1 for neutral on panel. Dimmed cost fails at 4.26:1 (AR-V-05) |
| Text contrast: subtitles | N/A | No subtitles | N/A | |
| Colorblind mode: Protanopia | Standard (met by design) | All colour-coded gameplay | Designed | No palette swap. Magenta vs orange is the one real protan/deutan risk; chevron shape plus pulse backs it (art bible §4). See Colour audit |
| Colorblind mode: Deuteranopia | Standard (met by design) | All colour-coded gameplay | Designed | Same as above |
| Colorblind mode: Tritanopia | Standard (met by design) | All colour-coded gameplay | Designed | Cyan towers vs violet status could merge; they never share an entity (violet only on enemies) and towers are polygons. Verify with a simulator |
| Color-as-only-indicator audit | Basic | All UI and gameplay | Designed | Table below. No row relies on colour alone |
| UI scaling | Standard | Screen-space UI | Not Started | One 125% step (AR-V-03), Alpha. Field glyphs do not scale; the field already scales with screen size (`field_scale`) |
| High contrast mode | Comprehensive | | Out of scope | The base palette is already high contrast on a near-black field. See Known Intentional Limitations |
| Brightness/gamma controls | Basic | Global | Out of scope | The phone's own brightness covers it; a flat, near-black, unlit style has no gamma-dependent detail (art bible §6). Revisit if device tests show crushed blacks |
| Screen flash / strobe warning | Basic | All VFX | Not Started | AR-V-08 rule from MVP; notice AR-V-09 at Vertical Slice; automated check in the test plan |
| Motion/animation reduction mode | Standard (lifted from Comprehensive here) | All UI and field animation | Designed (flag at MVP) | AR-V-10 table. Toggle at Alpha |
| Subtitles: on/off | N/A | | N/A | No voiced content |
| Subtitles: speaker identification | N/A | | N/A | |
| Subtitles: style customization | N/A | | N/A | |
| Subtitles: sound effect captions | N/A | | N/A | Every gameplay sound has a visual twin, so no caption is needed (Auditory) |

### Color-as-Only-Indicator Audit

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| Danger at the lane exit | Magenta chevrons vs orange enemies | A leak is happening or near | Chevron shape and downward travel; 2 Hz pulse (frozen under Reduce Motion, shape stays); lives dashes drop | Designed |
| Slowed enemy | Violet tint | The enemy is slowed | Drag lines plus size wobble (art bible §4; Combat) | Designed |
| Armoured vs damaged enemy | Both darker | Armour vs low health | Outer ring vs inner core (art bible §4) | Designed |
| Tower ready vs cooling | Ring fill level | Tower can fire | Complete ring vs regrowing clockwise ring (art bible §4, Tower) | Designed |
| Burst button ready vs cooling vs locked | Gold fill vs neutral | Burst can be aimed | Filled vs outline plus sweep wedge plus digit vs dotted outline (art bible §7) | Designed |
| Hero's Ready state on the field | Gold ticks | Burst is ready, seen without looking at the corner | Four static ticks at radius 40, shape not hue (Hero) | Designed |
| Hero vs tower vs enemy | Gold vs cyan vs orange | Who is who | Kite vs regular polygon vs circle; survives greyscale at quarter scale (art bible §1, §5) | Designed |
| Hero shot vs tower shot | Gold vs cyan line | Who dealt the hit | Line origin shape, width and flash strength (Combat) | Designed |
| Build arc discs | All cyan | Which tower role | Triangle, hexagon, square in a fixed order, plus a word panel: Single, Splash, Slow (Battle HUD Rule 6) | Designed |
| Unaffordable disc or chip | Dim | Cannot afford | Strike-through on the cost (Battle HUD, Tower). No magenta | Designed; contrast fix AR-V-05 |
| Wave pips | Fill | Done, current, upcoming | Filled, outlined, dotted (Battle HUD) | Designed |
| Lives | Dash alpha | Lives left | Dash count; lost dashes stay countable (Battle HUD) | Designed |
| Free vs blocked slot | Alpha | Can build here | 4-dot corner mark vs diagonal hairline, shape first (art bible §6) | Designed; contrast fix AR-V-07 |
| Leash in-zone vs out-of-zone | Tint | Hero can or cannot fight there | Dash density, dashed to solid (art bible §4) | Designed |
| Kill preview during aim | None (body knocked out) | This enemy dies to the burst | Knocked-out body with a steady white contour (Hero) | Designed |
| Current vs next range ring | Alpha only | Range now vs after upgrade | **None yet besides alpha.** AR-V-06 asks for a pattern (dashed) | GDD change needed |
| Stage A vs stage B | Field hue | Which stage | Path curve and grid tilt; hue alone never separates two stages (art bible §6) | Designed |
| Burst aim cancelling | Dim | Release will cancel | Reticle alpha 0.3, radius preview hidden, kill marks hidden (Hero) | Designed |

---

## Motor Accessibility

Motor load is the game's main barrier. A player holds the phone in one hand and plays with that thumb, while enemies move. The design already removes the worst of it: no long press, no double tap, no two-finger gesture, no tap time limit, and a press held still for ten seconds is still a tap (Input Rule 3, "the accessibility floor"). What remains is drags (pin and aim), small adjacent targets (the arc discs), and two short windows (the cost chip and the intermission).

**Target sizes at the minimum screen (360 dp wide).** Hit size is what counts; the drawn shape may be smaller.

| Target | Hit radius (units) | Hit diameter | Meets 48 dp? | Source |
|---|---|---|---|---|
| Tower, build slot, arc disc | 36 | 48 dp | Yes, with no margin | Input GDD, art bible §3 |
| Upgrade chip | 40 | 53 dp | Yes | Battle HUD Rule 9 |
| Burst button | 48 | 64 dp | Yes | Input GDD |
| Start/Call | 48 | 64 dp | Yes | Battle HUD Layout |
| Hero (drag) | 56 | 75 dp | Yes | Input GDD |
| Retry, Play again | 128 x 72 rect | 85 x 48 dp | Yes | Battle HUD Layout |
| Paused, result screens | Full screen | Full screen | Yes | ADR-0003 TapScreen |

**Requirements.**

- **AR-M-01 One thumb, one tap or one drag.** Already decided (Pillar 4). Every action is one tap or one drag of one finger; a feature that needs two thumbs is cut or redesigned. MVP, every system; enforced by the Input resolver's one-pointer rule.
- **AR-M-02 48 dp hit floor, no exceptions.** Already decided (Pillar 4, Input `target_ok`, ADR-0003 minimum size guard of 360 x 640 dp). 48 dp is the Android figure and also clears iOS's 44 pt. New: every menu and settings screen at Vertical Slice and Alpha follows it too. MVP, Input and every target owner; Vertical Slice, Menu & Screen Flow.
- **AR-M-03 Handedness.** Already decided at MVP as a data flag, `left_handed` on the Input record, read once into `PresentationSettings` (ADR-0001). Only the burst button and its digit mirror (Battle HUD, Hero). New: at Alpha it becomes a setting, chosen on first launch at Vertical Slice (a one-screen choice before the first stage, defaulting to right). Vertical Slice for the first-launch choice, Menu & Screen Flow; Alpha for the setting, Settings & Accessibility.
- **AR-M-04 Hit-area scale.** Reserved in the Input GDD (Deliberately not built; Open Questions). New commitment: one setting, x1.0 or x1.25, multiplying every target's hit radius in the hit test. It must not change which target wins where discs did not overlap before: the content rules that keep Start/Call 17.3 units clear of a slot and 7.2 clear of the left-hand burst disc fail at x1.25, so the content test must run at the largest scale, or the scale must skip the targets those rules protect. Alpha, Input & Gesture Resolver with Settings & Accessibility; Enemy & Wave and Battle HUD own the content rules. **GDD change needed:** Battle HUD content-rules table and Enemy & Wave L3 must state the scale they are checked at.
- **AR-M-05 Steady-hand slop.** Reserved in the Input GDD ("steady hand" x1.5). New commitment: one setting that multiplies `drag_slop` and `tap_slop` by 1.5, kept inside their hard domains (8 to 30 and 16 to 34) and keeping `tap_slop` above `drag_slop`. This helps players with tremor whose taps drift into dead drags. Alpha, Input & Gesture Resolver; the runtime slop setter is the Input GDD's reserved hook.
- **AR-M-06 Two-tap mode in place of drags.** Reserved in the Input GDD Open Questions. New commitment: a setting where a tap on the hero, then a tap on the field, pins the hero there; and a tap on the Ready burst button, then a tap on the field, aims and fires there, with a visible armed state and a tap on the button again to cancel. No action in the game may then need a drag. The resolver's owner API already hides the physical gesture, so owners change, not the resolver's signals. Alpha, Hero System and Input & Gesture Resolver, with Settings & Accessibility. **GDD change needed:** the Input GDD burst sink ("a tap on the burst button does nothing and reaches nothing beneath"), the concept's Pillar 4 text, and Hero Rule 11 hold only in the default mode; each must name the two-tap mode as the exception. This needs its own Pillar 4 phone test, since the zero mis-fire bar applies to it too.
- **AR-M-07 Cost-chip window multiplier.** New. The 1.5 s second-tap window (Tower Rule 8) is a timed input. A setting gives x1, x2 or x3 (1.5, 3.0 or 4.5 s); the 200 ms bounce guard stays fixed. A longer window means a later tap on the same tower can still upgrade it; the draining bar must make that visible. Alpha, Tower System with Settings & Accessibility. **GDD change needed:** Tower GDD gains the multiplier as a tuning knob with its safe range.
- **AR-M-08 Intermission length multiplier.** New. The intermission counts down and then starts the next wave by itself (Flow, `intermission_left`), which is time pressure on building. A setting gives x1, x1.5 or x2. The call-early bonus must be computed against the default length, so a longer intermission gives more time, never more gold; Hero's burst cooldown still fits, since a longer intermission only widens the `intermission_duration >= cooldown + telegraph_duration` margin. Alpha, Game State & Stage Flow with Enemy & Wave and Tower System (bonus formula). **GDD change needed:** Flow and Tower formulas for `seconds_left` and the call bonus.
- **AR-M-09 No hold, no rapid input, no tap time limit.** Already decided (Input Rule 3; Deliberately not built: long press, tap duration limit). Recorded as a commitment: no later system may add a hold-to-act, a mash or a tap timeout without an alternative here. MVP onward, every system.
- **AR-M-10 Rejected edges.** Already decided (Input Rule 12; ADR-0003 Decision 3): presses inside the side-edge margin and OS insets never reach the game, so an OS back swipe cannot fire an action. MVP, Input adapter; the 36-unit margin is unverified on devices (Input Open Questions).
- **AR-M-11 Arc disc spacing.** Known risk, already open (Battle HUD Open Questions): adjacent arc discs are 4 units apart and a wrong disc is a permanent buy with no sale. Recorded here as a motor barrier: if the Pillar 4 test shows any wrong-disc mis-fire, the fallback is a larger arc radius `R`, not a confirm step. MVP+ (first phone build), Battle HUD.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Full input remapping | Standard (touch equivalent) | All gameplay input | Not Started | No bindings exist. The equivalent set is AR-M-03 to AR-M-06 |
| Input method switching | N/A | | N/A | Touch only on device. Desktop mouse is a dev tool |
| One-hand mode | Standard (lifted, by design) | Whole game | Designed | One thumb is the only mode (AR-M-01). No feature needs two hands |
| Hold-to-press alternatives | Standard | All hold inputs | Designed | No hold inputs exist (AR-M-09) |
| Rapid input alternatives | Standard | | Designed | No rapid input. Burst cooldown 10 s; towers fire on their own |
| Input timing adjustments | Standard | Cost-chip window, intermission | Not Started | AR-M-07, AR-M-08 at Alpha. The 200 ms disc and chip guards and 300 ms arming are protective delays, not windows, and stay fixed |
| Aim assist | Standard (partial) | Burst aim | Designed in part | The offset reticle, the reach clamp and the kill preview help aim (Hero). No snap: "aim snap" is not built for MVP (Hero). Two-tap mode (AR-M-06) is the larger aid |
| Auto-sprint / movement assists | N/A | | N/A | The hero walks to its pin by itself; no held movement |
| Platforming / traversal assists | N/A | | N/A | No platforming |
| HUD element repositioning | Comprehensive (partial) | Burst button | Designed | Left-hand mirror only (AR-M-03). Full repositioning out of scope |

---

## Cognitive Accessibility

A battle asks the player to watch a lane, a hero, a cooldown, gold and lives at once, while deciding where to pin and what to build. The design keeps the screen sparse on purpose: no damage numbers, no HP bars, no tower stats, one prompt at a time, and a next-wave line that names what comes (Battle HUD Rules 4, 5 and 13). The gaps are pause, retrieving help, and the pace of waves.

- **AR-C-01 Pause anywhere.** Partly decided: at MVP losing focus or backgrounding pauses (Flow Rule 17), and Android back pauses instead of quitting (ADR-0003 Decision 5). There is no pause button at MVP (Battle HUD Rule 4), which is fine on a desktop MVP but not on a phone: iOS has no back button. New: a pause control in every live phase from the first phone build. It is a 48 dp target outside the bottom 30% of the screen, which art bible §7 keeps for the field and burst button, and it must not take a press meant for the field. The top band ignores input today (Battle HUD Rule 1), so the UX spec must decide where it goes. Vertical Slice (phone build), Battle HUD with Menu & Screen Flow and Game State & Stage Flow. **GDD change needed:** Battle HUD Rule 4 and Flow Rule 17 ("no pause button") end at Vertical Slice.
- **AR-C-02 Paused screen holds still.** Already decided (Battle HUD Rule 17): a static 40% scrim, one line, resume on tap, no timer. Recorded here so no later Paused menu adds a timer.
- **AR-C-03 Prompts hide on the act, never on a timer.** Already decided (Battle HUD Rule 13). Meets "reading time for UI": no actionable text auto-dismisses. The result screens wait for Retry. The chip's 1.5 s window is a timed input, covered by AR-M-07.
- **AR-C-04 Help you can find again.** New. The three verb prompts teach once per battle. From Vertical Slice a "How to play" screen, reached from Pause, shows the four verbs (tap a slot, tap a tower twice, drag the hero, drag from the big button) with one static picture each. Vertical Slice, Onboarding Prompts with Menu & Screen Flow.
- **AR-C-05 Next wave in view.** Already decided (Battle HUD Rule 5): glyph and count per enemy type before each wave. This is the game's "objective clarity".
- **AR-C-06 Plain, blame-free result text.** Already decided (Battle HUD Rules 15 and 16; Game Feel): fixed order, same weight, no "you", no percentages. Recorded so later report screens keep it.
- **AR-C-07 Verbs stay few.** Already decided (Input Game Feel): no long press, no double tap; one verb for the hero. New systems at Vertical Slice and Alpha (skill tree, weapons) must not add a battle verb without a row in the Per-Feature Matrix.
- **AR-C-08 Slower game speed.** New, pending a technical check. A 0.75x game speed for players who need more time to read the field. The tick clock is fixed at 60 Hz and drives deterministic results (ADR-0004), so this must slow real time per tick and never change tick math. Alpha, Game State & Stage Flow with Settings & Accessibility; technical-director to confirm it fits ADR-0004 before it is promised (Open Questions). If it does not fit, AR-M-08 and pause carry the load and this moves to Known Intentional Limitations.
- **AR-C-09 Difficulty.** No difficulty settings at MVP or Vertical Slice; waves are tuned against bot criteria (Pillar 2). New: at Alpha the producer decides whether a "more lives" assist (for example x2 starting lives, with the lives display still fitting the 10-dash limit or growing a row) is offered. Recorded as an Open Question, not a commitment.
- **AR-C-10 Settings changes take effect cleanly.** New. `PresentationSettings` is read once (ADR-0001), so a change made from Pause applies at the next battle build, and the settings screen must say so in one line. Alpha, Settings & Accessibility.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Difficulty options | Standard | Stage difficulty | Not Started | None at MVP or VS. Alpha decision (AR-C-09). Fixed parameters are justified by Pillar 2 wave tuning |
| Pause anywhere | Basic | All live phases | Partial | Focus loss and Android back pause at MVP. Pause control from the phone build (AR-C-01) |
| Tutorial persistence | Standard | Verb prompts | Not Started | AR-C-04 at Vertical Slice |
| Quest / objective clarity | Standard | Stage goal, next wave | Designed | One goal (hold the lane); next-wave line (AR-C-05) |
| Visual indicators for audio-only information | Standard | All SFX | Designed | No audio-only information exists or may be added (Auditory) |
| Reading time for UI | Standard | All text | Designed | Nothing actionable auto-dismisses (AR-C-03). Chip window: AR-M-07 |
| Cognitive load documentation | Comprehensive | Per system | Designed | Matrix below lists the count per system |
| Navigation assists | N/A | | N/A | No world to navigate; one lane per stage at MVP and VS |

---

## Auditory Accessibility

There is no audio at MVP (concept, Technical Considerations), and the target player often plays with sound off. Audio arrives at Small Ship (Audio, Alpha): SFX per tower and hero action and one loop per stage family. There is no voice, no dialogue and no narration at any tier. So the rule is simple and strict: **every sound that tells the player to do something has a visual that already tells them, and the sound only repeats it.**

- **AR-A-01 No audio-only information, ever.** New as a rule for the Audio GDD. Every SFX in the audit below must have its visual twin before the SFX ships. Alpha, Audio.
- **AR-A-02 Independent volume.** New. Three sliders: Music, SFX, UI. No voice bus exists. 0 to 100%, saved. Alpha, Audio with Settings & Accessibility and Save/Load.
- **AR-A-03 Mono audio.** New, low cost. A mono toggle, so a player with hearing in one ear misses nothing. Stereo carries no information in a portrait game, so this is a comfort item. Alpha, Audio.
- **AR-A-04 Respect the silent switch and other apps' audio.** New. Sound off on iOS's ring/silent switch, and do not stop a player's own music unless they turn game music on. Alpha, Audio with Mobile Platform & Performance (exact behaviour unverified on Godot 4.7, Open Questions).
- **AR-A-05 Low-frequency cues.** New. No gameplay SFX may rely on content above 4 kHz alone, since hearing aids often cut high frequencies. Alpha, Audio.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Subtitles for all spoken dialogue | N/A | | N/A | No spoken content |
| Closed captions for gameplay-critical SFX | Comprehensive | | N/A by design | Every SFX has a visual twin (audit below), so no caption is needed |
| Mono audio option | Comprehensive (lifted) | Global | Not Started | AR-A-03, Alpha |
| Independent volume controls | Basic | Music, SFX, UI | Not Started | AR-A-02, Alpha. No audio exists before then |
| Visual representations for directional audio | Comprehensive | | N/A by design | No off-screen threats: the whole lane is on screen |
| Hearing aid compatibility mode | Standard | All SFX | Not Started | AR-A-05 as an authoring rule, not a mode |

### Gameplay-Critical SFX Audit

These sounds are planned for Small Ship and do not exist yet. Each row names the visual that already carries the same fact.

| Sound Effect | What It Communicates | Visual Backup | Caption Required | Status |
|-------------|---------------------|--------------|-----------------|--------|
| Enemy leak | A life is lost | Lost dash fades; danger chevrons animate at the exit | No | Not Started |
| Burst ready | Burst can be aimed | Gold fill and complete ring on the button; four Ready ticks around the hero | No | Not Started |
| Burst release and kills | Hit and how many died | Gold ring, spokes per kill, hero pulse by kill count (Hero) | No | Not Started |
| Wave start | Enemies are coming | Pips advance; Start/Call hides; enemies enter | No | Not Started |
| Intermission ending | Next wave is about to start | Seconds left under Start/Call (Battle HUD Rule 10) | No | Not Started |
| Build and upgrade | Gold spent, tower placed or grown | Build overlay and new geometry on the first frame; gold digits change | No | Not Started |
| Refused build or upgrade | Not enough gold | Strike-through, dim, and the non-motion refusal cue (AR-V-11) | No | Not Started |
| Hero pinned | Pin landed | Ground ring snaps in (Hero) | No | Not Started |
| Win and loss | Stage outcome | Result panel and text | No | Not Started |
| Ground tap | Nothing happens here | Silent by design (Input); the dim ring for the first three taps | No | Designed |

---

## Platform Accessibility API Integration

The battle is not made of Control nodes. Every field element and most of the HUD are drawn by `_draw()`, and their hit targets are discs in the Input resolver, not Controls (Battle HUD Rule 1; Input UI Requirements). Godot's AccessKit, added in 4.5, works through Control nodes (engine reference `modules/ui.md`), so a screen reader cannot see the battle. The result and Paused screens are `TapScreen` Controls, not `Button`, so they also lose Button's AccessKit role; ADR-0003 says they should get an accessible name if AccessKit allows one on a plain Control, which is unverified, and that keyboard resume is not supported. Menus arrive at Vertical Slice and are the one place a screen reader could work.

- **AR-P-01 Menus use labelled Controls.** New. Menu & Screen Flow builds menus and settings from standard Controls with a visible text label and an accessible name, in a logical focus order, so that TalkBack and VoiceOver can read them if Godot 4.7's AccessKit reaches them on mobile. A best effort, not a promise: whether AccessKit works on Android and iOS in 4.7 is unverified (Open Questions). Vertical Slice, Menu & Screen Flow.
- **AR-P-02 TapScreen accessible name.** Carried from ADR-0003 (Negative consequences, G16). If a plain Control can carry an accessible name, Paused reads "Paused. Tap to resume" and the result screen reads its text in table order. No keyboard path is added; desktop is a dev build. Vertical Slice (when Menu & Screen Flow replaces the MVP result), Battle HUD and Menu & Screen Flow; verified by the ADR-0003 S0 spike or a later probe.
- **AR-P-03 Honour OS display settings where cheap.** New. Copy the OS Reduce Motion or Remove Animations setting into the first-launch default (AR-V-10). OS font scale (Dynamic Type, Android font size) is not followed in the battle, since the field layout is fixed; the Larger text setting (AR-V-03) covers it. Alpha, Settings & Accessibility with Mobile Platform & Performance.
- **AR-P-04 OS magnification and back.** Already decided: the letterbox and fixed field do not block OS zoom, and Android back pauses (ADR-0003 Decision 5). Nothing to build.

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| Xbox (GDK) | XAG | None | N/A | No Xbox release |
| PlayStation 5 | Sony guidelines | None | N/A | No PlayStation release |
| Steam (PC) | Steam Input | None | N/A | Desktop is a dev build only |
| iOS | UIAccessibility / VoiceOver | VoiceOver for menus if AccessKit reaches iOS (AR-P-01); Reduce Motion default (AR-P-03); silent switch (AR-A-04) | Not Started | AccessKit on iOS in Godot 4.7 unverified. The battle is out of scope |
| Android | AccessibilityService / TalkBack | TalkBack for menus if AccessKit reaches Android (AR-P-01); Remove Animations default (AR-P-03); back pauses (ADR-0003) | Not Started | AccessKit on Android in Godot 4.7 unverified. The battle is out of scope |
| PC (Screen Reader) | AccessKit (Godot 4.5+) | None for players | N/A | Desktop is a dev build. TapScreen has no keyboard resume (ADR-0003) |

---

## Per-Feature Accessibility Matrix

"Load" is the most things the system asks the player to track at once; a load above 4 is a review trigger. Every system in `systems-index.md` has a row. Systems with no GDD yet carry the requirements this document sets for them.

| System | Visual Concerns | Motor Concerns | Cognitive Concerns (load) | Auditory Concerns | Addressed | Notes |
|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| 1 Data & Config Pipeline | None player-facing | None | None (0) | None | Yes | Holds `left_handed` and `reduce_motion` on the Input record until Settings exists (ADR-0001) |
| 2 Input & Gesture Resolver | Draws nothing | Target size, slop, edge rejection, palm rejection, no tap limit | Two gesture classes only (1) | None; ground tap silent | Partial | AR-M-04, AR-M-05, AR-M-06 at Alpha; Pillar 4 test unrun |
| 3 Game State & Stage Flow | Pause scrim | No pause control at MVP | Intermission countdown pressure (2: phase, time left) | None | Partial | AR-C-01 (VS), AR-M-08, AR-C-08 (Alpha) |
| 4 Combat & Damage | Hit flashes (80 ms, small); hero vs tower lines read in greyscale | None | None directly (0) | None at MVP | Yes | AR-V-08 flash rule; burst clearance keeps the hero brightest |
| 5 Enemy & Wave | Glyph size 16 to 30 px; types by shape and size | None | Enemy types and convergence on the lane (3) | None | Yes | AR-V-12 greyscale test for every new type; next-wave line |
| 6 Tower System | Range ring contrast; slot mark contrast; hexagon vs square at quarter scale | 48 dp targets with no margin; 1.5 s chip window; adjacent slots | Gold, cost, role, level (4) | None at MVP | Partial | AR-V-06, AR-V-07, AR-V-11 (MVP); AR-M-07 (Alpha) |
| 7 Hero System | Leash over path; reach dots; kill preview; burst VFX motion | Pin drag, burst drag, re-grabbing a hero high on the screen | Pin position, leash, cooldown, aim, kill preview (5, during aim only) | None at MVP | Partial | Load 5 only while aiming, and the aim view hides the rest; AR-M-06 two-tap at Alpha; AR-V-10, AR-V-11 |
| 8 Battle HUD & Build UI | Dimmed cost contrast; 14 dp text; text scaling | Arc discs 4 units apart; Start/Call beside the left burst disc (7.2 clear) | Lives, gold, pips, prompt, next wave (5, all glanceable) | None | Partial | AR-V-03, AR-V-05, AR-C-01, AR-M-11; panels must grow for 125% text |
| 9 Stat & Modifier Resolution | None player-facing | None | None (0) | None | Yes | |
| 10 Skill Point Economy | Point counts as text | None | Points left, cost (2) | None | Not Started | Any screen follows AR-V-01, AR-M-02 |
| 11 Skill Tree System | Node states must not be colour-only (use filled, outlined, dotted, the tree-node grammar in art bible §7) | Node targets 48 dp; tree may scroll on a phone | Tree paths, costs, the one-tree scarcity rule (4+) | None | Not Started | Must state node states by shape; free respec lowers the cost of a wrong choice |
| 12 Hero Weapons | Weapon by added contour element, never recolour (art bible §5) | None new | One more choice before a stage (1) | None | Not Started | Greyscale test at 44 px |
| 13 Stage Progression & Stars | Stars must not be colour-only; preview at small scale | 48 dp targets | Star rules, stage preview (2) | None | Not Started | Preview is real geometry rendered small; check legibility at phone size |
| 14 Save/Load | None | None | None (0) | None | Not Started | Must save every Settings & Accessibility value (AR-C-10) |
| 15 Menu & Screen Flow | Text floor, contrast, 125% text | 48 dp targets, one thumb, no two-finger scroll | Menu depth | None | Not Started | AR-P-01, AR-V-09, AR-C-01, AR-C-04, AR-M-03 first-launch hand |
| 16 Mobile Platform & Performance | Safe area, letterbox, large top inset meeting the prompt | Edge rejection margin on devices | None | Silent switch | Not Started | AR-A-04, AR-P-03; owns the Battle HUD inset question |
| 17 Onboarding Prompts | Prompt text floor and position (seen while eyes are on the lane?) | None | Must teach verbs once, then be retrievable | None | Not Started | AR-C-04 |
| 18 Cross-Tree Synergy Hook | Buff visible within one wave without colour alone | None | One link between hero and towers (1) | None | Not Started | Visual Feedback & VFX contract |
| 19 Visual Feedback & VFX | Flashes, pulses, glow budget; Reduce Motion fallbacks | None | Must not hide the hero or a path | None | Not Started | AR-V-08, AR-V-10, AR-V-13; owns the automated flash check |
| 20 Audio | N/A | None | None | All of the Auditory section | Not Started | AR-A-01 to AR-A-05 |
| 21 Settings & Accessibility | Settings screen text and contrast | 48 dp toggles, one thumb | Each setting one line, plain words | UI sounds have no meaning of their own | Not Started | Owns every Alpha setting here: Larger text, Reduce Motion, hand, hit scale, steady hand, two-tap mode, chip and intermission multipliers, game speed, volumes, mono |
| 22 Cross-Tree Synergies (full lattice) | Many buffs at once must stay legible within the feature budget | None | Highest load in the game (4+) | None | Not Started | Review trigger: needs a load check when its GDD is written |

---

## Accessibility Test Plan

Three kinds of test, as the template asks: automated (numbers), manual internal (the team simulating barriers), and user testing (players who use the features). No test here has run.

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---------|------------|------------|--------------|-------------|--------|
| Text and graphic contrast | Automated: a unit test that computes WCAG contrast from the palette constants and each state's alpha; then a contrast check on retained screenshots | Every text and essential graphic in the contrast table, in every state, on field and on path | Text at or above 4.5:1; essential graphics at or above 3:1; listed exceptions only | ux-designer, test harness story | Not Started |
| Target size | Automated: the Input GDD's `target_ok` test at 360 x 640 dp; a registry scan for every registered radius | Every registered target, both hands; at hit scale x1.25 once AR-M-04 exists | Every target at or above 48 dp; content rules still hold at the largest scale | gameplay-programmer | Not Started |
| Colour independence | Manual: greyscale and colour-blind simulator (protan, deutan, tritan) on retained screenshots | Build, Wave with mixed enemies and a slowed one, danger at the exit, arc open with one unaffordable disc, chip open, burst cooling | Every row of the Colour audit reads without hue | ux-designer, art-director | Not Started |
| Text size and Larger text | Manual: screenshots at 360 dp width at 100% and 125% | Every HUD panel, result, Paused, every menu | No clipped or overlapping text; 14 dp floor at 100% | ux-designer | Not Started (125% at Alpha) |
| Reduce Motion | Manual: flag on, play one full stage; frame-stepped capture of the burst | Every row of the AR-V-10 table | Every "under Reduce Motion" behaviour as listed; enemy telegraphs still present; every refusal has a static cue | ux-designer | Not Started |
| Photosensitivity | Automated: Harding or PEAT analysis of a recorded stage with the most bursts and leaks | One full stage on a 360 dp phone capture | No fail; no flash over 3 per second above 25% of screen | qa-tester | Not Started (Vertical Slice) |
| One thumb and handedness | Manual: play each stage one-handed, right and left hand, on a 360 to 400 dp phone | All verbs, Pause, Retry | Every action reachable by the holding thumb; left hand mirrors only button and digit | qa-tester | Not Started (phone build) |
| Pillar 4 gesture test | User testing: the Input GDD's P1 protocol | 20 attempts per gesture, two non-developer testers, one left-handed if available | Misses at most 5% per gesture; zero mis-fires | producer | Not Started (first phone build) |
| Two-tap mode | User testing: P1 protocol repeated with two-tap mode on | Pin and burst by two taps | Same bar as P1 | producer | Not Started (Alpha) |
| Timing multipliers | Manual: each multiplier value | Chip at x1, x2, x3; intermission at x1, x1.5, x2 | Window lengths as set; call bonus never higher than at x1 | qa-tester | Not Started (Alpha) |
| Sound-off play | Manual: one full stage with audio muted, once audio exists | Every row of the SFX audit | Every SFX fact is visible on screen | qa-tester | Not Started (Alpha) |
| Platform screen reader (menu) | Manual: TalkBack and VoiceOver on, navigate every menu | Main menu, settings, Pause, result | Every menu control has a spoken name; order is logical. NOT ASSESSED if AccessKit does not reach mobile | ux-designer | Not Started (Vertical Slice) |
| User testing: motor | User testing with players who have tremor, limited thumb reach or use one hand | One stage with hit scale, steady hand and two-tap mode on | Finishes the starter stage; no mis-fire they did not intend | producer | Not Started (Alpha) |
| User testing: low vision and colour-blind | User testing | One stage on their own phone, with Larger text | Names every enemy type and state without asking | producer | Not Started (Alpha) |

Every screenshot above is retained in `production/qa/evidence/` (coding standards: a parse check is not a run).

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Screen reader for the battle field and HUD | Comprehensive | The field and HUD are `_draw()` with disc hit targets, not Controls; AccessKit covers Controls only. A spoken spatial battle is a different game | Blind players cannot play a battle. Low-vision players who rely on a screen reader get menus only (if AR-P-01 works) | Menus best effort (AR-P-01); high base contrast; Larger text; next-wave line in plain words |
| Palette-swap colour-blind modes | Standard (baseline item) | One fixed palette carries the semantic vocabulary (one hue, one fact); every pair already has a shape or motion backup. A swap would add a second vocabulary to test | Low if the Colour audit holds; a player may still want a palette that suits them | Shape-first design; simulator and user tests; revisit if user tests show confusion |
| High contrast mode | Exemplary | The base style is already near-black field with bright flat shapes | Players who need pure black and white UI | Contrast floors AR-V-04; Larger text |
| Full HUD repositioning | Comprehensive | The layout is fixed in field units with content rules that protect taps; moving elements breaks those rules | Players with limited reach to the top band | Left-hand mirror; the top band holds read-only items; Start/Call and burst sit low |
| Keyboard, gamepad and switch access | Standard (remapping) | Touch-only mobile game; every action is a disc (Battle HUD Deliberately not built); TapScreen has no keyboard resume (ADR-0003) | Players who cannot use a touch screen at all, including switch users | Two-tap mode reduces the gesture set to taps; revisit for a desktop release |
| Haptics | Exemplary | Not in scope at MVP (Hero: Deliberately not built) | None for information, since no audio-only cue exists | Visual twin for every sound |
| Following OS font size in the battle | Comprehensive | Fixed 540 x 960 field layout | Players who rely on OS large text | Larger text at 125% (AR-V-03); 14 dp floor |
| Ground ring below 3:1 (alpha 0.35, 2.5:1) | Basic (contrast) | It is a hint for the first three ground taps; a ground tap does nothing either way (art bible §7) | Some players miss the hint and think the tap failed, which is true | Keep; revisit if the first-run test shows confusion |
| Arc disc hit areas nearly touch (4 units apart) | Standard (motor) | The arc fan must fit above the slot at 48 dp per disc | Wrong-disc buys, which cannot be undone | Pillar 4 test; first fallback a larger `R` (AR-M-11); hit scale must not make it worse |
| Subtitle features | Basic to Exemplary | No voice or dialogue at any tier | None | N/A |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| 2026-11-04 | Internal, this `/ux-design accessibility` session (autonomous) | Desk review of design documents | Concept, systems index, art bible §4 to §7, Battle HUD, Input, Hero and Tower GDDs, architecture.md, ADR-0001, ADR-0003 | Tier set to Standard. Computed contrast: 3 fails (dimmed cost text 4.26:1, next-level range ring 1.65:1, slot outline 2.1:1) and 1 accepted exception (ground ring). 14 GDD or ADR changes listed below. Nothing has been rendered or run on a device | Open |
| Owed | ux-designer (agent) | Review | Whole document | **Review owed.** This session could not start the ux-designer agent | Not run |
| Owed | accessibility-specialist (agent) | Criteria review | Tier choice, the Standard mapping, and every requirement's pass criterion | **Review owed.** This session could not start the accessibility-specialist agent | Not run |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 | https://www.w3.org/TR/WCAG21/ | Contrast (1.4.3, 1.4.11), target size (2.5.5), timing (2.2.1), flashes (2.3.1) |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Game checklist by category and cost |
| AbleGamers Player Panel | https://ablegamers.org/player-panel/ | User testing with disabled players (motor test above) |
| Apple Human Interface Guidelines: Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility | 44 pt targets, Reduce Motion, VoiceOver |
| Android accessibility: touch target size | https://developer.android.com/guide/topics/ui/accessibility/apps | 48 dp targets, TalkBack, Remove Animations |
| Colour Blindness Simulator (Coblis) | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Simulator for the Colour audit |
| Trace Center PEAT | https://trace.umd.edu/peat/ | Photosensitivity analysis of recorded video |
| Accessible Games Database | https://accessible.games | Examples of accessible design decisions |
| Godot AccessKit notes | `docs/engine-reference/godot/modules/ui.md` | Control nodes work with AccessKit (4.5+); mobile support unverified |

---

## GDD and ADR Changes Needed

This document edits no GDD, ADR or the art bible. These are the places they would have to change to meet it. Each is for the owning document's next revision.

| # | Document and place | Today | Needed | Requirement | Tier |
|---|---|---|---|---|---|
| 1 | `battle-hud.md` Visual/Audio table, "Unaffordable" | Alpha 0.55 | Cost text at alpha 0.6 or above (4.83:1); the polygon may stay at 0.55 | AR-V-05 | MVP |
| 2 | `tower-system.md` Visual/Audio table, "Range ring" | Next level at alpha 0.25 (1.65:1) | 3:1 on the path, told apart by pattern (for example dashed at 0.5) | AR-V-06 | MVP |
| 3 | `design/art/art-bible.md` §6, slot marks | Outline 1 px at alpha 0.3 (2.1:1); corner mark alpha unset | Free-slot corner mark at 3:1 or above (alpha 0.45 gives 3.3:1) | AR-V-07 | MVP |
| 4 | `tower-system.md` and `hero-system.md` UI Requirements; `battle-hud.md` | Refusal and locked nudges skipped under Reduce Motion, with no replacement | A static refusal cue under Reduce Motion | AR-V-11 | MVP |
| 5 | `battle-hud.md` UI Requirements, Reduce Motion line | Lists slides only | Point to the AR-V-10 table here as the one list | AR-V-10 | MVP |
| 6 | `battle-hud.md` Rule 4 and Deliberately not built; `game-state-stage-flow.md` Rule 17 | No pause button | A pause control from the first phone build | AR-C-01 | Vertical Slice |
| 7 | `battle-hud.md` Layout and Visual table | Panels sized for 100% text | Panels fit 125% text | AR-V-03 | Alpha |
| 8 | `battle-hud.md` content rules; Enemy & Wave L3 | Clearances checked at hit scale x1 (Start/Call 17.3 from a slot, 7.2 from the left burst disc) | State the hit scale the rules hold at; check at x1.25 | AR-M-04 | Alpha |
| 9 | `input-gesture-resolver.md` burst sink and Pillar 4 text; `game-concept.md` Pillar 4; `hero-system.md` Rule 11 | "A tap on the burst button does nothing" | True in the default mode only; two-tap mode is the named exception | AR-M-06 | Alpha |
| 10 | `tower-system.md` Rule 8 and Tuning Knobs | 1.5 s window, fixed | Window multiplier x1 to x3 as a knob | AR-M-07 | Alpha |
| 11 | `game-state-stage-flow.md` and `tower-system.md` formulas | Intermission fixed; call bonus from `seconds_left` | Intermission multiplier; bonus computed against the default length | AR-M-08 | Alpha |
| 12 | ADR-0004 (fixed tick clock) | 60 Hz tick from real time | Confirm a 0.75x game speed can slow real time per tick without touching tick math, or record that it cannot | AR-C-08 | Alpha |
| 13 | ADR-0003 Negative consequences (G16) | TapScreen accessible name unverified | Verify in a probe whether a plain Control can carry an accessible name; record the answer | AR-P-02 | Vertical Slice |
| 14 | ADR-0001 / architecture.md, `PresentationSettings` | Read once from the Input record at AppRoot | At Alpha, Settings is the source (already planned); gains the new Alpha fields (text scale, hit scale, slop scale, two-tap mode, multipliers), or they live elsewhere | AR-C-10 and Alpha settings | Alpha |

No conflict found with an Accepted ADR: every item above adds to an ADR or fills a gap it names, and none reverses a decision.

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Does Godot 4.7's AccessKit reach TalkBack and VoiceOver on Android and iOS, or only desktop screen readers? | godot-specialist | Before Menu & Screen Flow GDD (Vertical Slice) | Unresolved. The pinned reference says only "Control nodes work with AccessKit" |
| Can a plain Control (TapScreen) carry an accessible name in 4.7? | godot-specialist | Vertical Slice | Unresolved (ADR-0003 G16) |
| Can the game read the OS Reduce Motion (iOS) and Remove Animations (Android) settings in Godot 4.7? | godot-specialist | Alpha | Unresolved |
| Does a 0.75x game speed fit ADR-0004's fixed tick without changing results? | technical-director | Before Settings & Accessibility GDD (Alpha) | Unresolved (AR-C-08) |
| Where does the pause control go, given the top band ignores input and the bottom 30% is kept for the field and burst? | ux-designer, Battle HUD | Before the first phone build | Unresolved (AR-C-01) |
| Should Alpha offer a "more lives" assist, and does it break Pillar 2's bot criteria? | producer, game-designer | Alpha | Unresolved (AR-C-09) |
| Does hit scale x1.25 keep the zero mis-fire bar near the arc discs and Start/Call, or should it skip some targets? | Input & Gesture Resolver GDD | Alpha | Unresolved (AR-M-04) |
| Does the app store require or show an accessibility declaration for our release window (Apple has announced per-app accessibility labels; unverified)? | producer | Before store submission | Unresolved |
| How does the game behave with the iOS silent switch and other apps' audio in Godot 4.7? | godot-specialist | Alpha (Audio) | Unresolved (AR-A-04) |
| No player journey map exists (`design/player-journey.md`). Author it from `.claude/docs/templates/player-journey.md` so the first-run and help requirements (AR-C-04) rest on known player context | ux-designer | Before Vertical Slice UX specs | Unresolved |
| No interaction pattern library exists (`design/ux/interaction-patterns.md`). The refusal cue (AR-V-11) and two-tap mode (AR-M-06) should become named patterns there | ux-designer | Before `/team-ui` | Unresolved |
