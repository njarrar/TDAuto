# Accessibility Requirements

> **Status**: In Design (tier committed in autonomous mode; awaiting user confirmation)
> **Author**: njarrar + ux-designer
> **Last Updated**: 2026-11-04
> **Accessibility Tier Target**: Standard (adapted for a touch-only, one-thumb, no-audio game; phased: Basic items at MVP, Standard items at Alpha)
> **Platform(s)**: iOS, Android (portrait). Desktop build for development only.
> **External Standards Targeted**:
> - WCAG 2.1 Level AA (contrast, text resize intent, target size as a reference)
> - AbleGamers CVAA Guidelines: N/A (no voice chat or messaging)
> - Xbox Accessibility Guidelines (XAG): No (not a target platform)
> - PlayStation Accessibility (Sony Guidelines): No (not a target platform)
> - Apple / Google Accessibility Guidelines: Partial (44 pt / 48 dp touch targets, safe areas; VoiceOver and TalkBack see Platform API)
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `design/ux/interaction-patterns.md`
> **Template**: Accessibility Requirements

> **Why this document exists**: per-screen notes belong in UX specs. This file holds the project-wide commitment, the feature matrix, the test plan and the audit history. If a feature conflicts with a commitment here, this file wins unless the producer approves a revision.
>
> **Source rule**: every requirement cites a GDD rule. Where the GDDs leave a gap, it is listed in Open Questions as an open item, not decided here. Godot claims cite `docs/engine-reference/godot/` or are marked NOT SOURCEABLE.

---

## Accessibility Tier Definition

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|---|---|---|
| **Basic** | Critical text readable; no colour-only meaning; independent volume controls; no photosensitivity risk | Low |
| **Standard** | Basic, plus input remapping, subtitles with speaker names, adjustable text size, a colourblind mode, and no timed input that cannot be extended | Medium |
| **Comprehensive** | Standard, plus menu screen reader, mono audio, assist modes, HUD repositioning, reduced motion, visual cues for all critical audio | High |
| **Exemplary** | Comprehensive, plus full subtitle styling, high contrast, cognitive assists, haptic alternatives, external audit | Very high |

### This Project's Commitment

**Target Tier**: **Standard**, adapted to this game, phased in two steps.

**Rationale**: TowerRiot is a one-thumb portrait tower defense played on phones, often one-handed and with sound off (concept, Target Player Profile). Its main barriers are motor (every action is a precise tap or drag at the 48 dp floor, and two verbs are drag-only) and visual (14 dp text, colour as state on a dark field, small primitives). It has no dialogue and no audio at MVP, so the auditory and subtitle rows of the template barely apply. Standard is the lowest tier that answers the motor barrier, because it requires an alternative to fixed timed input and to the default input; Basic would leave the 1.5 s upgrade window and the drag-only verbs with no answer. Comprehensive needs a screen reader path for an all-disc battle that the engine reference does not show is possible (see Platform API), so it is out of reach for a solo team at MVP. The GDDs already reserve the hooks Standard needs (steady-hand slop, hit-area scale, two-tap alternative, left hand, Reduce Motion) for Settings & Accessibility at Alpha.

**Phasing**:
- **MVP (now)**: all Basic items, plus the rules the GDDs already fix: no tap timeout, slide-off abort, 48 dp targets, shape-first colour, Reduce Motion and left-hand as data flags.
- **Alpha (Settings & Accessibility GDD)**: the Standard items, adapted below. Standard is not met until Alpha ships.

**Adaptations of Standard to this game** (the template assumes controllers and dialogue):
- "Full input remapping" becomes **gesture alternatives**: runtime slop setter, hit-area scale, two-tap alternative to drag, left-hand mirror (Input Open Questions; Battle HUD Dependencies).
- "Subtitles" becomes N/A at MVP: no voiced content exists.
- "A colourblind mode" may be met by a verified shape-first design with no colour-only signal; whether a separate palette mode is still needed is an open item (OQ-6).

**Features explicitly in scope (beyond tier baseline)**:
- Reduce Motion (a Comprehensive item): already designed in the Battle HUD and Hero GDDs, so it is cheap to keep.
- Left-handed mirror of the burst button: Pillar 4 needs it for a one-thumb game.

**Features explicitly out of scope**:
- Screen reader for the battle field (Known Intentional Limitations).
- Haptics (Hero GDD, not built for MVP).
- HUD repositioning (layout is fixed by content tests).

