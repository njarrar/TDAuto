class_name TowerLevel extends RefCounted
## One level of a tower. Values are absolute, never deltas.
##
## `range_` is the `range` field of the data file and of `StatKeys.RANGE`; the
## member carries a trailing underscore so it does not shadow GDScript's
## global `range()`. `to_dict()` writes the key `range`.
## The three role fields are 0.0 when the tower lacks that role's tag (the
## validator rejects a role field without its tag, and 0.0 is outside every
## role field's domain, so 0.0 always means "absent").

var cost: int = 0
var damage: float = 0.0
var range_: float = 0.0
var attack_interval: float = 0.0
var visual_key: String = ""
var splash_radius: float = 0.0
var slow_strength: float = 0.0
var slow_duration: float = 0.0


## Builds a level from a validated data dictionary.
static func from_dict(data: Dictionary) -> TowerLevel:
	var level: TowerLevel = TowerLevel.new()
	level.cost = int(data["cost"])
	level.damage = float(data["damage"])
	level.range_ = float(data["range"])
	level.attack_interval = float(data["attack_interval"])
	level.visual_key = String(data["visual_key"])
	level.splash_radius = float(data.get("splash_radius", 0.0))
	level.slow_strength = float(data.get("slow_strength", 0.0))
	level.slow_duration = float(data.get("slow_duration", 0.0))
	return level


## A fresh copy of every field, JSON-native types only.
func to_dict() -> Dictionary:
	return {
		"cost": cost,
		"damage": damage,
		"range": range_,
		"attack_interval": attack_interval,
		"visual_key": visual_key,
		"splash_radius": splash_radius,
		"slow_strength": slow_strength,
		"slow_duration": slow_duration,
	}
