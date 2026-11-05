class_name CatalogueSchema extends RefCounted
## The schema table for the catalogue (ADR-0002 Decision 4).
##
## Constants only; never instantiated. For each record type and sub-record it
## lists every field with its kind and domain. The domain bounds are invariants
## against typos and broken sims, not balance values (Data & Config GDD,
## Field domains). Adding a field means a change here, in the record class
## (including `to_dict()`), in the GDD table, and a validator test.
##
## A spec is an Array: [kind, min, max, min_inclusive, max_inclusive].
## `min` and `max` are null when a kind has no numeric domain or no bound.
## Kinds: int, float, bool, string, id, id_ref:<type>, id_refs:<type>, tags,
## point, points, rect, shapes, list:<sub>.

const TOWER: StringName = &"tower"
const ENEMY: StringName = &"enemy"
const WAVE: StringName = &"wave"
const STAGE: StringName = &"stage"
const HERO: StringName = &"hero"
const BURST: StringName = &"burst"
const INPUT: StringName = &"input"

## Record types in the order they are built and reported.
const TYPE_ORDER: Array[StringName] = [TOWER, ENEMY, WAVE, STAGE, HERO, BURST, INPUT]

## Closest legal time value: one tick at 60 Hz.
const TICK: float = 1.0 / 60.0
## Every point coordinate lies inside this symmetric range.
const COORD_LIMIT: float = 2000.0
## Directions a pin exclusion shape may name.
const HANDS: Array[String] = ["right", "left", "both"]

const SPEC_KIND: int = 0
const SPEC_MIN: int = 1
const SPEC_MAX: int = 2
const SPEC_MIN_INCL: int = 3
const SPEC_MAX_INCL: int = 4

# Reusable domains.
const _ID: Array = ["id", null, null, false, false]
const _TEXT: Array = ["string", null, null, false, false]
const _BOOL: Array = ["bool", null, null, false, false]
const _INTERVAL: Array = ["float", TICK, 600.0, true, true]
const _SECONDS: Array = ["float", 0.0, 600.0, true, true]
const _DAMAGE: Array = ["float", 0.0, 1000000.0, true, true]
const _LENGTH: Array = ["float", 0.0, 2000.0, false, true]
const _GOLD: Array = ["int", 0, 100000, true, true]

## Tag vocabulary per record type. Enemy tags may be empty at MVP, so none are known.
const TAGS: Dictionary = {
	"tower": ["single_target", "splash", "slow"],
	"enemy": [],
}

## Tags that are tower roles, and the level fields each role requires.
const ROLE_FIELDS: Dictionary = {
	"single_target": [],
	"splash": ["splash_radius"],
	"slow": ["slow_strength", "slow_duration"],
}

## Fields that may be absent on a record type. Every other declared field is required.
const OPTIONAL_FIELDS: Dictionary = {
	"tower_level": ["splash_radius", "slow_strength", "slow_duration"],
	"stage": ["sell_refund_percent"],
}

## Fields of each record type and sub-record. Keys are the JSON names.
const FIELDS: Dictionary = {
	"tower": {
		"id": _ID,
		"rationale": _TEXT,
		"tags": ["tags", null, null, false, false],
		"levels": ["list:tower_level", null, null, false, false],
	},
	"tower_level": {
		"cost": _GOLD,
		"damage": _DAMAGE,
		"range": _LENGTH,
		"attack_interval": _INTERVAL,
		"visual_key": _TEXT,
		"splash_radius": _LENGTH,
		"slow_strength": ["float", 0.0, 1.0, false, false],
		"slow_duration": _INTERVAL,
	},
	"enemy": {
		"id": _ID,
		"rationale": _TEXT,
		"max_hp": ["float", 0.0, 1000000.0, false, true],
		"move_speed": _LENGTH,
		"bounty": _GOLD,
		"lives_cost": ["int", 0, 1000, true, true],
		"visual_key": _TEXT,
		"tags": ["tags", null, null, false, false],
	},
	"wave": {
		"id": _ID,
		"rationale": _TEXT,
		"groups": ["list:wave_group", null, null, false, false],
		"intermission_duration": _SECONDS,
	},
	"wave_group": {
		"enemy_id": ["id_ref:enemy", null, null, false, false],
		"count": ["int", 1, 500, true, true],
		"spawn_interval": _INTERVAL,
		"start_delay": _SECONDS,
	},
	"stage": {
		"id": _ID,
		"rationale": _TEXT,
		"scene_ref": _TEXT,
		"wave_ids": ["id_refs:wave", null, null, false, false],
		"starting_gold": _GOLD,
		## Share of a tower's total spend paid back on sell, 0 to 100. Optional (default 70).
		"sell_refund_percent": ["int", 0, 100, true, true],
		"starting_lives": ["int", 1, 1000, true, true],
		"early_call_seconds_per_gold": _INTERVAL,
		"path_points": ["points", null, null, false, false],
		"slot_positions": ["points", null, null, false, false],
		"path_width": _LENGTH,
		"requires_bend": _BOOL,
		"hero_start": ["point", null, null, false, false],
		"pin_rect": ["rect", null, null, false, false],
		"pin_exclusion": ["shapes", null, null, false, false],
	},
	"hero": {
		"id": _ID,
		"rationale": _TEXT,
		"damage": _DAMAGE,
		"attack_interval": _INTERVAL,
		"leash_radius": _LENGTH,
		"walk_speed": _LENGTH,
		"burst_id": ["id_ref:burst", null, null, false, false],
		"visual_key": _TEXT,
	},
	"burst": {
		"id": _ID,
		"rationale": _TEXT,
		"damage": _DAMAGE,
		"radius": _LENGTH,
		"reach": _LENGTH,
		"cooldown": _INTERVAL,
		"telegraph_duration": _SECONDS,
	},
	"input": {
		"id": _ID,
		"rationale": _TEXT,
		"drag_slop": ["float", 8.0, 30.0, true, true],
		"tap_slop": ["float", 16.0, 34.0, true, true],
		"edge_reject_margin": ["float", 0.0, 48.0, true, true],
		"left_handed": _BOOL,
		"reduce_motion": _BOOL,
	},
}

## Keys a `pin_exclusion` shape and a `pin_rect` may carry (all required).
const SHAPE_KEYS: Array[String] = ["a", "b", "radius", "hand"]
const RECT_KEYS: Array[String] = ["min", "max"]

## Domain of a pin shape radius (above 0, at most the coordinate limit).
const SHAPE_RADIUS: Array = ["float", 0.0, 2000.0, false, true]
