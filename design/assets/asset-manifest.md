# Asset Manifest

> Last updated: 2026-11-05

## Progress Summary

| Total | Needed | In Progress | Done | Approved |
|-------|--------|-------------|------|----------|
| 43 | 43 | 0 | 0 | 0 |

## Assets by Context

### System: hero-system
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-001 | Hero (`char_hero`) | Sprite / 2D (code) | Needed | design/assets/specs/hero-system-assets.md |
| ASSET-002 | Hero halo | Sprite / 2D (code) | Needed | design/assets/specs/hero-system-assets.md |
| ASSET-021 | Burst wind-up, ring and release | VFX (code) | Needed | design/assets/specs/hero-system-assets.md |
| ASSET-024 | Leash (`zone_leash`) | VFX / Zone (code) | Needed | design/assets/specs/hero-system-assets.md |
| ASSET-025 | Kite ghost and pin ring | VFX / Zone (code) | Needed | design/assets/specs/hero-system-assets.md |
| ASSET-026 | Reticle and radius preview (`zone_reticle`, `zone_preview`) | VFX / Zone (code) | Needed | design/assets/specs/hero-system-assets.md |
| ASSET-027 | Reach ring (`zone_reach`) | VFX / Zone (code) | Needed | design/assets/specs/hero-system-assets.md |
| ASSET-028 | Kill preview mark | VFX / Zone (code) | Needed | design/assets/specs/hero-system-assets.md |
| ASSET-029 | Hero Ready ticks and grab ring | VFX / Zone (code) | Needed | design/assets/specs/hero-system-assets.md |

### System: enemy-wave
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-003 | Enemy `normal` (`enemy_normal`) | Sprite / 2D (code) | Needed | design/assets/specs/enemy-wave-assets.md |
| ASSET-004 | Enemy `fast` (`enemy_fast`) | Sprite / 2D (code) | Needed | design/assets/specs/enemy-wave-assets.md |
| ASSET-005 | Enemy `heavy` (`enemy_heavy`) | Sprite / 2D (code) | Needed | design/assets/specs/enemy-wave-assets.md |
| ASSET-010 | Field background (`field_stage01`) | Environment (code) | Needed | design/assets/specs/enemy-wave-assets.md |
| ASSET-011 | Path (`path_stage01`) | Environment (code) | Needed | design/assets/specs/enemy-wave-assets.md |
| ASSET-012 | Build slot (`slot_build`) | Environment (code) | Needed | design/assets/specs/enemy-wave-assets.md |
| ASSET-013 | Exit strip chevrons | Environment (code) | Needed | design/assets/specs/enemy-wave-assets.md |

### System: tower-system
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-006 | Tower `single_target` (`tower_tri`, `tower_tri_l2`) | Sprite / 2D (code) | Needed | design/assets/specs/tower-system-assets.md |
| ASSET-007 | Tower `splash` (`tower_hex`, `tower_hex_l2`) | Sprite / 2D (code) | Needed | design/assets/specs/tower-system-assets.md |
| ASSET-008 | Tower `slow` (`tower_sq`, `tower_sq_l2`) | Sprite / 2D (code) | Needed | design/assets/specs/tower-system-assets.md |
| ASSET-009 | Tower ready and cooling ring | Sprite / 2D (code) | Needed | design/assets/specs/tower-system-assets.md |
| ASSET-022 | Build and upgrade overlay | VFX (code) | Needed | design/assets/specs/tower-system-assets.md |
| ASSET-023 | Range ring | VFX / Zone (code) | Needed | design/assets/specs/tower-system-assets.md |

### System: combat-damage
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-014 | Hit flash | VFX (code) | Needed | design/assets/specs/combat-damage-assets.md |
| ASSET-015 | Tower tracer | VFX (code) | Needed | design/assets/specs/combat-damage-assets.md |
| ASSET-016 | Hero shot line | VFX (code) | Needed | design/assets/specs/combat-damage-assets.md |
| ASSET-017 | Splash ring | VFX (code) | Needed | design/assets/specs/combat-damage-assets.md |
| ASSET-018 | Slow drag lines | VFX (code) | Needed | design/assets/specs/combat-damage-assets.md |
| ASSET-019 | Damaged core | VFX (code) | Needed | design/assets/specs/combat-damage-assets.md |
| ASSET-020 | Death disc | VFX (code) | Needed | design/assets/specs/combat-damage-assets.md |

### System: battle-hud
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-030 | Ground tap ring | VFX / Zone (code) | Needed | design/assets/specs/battle-hud-assets.md |
| ASSET-031 | Lives dashes | UI (code) | Needed | design/assets/specs/battle-hud-assets.md |
| ASSET-032 | Wave pips | UI (code) | Needed | design/assets/specs/battle-hud-assets.md |
| ASSET-033 | Gold | UI (code) | Needed | design/assets/specs/battle-hud-assets.md |
| ASSET-034 | Next-wave line | UI (code) | Needed | design/assets/specs/battle-hud-assets.md |
| ASSET-035 | Start/Call button | UI (code) | Needed | design/assets/specs/battle-hud-assets.md |
| ASSET-036 | Burst button (`ui_btn_burst_ready`) | UI (code) | Needed | design/assets/specs/battle-hud-assets.md |
| ASSET-037 | Build arc | UI (code) | Needed | design/assets/specs/battle-hud-assets.md |
| ASSET-038 | Upgrade chip | UI (code) | Needed | design/assets/specs/battle-hud-assets.md |
| ASSET-039 | Unaffordable and refusal cue | UI (code) | Needed | design/assets/specs/battle-hud-assets.md |
| ASSET-040 | Prompt line | UI (code) | Needed | design/assets/specs/battle-hud-assets.md |
| ASSET-041 | Max label | UI (code) | Needed | design/assets/specs/battle-hud-assets.md |
| ASSET-042 | UI font | UI (code) | Needed | design/assets/specs/battle-hud-assets.md |

### System: game-state-stage-flow
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-043 | Fatal screen | UI (code) | Needed | design/assets/specs/game-state-stage-flow-assets.md |
## Rulings (2026-11-05, autonomous mode, logged in production/session-logs/decision-log.md)

- **Line width under 4.7.** Godot 4.7 draws lines with no AA feather. Lines under 2 px (slot outline, field grid) go up to 2 px; every GDD width of 2 px and up stays as written. Confirm on the first phone build.
- **GDD over art bible.** Where an approved GDD and the art bible differ (burst wind-up 0.1 s against 0.15 s; triangle tower 55 px against the 56 px floor), the specs follow the GDD and the asset's Flags row names the art bible line to update.
- **Open flags.** Each spec's Flags row lists what is still unset (proposed colours for the damaged core, kite ghost and Ready ticks; reticle radius; low-alpha zone contrast under 3:1; fatal text on the raw field). None blocks a first build; each is checked when its view story is written.
