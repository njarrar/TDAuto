extends RefCounted
## Battle probes (ADR-0007 Decision 5). Static only.
##
## Built now: alive(). ADR-0001 Validation 3 and 3b need it before any sim exists.
##
## TODO (sims module, needs Battle, ADR-0006 Battle.emitters() and EMITTER_KEYS):
##   static func system(battle: Battle, key: StringName) -> Object
##       Returns battle.emitters()[Battle.EMITTER_KEYS.find(key)]. No new Battle API.
##   static func digest(battle: Battle) -> String
##       JSON.stringify with sorted keys and full precision of read-only queries only
##       (phase, lives, gold, ticks_run(), then each system's queries). Never a private field.
## They are left out on purpose: a Battle type in a signature would stop this file parsing
## until Battle exists. tests/helpers/battle_runner.gd, baselines.gd, wiring_check.gd and
## combat_invariant.gd are also owned by the sims module.


## Names each ref that still resolves, as "ref <index>". Empty means every object is gone.
static func alive(refs: Array[WeakRef]) -> PackedStringArray:
	var still_alive: PackedStringArray = PackedStringArray()
	for i in refs.size():
		if refs[i].get_ref() != null:
			still_alive.append("ref %d" % i)
	return still_alive
