class_name KBuilder extends RefCounted
static func build(stage_id: StringName, seed: int, fatal_handler: Callable) -> KBattle:
	var b := KBattle.new()
	b.fatal_latch = KLatch.new(fatal_handler)
	if stage_id == &"":
		b.fatal_latch.fatal("no stage")
		return null
	return b