---

## Visual Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---|---|---|---|---|
| Minimum text size, all battle text | Basic | Top band, prompts, costs, chip, Start/Call, result, Paused | Designed (GDD) | 14 dp floor, 21 units at 360 dp (Battle HUD UI Req). Gold and result text 16 dp. Font not yet chosen; must have tabular figures |
| Adjustable text size | Standard | All text | Not Started (gap) | No GDD defines it. Layout has no spare room at 14 dp (arc panels, prompt panel). Open item OQ-3 |
| Touch target size | Basic | Every disc | Designed (GDD) | 48 dp minimum at 360 dp; hero 74.7 dp, burst and Start/Call 64 dp (Input `target_ok`; Pillar 4) |
| Text contrast | Standard | All text on panel | Not Started | Target 4.5:1 body, 3:1 for 18 px+. Art bible §4 ratios are hand-calculated against #0B1020 and unverified on device |
| Colour-as-only-indicator audit | Basic | All UI and field | In progress (see table) | Art bible rule: "shape is role, colour is state" |
| Colourblind support | Standard | Colour-coded gameplay | Not Started | Shape and fill backups exist for every row below. Need simulator check (protan, deutan, tritan). Separate mode: OQ-6 |
| UI scaling | Standard | HUD | Not Started (gap) | Field scales with device width only (Input `field_scale`). No player setting in any GDD. OQ-3 |
| Screen flash / strobe | Basic | Burst, build, danger | Designed, unverified | Build flash is one 120 ms white overlay. Burst dips the field 3%. Danger uses a 2 Hz pulse (art bible §4), under 3 flashes per second. No full-screen flash exists. Needs a render check against the 3 per second limit |
| Reduce Motion | Comprehensive (in scope) | Slides, nudges, burst wind-up, Ready pop | Designed (GDD), no UI | Data flag until Settings (Battle HUD UI Req; Hero V/A). Fades and clock bars stay |
| Subtitles | Basic | Voiced content | N/A | No voiced content in any GDD |

### Color-as-Only-Indicator Audit

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|---|---|---|---|---|
| Towers vs enemies vs hero | Cyan / orange-red / white-gold | Role (yours, threat, hero) | Shape: polygons, small circles, irregular kite (art bible) | Designed |
| Danger magenta vs enemy orange | Hue | Danger | Chevron shape plus 2 Hz pulse (art bible §4) | Designed |
| Unaffordable disc or chip | Dimmed | Cannot buy | Cost struck through (Battle HUD Rule 7) | Designed |
| Burst button state | Fill | Locked, cooling, ready | Dots, wedge with digit, full ring (Battle HUD Rule 12) | Designed |
| Wave pips | Fill | Done, current, upcoming | Filled, outlined, dotted (Battle HUD V/A) | Designed |
| Lost lives | Alpha 0.2 | Life lost | Dashes stay countable; count of full dashes | Designed |
| Aim cancelling vs live | Reticle alpha 0.3 | Will cancel | Ring at 64 vs 48, preview and kill marks hidden (Hero Rule 13) | Designed |
| Kill preview | White contour | Will die | Body knocked out to field colour (Hero V/A) | Designed; readability at 22 px open (Hero OQ) |
| Tower level | Inset outline | Level 2 | Shape accretion, no colour (Tower V/A) | Designed |
| Slow victim | Violet | Slowed | No shape backup found in the GDDs read | Open (OQ-7) |

---

