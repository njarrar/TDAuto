extends RefCounted
## One recording fake for signals (ADR-0007 Decision 4).
##
## watch() and watch_all() connect a variadic listener that appends {signal, args} to ONE
## ordered log shared by every watched signal. At record time each payload is checked
## against the signal declaration: argument count, and typeof() equal to the declared type
## (TYPE_STRING_NAME for IDs, TYPE_INT for enums and integer IDs). A declared TYPE_NIL or
## TYPE_OBJECT parameter is itself an error (ADR-0006: typed, object-free payloads).
## expect() compares the whole log in order. assert_signal and monitor_signals are not used.
##
## The fake holds payload values only, never an emitter. Call stop() (and clear every
## variable that holds the fake) before a weakref assert: a lambda's release is not relied on.

## Sentinel for expect(): matches any value of the declared type.
var ANY: Object = RefCounted.new()

var _log: Array[Dictionary] = []
var _type_errors: PackedStringArray = PackedStringArray()
var _connections: Array[Dictionary] = []


## Records one signal. Reads the declared parameter types from the emitter's signal list.
func watch(sig: Signal) -> void:
	var emitter: Object = sig.get_object()
	var signal_name: StringName = sig.get_name()
	if emitter == null:
		_type_errors.append("watch(%s): the signal has no emitter" % signal_name)
		return
	var declared: Array = []
	var found: bool = false
	for entry: Dictionary in emitter.get_signal_list():
		if entry["name"] == signal_name:
			declared = entry["args"]
			found = true
			break
	if not found:
		_type_errors.append("watch(%s): the emitter declares no such signal" % signal_name)
		return
	var recorder: Callable = func(...args: Array) -> void:
		_record(signal_name, declared, args)
	sig.connect(recorder)
	_connections.append({"id": emitter.get_instance_id(), "name": signal_name, "callable": recorder})


## Records every signal the emitter's script declares.
func watch_all(emitter: Object) -> void:
	var script: Script = emitter.get_script()
	if script == null:
		_type_errors.append("watch_all: the emitter has no script")
		return
	for entry: Dictionary in script.get_script_signal_list():
		watch(Signal(emitter, entry["name"]))


## The log in emit order: {signal: StringName, args: Array}.
func entries() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry in _log:
		copy.append(entry)
	return copy


## Payload type and count errors found at record time.
func type_errors() -> PackedStringArray:
	return _type_errors.duplicate()


## Compares the whole log with expected, a list of [signal_name, [args...]]. Returns one
## line per problem; an empty result means the log and every payload type match.
func expect(expected: Array) -> PackedStringArray:
	var result: PackedStringArray = _type_errors.duplicate()
	var total: int = maxi(expected.size(), _log.size())
	for i in total:
		if i >= _log.size():
			result.append("entry %d missing: expected %s" % [i, _describe_expected(expected[i])])
			continue
		var got: Dictionary = _log[i]
		if i >= expected.size():
			result.append("entry %d unlisted: got %s %s" % [i, got["signal"], str(got["args"])])
			continue
		var want: Array = expected[i]
		var want_name: String = str(want[0])
		var want_args: Array = want[1] if want.size() > 1 else []
		if str(got["signal"]) != want_name:
			result.append("entry %d: expected signal %s, got %s" % [i, want_name, got["signal"]])
			continue
		var got_args: Array = got["args"]
		if got_args.size() != want_args.size():
			result.append("entry %d (%s): expected %d args, got %d" % [i, want_name, want_args.size(), got_args.size()])
			continue
		for k in got_args.size():
			if not _same_arg(want_args[k], got_args[k]):
				result.append("entry %d (%s) arg %d: expected %s (%s), got %s (%s)" % [
					i, want_name, k, str(want_args[k]), type_string(typeof(want_args[k])),
					str(got_args[k]), type_string(typeof(got_args[k])),
				])
	return result


## Disconnects every recording listener. Does nothing for emitters already freed.
func stop() -> void:
	for connection in _connections:
		var emitter: Object = instance_from_id(connection["id"])
		if emitter == null or not is_instance_valid(emitter):
			continue
		var sig: Signal = Signal(emitter, connection["name"])
		if sig.is_connected(connection["callable"]):
			sig.disconnect(connection["callable"])
	_connections.clear()


## Forgets the log and the type errors. Connections stay.
func clear() -> void:
	_log.clear()
	_type_errors = PackedStringArray()


func _record(signal_name: StringName, declared: Array, args: Array) -> void:
	_log.append({"signal": signal_name, "args": args.duplicate()})
	if declared.size() != args.size():
		_type_errors.append("%s: declared %d args, emitted %d" % [signal_name, declared.size(), args.size()])
		return
	for i in args.size():
		var decl: Dictionary = declared[i]
		var decl_type: int = decl["type"]
		var arg_name: String = str(decl["name"])
		if decl_type == TYPE_NIL or decl_type == TYPE_OBJECT:
			_type_errors.append("%s arg %d (%s): declared type %s is not allowed on a signal payload" % [signal_name, i, arg_name, type_string(decl_type)])
			continue
		if typeof(args[i]) != decl_type:
			_type_errors.append("%s arg %d (%s): declared %s, emitted %s" % [signal_name, i, arg_name, type_string(decl_type), type_string(typeof(args[i]))])


func _same_arg(want: Variant, got: Variant) -> bool:
	if is_same(want, ANY):
		return true
	return typeof(want) == typeof(got) and want == got


func _describe_expected(entry: Array) -> String:
	var args: Array = entry[1] if entry.size() > 1 else []
	return "%s %s" % [str(entry[0]), str(args)]
