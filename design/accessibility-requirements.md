# Accessibility Requirements

> Authoring guidance: .claude/docs/templates/guidance/accessibility-requirements-guide.md (load per-section as you author, do not read entirely).

> **Status**: In Design (draft, autonomous mode; tier committed below)
> **Author**: user + ux-designer
> **Last Updated**: 2026-11-05
> **Accessibility Tier Target**: Basic, plus the elevated items listed under This Project's Commitment
> **Platform(s)**: iPhone (iOS) first, Android deferred (ADR-0012 Decision 7); portrait, one thumb. MVP runs on desktop with mouse-as-touch (`design/gdd/game-concept.md`, Core Identity, MVP Definition)
> **External Standards Targeted**:
> - WCAG 2.1 Level AA, for text contrast, non-text contrast and flash limits only (proposed)
> - AbleGamers CVAA Guidelines: N/A (no voice chat or messaging)
> - Xbox Accessibility Guidelines (XAG): No (no Xbox release)
> - PlayStation Accessibility (Sony Guidelines): No (no PlayStation release)
> - Apple / Google Accessibility Guidelines: Partial (touch target size only at MVP; see Platform Accessibility API Integration)
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `design/ux/interaction-patterns.md`
> **Template**: Accessibility Requirements

> **Why this document exists**: Per-screen accessibility notes belong in UX
> specs. This document holds the project-wide commitments, the feature matrix
> across all systems, the test plan and the audit history. If a feature
> conflicts with a commitment here, this document wins: change the feature, not
> the commitment, unless the producer approves a formal revision.
>
> **When to update**: after each `/gate-check` pass, after any accessibility
> audit, and whenever a system is added to `systems-index.md`.

**Source key.** "Concept" is `design/gdd/game-concept.md`. "HUD", "Input",
"Hero", "Tower" and "Flow" are the GDDs `battle-hud.md`,
`input-gesture-resolver.md`, `hero-system.md`, `tower-system.md` and
`game-state-stage-flow.md` in `design/gdd/`. "AB" is `design/art/art-bible.md`.
ADRs are in `docs/architecture/`; ADR-0003, 0008, 0010 and 0011 are all
**Proposed**, not Accepted, so any value cited from them may still move.
**Proposed** in this document means no source sets the value and this draft
suggests one. Units: field units on the 540 x 960 reference; 1.5 units = 1 dp
at the 360 dp minimum width (AB §3, Input Core Rules).

---

## Accessibility Tier Definition

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical player-facing text is readable at standard resolution. No feature requires color discrimination alone. Volume controls exist for music, SFX, and voice independently. The game is completable without photosensitivity risk. | Low: primarily design constraints |
| **Standard** | All of Basic, plus: full input remapping on all platforms, subtitle support with speaker identification, adjustable text size, at least one colorblind mode, and no timed input that cannot be extended or toggled. | Medium: requires dedicated implementation work |
| **Comprehensive** | All of Standard, plus: screen reader support for menus, mono audio option, difficulty assist modes, HUD element repositioning, reduced motion mode, and visual indicators for all gameplay-critical audio. | High: requires platform API integration and significant UI architecture |
| **Exemplary** | All of Comprehensive, plus: full subtitle customization (font, size, color, background, position), high contrast mode, cognitive load assist tools, tactile/haptic alternatives for all audio-only cues, and external third-party accessibility audit. | Very High: requires dedicated accessibility budget and specialist consultation |

### This Project's Commitment

**Target Tier**: Basic (MVP through Vertical Slice). Re-decide at the Small Ship gate, when Settings & Accessibility (Alpha, systems-index #21) exists.

**How the tier was picked.** The skill and its guide name no default tier;
they leave the pick to the user and give a reasoning checklist (genre
barriers, audience, platform rules, team capacity, cost of dropping a tier).
The project runs in autonomous mode, so this draft takes the option that
checklist points to for this project, and the user can overrule it.

**Rationale**: TowerRiot is built by one part-time, first-time developer, and
the MVP is a 6 to 7 day desktop build (Concept, Estimated Scope, Technical
Risks). Basic is the tier whose cost is "design constraints", which the GDDs
already carry: colour never carries state alone (AB §2 State set, §4), every
target is at least 48 dp (Concept Pillar 4), and there is no audio or dialogue
at MVP. The genre's motor load is lower than an action game (tactical calm,
no wait timer before wave 1, no long press or two-finger gesture), but the
one-thumb drag model and small glyphs at phone scale are the real barriers,
so those get elevated items below. Standard does not map well yet: remapping
has no meaning for a two-gesture touch game, there is no dialogue to subtitle,
and text scaling and timing extension need a settings screen that does not
exist until Alpha. Dropping below Basic would mean colour-only state or
sub-48 dp targets, which would break Pillar 4 for every player, not only
disabled ones.