## Motor Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---|---|---|---|---|
| One-hand play | Basic (core design) | Whole game | Designed (GDD) | Pillar 4: every action one tap or one drag, one thumb. A feature needing two thumbs is cut |
| No tap time limit, no long press | Basic | Every tap | Designed (GDD) | A press held 10 s and released in place is a tap (Input Rule 3, "the accessibility floor") |
| Slide-off abort | Basic | Every tap | Designed (GDD) | Rolling off a disc before release does nothing (Input Rule 3) |
| Palm and second-finger rejection | Basic | Every gesture | Designed (GDD) | One active pointer; a resting palm cannot block the thumb (Input Rule 1) |
| Edge rejection | Basic | Screen edges, OS insets | Designed, unverified | 36 units (24 dp at 360 dp); value from memory, check on device (Input) |
| Left-handed mirror | Standard | Burst button and digit | Data flag, no UI | Battle HUD Rule 12; Hero UI Req. Settings at Alpha |
| Gesture alternatives (replaces "input remapping") | Standard | Pin, aim | Reserved, not designed | Steady-hand slop (x1.5), hit-area scale, two-tap alternative to drag (Input Open Questions). Alpha |
| Hold-to-press alternatives | Standard | Hold inputs | N/A | No hold input exists |
| Rapid input alternatives | Standard | Mashing | N/A | No rapid input exists |
| Input timing adjustments | Standard | Upgrade chip window | Not Started (gap) | The chip commits only between 200 and 1,500 ms (Tower Rule 8). No extension exists. Both durations are presentation constants, so a multiplier is possible, but no GDD defines one. OQ-1 |
| Minimum-delay guards | n/a | Arming 300 ms, arc guard 200 ms, chip guard 200 ms | Designed | These delay acceptance; they never expire, so they are not deadlines. A slow tapper is not penalised |
| Aim assist | Standard | Burst aim | Not designed | "Aim snap" is not built for MVP (Hero). A soft aim magnet is a fallback in Hero OQ, gated on the phone test |
| Movement assists | Standard | Hero | Designed | Hero walks to the pin by itself; no held movement |
| HUD repositioning | Comprehensive | HUD | Out of scope | Fixed layout held by content tests |

---

## Cognitive Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---|---|---|---|---|
| Difficulty options | Standard | Gameplay | Not Started (gap) | No GDD read defines one. OQ-5 |
| Pause anywhere | Basic | All play | Gap | No pause button at MVP; Paused only on app focus loss (Battle HUD Rule 4, Flow Rule 17). Build phase waits for the player; Wave and Intermission do not. OQ-2 |
| Tutorial persistence | Standard | Prompts | Gap | Prompts hide on the act and retire per session; no way to see them again (Battle HUD Rule 13). Onboarding Prompts at Vertical Slice. OQ-4 |
| Objective clarity | Standard | Battle | Designed | One goal: hold the lane. Next-wave line shows types and counts. Next-try line after a loss names one verb, without blame (Battle HUD Rules 5, 16) |
| Visual indicators for audio | Standard | All SFX | Met by design | No audio at MVP |
| Reading time | Standard | Auto-dismissing text | Designed | Prompts never hide on a timer; result text stays until Retry. The only timed UI is the chip (1.5 s) and the level-2 range ring (1.5 s), which carries no text |
| Low on-screen load | Standard | HUD | Designed | Only what a decision needs: no damage numbers, HP bars or stats (Battle HUD Rule 4) |
| Silent misses | n/a | Every disc | Designed, watch | A miss gives no cue except the first three ground taps (Input Game Feel). A player who does not know why nothing happened gets no hint. Watch in the first-run test |
| Cognitive load per system | Comprehensive | Per system | See matrix | |

---

## Auditory Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---|---|---|---|---|
| Subtitles for dialogue | Basic | Voiced content | N/A | None exists |
| Captions for critical SFX | Comprehensive | SFX | N/A at MVP | No audio. From Small Ship, every sound that changes what to do needs a visual already in the GDDs |
| Independent volume controls | Basic | Music / SFX / UI | Deferred | No audio at MVP. Required the day the first sound ships |
| Mono audio | Comprehensive | Audio out | Out of scope | |

### Gameplay-Critical SFX Audit

| Sound Effect | What It Communicates | Visual Backup | Caption Required | Status |
|---|---|---|---|---|
| None at MVP | | Every state has a visual (Hero Game Feel: "spokes count kills with sound off") | No | Re-audit when audio is added (Small Ship) |

---

## Platform Accessibility API Integration

| Platform | API / Standard | Features Planned | Status | Notes |
|---|---|---|---|---|
| iOS | VoiceOver via AccessKit | Result and Paused modals only, if supported | Not Started | Godot 4.5 added screen reader support for Control nodes through AccessKit (`docs/engine-reference/godot/modules/ui.md`). Whether this reaches VoiceOver on iOS exports: NOT SOURCEABLE, not covered by `docs/engine-reference/godot/` |
| Android | TalkBack via AccessKit | Same | Not Started | Same: NOT SOURCEABLE for Android exports |
| Battle field (all platforms) | none | none | Out of scope | Every game action is an Input disc drawn by `_draw`, not a Control (Battle HUD Rule 2), so AccessKit, which covers Controls, has nothing to expose |
| Live announcements | `Control.accessibility_live` | Possible for result text | Not Started | The property exists and is typed `AccessibilityServer.AccessibilityLiveMode` in 4.7 (`modules/ui.md`). Its behaviour on mobile: NOT SOURCEABLE |
| Focus | 4.6 dual focus | n/a | Note | Touch focus is separate from keyboard focus since 4.6 (`modules/ui.md`, `modules/input.md`). Modals set `focus_mode` NONE (architecture, Engine Knowledge Gap Summary), which may conflict with screen reader navigation. OQ-8 |
| OS text size / bold text | iOS Dynamic Type, Android font scale | none | Not Started | Whether Godot reads these: NOT SOURCEABLE |

