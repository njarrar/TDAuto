extends RefCounted
## Battle probes (ADR-0007 Decision 5). Static only. Read-only queries only,
## never a private field.


## Names each ref that still resolves, as "ref <index>". Empty means every object is gone.
static func alive(refs: Array[WeakRef]) -> PackedStringArray:
	var still_alive: PackedStringArray = PackedStringArray()
	for i in refs.size():
		if refs[i].get_ref() != null:
			still_alive.append("ref %d" % i)
	return still_alive


## Returns battle.emitters()[Battle.EMITTER_KEYS.find(key)]; null for an unknown key.
static func system(battle: Battle, key: StringName) -> Object:
	var index: int = Battle.EMITTER_KEYS.find(key)
	if index < 0:
		return null
	return battle.emitters()[index]


## JSON text with sorted keys and full precision of read-only queries only.
## include_hero false leaves HeroSim out (never-pinned comparison).
static func digest(battle: Battle, include_hero: bool = true) -> String:
	var enemies: Array = []
	for t: Targetable in battle.enemy_wave.roster():
		enemies.append([t.spawn_id, t.distance, battle.combat.hp_left(t)])
	var wave_counts: Dictionary = {}
	var got: Dictionary = battle.enemy_wave.got_through_by_type()
	for key: Variant in got.keys():
		wave_counts[String(key)] = got[key]
	var data: Dictionary = {
		"phase": int(battle.flow.phase()),
		"lives": battle.flow.lives(),
		"gold": battle.tower_sim.gold(),
		"ticks": battle.ticks_run(),
		"intermission_left": battle.flow.intermission_left,
		"wave_index": battle.enemy_wave.wave_index(),
		"wave_state": int(battle.enemy_wave.wave_state()),
		"wave_tick": battle.enemy_wave.wave_tick(),
		"got_through": wave_counts,
		"dealt": [
			battle.combat.dealt_by_kind(Combat.SourceKind.TOWER),
			battle.combat.dealt_by_kind(Combat.SourceKind.HERO),
			battle.combat.dealt_by_kind(Combat.SourceKind.BURST),
		],
		"tower": battle.tower_sim.state_fields(),
		"enemies": enemies,
	}
	if include_hero:
		data["hero"] = battle.hero_sim.state_fields()
	return JSON.stringify(data, "", true, true)