**Features explicitly in scope (beyond tier baseline)**:
- Minimum touch target 48 dp (44 pt iOS) for every target. Source: Concept Pillar 4; Input Formulas `target_ok`; HUD AC 28. Basic does not require it; Pillar 4 does.
- Text floor 14 dp, cooldown digit 24 dp with an 18 dp floor. Source: AB §7 Typography; HUD UI Requirements; ADR-0011 Decision 9 (sizes 21, 24 and 36 units).
- Reduce Motion, as the `reduce_motion` data flag on the Input record until Settings exists. Source: HUD UI Requirements; Hero GDD Rule handoffs; ADR-0011 Decision 8. Elevated from Comprehensive because the burst dip, the danger pulse and the hero snap are the game's main motion.
- Left-handed mirror, as the `left_handed` data flag, fixed per battle. Source: Concept Pillar 4; Hero Rule 2; HUD Edge Cases; ADR-0010 Decision 8 (`HeroInput.attach(..., left_handed, ...)`).
- No hold, long press, double tap, rapid input or multi-touch anywhere. A press held any length and released in place is a tap. Source: Input Rule 3 ("the accessibility floor"), Rule 1, Game Feel.
- No auto-dismiss of actionable text. Prompts hide on the act, never on a timer; the result screen waits for a tap. Source: HUD Rules 13 and 15.

**Features explicitly out of scope**:
- Screen reader for the battle field, adjustable text size, input timing multiplier, manual pause button, colourblind palette modes, volume sliders, haptics. Each is in Known Intentional Limitations with its reason.

---

## Visual Accessibility

