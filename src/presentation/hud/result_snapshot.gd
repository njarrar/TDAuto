class_name ResultSnapshot extends RefCounted
## Values of one finished attempt (ADR-0010 Decision 11). Built once by HudLogic on the
## first advance after phase_changed(WON) or (LOST). It references no sim object, so a
## view may keep it after the battle is dropped. The result rows and the log read only it.
## Field names follow ADR-0010. Lint MATH-4 bans RNG use in presentation, not this
## recorded `rng_seed` value.

var result: StageResult = null
var stage_id: StringName = &""
var rng_seed: int = 0
var ticks_run: int = 0
## Copy of EnemyWave.got_through_by_type().
var got_through: Dictionary = {}
var slows_applied: int = 0
var towers_built: int = 0
var hero_pinned_ever: bool = false
var hero_share: float = 0.0
## Damage dealt per source id (StringName to float), copied from Combat.dealt_by_id for each
## arc tower id, the hero id and the burst id (Battle HUD Rule 19).
var dealt_by_source: Dictionary = {}
var repins: int = 0
var bursts_fired: int = 0
var bursts_hit_0: int = 0
var bursts_hit_3: int = 0
var bursts_hit_5: int = 0
var burst_victims: int = 0
var burst_kills: int = 0
var kills_per_burst: PackedInt32Array = PackedInt32Array()
var kills_on_hit_3: PackedInt32Array = PackedInt32Array()
var best_victims: PackedInt32Array = PackedInt32Array()
## Added for the result rows (Battle HUD Rules 15 and 16).
var wave_index: int = 0
var wave_count: int = 0
var starting_lives: int = 0
var slow_built: bool = false
var next_try: String = ""
