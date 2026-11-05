# PROTOTYPE - NOT FOR PRODUCTION. ADR-0001 V2 (teardown timing).
extends Node
## Builds a fake battle and wrapper, tears them down as ADR-0001 Decision 7
## step 4 and 5 say, then logs, frame by frame, which callbacks of the old
## wrapper subtree still fired and which weakrefs are still alive.

const Counter := preload("res://counter.gd")
const FakeBattle := preload("res://fake_battle.gd")
const FakeWrapper := preload("res://fake_wrapper.gd")

const AUTO_FRAMES: PackedInt32Array = [60, 180, 300]
const HEADLESS_QUIT_FRAME := 420
const WATCH_FRAMES := 3
const LOG_PATH := "user://adr0001_v2_log.txt"

var _counter: Counter = Counter.new()
var _battle: FakeBattle
var _wrapper: FakeWrapper
var _gen: int = 0
var _frame: int = 0
var _retry_requested: bool = false
var _retry_source: String = ""
var _watch_left: int = 0
var _watch_gen: int = 0
var _snapshot: Dictionary = {}
var _refs: Dictionary = {}
var _file: FileAccess
var _headless: bool = false


func _ready() -> void:
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_headless = DisplayServer.get_name() == "headless"
	_log("INFO godot=%s display=%s log=%s" % [Engine.get_version_info().get("string", "?"), DisplayServer.get_name(), ProjectSettings.globalize_path(LOG_PATH)])
	_log("INFO auto teardown at frames %s; press R or click the button for more" % str(AUTO_FRAMES))
	var help: Label = Label.new()
	help.text = "ADR-0001 V2. Keep the pointer on the button\nand move it a little. Auto retries at\nframes 60, 180, 300. Then press R or click."
	help.position = Vector2(20.0, 40.0)
	add_child(help)
	_build()


func _process(_delta: float) -> void:
	_frame += 1
	if _watch_left > 0:
		_report_watch()
	if _frame in AUTO_FRAMES:
		_request("auto")
	if _retry_requested:
		_retry_requested = false
		_teardown()
		_build()
	if _headless and _frame >= HEADLESS_QUIT_FRAME:
		_log("END v2")
		get_tree().quit(0)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_R:
		_request("key_r")


func _build() -> void:
	_gen += 1
	_battle = FakeBattle.new()
	_wrapper = FakeWrapper.new()
	_wrapper.name = "Wrapper%d" % _gen
	_wrapper.build(_gen, _counter)
	add_child(_wrapper)
	_wrapper.attach(_battle)
	_wrapper.retry_pressed.connect(_on_retry_pressed)
	_log("BUILD gen=%d frame=%d" % [_gen, _frame])


func _on_retry_pressed() -> void:
	_request("button")


func _request(source: String) -> void:
	if not _retry_requested:
		_retry_source = source
	_retry_requested = true
	_log("REQUEST source=%s gen=%d frame=%d" % [source, _gen, _frame])


func _teardown() -> void:
	var old: FakeWrapper = _wrapper
	_refs = {}
	_refs["battle"] = weakref(_battle)
	for i in _battle.sims.size():
		_refs["sim%d" % i] = weakref(_battle.sims[i])
	_refs["resolver"] = weakref(_battle.resolver)
	_refs["wrapper"] = weakref(old)
	_snapshot = _counter.n.duplicate()
	_watch_gen = _gen
	_log("TEARDOWN gen=%d source=%s frame=%d counts_so_far=%s" % [_gen, _retry_source, _frame, _gen_counts(_gen)])
	old.detach()
	remove_child(old)
	old.queue_free()
	_wrapper = null
	_battle = null
	old = null
	_report_refs("same_frame")
	_watch_left = WATCH_FRAMES


func _report_watch() -> void:
	var n: int = WATCH_FRAMES - _watch_left + 1
	var prefix: String = "g%d." % _watch_gen
	var fired: PackedStringArray = []
	for k: String in _counter.n.keys():
		if k.begins_with(prefix):
			var before: int = int(_snapshot.get(k, 0))
			var now: int = int(_counter.n[k])
			if now > before:
				fired.append("%s+%d" % [k, now - before])
	_log("AFTER gen=%d frame+%d fired=[%s]" % [_watch_gen, n, ", ".join(fired)])
	_report_refs("frame+%d" % n)
	_watch_left -= 1


func _report_refs(stage: String) -> void:
	var alive: PackedStringArray = []
	for k: String in _refs.keys():
		var w: WeakRef = _refs[k]
		if w.get_ref() != null:
			alive.append(k)
	_log("WEAKREF gen=%d %s alive=[%s] (%d of %d)" % [_watch_gen, stage, ", ".join(alive), alive.size(), _refs.size()])


func _gen_counts(gen: int) -> String:
	var parts: PackedStringArray = []
	var prefix: String = "g%d." % gen
	for k: String in _counter.n.keys():
		if k.begins_with(prefix):
			parts.append("%s=%d" % [k, int(_counter.n[k])])
	return "[%s]" % ", ".join(parts)


func _log(text: String) -> void:
	var line: String = "%06d t%d %s" % [_frame, Time.get_ticks_usec(), text]
	print(line)
	if _file != null:
		_file.store_line(line)
		_file.flush()