The field is a dark plane where colour is reserved for meaning and shape
carries role (AB §1 "Shape is role, colour is state", §4). Visual work at MVP
is mostly holding to that rule and measuring it on a device.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Minimum text size, HUD and modal screens | Basic (elevated) | All text | Not Started | 14 dp floor (21 units), 16 dp for gold, lives, labels and costs, 24 dp cooldown digit with an 18 dp floor. Source: AB §7; HUD UI Requirements and Visual/Audio table. No text on the raw field at small sizes; text sits on panel #141B30 (AB §7). |
| Minimum text size, subtitles | Basic | N/A at MVP | N/A | No dialogue or voice exists (Concept Aesthetics: Narrative N/A). |
| Text contrast, UI text on panel | Basic | All UI text | Not Started | Proposed target: 4.5:1 for text below 18 pt, 3:1 for larger (WCAG 2.1 SC 1.4.3). Neutral #C8D0E0 on panel #141B30 is about 11:1, hand-calculated here against an opaque panel; AB §4 gives 12.2:1 against the field. Verify on device. |
| Text contrast, dimmed (unaffordable) costs | Basic | Arc panels, chip | Not Started | HUD sets alpha 0.55. Hand-calculated here, 0.55 gives about 4.2:1 on panel, under the proposed 4.5:1. **Proposed: alpha 0.6 (about 4.8:1).** The strike-through still carries "cannot afford" on its own (HUD Visual/Audio). Tower UX flag asks that a dimmed cost stay legible. |
| Non-text contrast, zones and rings | Basic | Leash, reach ring, range ring, reticle | Not Started | Proposed target: 3:1 against what lies beneath (WCAG 2.1 SC 1.4.11). AB §7 already sets 3:1 for the leash over the path (two-tone or alpha 0.7). Reach dots (Hero UX flag) and range ring over the path (Tower UX flag) are open and must be measured. |
| Colourblind modes (palette swaps) | Standard | All colour-coded gameplay | Out of scope | Not needed if the audit below holds: every colour signal has a shape, fill or line backup (AB §2 State set, §4 Colour-blind safety). See Known Intentional Limitations. |
| Colour-as-only-indicator audit | Basic | All UI and gameplay | In Progress (designed, not rendered) | See table below. Every known row has a backup in the sources. |
| UI scaling | Standard | All UI | Out of scope | HUD layout is fixed in field units and checked by content rules (HUD Layout). ADR-0011 Decision 9 limits text to three sizes; a fourth is a budget change. |
| High contrast mode | Comprehensive | Menus, HUD | Out of scope | The base palette is already high contrast: every entity at 5:1 or better against anything beneath (AB §6 Legibility rule). |
| Brightness / gamma | Basic | Global | Out of scope | Phones expose system brightness. See Known Intentional Limitations. |
| Screen flash / strobe | Basic | All VFX | Not Started | Sources: the 2 Hz danger pulse is capped at a 25% alpha swing or drawn as travelling chevrons; the 0.4 s burst field dip never re-dips within 1 s (AB §7 Animation). Hit flash is an 80 ms white disc on one enemy body, at most 16 at once (AB §8; ADR-0011 Decision 4). **Proposed:** no element flashes more than 3 times in any 1 s at full-screen scale, and the combined area of simultaneous hit flashes stays under the WCAG 2.3.1 small-area limit; checked at ADR-0011's synthetic worst case (48 alive, 16 flashes). **Proposed:** a one-line photosensitivity notice at first launch once Menu & Screen Flow exists (Vertical Slice). |
| Motion reduction | Comprehensive (elevated) | HUD, hero, towers, field | Not Started | `reduce_motion` flag on the Input record until Settings (HUD UI Requirements; Hero GDD handoffs). Each model takes it in `attach` and each Reduce Motion row is a unit test both ways (ADR-0011 Decision 8). Rows from sources: HUD cuts slides, keeps fades and clock bars; Hero drops the dip, wind-up, snap and Ready pop, shows a static ring from T+0.1 and 4 px at release, keeps spokes; the locked-button nudge and the refused-tap nudge are skipped (Hero UI Requirements, Tower UI Requirements); the danger pulse freezes and the burst dip is skipped (AB §7). **Gap:** Tower asks for a refusal cue that does not use motion, plus static fallbacks for the build overlay and arc collapse (Tower UX flag). Proposed cue in `design/ux/interaction-patterns.md`, Refused Purchase. |
| Subtitles (on/off, speaker, style, SFX captions) | Basic to Comprehensive | N/A at MVP | N/A | No dialogue and no audio at MVP (HUD, Hero, Tower Visual/Audio: "Audio: none at MVP"). |

### Color-as-Only-Indicator Audit

Each row names a colour signal and the non-colour backup the sources already
give it. Status stays "Designed" until a grey quarter-scale render test passes
(HUD Manual criteria; AB §1 desaturate test).

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| Field entities | Gold hero, cyan towers, orange enemies | Who is who | Shape: asymmetric kite, regular polygons, circles (AB §1, §3) | Designed |
| Tower role | All towers cyan | Single, splash, slow | Triangle, hexagon, square (Tower Rule 1). Hexagon vs square at quarter scale is the weakest pair and needs a render test (Tower Visual/Audio) | Designed |
| Enemy type | All orange | Fast, normal, heavy | Size 16, 22, 30 px plus the fast's forward notch (AB §3; HUD Visual/Audio) | Designed |
| Danger at the exit | Magenta vs enemy orange | Leak happening | Chevron shape plus double outline on the exit strip; pulse is extra, and freezes under Reduce Motion (AB §2, §4) | Designed |
| Slowed enemy | Violet tint | Enemy is slowed | Two drag lines plus size wobble (AB §2). Drag lines stay under Reduce Motion | Designed |
| Tower ready vs cooling | Fill only, if done by colour | Can fire now | Complete ring vs regrowing ring (AB §2, §4) | Designed |
| Burst button ready / cooling / locked | Gold fill vs neutral | Can I burst | Fill plus full ring; outline plus clockwise wedge plus digit; dotted outline (AB §7; HUD Rule 12) | Designed |
| Unaffordable disc or chip | Dimmed | Cannot afford | Cost struck through (HUD Visual/Audio; Tower UI Requirements) | Designed |
| Wave pips | None needed | Done, current, upcoming | Filled, outlined, dotted (AB §7; HUD Visual/Audio) | Designed |
| Lives | Alpha 0.2 on a lost dash | Lives left | Dash count stays countable (AB §7) | Designed |
| Free vs blocked slot | Alpha | Can build here | 4-dot corner mark vs diagonal hairline (AB §6) | Designed |
| Leash in vs out of zone | Tint | Inside the leash | Dash density (AB §4) | Designed |
| Aim cancelling vs live | Alpha | Release will cancel | Reticle at alpha 0.3 with no ticks, preview and kill marks hidden (Hero Visual/Audio; AB §7) | Designed |
| Kill preview during aim | White contour | This enemy dies to the burst | Body knocked out to field colour plus steady contour (Hero Visual/Audio) | Designed |
| Stage A vs stage B | Field hue | Different stage | Path curve and grid tilt; hue alone never separates stages (AB §4, §6) | Designed |

