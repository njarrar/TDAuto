extends RefCounted
## Fakes for injected values (architecture.md B9; ADR-0007 Decision 3).
##
## Each is an inner class used as fake.method, exactly as the Battle Builder injects it:
## Callable(fake.halted) is never built; pass fake.halted. to_ticks is never faked: tests
## use a real SimTime.
##
## UNVERIFIED dependency: Targets uses Targetable (src/core/combat, ADR-0009). This file
## does not parse until that class exists.


## Stands in for the halted() query.
class Halted extends RefCounted:
	var value: bool = false

	func halted() -> bool:
		return value


## Stands in for the in_build() query.
class InBuild extends RefCounted:
	var value: bool = true

	func in_build() -> bool:
		return value


## Stands in for the fatal handler. Records every cause; can set a Halted fake.
class Fatal extends RefCounted:
	var halted_fake: Halted = null
	var _causes: PackedStringArray = PackedStringArray()

	func fatal(cause: String) -> void:
		_causes.append(cause)
		if halted_fake != null:
			halted_fake.value = true

	func causes() -> PackedStringArray:
		return _causes.duplicate()


## Stands in for the dev_error sink.
class DevErrors extends RefCounted:
	var _messages: PackedStringArray = PackedStringArray()

	func report(msg: String) -> void:
		_messages.append(msg)

	func messages() -> PackedStringArray:
		return _messages.duplicate()


## Stands in for the targets() query.
class Targets extends RefCounted:
	var list: Array[Targetable] = []

	func targets() -> Array[Targetable]:
		return list


## Stands in for a cancel callable. Counts calls.
class Canceller extends RefCounted:
	var _count: int = 0

	func cancel() -> void:
		_count += 1

	func count() -> int:
		return _count
