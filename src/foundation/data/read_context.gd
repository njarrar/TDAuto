class_name ReadContext extends RefCounted
## Who is reading a stat (ADR-0005 Decision 4). One per caller, made when its
## owner comes into being and reused for every read; a read never allocates one.
## The owning system holds the context, never the entity it names: the entity
## would otherwise form a RefCounted cycle through `live_entity`.

## The record's ID.
var def_id: StringName = &""
## Towers: 1 to level_count(def_id). Every other record: 0.
var level: int = 0
## The live enemy, tower or hero when one exists; null for a preview.
var live_entity: Object = null


## Builds a context.
static func make(p_def_id: StringName, p_level: int = 0, p_live_entity: Object = null) -> ReadContext:
	var ctx: ReadContext = ReadContext.new()
	ctx.def_id = p_def_id
	ctx.level = p_level
	ctx.live_entity = p_live_entity
	return ctx
