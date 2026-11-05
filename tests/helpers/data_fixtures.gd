extends RefCounted
## Fixture factory for Data & Config tests (ADR-0002 Decision 9, ADR-0007).
## No class_name; tests preload this file by path. Values are binary-exact
## (multiples of 1/4) and differ per record and per level so a read that
## picks the wrong field or level shows up.

const LABEL_PREFIX: String = "fixture:"
const RATIONALE: String = "Fixture value; not balance."


## Records the causes passed to an injected `fatal`.
class FatalSpy extends RefCounted:
	var causes: Array[String] = []

	func fatal(cause: String) -> void:
		causes.append(cause)


## The smallest valid catalogue dictionary, in data file shape. Every call
## returns a fresh copy, so a test may edit it freely.
static func minimal() -> Dictionary:
	return {
		"tower": [
			{
				"id": "tower_single", "rationale": RATIONALE, "tags": ["single_target"],
				"levels": [
					_level(50, 12.0, 150.0, 0.5, "tower_single_1"),
					_level(60, 20.0, 160.0, 0.5, "tower_single_2"),
				],
			},
			{
				"id": "tower_splash", "rationale": RATIONALE, "tags": ["splash"],
				"levels": [
					_level(70, 20.0, 140.0, 1.0, "tower_splash_1", {"splash_radius": 50.0}),
					_level(80, 28.0, 170.0, 1.25, "tower_splash_2", {"splash_radius": 70.0}),
				],
			},
			{
				"id": "tower_slow", "rationale": RATIONALE, "tags": ["slow"],
				"levels": [
					_level(40, 0.0, 130.0, 0.75, "tower_slow_1",
							{"slow_strength": 0.25, "slow_duration": 2.0}),
					_level(45, 0.0, 135.0, 0.75, "tower_slow_2",
							{"slow_strength": 0.5, "slow_duration": 2.5}),
				],
			},
		],
		"enemy": [
			{
				"id": "enemy_grunt", "rationale": RATIONALE, "max_hp": 100.0,
				"move_speed": 60.0, "bounty": 4, "lives_cost": 1,
				"visual_key": "enemy_grunt", "tags": [],
			},
		],
		"wave": [
			{
				"id": "wave_a", "rationale": RATIONALE, "intermission_duration": 10.0,
				"groups": [{"enemy_id": "enemy_grunt", "count": 4, "spawn_interval": 1.5, "start_delay": 0.0}],
			},
		],
		"stage": [stage("stage_a")],
		"hero": [
			{
				"id": "hero_a", "rationale": RATIONALE, "damage": 4.0, "attack_interval": 1.0,
				"leash_radius": 90.0, "walk_speed": 240.0, "burst_id": "burst_a",
				"visual_key": "hero_a",
			},
		],
		"burst": [
			{
				"id": "burst_a", "rationale": RATIONALE, "damage": 130.0, "radius": 70.0,
				"reach": 160.0, "cooldown": 10.0, "telegraph_duration": 0.25,
			},
		],
		"input": [
			{
				"id": "input_a", "rationale": RATIONALE, "drag_slop": 16.0, "tap_slop": 28.0,
				"edge_reject_margin": 36.0, "left_handed": false, "reduce_motion": false,
			},
		],
	}


## A valid stage record referring to `wave_a`.
static func stage(stage_id: String) -> Dictionary:
	return {
		"id": stage_id, "rationale": RATIONALE, "scene_ref": "res://fixture/stage.tscn",
		"wave_ids": ["wave_a"], "starting_gold": 120, "starting_lives": 10,
		"early_call_seconds_per_gold": 1.75,
		"path_points": [[-40, 200], [400, 200], [400, 400], [100, 400], [100, 600], [300, 600], [300, 980]],
		"slot_positions": [[270, 305], [190, 485]],
		"path_width": 72.0, "requires_bend": true, "hero_start": [350, 800],
		"pin_rect": {"min": [48, 174], "max": [492, 888]},
		"pin_exclusion": [{"a": [456, 816], "b": [456, 888], "radius": 60.0, "hand": "right"}],
	}


## Loads a dictionary through the production validator and builder, no file I/O.
static func catalogue(data: Dictionary, label: String) -> LoadResult:
	return Catalogue.from_data(LABEL_PREFIX + label, data)


## Loads a dictionary that must be valid, and returns its catalogue (null if not).
static func ready(data: Dictionary, label: String) -> Catalogue:
	return catalogue(data, label).catalogue


## Returns "code|record_id|field" for every error, sorted.
static func sigs(result: LoadResult) -> Array[String]:
	var list: Array[String] = []
	for err: ValidationError in result.errors:
		list.append("%s|%s|%s" % [String(err.code), String(err.record_id), String(err.field)])
	list.sort()
	return list


## The record dictionary at `index` of `type_name` (a reference into `data`).
static func record(data: Dictionary, type_name: String, index: int = 0) -> Dictionary:
	return (data[type_name] as Array)[index] as Dictionary


## The level dictionary of a tower record (a reference into `data`).
static func tower_level(data: Dictionary, tower_index: int, level_index: int) -> Dictionary:
	return (record(data, "tower", tower_index)["levels"] as Array)[level_index] as Dictionary


static func _level(
		cost: int, damage: float, range_value: float, interval: float, visual_key: String,
		extra: Dictionary = {}) -> Dictionary:
	var level: Dictionary = {
		"cost": cost, "damage": damage, "range": range_value,
		"attack_interval": interval, "visual_key": visual_key,
	}
	level.merge(extra)
	return level