---

## Motor Accessibility

Every game action is one tap or one drag with one thumb (Concept Pillar 4).
The resolver is built so that a slow, shaky or resting thumb causes a miss,
never a wrong action (Input Rules 1 to 5, Game Feel).

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Minimum touch target | Basic (elevated) | Every target | Not Started | 48 dp (72 units) at 360 dp; 44 pt on iOS. Radii: tower, slot, arc disc 36; chip 40; burst button and Start/Call 48; hero drag 56 (Input Hit targets; Tower Rule 8; HUD Layout; Hero Rule 15). Enforced by `target_ok` (Input Formulas; HUD AC 28; ADR-0008 Decision 10). |
| Target spacing | Basic | Tap targets with different actions | Not Started | Sources: Start/Call at least 16 units clear of any slot and arc disc; arc disc at least 84 from the burst line (HUD Content rules). **Proposed:** at least 8 dp (12 units) clear between adjacent tap targets that do different things. Known failure: adjacent arc discs are 4 units apart (HUD Open Questions); first fallback is a larger arc radius `R`. |
| Minimum width guard | Basic | Device support | Not Started | Under 360 dp targets fall below 48 dp, so it is unsupported. Runtime guard logs it; store device filter excludes it (Input Edge Cases; ADR-0003 Decision 5 `width_supported`, true at 360, false at 359). |
| Safe area and edge rejection | Basic | All presses | Not Started | Presses inside `edge_reject_margin` (36 units) of a side edge or inside safe-area insets never reach the resolver (Input Rule 12; ADR-0003 Decision 5). Burst button at least 24 dp from the side edge and 16 dp above the gesture inset (AB §7). Margin value is from memory of Android's back-swipe zone and must be checked on device (Input Tuning Knobs). |
| One-hand play | Basic (elevated) | Whole game | Not Started | Designed for one thumb; a feature needing two thumbs is cut (Concept Pillar 4). Left-handed mirror moves only the burst button and its digit; Start/Call stays put for both hands (HUD Edge Cases; Hero UI Requirements). Flag fixed per battle (Hero Rule 2). |
| Input remapping | Standard | N/A | N/A | Touch only, two gesture classes; nothing to rebind. |
| Hold-to-press alternatives | Standard | Hold inputs | N/A | No hold input exists. No long press; no tap duration limit (Input Rule 3). |
| Rapid input alternatives | Standard | Mashing | N/A | No rapid input. Burst is a 10 s cooldown (Hero Rule 10). |
| Drag-only actions | Basic | Pin, burst aim | Not Started | Pin and burst are drags by design, so a resting thumb never spends the burst (Concept Core Mechanic 2). Drag start needs only 15 units (10 dp) of travel (`drag_slop`). Cancel by dragging back onto the button, with hysteresis 64 out, 48 back (Hero Rule 13). A tap-based alternative is reserved for Settings at Alpha ("an alternative path to discs", HUD Dependencies). |
| Tremor and resting palm | Basic | All gestures | Not Started | One active pointer; a second finger is dropped; a resting palm with no real tap target is replaced by the next press (Input Rule 1). Slide-off-to-abort on taps (Input Rule 3). Sticky drag, so hesitation cannot cancel a pin (Input Game Feel). |
| Mis-spend guards | Basic | Build, upgrade | Not Started | Arc disc press ignored for 200 ms after opening (HUD Rule 6). Upgrade needs a second tap 200 to 1500 ms after the chip opens (Tower Rule 8). Buttons ignore presses for 300 ms after appearing (HUD Rule 11). |
| Input timing adjustments | Standard | Chip window | Out of scope at MVP | The 1.5 s chip window is the only timed input (Tower Rule 8). **Proposed for Alpha Settings:** chip window multiplier 1.0x to 3.0x (1.5 s to 4.5 s). Runtime slop setter and hit-area scale are reserved for Alpha (Input Deliberately not built). |
| Aim assist | Standard | Burst aim | Partial by design | Reticle is offset 100 units (about 67 dp) above the thumb so the thumb never hides it (Hero Rule 12); aim clamps to reach so a person is never refused (Hero Rule 12); kill preview shows victims before release (Hero Visual/Audio). No snap (Hero Deliberately not built). |
| HUD repositioning | Comprehensive | HUD | Out of scope | Layout is fixed by content rules; only handedness moves the button. |

