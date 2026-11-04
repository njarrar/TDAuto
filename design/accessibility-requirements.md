# Accessibility Requirements

> **Status**: Committed (tier chosen in autonomous mode on 2026-11-04; the user may revise it, see AQ-01)
> **Author**: ux-designer (autonomous mode; user to review)
> **Last Updated**: 2026-11-04
> **Accessibility Tier Target**: Standard, phased (MVP ships the Basic subset the design already meets; the Standard items arrive with Settings & Accessibility at Alpha)
> **Platform(s)**: iOS, Android (touch only). A desktop build exists for development and testing only, with the mouse standing in for touch.
> **External Standards Targeted**:
> - WCAG 2.1 Level AA: Yes, for text contrast (1.4.3), non-text contrast (1.4.11) and the colour rule (1.4.1). Target-size and motion rules are met through the platform guidelines below.
> - AbleGamers CVAA Guidelines: N/A (no chat, voice or messaging)
> - Xbox Accessibility Guidelines (XAG): N/A (not a target platform)
> - PlayStation Accessibility (Sony Guidelines): N/A (not a target platform)
> - Apple / Google Accessibility Guidelines: Yes (44 pt / 48 dp targets, VoiceOver and TalkBack on `Control` screens)
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `design/ux/interaction-patterns.md`, `design/art/art-bible.md`
> **Template**: Accessibility Requirements

> **Why this document exists**: Per-screen accessibility notes belong in UX
> specs. This file holds the project-wide commitments, the feature matrix across
> all systems, the test plan and the audit history. If a feature conflicts with
> a commitment here, this document wins: change the feature, not the commitment,
> unless the producer approves a formal revision.
>
> **How it was written**: no UX spec exists yet, so every row is drawn from the
> GDDs and the art bible, and contrast figures were computed from the art bible's
> hex values (the art bible itself calls its own figures hand-calculated). Status
> `Designed` means the design already specifies it; `Not Started` means no
> implementation; nothing here has been tested on a device.
>
> **When to update**: after each `/gate-check` pass, after any audit, and
> whenever a system is added to `systems-index.md` (add a row to the matrix).

---

## Accessibility Tier Definition

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical player-facing text is readable at standard resolution. No feature requires colour discrimination alone. Volume controls exist for music, SFX and voice independently. The game is completable without photosensitivity risk. | Low: primarily design constraints |
| **Standard** | All of Basic, plus: full input remapping on all platforms, subtitle support with speaker identification, adjustable text size, at least one colourblind mode, and no timed input that cannot be extended or toggled. | Medium: dedicated implementation work |
| **Comprehensive** | All of Standard, plus: screen reader support for menus, mono audio option, difficulty assist modes, HUD element repositioning, reduced motion mode, and visual indicators for all gameplay-critical audio. | High: platform API integration and significant UI architecture |
| **Exemplary** | All of Comprehensive, plus: full subtitle customisation, high contrast mode, cognitive load assist tools, tactile or haptic alternatives for all audio-only cues, and an external third-party accessibility audit. | Very high: dedicated budget and specialist consultation |

### This Project's Commitment

**Target Tier**: Standard, phased.

**Rationale**: TowerRiot is a touch-only, one-thumb game (Pillar 4), so the barriers that dominate other genres do not apply: there is no speech, no subtitle need, no audio-only cue, no rebindable control scheme and no sustained button mashing. The barriers that do apply are small targets, colour, motion and one timed input (the 1.5 s upgrade chip). The art bible already makes colour a secondary cue everywhere and caps the flash and pulse rates, and the 48 dp minimum is a pillar, so most Basic rows are met by design and cost nothing. Comprehensive would need screen-reader support for a field drawn in a single `_draw` node, which does not fit a solo part-time project. Standard is the tier that matches the real risks and the real budget. Basic would leave the timed chip and the motion effects without a setting, and both are cheap to fix.

**Phasing**:
- **MVP and Vertical Slice**: the design-time commitments (text floor, contrast, colour independence, target size, photosensitivity caps, left-handed mirror, the `reduce_motion` data flag). No settings screen exists yet; the two data flags live on the Data `Input` record.
- **Alpha**, with Settings & Accessibility (system 21): Reduce Motion toggle, chip-window length, colourblind palette, text size, independent music and SFX volume.

