extends SceneTree
func _init() -> void:
	# touch DamageEvent before Combat in a fresh process
	var ev := DamageEvent.new(Targetable.new(), 1.0, Combat.SourceKind.BURST, &"burst")
	print("DamageEvent first: kind=", ev.source_kind, " then Combat: ", Combat.new().kind_name(ev.source_kind))
	quit()
