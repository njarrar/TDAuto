extends RefCounted
var name_: String
var log: Array[String]
var em  # Emitter, for the nested emit
var seen_type: int = -1
var seen_value = null
func _init(n: String, l: Array[String]) -> void:
	name_ = n
	log = l
func on_fired(n: int) -> void:
	log.append(name_ + ":fired:start")
	if em != null:
		em.inner.emit(n + 100)
	log.append(name_ + ":fired:end")
func on_inner(n: int) -> void:
	log.append(name_ + ":inner:" + str(n))
func on_typed(n) -> void:
	seen_type = typeof(n)
	seen_value = n
	log.append(name_ + ":typed:" + type_string(typeof(n)) + ":" + str(n))
