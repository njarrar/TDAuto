class_name StatKeys extends RefCounted
## The stat-key vocabulary (ADR-0005 Decision 3). Constants and a const table
## only; never instantiated. Callers pass `StatKeys.X`, never a literal.
## Constant values equal the data field names. The Dictionary is `const`, never
## a `static var`.

const COST: StringName = &"cost"
const DAMAGE: StringName = &"damage"
const RANGE: StringName = &"range"
const ATTACK_INTERVAL: StringName = &"attack_interval"
const SPLASH_RADIUS: StringName = &"splash_radius"
const SLOW_STRENGTH: StringName = &"slow_strength"
const SLOW_DURATION: StringName = &"slow_duration"
const BOUNTY: StringName = &"bounty"
const LIVES_COST: StringName = &"lives_cost"
const MAX_HP: StringName = &"max_hp"
const MOVE_SPEED: StringName = &"move_speed"
const LEASH_RADIUS: StringName = &"leash_radius"
const WALK_SPEED: StringName = &"walk_speed"
const RADIUS: StringName = &"radius"
const REACH: StringName = &"reach"
const COOLDOWN: StringName = &"cooldown"
const TELEGRAPH_DURATION: StringName = &"telegraph_duration"

## key -> {is_int: bool, types: Array of record types, role: role tag or &""}.
const TABLE: Dictionary = {
	COST: {"is_int": true, "types": [&"tower"], "role": &""},
	DAMAGE: {"is_int": false, "types": [&"tower", &"hero", &"burst"], "role": &""},
	RANGE: {"is_int": false, "types": [&"tower"], "role": &""},
	ATTACK_INTERVAL: {"is_int": false, "types": [&"tower", &"hero"], "role": &""},
	SPLASH_RADIUS: {"is_int": false, "types": [&"tower"], "role": &"splash"},
	SLOW_STRENGTH: {"is_int": false, "types": [&"tower"], "role": &"slow"},
	SLOW_DURATION: {"is_int": false, "types": [&"tower"], "role": &"slow"},
	BOUNTY: {"is_int": true, "types": [&"enemy"], "role": &""},
	LIVES_COST: {"is_int": true, "types": [&"enemy"], "role": &""},
	MAX_HP: {"is_int": false, "types": [&"enemy"], "role": &""},
	MOVE_SPEED: {"is_int": false, "types": [&"enemy"], "role": &""},
	LEASH_RADIUS: {"is_int": false, "types": [&"hero"], "role": &""},
	WALK_SPEED: {"is_int": false, "types": [&"hero"], "role": &""},
	RADIUS: {"is_int": false, "types": [&"burst"], "role": &""},
	REACH: {"is_int": false, "types": [&"burst"], "role": &""},
	COOLDOWN: {"is_int": false, "types": [&"burst"], "role": &""},
	TELEGRAPH_DURATION: {"is_int": false, "types": [&"burst"], "role": &""},
}


## True if the key is in the vocabulary.
static func is_key(key: StringName) -> bool:
	return TABLE.has(key)


## True if the key is an int key. False for float keys and unknown keys.
static func is_int(key: StringName) -> bool:
	if not TABLE.has(key):
		return false
	return bool((TABLE[key] as Dictionary)["is_int"])


## True if the key applies to the record type (`&"tower"` and so on).
static func applies_to(key: StringName, record_type: StringName) -> bool:
	if not TABLE.has(key):
		return false
	return ((TABLE[key] as Dictionary)["types"] as Array).has(record_type)


## The role tag a tower needs for this key, or &"" if none.
static func role_tag(key: StringName) -> StringName:
	if not TABLE.has(key):
		return &""
	return (TABLE[key] as Dictionary)["role"] as StringName


## Every key in the vocabulary.
static func all_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: Variant in TABLE.keys():
		keys.append(key as StringName)
	return keys
