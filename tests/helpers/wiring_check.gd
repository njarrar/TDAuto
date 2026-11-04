extends RefCounted
## The headless listener-count check of ADR-0006 Decision 8 (rules 1 to 5).
## Returns one problem line per defect; empty means the battle passes.

const Contract := preload("res://tests/integration/battle_wiring/battle_signal_contract.gd")


## Checks a freshly built battle (no wrapper attached).
static func check(battle: Battle) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var emitters: Array[Object] = battle.emitters()
	var wiring: Dictionary = Contract.WIRING
	var allow: Dictionary = Contract.VIEW_ALLOWLIST
	for index in range(Battle.EMITTER_KEYS.size()):
		var emitter_key: String = String(Battle.EMITTER_KEYS[index])
		var emitter: Object = emitters[index]
		var declared: Array[String] = _declared_signals(emitter)
		# Rule 1: every declared signal is listed.
		for sig_name: String in declared:
			var key: String = "%s.%s" % [emitter_key, sig_name]
			if not wiring.has(key) and not allow.has(key):
				problems.append("%s: signal not in the contract" % key)
		# Rule 3: wiring connections equal the expected list.
		for key: Variant in wiring.keys():
			var key_text: String = String(key)
			if not key_text.begins_with(emitter_key + "."):
				continue
			var sig_name: String = key_text.substr(emitter_key.length() + 1)
			if not declared.has(sig_name):
				problems.append("%s: stale key, emitter declares no such signal" % key_text)
				continue
			var expected: Array[String] = []
			for entry: Variant in (wiring[key] as Array):
				var pair: Array = entry as Array
				expected.append("%s.%s|0" % [String(pair[0]), String(pair[1])])
			var actual: Array[String] = _connections(emitter, sig_name, emitters)
			for want: String in expected:
				if not actual.has(want):
					problems.append("%s: missing %s" % [key_text, want.get_slice("|", 0)])
			for got: String in actual:
				if not expected.has(got):
					problems.append("%s: extra %s" % [key_text, got])
		# Rules 2 and 4: view keys exist and have no sim listener.
		for key: Variant in allow.keys():
			var key_text: String = String(key)
			if not key_text.begins_with(emitter_key + "."):
				continue
			var sig_name: String = key_text.substr(emitter_key.length() + 1)
			if not declared.has(sig_name):
				problems.append("%s: stale key, emitter declares no such signal" % key_text)
				continue
			var actual: Array[String] = _connections(emitter, sig_name, emitters)
			if not actual.is_empty():
				problems.append("%s: view signal has a headless listener %s" % [key_text, actual[0]])
	return problems


## Rule 5: the data-store classes and other non-emitters declare no signal.
static func check_non_emitters() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var scripts: Array[Script] = [
		Catalogue, StatAccessor, ReadContext, Targetable, Enemy, Health, Status,
		DamageEvent, StageResult, FatalLatch, FatalRelay, Battle,
	]
	for script: Script in scripts:
		if not script.get_script_signal_list().is_empty():
			problems.append("%s declares a signal" % script.resource_path)
	return problems


static func _declared_signals(emitter: Object) -> Array[String]:
	var names: Array[String] = []
	var script: Script = emitter.get_script() as Script
	if script == null:
		return names
	for entry: Dictionary in script.get_script_signal_list():
		names.append(String(entry["name"]))
	return names


## "key.method|flags" for each connection of the signal.
static func _connections(emitter: Object, sig_name: String, emitters: Array[Object]) -> Array[String]:
	var list: Array[String] = []
	for entry: Dictionary in emitter.get_signal_connection_list(sig_name):
		var callable: Callable = entry["callable"] as Callable
		var target: Object = callable.get_object()
		var target_key: String = "foreign"
		var at: int = emitters.find(target)
		if at >= 0:
			target_key = String(Battle.EMITTER_KEYS[at])
		list.append("%s.%s|%d" % [target_key, String(callable.get_method()), int(entry["flags"])])
	return list