**Effect on the verdict**: because the engine reference does not cover mobile screen reader or OS text-size support, the screen reader and OS text-size rows are **NOT ASSESSED**, not "planned and fine". They stay that way until the Input or UI ADR cites live 4.7 docs or a device run.

---

## Per-Feature Accessibility Matrix

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|---|---|---|---|---|---|---|
| Input & Gesture Resolver | None (draws nothing) | Drag-only verbs; slops untested on phones; edge margin from memory | Silent misses | None | Partial | Steady-hand slop, hit-area scale, two-tap reserved for Alpha |
| Battle HUD & Build UI | 14 dp floor, no resize; contrast unverified; font unchosen | 4-unit gap between arc discs; 7.2-unit gap at left-hand burst; Retry armed 300 ms | Prompts not recallable; top-band prompt may be missed | None | Partial | OQ-3, OQ-4 |
| Tower System | Hexagon vs square at quarter scale weakest pair; range ring contrast over path | 1.5 s upgrade window, not extendable | Cost of each choice visible; no selling, so a wrong buy is permanent | None | Partial | OQ-1 |
| Hero System | Reticle far from thumb when clamped; reach dots at alpha 0.6; kill mark at 22 px | Pin and aim are drags; re-grab near top with one thumb; aim stops at y 860 | Aim has two states (cancel, live) shown by ring | None | Partial | Two-tap alternative at Alpha |
| Game State & Stage Flow | n/a | No pause button | Phases change without the player | None | Gap | OQ-2 |
| Enemy & Wave | Enemy types by size and notch, 16 to 30 px | None | Convergences must be seen on field | None | Not reviewed | GDD not read in this pass |
| Combat & Damage | Slow victim violet | None | None | None | Not reviewed | OQ-7 |
| Data & Config Pipeline | n/a | n/a | n/a | n/a | n/a | Holds the Input record (slops, margin) |

---

## Accessibility Test Plan

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---|---|---|---|---|---|
| Touch targets | Automated content test | Every disc at 360 dp | `2 x r x width_dp >= 25920` for every target (Input `target_ok`) | gameplay-programmer | Not Started |
| Pillar 4 gesture test | Manual, non-developer tester on a phone | 20 each of slot tap, arc disc tap, tower tap, Start/Call tap, pin drag, burst drag, then 5 min unprompted | Misses at most 5% per gesture; zero mis-fires, including accidental upgrades (concept Pillar 4) | producer, qa-lead | Not Started |
| Upgrade safety | Manual on phone | 3 testers, 20 builds and 20 upgrades each | No unintended upgrade, no wrong disc (Tower Acceptance Criteria) | qa-lead | Not Started |
| No tap timeout | Unit test | Press held 10 s, release in place | Emits `tap` | gameplay-programmer | Not Started |
| Text size | Screenshot at 360 dp | Every HUD and modal string | No text under 14 dp | ux-designer | Not Started |
| Contrast | Contrast tool on device screenshots | All text on panel; reach dots; range ring over path | 4.5:1 body text, 3:1 large text and key graphics | ux-designer | Not Started |
| Colour-only audit | Simulator on screenshots (protan, deutan, tritan, greyscale) | Battle in Build, Wave, burst, Lost, Won | Every row in the audit table readable; towers and hero found in greyscale at quarter scale | ux-designer | Not Started |
| Flash | Frame review of burst, build, danger | All three | No more than 3 flashes per second | ux-designer | Not Started |
| Reduce Motion | Manual with flag on | Nudges, arc, burst, Ready pop | All listed motions cut; fades and clock bars remain | qa-tester | Not Started |
| Left hand | Manual with flag on | Burst aim, Start/Call near left button | Same miss and mis-fire bars as right hand | qa-tester | Not Started |
| One-thumb reach | Phone test | Re-grab hero pinned near top; aim to path bottom | Recorded, not gated (Hero OQ) | producer | Not Started |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---|---|---|---|---|
| Screen reader for the battle | Comprehensive | Every action is a disc, not a Control (Battle HUD Rule 2; "any keyboard, gamepad or screen-reader path" not built) | Blind players cannot play | None planned for battle; modals may be exposed later |
| Keyboard and gamepad play | Standard (switch access) | Touch-only platform; not built for MVP | Switch and external-keyboard users excluded | Two-tap alternative at Alpha may let switch tools reach discs; not designed |
| Haptics | Exemplary | Not built for MVP (Hero) | Small; no audio cue relies on it | Revisit at Small Ship |
| HUD repositioning | Comprehensive | Layout fixed by content tests | Low on phones | None |
| Accessibility settings UI at MVP | Standard | Settings & Accessibility is an Alpha system | MVP testers cannot change left hand or Reduce Motion | Data flags exist |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|---|---|---|---|---|---|
| 2026-11-04 | Internal, ux-designer | Design review from GDDs | Input, Battle HUD, Tower, Hero GDDs; architecture engine gap summary | Tier committed (Standard, phased). 9 open items, mainly the fixed chip window, no pause, drag-only verbs, no text resize, and unsourced mobile screen reader support | Open |

