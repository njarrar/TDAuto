extends RefCounted
## Combat accounting invariant on a whole battle, from read-only queries:
## the three kind sums add up to dealt_total and hero_share is in 0 .. 1.


static func holds(battle: Battle) -> bool:
	var combat: Combat = battle.combat
	var tower: float = combat.dealt_by_kind(Combat.SourceKind.TOWER)
	var hero: float = combat.dealt_by_kind(Combat.SourceKind.HERO)
	var burst: float = combat.dealt_by_kind(Combat.SourceKind.BURST)
	if tower < 0.0 or hero < 0.0 or burst < 0.0:
		return false
	if absf(combat.dealt_total() - (tower + hero + burst)) > 0.000001:
		return false
	var share: float = combat.hero_share()
	return share >= 0.0 and share <= 1.0