---

## Cognitive Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Difficulty options | Standard | Gameplay | Out of scope at MVP | One stage, fixed values. Wave 1 cannot be lost (Concept Flow State Design); retry is instant (Flow Rule 16). |
| Pause anywhere | Basic | All gameplay states | Partial | No pause button at MVP (Flow Rule 17; HUD Rule 4). Focus loss or backgrounding enters Paused on every platform, and a tap resumes with no countdown (Flow Rule 17; HUD Rule 17). Build has no timer at all. This is a risk; see Known Intentional Limitations. |
| Tutorial persistence | Standard | Prompts | Partial | Three one-line prompts teach verbs, show until the act is done, never on a timer (HUD Rule 13). After a loss the next-try line repeats a missed verb (HUD Rule 16). No Help screen at MVP. |
| Objective clarity | Standard | Battle | Designed | The objective is always on the field: lives as dashes, wave pips, next-wave line (HUD Rules 4 and 5). |
| Visual indicators for audio-only information | Standard | All SFX | Met by default | No audio at MVP; every event is visual and reads with sound off (Hero Game Feel: "spokes count kills with sound off"; AB §2 Danger). |
| Reading time | Standard | Auto-dismissing text | Designed | Nothing actionable auto-dismisses. Result text appears 400 ms after Lost and 1000 ms after Won and stays until Retry (HUD Rule 15). The chip auto-closes after 1.5 s, but it holds no information that is lost: tap the tower again to reopen (Tower Rule 8). |
| Cognitive load | Comprehensive | Per system | Noted | See Per-Feature Accessibility Matrix. Peak load is in Wave: lanes, burst state, gold. Result shows raw counts only, no ranking or percentage (HUD Rule 15). |
| Plain wording | Basic (proposed) | All strings | Designed | Strings are fixed in HUD Rules 13, 15, 16. Next-try lines avoid "you" and past tense so they read as advice, not blame (HUD Game Feel). |

---

## Auditory Accessibility

