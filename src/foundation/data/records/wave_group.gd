class_name WaveGroup extends RefCounted
## One spawn group of a wave. Groups may overlap and need not be ordered.

var enemy_id: StringName = &""
var count: int = 0
var spawn_interval: float = 0.0
var start_delay: float = 0.0


## Builds a group from a validated data dictionary.
static func from_dict(data: Dictionary) -> WaveGroup:
	var group: WaveGroup = WaveGroup.new()
	group.enemy_id = StringName(String(data["enemy_id"]))
	group.count = int(data["count"])
	group.spawn_interval = float(data["spawn_interval"])
	group.start_delay = float(data["start_delay"])
	return group


## A fresh copy of every field, JSON-native types only.
func to_dict() -> Dictionary:
	return {
		"enemy_id": String(enemy_id),
		"count": count,
		"spawn_interval": spawn_interval,
		"start_delay": start_delay,
	}
