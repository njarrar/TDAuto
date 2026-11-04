class_name VisualKeys extends RefCounted
## Visual keys of one battle (ADR-0011 Decision 3). StringNames only: no
## records, no Callables, no signals, so it can form no cycle. Built once by
## BattleBuilder from the catalogue snapshot and read by the presentation layer.

var _enemy: Dictionary = {}
var _tower: Dictionary = {}
var _hero: StringName = &""


## Builds the keys from a parsed `Catalogue.snapshot()` dictionary.
static func from_snapshot(snap: Dictionary, hero_id: StringName) -> VisualKeys:
	var keys: VisualKeys = VisualKeys.new()
	var enemies: Dictionary = snap.get("enemy", {}) as Dictionary
	for id: Variant in enemies.keys():
		var rec: Dictionary = enemies[id] as Dictionary
		keys._enemy[StringName(String(id))] = StringName(String(rec.get("visual_key", "")))
	var towers: Dictionary = snap.get("tower", {}) as Dictionary
	for id: Variant in towers.keys():
		var rec: Dictionary = towers[id] as Dictionary
		var list: Array[StringName] = []
		for level: Variant in (rec.get("levels", []) as Array):
			list.append(StringName(String((level as Dictionary).get("visual_key", ""))))
		keys._tower[StringName(String(id))] = list
	var heroes: Dictionary = snap.get("hero", {}) as Dictionary
	if heroes.has(String(hero_id)):
		keys._hero = StringName(String((heroes[String(hero_id)] as Dictionary).get("visual_key", "")))
	return keys


## The visual key of an enemy definition, or &"" if unknown.
func enemy(def_id: StringName) -> StringName:
	return _enemy.get(def_id, &"") as StringName


## The visual key of a tower at a level (levels count from 1), or &"" if unknown.
func tower(tower_id: StringName, level: int) -> StringName:
	var list: Array[StringName] = _tower.get(tower_id, [] as Array[StringName]) as Array[StringName]
	if level < 1 or level > list.size():
		return &""
	return list[level - 1]


## The visual key of the battle's hero.
func hero() -> StringName:
	return _hero
