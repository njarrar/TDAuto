class_name StageResult extends RefCounted
## Built once by Flow when an outcome commits (ADR-0006 Decision 6). Holds
## values only, no references, so a view may keep it after the battle is dropped.

## WON, LOST or FATAL.
var outcome: Flow.Phase = Flow.Phase.FATAL
## EnemyWave.wave_index() at the outcome.
var last_wave_started: int = 0
var lives_left: int = 0
## Combat.dealt_by_kind(TOWER).
var dealt_tower: float = 0.0
## Combat.dealt_by_kind(HERO).
var dealt_hero: float = 0.0
## Combat.dealt_by_kind(BURST).
var dealt_burst: float = 0.0
## Combat.dealt_total().
var dealt_total: float = 0.0