There is no audio at MVP (HUD, Hero, Tower, Input: "Audio: none at MVP"). The
target player often plays with sound off (Concept Target Player Profile), so
every rule here is about keeping that true when audio arrives.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Subtitles for dialogue | Basic | Voiced content | N/A | No dialogue. |
| Captions for gameplay SFX | Comprehensive | SFX | N/A at MVP | Rule from now on: any SFX added later must have a visual that already carries the fact (table below). |
| Mono audio | Comprehensive | Output | Out of scope | No spatial audio planned. |
| Independent volume controls | Basic | Music, SFX, UI | Deferred | Required by Basic once audio exists. **Proposed:** Music and SFX sliders, 0 to 100%, in Settings & Accessibility (Alpha), shipped with the Audio system (systems-index #20). Until then the OS volume and mute switch apply. |
| Directional audio indicators | Comprehensive | Off-screen threats | N/A | Whole field is on screen; nothing is off-screen. |
| High-frequency cues | Standard | Audio cues | N/A at MVP | Revisit with the Audio GDD. |

### Gameplay-Critical SFX Audit

No SFX exist at MVP. These rows are the events most likely to get sound at
Small Ship (Concept Technical Considerations: "SFX per tower/hero action"),
with the visual each already has.

| Sound Effect | What It Communicates | Visual Backup | Caption Required | Status |
|-------------|---------------------|--------------|-----------------|--------|
| Enemy leaks (future) | Life lost | Magenta chevrons at the exit plus a dash fading to alpha 0.2 (AB §2, §7) | No | Not Started |
| Burst ready (future) | Burst can fire | Four Ready ticks around the hero plus a gold-filled button (Hero Visual/Audio; AB §7) | No | Not Started |
| Burst release (future) | Burst landed, kills | Gold ring meets preview; spokes per kill (Hero Visual/Audio) | No | Not Started |
| Wave start or call (future) | Next wave coming | Pips update; Start/Call hides (HUD Rule 10; Visual/Audio) | No | Not Started |
| Refused tap (future) | Cannot afford | Strike-through plus nudge, or the static cue under Reduce Motion (Tower UI Requirements) | No | Not Started |

---

## Platform Accessibility API Integration

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| iOS | UIAccessibility / VoiceOver | None at MVP | Not Started | The battle is custom-drawn discs, not Controls (HUD Rule 2; Input UI Requirements), so VoiceOver has nothing to read there. How Godot 4.7 behaves on iOS with VoiceOver on (touch routing) is **NOT SOURCEABLE**: `docs/engine-reference/godot/` does not cover it. |
| Android | AccessibilityService / TalkBack | None at MVP | Not Started | Same as iOS. TalkBack touch exploration behaviour under Godot is **NOT SOURCEABLE** from `docs/engine-reference/godot/`. |
| Modal screens (all) | Godot AccessKit on Controls | Accessible names for Retry, Play again, Paused (proposed, Vertical Slice) | Not Started | Engine reference says Control nodes work with AccessKit (`docs/engine-reference/godot/modules/ui.md`, `current-best-practices.md`). Whether that reaches VoiceOver or TalkBack in a mobile export is **NOT SOURCEABLE** there. The result and Paused screens are Controls (HUD Rule 2), so they are the only candidates. |
| OS Reduce Motion setting | iOS / Android system flag | Seed `reduce_motion` from the OS (proposed) | Not Started | Whether Godot 4.7 exposes the OS flag is **NOT SOURCEABLE** in `docs/engine-reference/godot/`. Until checked, the flag is data only (HUD UI Requirements). |
| Safe area | `DisplayServer.get_display_safe_area()` | Insets for HUD and press rejection | Designed | ADR-0003 Decision 5. Marked NEEDS VERIFICATION there (SP8). |
| PC (dev build only) | N/A | None | N/A | Desktop is the dev and test build with mouse-as-touch (Concept Core Identity). Not a release target. |

**Verdict effect.** Because three rows are NOT SOURCEABLE, this section is
**NOT ASSESSED** for screen reader and OS-flag support until an ADR checks live
4.7 docs and a phone run. That does not block the Basic tier, which needs
neither.

---

## Per-Feature Accessibility Matrix

One row per system in `design/gdd/systems-index.md`. Systems with no GDD yet
carry the concerns their dependencies already imply.

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| 1 Data & Config | None (no screen) | None | None | None | Yes | Holds `left_handed` and `reduce_motion` on the Input record (HUD UI Requirements). |
| 2 Input & Gesture Resolver | None | Drag precision; resting palm; second finger; edge zones | Few verbs; no long press or double tap | None | Partial | Rules 1 to 5, 12. Slop setter and hit-area scale reserved for Alpha. Pillar 4 phone test unpassed. |
| 3 Game State & Flow | Paused scrim | No pause button | Timer in Intermission; Build untimed | None | Partial | Flow Rule 17. See Known Intentional Limitations (pause). |
| 4 Combat & Damage | Hit flashes; burst dip | None | Damage by source shown raw | None | Partial | Flash checks in Visual table. |
| 5 Enemy & Wave | Type by size and notch at 16 px | None | Next-wave line, one wave ahead | None | Partial | Grey quarter-scale render test pending (HUD Manual). |
| 6 Tower System | Hexagon vs square at quarter scale; dimmed cost contrast | Chip second tap within 1.5 s | Cost chip, range ring | None | Partial | Refusal cue without motion open (Tower UX flag). |
| 7 Hero System | Reach dots contrast; reticle far from thumb when clamped | Pin and burst are drags; re-grab a hero pinned high up | Burst state, reach, cancel zone | None | Partial | Hero UX flag open points. |
| 8 Battle HUD | 14 dp text; dimmed alpha 0.55 | 48 dp targets; arc discs 4 units apart | Three prompts; result text | None | Partial | Dimmed alpha proposed 0.6. |
| 9 Stat & Modifier | None | None | None | None | Not Started | No UI. |
| 10 Skill Point Economy | Point counter | None | Spend decisions | None | Not Started | |
| 11 Skill Tree | Node states: filled, outlined, dotted (AB §3) | Node tap targets 48 dp | Tree reading load; free respec | None | Not Started | AB §2 has a slow pulse on available nodes; must honour Reduce Motion. |
| 12 Hero Weapons | Weapon by added element, not colour (AB §5) | None | None | None | Not Started | |
| 13 Stage Progression | Stars, preview thumbnails | None | Report screen | None | Not Started | Preview must hold the stage-by-shape rule (AB §6). |
| 14 Save/Load | None | None | None | None | Not Started | |
| 15 Menu & Screen Flow | Menu text | Menu targets | Navigation depth | None | Not Started | First place for the photosensitivity notice (proposed). |
| 16 Mobile Platform | Safe area, letterbox | Edge zones, gesture insets | None | None | Not Started | Owns large insets (HUD Layout). |
| 17 Onboarding Prompts | Prompt text | None | Teaching pace | None | Not Started | Replaces HUD Rule 13; must keep "hide on act, never on timer". |
| 18 Synergy Hook | Aura visibility | None | One more rule to track | None | Not Started | |
| 19 Visual Feedback & VFX | Flash and motion | None | None | None | Not Started | Inherits Reduce Motion and flash rules. |
| 20 Audio | None | None | None | Volume control; visual backup for every SFX | Not Started | See SFX audit. |
| 21 Settings & Accessibility | Settings text | Settings targets | Settings wording | None | Not Started | Home for flags, slop, hit scale, chip multiplier, volumes. |
| 22 Cross-Tree Synergies | Lattice reading | None | High load (full lattice) | None | Not Started | |

---

## Accessibility Test Plan

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---------|------------|------------|--------------|-------------|--------|
| Touch target size | Automated unit test | Every radius through `target_ok` at 360 dp | 36, 40, 48, 56 pass; 35 fails (HUD AC 28; Input AC 33) | gameplay-programmer | Not Started |
| 360 dp guard | Automated unit test | `width_supported` | True at 360, false at 359 (ADR-0003 Decision 5) | gameplay-programmer | Not Started |
| Text contrast | Manual: contrast checker on device screenshots | Every text and panel pair, dimmed costs, Arming text | Body text at least 4.5:1, large at least 3:1 (proposed) | ux-designer | Not Started |
| Non-text contrast | Manual: screenshots over the path | Leash, reach dots, range ring, reticle | At least 3:1 (proposed; leash 3:1 per AB §7) | ux-designer | Not Started |
| Colour-only audit | Manual: Coblis on screenshots, plus grey quarter-scale render | Every row of the audit table | Each state still named without colour (HUD Manual render tests) | ux-designer | Not Started |
| Reduce Motion | Automated per row, both ways (ADR-0011 Decision 8), plus screenshots | Every Reduce Motion row in HUD, Hero, Tower, AB §7 | No slide, dip, snap, nudge or pulse with the flag on; clocks and fades stay | gameplay-programmer, ux-designer | Not Started |
| Left-handed | Manual screenshots (HUD Manual "left hand") plus unit tests (HUD AC 15) | Button at x 84; Start/Call unchanged; pins refused on the left line only | Matches HUD Layout and Hero Rule 2 | qa-tester | Not Started |
| Photosensitivity | Manual: frame capture at worst case | Danger pulse, burst dip, 16 hit flashes | No more than 3 flashes per second at large area; pulse swing at most 25% (proposed, AB §7) | ux-designer | Not Started |
| One-thumb gestures | Pillar 4 phone test P1 (Input Acceptance Criteria) | 20 attempts each of six gestures, two testers, one left-handed if available | Misses at most 5%, mis-fires zero, per gesture | producer, qa-tester | Not Started |
| Sound-off play | Manual playthrough with audio muted | Full stage | Every event readable (Concept Target Player Profile) | qa-tester | Not Started |
| Screen reader (modal Controls) | Manual, VoiceOver and TalkBack | Retry, Play again, Paused | NOT ASSESSED until the engine behaviour is sourced | ux-designer | Not Started |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Screen reader for the battle | Comprehensive | Every battle action is a custom-drawn disc, not a Control (HUD Rule 2, Deliberately not built) | Blind players cannot play | None at MVP. Modal screens are Controls and may get names (Platform table). |
| Keyboard and gamepad paths | Standard (persona checklist) | Touch-only game; HUD says no keyboard, gamepad or screen-reader path at MVP (HUD Deliberately not built) | Players who cannot touch the screen | iOS Switch Control and Voice Control may emulate taps and drags; untested (Open Questions). |
| Manual pause button | Basic ("pause anywhere") | Not built at MVP (Flow Rule 17; HUD Rule 4) | A player who must stop mid-wave has to switch apps | Focus loss pauses, with tap to resume (Flow Rule 17). **Proposed:** a pause button by Vertical Slice, once Menu & Screen Flow exists. |
| Timing extension for the chip | Standard | No Settings screen until Alpha | Slow tappers may miss the 1.5 s window | A miss never spends gold; tap again to reopen (Tower Rule 8). Proposed Alpha multiplier 1.0x to 3.0x. |
| Adjustable text size | Standard | Three fixed sizes in the draw budget (ADR-0011 Decision 9) | Low-vision players | 14 dp floor; OS zoom. |
| Colourblind palette modes | Standard | Not needed if every colour has a backup (audit table) | Low, if the render tests pass | Audit table; Coblis test. |
| Brightness / gamma | Basic | Phones have system brightness; field contrast fixed by AB §6 | Players in bright light | Every entity at 5:1 or better (AB §6). |
| Volume controls | Basic | No audio at MVP | None until audio ships | Proposed sliders ship with the Audio system. |
| Haptics | Exemplary | Not built (Hero Deliberately not built) | Players who rely on touch feedback | All feedback is visual. |
| Tap alternative to drag | Comprehensive | Drag-only burst protects the cooldown from a resting thumb (Concept Core Mechanic 2) | Players who cannot drag | Reserved for Settings at Alpha (HUD Dependencies). |
| Settings screen for the two flags | Basic (to reach the features) | Settings is Alpha (systems-index #21) | Reduce Motion and left hand exist but players cannot turn them on at MVP | MVP is a desktop dev build; flags are data. Must ship before any public build. |

---

## Audit History

No audits yet. This draft is a desk review against the GDDs and ADRs, not an
audit.

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| (planned) first phone build | Internal, ux-designer + non-developer testers | Pillar 4 phone test | Six gestures, one-thumb play | Not run | Planned |
| (planned) Small Ship gate | Internal, accessibility-specialist | Tier review | Re-decide tier with Settings in scope | Not run | Planned |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 | https://www.w3.org/TR/WCAG21/ | Contrast (1.4.3, 1.4.11), flashes (2.3.1) |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Game checklist by cost |
| AbleGamers Player Panel | https://ablegamers.org/player-panel/ | User testing with disabled players |
| Apple Human Interface Guidelines: Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility | 44 pt targets, VoiceOver, Reduce Motion |
| Android accessibility | https://developer.android.com/guide/topics/ui/accessibility | 48 dp targets, TalkBack |
| Coblis colour blindness simulator | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Colour audit test |

Xbox, PlayStation and CVAA rows from the template are dropped: no console
release and no communication features.

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Is Basic the right tier? This draft took it in autonomous mode; the user picks. | user | Pre-Production gate | Unresolved |
| Which phone comes first? Resolved: the iPhone (ADR-0012 Decision 7, user instruction 2026-11-04); Android deferred. Targets are 44 pt and 48 dp either way. | user, producer | MVP+ | Resolved (ADR-0012, Proposed) |
| Does Godot 4.7 expose the OS Reduce Motion flag, and do AccessKit names reach VoiceOver and TalkBack in a mobile export? NOT SOURCEABLE in `docs/engine-reference/godot/`. | technical-director | Before the Settings GDD | Unresolved |
| Dimmed cost alpha: accept the proposed 0.6? | art-director, ux-designer | Before HUD stories | Unresolved |
| Adjacent arc discs are 4 units apart, under the proposed 8 dp gap. Larger `R` first (HUD Open Questions). | ux-designer | First phone build | Unresolved |
| Do iOS Switch Control or Voice Control drive pin and burst drags? | qa-tester | Vertical Slice | Unresolved |
| No `design/player-journey.md` exists. Author it from `.claude/docs/templates/player-journey.md`. | ux-designer | Before the first UX spec | Unresolved |
