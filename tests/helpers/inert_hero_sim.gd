extends HeroSim
## HeroSim whose tick does nothing (ADR-0010 Decision 9): "absent" for the
## never-pinned-equals-absent test. _init forwards every argument with super.


func _init(stage: StageRecord, hero_id: StringName, burst_id: StringName, left_handed: bool,
		accessor: StatAccessor, halted: Callable, between_ticks: Callable, in_build: Callable,
		targets: Callable, to_ticks: Callable, dt: float, combat: Combat, fatal: Callable) -> void:
	super(stage, hero_id, burst_id, left_handed, accessor, halted, between_ticks, in_build,
			targets, to_ticks, dt, combat, fatal)


func tick() -> void:
	pass