**Features explicitly in scope (beyond the tier baseline)**:
- Left-handed mirror of the burst button (already designed; `left_handed` on the Input record). One-handed use is the whole control model, so this is a core feature, not an add-on.
- Photosensitivity caps in the art bible (danger pulse capped at a 25% alpha swing, no chained burst dip). Needed at Basic.
- A phone test that includes a left-handed tester and a tester who plays one-handed (the Input GDD's Pillar 4 gate already asks for one left-handed tester "if available"; this makes it required).

**Features explicitly out of scope** (each is also in Known Intentional Limitations):
- Screen-reader support for the battle field.
- A drag-free alternative for pin and aim.
- Mono audio, subtitles, closed captions and haptic alternatives (no speech and no audio-only cue exists).
- High contrast mode and HUD repositioning (Comprehensive).

---

## Visual Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Minimum text size, HUD and panels | Basic | All text | Designed (MVP) | 14 dp (21 units at 360 dp) is the floor for any body text; 16 dp for gold, lives, labels and costs; 24 dp burst digit (floor 18 dp). Art bible section 7 rejected a 12 dp draft. Font not yet chosen; it needs tabular numerals (PQ-07). |
| Text contrast, UI text | Basic | All text | Designed (MVP); verify on device | Neutral `#C8D0E0` on panel `#141B30` is 11.0:1 (on the 85% panel over the field, 11.2:1). Pass criterion 4.5:1. Text never sits on the raw field at small sizes. |
| Dimmed text contrast | Basic | Unaffordable costs | Not Started | Alpha 0.6 on panel gives 4.8:1 and passes; 0.5 gives 3.8:1 and 0.4 gives 2.8:1 and fail. **The dimmed alpha floor is 0.6.** The strike-through carries the meaning (pattern P-13). |
| Gameplay colour contrast on the field | Basic | Hero, towers, enemies, danger, status | Designed (MVP); verify on device | Against the field `#0B1020`: hero 15.8:1, tower 9.0:1, enemy 7.3:1, danger 5.5:1, status 5.8:1. Against panel `#141B30`: hero 14.2, tower 8.1, enemy 6.6, danger 4.9, status 5.3. All pass 4.5:1. Per-stage field hues (170 to 280, V at most 14%) can change these; the content test should recheck contrast per stage. |
| Non-text contrast, thin lines | Basic | Leash, reach ring, range ring | Designed; verify | Needs 3:1 (WCAG 1.4.11). Reach ring dots are neutral at alpha 0.6, which is 5.0:1 on the field. The leash is required to clear 3:1 where it crosses the lifted path (two tones, or alpha 0.7). 4.7 draws lines with no antialiasing feather, so lines are widened by about 1 px; recheck contrast after that change. |
| Colour never the sole indicator | Basic | All UI and gameplay | Designed (MVP) | See the audit below. Every colour-coded fact has a shape, pattern or text backup. |
| Colourblind palette option | Standard | Danger vs enemy, status vs enemy | Not Started (Alpha) | The design does not depend on colour, so this is a safety net. Scope is one alternate palette that moves the danger and enemy hues apart for protan and deutan players. Ships at Alpha; test with Coblis first and widen it only if the simulator or the phone test shows confusion. See AQ-04. |
| Text size option | Standard | Result, Paused, menus, HUD labels | Not Started (Alpha) | Required at Standard. The HUD is built to a fixed budget (three text sizes, a 48 dp top band, at most 3 text draws), so scaling the HUD may break layout. See AQ-03. Control screens (Result, Paused, menus) can scale freely. |
| Screen flash and strobe | Basic | Burst, hit flash, danger pulse | Designed; audit needed | Danger pulse is 2 Hz with at most a 25% alpha swing (or travelling chevrons). The 0.4 s burst field dip never chains: no re-dip within 1 s. Hit flash is an 80 ms white disc. **Open:** many simultaneous hits could add up to more than 3 flashes per second on screen (AQ-09). Run the Harding-style audit on the burst and a crowded wave. |
| First-launch photosensitivity notice | Basic | First launch | Not Started | A one-screen notice before the first battle. Owner: Menu & Screen Flow (Vertical Slice). |
| Reduce Motion | Standard | Nudges, slides, pulse, dip | Designed (flag); toggle Not Started (Alpha) | Cuts the 2 px nudges and the panel slides, freezes the 2 Hz pulse and skips the burst dip. Fades and clock bars stay. A `reduce_motion` bool on the Input record serves until Settings exists. Gap: a refusal cue that survives Reduce Motion (P-12), and static fallbacks for the arc collapse. |
| Subtitles | n/a | | n/a | No speech. |
| Brightness and gamma | n/a | | n/a | The OS owns display brightness on iOS and Android. |
| High contrast mode | Comprehensive | | Out of scope | The palette is already high contrast. See Known Intentional Limitations. |

### Color-as-Only-Indicator Audit

All rows come from art bible section 4 ("Colour-blind safety") or from the GDDs. Each has a non-colour backup.

| Location | Colour Signal | What It Communicates | Non-Colour Backup | Status |
|----------|--------------|---------------------|-------------------|--------|
| Danger vs enemy | Magenta `#FF2E93` vs orange `#FF7A2F` | A leak threat vs an enemy | Chevron shape plus a 2 Hz pulse (frozen under Reduce Motion, so the chevron shape alone must carry it) | Designed |
| Slowed enemy | Violet tint | Enemy is slowed | Drag lines plus a size wobble | Designed |
| Armoured vs damaged enemy | Both read darker | Armour vs damage | Outer ring vs inner core | Designed |
| Burst button Ready vs Cooling | Fill level | Can fire or not | Outline vs filled plus sweep wedge plus a digit | Designed |
| Tower Ready vs Cooling | Fill level | Can fire or not | Complete ring vs regrowing ring | Designed |
| Stage A vs stage B | Hue | Which stage | Path curve and grid tilt | Designed |
| Leash in-zone vs out-of-zone | Tint | Hero is inside or outside the leash | Dash density, up to solid | Designed |
| Tower role | Cyan for all three | Single, Splash or Slow | Triangle, hexagon, square, plus the word on the arc panel | Designed |
| Unaffordable cost | Dim | Cannot afford | Strike-through | Designed |
| Wave pips | Fill | Done, current, upcoming | Filled, outlined, dotted | Designed |
| Lives row | Fade to alpha 0.2 | Lives left | A lost dash fades to alpha 0.2 but stays countable (dash count) | Designed |
| Hero vs supporting shapes | White-gold | The hero | Asymmetric shape and the only glow | Designed |

---

## Motor Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Touch target size | Basic | Every tappable or draggable target | Designed (MVP); verify on device | 48 dp (72 units at 360 dp) with **no margin** at that width, and the unit-to-dp scale is not yet fixed (Tower UX flag). Hero grab is 56 units; burst hit 96 px. A device check at 360 dp is required before Pillar 4 is claimed. |
| One-handed play | Basic | Whole game | Designed (MVP) | The core model. One finger, one pointer; a second finger is ignored. No multi-touch gesture, no pinch, no two-finger action exists. |
| Left-handed mirror | Basic (elevated) | Burst button and digit | Designed (flag); toggle Not Started (Alpha) | `left_handed` on the Input record. Mirrors the button and digit only, never the leash kite or the aim offset. Phone test must include a left-handed tester. |
| Input remapping | n/a | | n/a | Touch has no bindings. |
| Hold-to-press alternatives | Standard | All hold inputs | Not applicable | No input is a timed hold. The two drags (pin, aim) are held only while moving; neither needs a duration. |
| Rapid input alternatives | Standard | | Not applicable | No input needs repeated presses. |
| Input timing adjustments | Standard | Upgrade chip window (1.5 s) | Not Started (Alpha) | The chip's 1.5 s commit window is the one timed input. Provide a window multiplier of 1x (1.5 s), 2x (3 s), 3x (4.5 s). The window is a safeguard, not a threat: an expired chip loses nothing. The tower range ring (1.5 s) is information and also follows the setting. The 300 ms arming delay (P-08) protects the player and needs no setting. |
| Edge and gesture conflicts | Basic | Screen edges | Designed; verify on device | Presses inside `edge_reject_margin` (0 to 48 units) and platform insets are rejected. Burst hit box ends at least 24 dp from the side (Android back-swipe, unverified) and 16 dp above the gesture inset. |
| Aim assist | n/a | | n/a | The burst is aimed on a preview with a generous cancel zone. No aim assist exists or is planned. |
| Platforming assists | n/a | | n/a | No platforming. |
| HUD repositioning | Comprehensive | | Out of scope | See Known Intentional Limitations. Handedness covers the one control that moves. |
| Drag-free alternative | Comprehensive | Pin and aim | Out of scope | Pillar 4 defines every action as one tap or one drag. See AQ-07. |

---

## Cognitive Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Pause anywhere | Basic | All gameplay states | **Gap** | Game State Rule 17 says **no pause button exists at MVP**; Paused comes only from focus loss or backgrounding. Build already stops the clock, but Wave and Intermission cannot be paused by choice. This conflicts with the Basic row. See AQ-02. |
| Difficulty options | Standard | Whole game | **Gap** | The GDDs define none. Waves are tuned assuming the hero's contribution, and bots calibrate the balance. See AQ-06. |
| Tutorial persistence | Standard | Three HUD prompts | Not Started | The prompts stay until the action is done (no auto-dismiss), so they cannot be lost by reflex. Once done, they cannot be read again. Add a Help entry when the Menu exists (PQ-06). |
| Reading time for UI | Standard | Auto-dismissing elements | Designed with one exception | Nothing auto-dismisses except the upgrade chip and the range ring, both 1.5 s. The chip shows an actionable cost; the Standard rule asks for at least 5 s on actionable text. The window multiplier (Motor, above) is the mitigation, and the chip loses nothing when it expires. Result text appears after a delay (400 ms Lost, 1,000 ms Won) and stays. |
| Objective clarity | Standard | Stage goal | Designed | Pips and a next-wave line are always visible in Build and Intermission. Lives are always visible. |
| Cognitive load | Comprehensive | Per system | Reviewed below | See the matrix. The HUD deliberately shows no damage numbers, HP bars, tower stats or spawn timings. The next-wave line is capped at 3 enemy types. |
| Visual indicators for audio-only information | Standard | All gameplay SFX | Designed | No gameplay information is audio-only (see the SFX audit). Rule for the Audio GDD: **a cue may not be the only carrier of any state**. |
| Navigation assists | n/a | | n/a | Single-screen battles. |

---

## Auditory Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Subtitles and captions for speech | n/a | | n/a | The game has no speech. |
| Independent volume controls | Basic | Music, SFX | Not Started (Alpha) | Two sliders (no voice bus). Persist with Save/Load. Expose in Settings and on the Paused screen. Audio is an Alpha system. |
| Mono audio | Comprehensive | | Out of scope | See Known Intentional Limitations. |
| Visual representation of directional audio | Comprehensive | | Not applicable | No audio carries direction; the field is fully visible. |
| Hearing aid compatibility | Standard | High-frequency cues | Not applicable now | Revisit when the Audio GDD exists. No cue may rely only on content above 4 kHz. |

### Gameplay-Critical SFX Audit

Audio is an Alpha system, so these are the cues that will exist and the visual that already carries each one.

| Sound Effect | What It Communicates | Visual Backup | Caption Required | Status |
|-------------|---------------------|--------------|-----------------|--------|
| Tower and hero attack | An attack landed | Tracer, hit flash, damage applied to the enemy | No | Designed |
| Burst telegraph and release | Burst is firing | Empty wedge on the button; burst ring and preview | No | Designed |
| Burst ready | The cooldown ended | Gold fill and complete ring on the button | No | Designed |
| Enemy leak | A life was lost | Dash fades on the lives row; danger chevrons in the field | No | Designed |
| Wave start and clear | Phase changed | Pips change; Start/Call appears | No | Designed |
| Stage Won and Lost | Outcome | Modal Result screen | No | Designed |

---

## Platform Accessibility API Integration

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| iOS | UIAccessibility / VoiceOver | Labels and order on `Control` screens (Result, Paused, Fatal, later menus) | Not Started | Through Godot's AccessKit support for `Control` nodes (4.5+). The engine reference says `Control` nodes integrate with AccessKit; **whether that works on iOS and Android in 4.7 is NEEDS VERIFICATION** (AQ-05). Field gameplay is not covered. |
| Android | AccessibilityService / TalkBack | Same as iOS | Not Started | Same note. 4.7 moved `Control.accessibility_live` to `AccessibilityServer.AccessibilityLiveMode`; use the new type. |
| iOS and Android | OS reduce-motion and font-scale settings | Read the OS setting as the default for Reduce Motion and text size | Not Started | Whether Godot exposes these is unverified (AQ-05). The in-game setting is the fallback. |
| Display | Safe area and gesture insets | See Motor, "Edge and gesture conflicts" | Not Started | `DisplayServer.get_display_safe_area()` is unverified; ADR-0003 verifies it. |
| Xbox, PlayStation, Steam (PC) | n/a | | n/a | Not target platforms. |

---

## Per-Feature Accessibility Matrix

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| 1 Data & Config | None (owns no screen); owns the `reduce_motion` and `left_handed` flags | None | None | None | Yes | The fatal screen belongs to Game State. |
| 2 Input & Gesture | None | Slops and edge rejection set the tap and drag feel; 48 dp targets with no margin | One pointer only | None | Partly | Slop values and edge margins need the phone test (PQ-01, PQ-02). |
| 3 Game State & Stage Flow | Result, Paused and Fatal screens: plain text, no auto-dismiss | Resume tap is an Armed Button (P-08) | **No user pause button** | None | **Gap** | AQ-02. |
| 4 Combat & Damage | Hit flash is an 80 ms white disc | None | Result shows damage by source as plain numbers, no percentage | None | Partly | Flash rate audit (AQ-09). |
| 5 Enemy & Wave | Enemy types by size, notch and ring, not colour; danger needs chevron shape | None | Next-wave line is capped at 3 types | None | Yes | Danger pulse freezes under Reduce Motion. |
| 6 Tower | Role by polygon, ready by ring shape | Chip is a 1.5 s timed commit | Mis-spend safeguard (chip, no selling) | None | Partly | Chip window setting (Alpha). Refusal cue without motion (P-12). |
| 7 Hero | Burst Ready vs Cooling by shape; leash by dash density | One-thumb pin and aim; cancel zone; left-handed mirror | Prompt "Drag the hero" persists | None | Partly | No drag-free alternative (limitation). |
| 8 Battle HUD | 14 dp text floor; fixed layout budget; contrast computed | 48 dp targets; Armed Buttons | Shows only lives, pips, gold, burst, next wave | None | Partly | Text size option conflicts with the fixed layout (AQ-03). |
| 9 to 22 (Vertical Slice and Alpha systems) | To be addressed in each system's GDD | | | | Pending | A row is added here when the system's GDD is written. Skill Tree: nodes must state owned, available and locked by fill, outline and dots (the art bible grammar), never colour alone. Audio: no audio-only cue. Settings: owns the Alpha toggles in this document. |

---

## Accessibility Test Plan

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---------|------------|------------|--------------|-------------|--------|
| Text and line contrast | Automated contrast check on screenshots at final colours | Every text and background pair; leash over the path; dimmed cost; per-stage field hues | Body text at least 4.5:1; thin lines at least 3:1; dimmed cost at alpha 0.6 or higher | ux-designer | Not Started |
| Colour independence | Manual, Coblis simulator (protanopia, deuteranopia, tritanopia) on battle screenshots | Danger vs enemy, slowed, armoured, ready vs cooling, stage identity | Every row of the audit is distinguishable without colour | ux-designer | Not Started |
| Touch target size | Manual on a 360 dp device and a wider one | Every target in P-01 | Each target measures at least 48 dp with the real unit-to-dp scale | qa-tester | Not Started |
| One-handed and left-handed play | Pillar 4 phone test (Input GDD gate P1) with at least two non-developer testers, one left-handed, one who plays with one hand | Slot tap, arc disc, tower tap, Start/Call, pin drag, burst drag, 20 attempts each | Misses at most 5% and mis-fires zero per gesture, for each tester group | producer | Not Started |
| Edge and gesture conflicts | Manual on Android with gesture navigation and on iOS | Burst button in each corner; presses near the edges | No press triggers the OS back or home gesture by accident | qa-tester | Not Started |
| Reduce Motion | Manual, flag on | Refused tap, arc open and close, panel slides, danger, burst dip | No nudge, slide, pulse or dip; every refusal still has a visible cue | ux-designer | Not Started |
| Photosensitivity | Manual plus a flash analysis tool on recorded video | A burst into a crowded wave; many simultaneous hit flashes; danger pulse | No more than 3 flashes per second over the luminance threshold | qa-tester | Not Started |
| Chip window setting | Manual (Alpha) | 1x, 2x, 3x | The window length matches; an expired chip loses nothing | qa-tester | Not Started |
| Screen reader on Control screens | Manual with TalkBack and VoiceOver | Result, Paused, Fatal, first menu | Each interactive element has a name and role; order is logical | ux-designer | Not Started |
| Text size | Manual (Alpha) | Smallest and largest setting on every Control screen and the HUD | No clipped or overlapping text | ux-designer | Not Started |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Screen-reader support for the battle field | Comprehensive | The field is drawn in a few `_draw` nodes and is real-time and spatial. A screen reader cannot describe it usefully. | Blind players cannot play the battle | Control screens (Result, Paused, menus) are labelled. State this in the store text. |
| Drag-free alternative for pin and aim | Comprehensive | Pillar 4 makes the drag the core verb. A tap-based alternative would change the design. | Players who cannot drag cannot pin or aim | Revisit only if the phone test shows drag failures. AQ-07. |
| Difficulty assist | Comprehensive | None designed; the balance is tuned to the hero and to bots | Some players cannot finish later stages | AQ-06 proposes a cheap data-driven option. |
| High contrast mode | Comprehensive | The palette is already high contrast | Low | Revisit after the contrast test. |
| HUD repositioning | Comprehensive | The HUD is a fixed budget; only the burst button moves, by handedness | Low | Handedness covers the one control most affected. |
| Mono audio, subtitles, captions, haptic alternatives | Comprehensive and Exemplary | No speech and no audio-only cue exists | None, while the "no audio-only cue" rule holds | Enforce that rule in the Audio GDD. |
| Pause button at MVP | Basic | Game State Rule 17 | Players cannot pause by choice | **Disputed.** AQ-02. |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| 2026-11-04 | ux-designer (document review, no device) | Desk review | GDDs and art bible | Contrast computed for all gameplay and UI colours; dimmed-text floor found (alpha 0.6); pause and difficulty gaps found; no device test | Open |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 | https://www.w3.org/TR/WCAG21/ | Contrast (1.4.3, 1.4.11), colour (1.4.1), flashing (2.3.1) |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Game-specific checklist by category and cost |
| AbleGamers Player Panel | https://ablegamers.org/player-panel/ | User testing with disabled players |
| Colour Blindness Simulator (Coblis) | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Colour independence test |
| Apple Human Interface Guidelines, Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility | 44 pt targets, VoiceOver |
| Android accessibility guidance | https://developer.android.com/guide/topics/ui/accessibility | 48 dp targets, TalkBack |
| Godot docs, accessibility | https://docs.godotengine.org/en/stable/ | AccessKit and `Control` accessibility on 4.7 (verify) |

---

## Open Questions

| ID | Question | Owner | Deadline | Resolution |
|----|----------|-------|----------|-----------|
| AQ-01 | Confirm or change the Standard (phased) tier. It was chosen in autonomous mode. | user | Before `/gate-check pre-production` | Open |
| AQ-02 | Game State Rule 17 has no pause button, but the Basic tier requires "pause anywhere". Add a user pause control (for example at Alpha with Settings), or record a formal exception with the producer. | game-designer, producer | Before the Game State GDD is Approved | Open, **High** |
| AQ-03 | Standard requires adjustable text size, but the HUD is built to three text sizes, a 48 dp band and at most 3 text draws. Decide how the HUD scales, or limit the option to the Control screens. | ux-designer, art-director | HUD UX spec | Open |
| AQ-04 | Is a colourblind palette needed, given colour independence by design? Run Coblis on the first battle screenshots before building it. | ux-designer | Vertical Slice | Open |
| AQ-05 | Verify on 4.7: AccessKit on iOS and Android `Control` nodes; whether Godot exposes the OS reduce-motion and font-scale settings; `DisplayServer.get_display_safe_area()` units. | godot-specialist, ADR-0003 | Before the Settings GDD | Open |
| AQ-06 | Difficulty assist. Gameplay values are data-driven, so an option such as extra starting lives is cheap, but the waves are tuned assuming the hero. Does the game want one? | game-designer | Alpha | Open |
| AQ-07 | If the phone test shows drag failures, what is the alternative to pin and aim? | game-designer, ux-designer | After the Pillar 4 test | Open |
| AQ-08 | Who owns the first-launch photosensitivity notice (Menu & Screen Flow, Vertical Slice)? | ux-designer | Menu GDD | Open |
| AQ-09 | Aggregate hit-flash rate: many 80 ms flashes in one second could pass 3 per second on screen. Define a cap or a merge rule. | technical-artist, qa-tester | Vertical Slice | Open |
| AQ-10 | Refusal cue that survives Reduce Motion (pattern P-12). | ux-designer | Arc and chip spec | Open |
