class_name VisualKeys extends RefCounted
## Visual keys of one battle (ADR-0011 Decision 3). StringNames only: no
## records, no Callables, no signals, so it can form no cycle. Built once by
## BattleBuilder from the catalogue records and read by the presentation layer.

var _enemy: Dictionary = {}
var _tower: Dictionary = {}
var _hero: StringName = &""


## Builds the keys from each record's `visual_key`, using the catalogue's
## non-fatal id lookups. `hero_id` is the battle's hero; an unknown id gives &"".
static func from_catalogue(catalogue: Catalogue, hero_id: StringName) -> VisualKeys:
	var keys: VisualKeys = VisualKeys.new()
	for enemy_id: StringName in catalogue.enemy_ids():
		var enemy_record: EnemyRecord = catalogue.enemy(enemy_id)
		keys._enemy[enemy_id] = StringName(enemy_record.visual_key)
	for tower_id: StringName in catalogue.tower_ids():
		var tower_record: TowerRecord = catalogue.tower(tower_id)
		var list: Array[StringName] = []
		for level: TowerLevel in tower_record.levels:
			list.append(StringName(level.visual_key))
		keys._tower[tower_id] = list
	var hero_record: HeroRecord = catalogue.hero(hero_id)
	if hero_record != null:
		keys._hero = StringName(hero_record.visual_key)
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
