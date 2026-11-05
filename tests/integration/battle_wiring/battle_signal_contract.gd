extends RefCounted
## ADR-0006 Decision 8: the wiring contract, const data copied from Decision 5.

## Wiring signals W1 to W5: "emitter.signal" -> exact [emitter_key, method_name] listeners.
const WIRING: Dictionary = {
	"enemy_wave.enemy_leaked": [["flow", &"on_enemy_leaked"]],
	"enemy_wave.enemy_killed": [["tower_sim", &"on_enemy_killed"]],
	"enemy_wave.wave_cleared": [["flow", &"on_wave_cleared"]],
	"enemy_wave.waves_completed": [["flow", &"on_waves_completed"]],
	"flow.wave_called_early": [["tower_sim", &"on_wave_called_early"]],
}

## View signals P1 to P9 and G1 to G8: key -> required_after_attach.
const VIEW_ALLOWLIST: Dictionary = {
	"flow.phase_changed": true,
	"flow.lives_changed": true,
	"tower_sim.gold_changed": true,
	"tower_sim.tower_built": true,
	"tower_sim.tower_upgraded": false,
	"hero_sim.hero_pinned": false,
	"hero_sim.burst_started": true,
	"combat.attack_fired": true,
	"combat.damage_applied": true,
	"resolver.pressed": true,
	"resolver.tapped": true,
	"resolver.ground_tapped": true,
	"resolver.drag_started": true,
	"resolver.drag_moved": true,
	"resolver.drag_ended": true,
	"resolver.drag_cancelled": true,
	"resolver.became_idle": true,
}
