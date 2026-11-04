class_name StatAccessor extends RefCounted
## The one stat accessor (ADR-0005). Created per battle with the session
## catalogue and the battle's `fatal` Callable. A bad call calls `fatal` once
## with a cause and returns 0 or 0.0; callers check `halted()` before using the
## value, and tests never assert the returned value. At MVP each read returns
## the base value from the catalogue.

var _catalogue: Catalogue
var _fatal: Callable


func _init(catalogue: Catalogue, fatal: Callable) -> void:
	_catalogue = catalogue
	_fatal = fatal
	if not fatal.is_valid():
		push_error("StatAccessor: fatal callable is not valid; a bad call would have nowhere to go")


## Returns the value of an int key for this context. A bad call calls the
## injected fatal once, names the cause, and returns 0.
func stat_int(ctx: ReadContext, key: StringName) -> int:
	var cause: String = _bad_call_cause(ctx, key, true, "stat_int")
	if cause != "":
		_fatal.call(cause)
		return 0
	return _read_int(ctx, key)


## Same, for a float key. Returns 0.0 after a bad call.
func stat_float(ctx: ReadContext, key: StringName) -> float:
	var cause: String = _bad_call_cause(ctx, key, false, "stat_float")
	if cause != "":
		_fatal.call(cause)
		return 0.0
	return _read_float(ctx, key)


## Non-fatal: true if the ID names a tower. Never calls fatal.
func is_tower(id: StringName) -> bool:
	return _catalogue.is_tower(id)


## Non-fatal: the tower's level count, 0 if not a tower. Never calls fatal.
func level_count(def_id: StringName) -> int:
	return _catalogue.level_count(def_id)


## Returns "" for a good call, else the cause of the first failed check (the
## seven bad calls of ADR-0005 Decision 5, in order). The string is built only
## on the failure path.
func _bad_call_cause(ctx: ReadContext, key: StringName, wants_int: bool, method: String) -> String:
	if not StatKeys.is_key(key):
		return "%s: key '%s' is not in StatKeys" % [method, String(key)]
	if StatKeys.is_int(key) != wants_int:
		return "%s: key '%s' has the other number type" % [method, String(key)]
	if ctx == null:
		return "%s: key '%s' read with a null context" % [method, String(key)]
	var record_type: StringName = _catalogue.record_type(ctx.def_id)
	if record_type == &"":
		return "%s: key '%s': def_id '%s' does not resolve to a record" % [method, String(key), String(ctx.def_id)]
	if not StatKeys.applies_to(key, record_type):
		return "%s: key '%s' does not apply to %s '%s'" % [method, String(key), String(record_type), String(ctx.def_id)]
	if record_type == CatalogueSchema.TOWER:
		var role: StringName = StatKeys.role_tag(key)
		if role != &"" and not _catalogue.tower(ctx.def_id).has_tag(role):
			return "%s: key '%s' needs tag '%s' on tower '%s'" % [method, String(key), String(role), String(ctx.def_id)]
		if ctx.level < 1 or ctx.level > _catalogue.level_count(ctx.def_id):
			return "%s: key '%s': tower '%s' level %d is outside 1 to %d" % [
					method, String(key), String(ctx.def_id), ctx.level, _catalogue.level_count(ctx.def_id)]
	elif ctx.level != 0:
		return "%s: key '%s': %s '%s' has no levels but level is %d" % [
				method, String(key), String(record_type), String(ctx.def_id), ctx.level]
	return ""


func _read_int(ctx: ReadContext, key: StringName) -> int:
	var record_type: StringName = _catalogue.record_type(ctx.def_id)
	if record_type == CatalogueSchema.TOWER:
		var level: TowerLevel = _catalogue.tower(ctx.def_id).levels[ctx.level - 1]
		if key == StatKeys.COST:
			return level.cost
	elif record_type == CatalogueSchema.ENEMY:
		var enemy: EnemyRecord = _catalogue.enemy(ctx.def_id)
		if key == StatKeys.BOUNTY:
			return enemy.bounty
		if key == StatKeys.LIVES_COST:
			return enemy.lives_cost
	return 0


func _read_float(ctx: ReadContext, key: StringName) -> float:
	var record_type: StringName = _catalogue.record_type(ctx.def_id)
	if record_type == CatalogueSchema.TOWER:
		return _tower_float(_catalogue.tower(ctx.def_id).levels[ctx.level - 1], key)
	if record_type == CatalogueSchema.ENEMY:
		var enemy: EnemyRecord = _catalogue.enemy(ctx.def_id)
		if key == StatKeys.MAX_HP:
			return enemy.max_hp
		if key == StatKeys.MOVE_SPEED:
			return enemy.move_speed
	elif record_type == CatalogueSchema.HERO:
		var hero: HeroRecord = _catalogue.hero(ctx.def_id)
		if key == StatKeys.DAMAGE:
			return hero.damage
		if key == StatKeys.ATTACK_INTERVAL:
			return hero.attack_interval
		if key == StatKeys.LEASH_RADIUS:
			return hero.leash_radius
		if key == StatKeys.WALK_SPEED:
			return hero.walk_speed
	elif record_type == CatalogueSchema.BURST:
		var burst: BurstRecord = _catalogue.burst(ctx.def_id)
		if key == StatKeys.DAMAGE:
			return burst.damage
		if key == StatKeys.RADIUS:
			return burst.radius
		if key == StatKeys.REACH:
			return burst.reach
		if key == StatKeys.COOLDOWN:
			return burst.cooldown
		if key == StatKeys.TELEGRAPH_DURATION:
			return burst.telegraph_duration
	return 0.0


func _tower_float(level: TowerLevel, key: StringName) -> float:
	if key == StatKeys.DAMAGE:
		return level.damage
	if key == StatKeys.RANGE:
		return level.range_
	if key == StatKeys.ATTACK_INTERVAL:
		return level.attack_interval
	if key == StatKeys.SPLASH_RADIUS:
		return level.splash_radius
	if key == StatKeys.SLOW_STRENGTH:
		return level.slow_strength
	if key == StatKeys.SLOW_DURATION:
		return level.slow_duration
	return 0.0


## Non-fatal: true if the tower `def_id` carries the role tag (`&"splash"`,
## `&"slow"`, `&"single_target"`). False for an unknown or non-tower ID. Never
## calls fatal. TowerSim uses it to pick the targeting and the role reads.
func has_tag(def_id: StringName, tag: StringName) -> bool:
	var record: TowerRecord = _catalogue.tower(def_id)
	if record == null:
		return false
	return record.has_tag(tag)