---

## External Resources

| Resource | URL | Relevance |
|---|---|---|
| WCAG 2.1 | https://www.w3.org/TR/WCAG21/ | Contrast and target size reference |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Game checklist by cost |
| AbleGamers Player Panel | https://ablegamers.org/player-panel/ | User testing with disabled players |
| Apple Human Interface Guidelines, Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility | iOS target size and VoiceOver |
| Android accessibility | https://developer.android.com/guide/topics/ui/accessibility | Android target size and TalkBack |
| Coblis | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Colourblind simulation |

---

## Open Questions

Open items are GDD gaps. None is decided here.

| ID | Question | Owner | Deadline | Resolution |
|---|---|---|---|---|
| OQ-1 | The upgrade chip commits only inside 200 to 1,500 ms and cannot be extended. Standard requires timed input to be extendable. Add a window multiplier, or a non-timed upgrade path? | Settings & Accessibility GDD; Tower GDD | Alpha | Unresolved |
| OQ-2 | No pause button; Paused only on app focus loss. Basic requires pause anywhere. Does Flow add one, and where can a one-thumb target go? | Flow GDD; Menu & Screen Flow | Before Vertical Slice | Unresolved |
| OQ-3 | No text size or UI scale setting, and the 14 dp layout has no spare room. Which elements can grow, and what gives? | Settings & Accessibility GDD; art-director | Alpha | Unresolved |
| OQ-4 | Retired prompts cannot be recalled. Where does a player see "how to" again? | Onboarding Prompts GDD | Vertical Slice | Unresolved |
| OQ-5 | No difficulty or assist option is defined. Is one needed for Standard, given a never-pinned hero equals towers-only? | game-designer | Alpha | Unresolved |
| OQ-6 | Is a verified shape-first design enough for "a colourblind mode", or is a palette mode still needed? | ux-designer, art-director | After the simulator test | Unresolved |
| OQ-7 | Slow victims show violet with no shape backup found in the GDDs read. Is there one in Combat or the art bible? | art-director | First render | Unresolved |
| OQ-8 | Does AccessKit reach VoiceOver and TalkBack on mobile exports, and does `focus_mode` NONE on the modals block it? NOT SOURCEABLE in `docs/engine-reference/godot/` | technical-director (UI ADR) | Before first modal story | Unresolved |
| OQ-9 | Two-tap alternative to drag for pin and aim: reserved in prose only. What is the interaction, and how does it keep zero mis-fires? | Settings & Accessibility GDD | Alpha | Unresolved |

### Decisions taken in autonomous mode

No questions were asked (`modes.automation: autonomous`). These choices could not be written to `production/session-logs/decision-log.md` in this run (no shell access for `log_decision`), so they are recorded here.

| Decision point | Chosen | Reason |
|---|---|---|
| Tier | Standard, adapted and phased (Basic at MVP, Standard at Alpha) | Lowest tier that answers the motor barrier; GDDs already reserve its hooks. The user should confirm: the tier is the gated part |
| "Input remapping" on a touch-only game | Replaced by gesture alternatives already reserved in the Input GDD | Keeps to existing design |
| Colourblind mode | Left open (OQ-6) instead of decided | GDD gap rule |
