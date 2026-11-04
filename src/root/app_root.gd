class_name AppRoot extends Node
## The main scene (ADR-0001 Decision 2). Owns the session: the catalogue, the
## app latch, the state, the battle and its wrapper. Holds no gameplay logic.
## Preloads no scene: the wrapper and the fatal screen load at run time and are
## null-checked, so a missing scene file cannot stop this script from loading.
## The wrapper is used by duck typing (attach, detach) for the same reason.

enum AppState { BOOT, IN_STAGE, FATAL }

const DEFAULT_MANIFEST: String = "res://assets/data/manifest.json"
const DEFAULT_WRAPPER_PATH: String = "res://src/root/battle_wrapper.tscn"
const DEFAULT_FATAL_PATH: String = "res://src/root/fatal_screen.tscn"
const FATAL_MESSAGE: String = "Something went wrong. Please restart the game."

const ERR_CATALOGUE: String = "catalogue load failed"
const ERR_NO_STAGE: String = "no stage to play"
const ERR_BUILD: String = "battle build failed"
const ERR_WRAPPER_LOAD: String = "battle wrapper scene failed to load or instantiate"
const ERR_WRAPPER_ATTACH: String = "battle wrapper attach failed"

var _options: Dictionary = {}
var _catalogue: Catalogue = null
var _app_latch: FatalLatch = FatalLatch.new()
var _state: AppState = AppState.BOOT
var _battle: Battle = null
var _wrapper: Node = null
var _fatal_screen: Node = null
var _retry_requested: bool = false
var _rng_seed: int = 0
var _stage_id: StringName = &""
var _wrapper_path: String = DEFAULT_WRAPPER_PATH
var _fatal_path: String = DEFAULT_FATAL_PATH
var _builds_made: int = 0


## Tests only, before add_child. Keys: manifest, stage_id, rng_seed,
## wrapper_scene_path, fatal_scene_path, and load_result (a LoadResult that
## replaces the manifest load, so a fixture catalogue needs no file).
func configure(options: Dictionary) -> void:
	_options = options.duplicate()


func _ready() -> void:
	_app_latch = FatalLatch.new()
	_state = AppState.BOOT
	_wrapper_path = String(_options.get("wrapper_scene_path", DEFAULT_WRAPPER_PATH))
	_fatal_path = String(_options.get("fatal_scene_path", DEFAULT_FATAL_PATH))
	var result: LoadResult = _options.get("load_result") as LoadResult
	if result == null:
		result = Catalogue.load_manifest(String(_options.get("manifest", DEFAULT_MANIFEST)))
	if not result.ok or result.catalogue == null:
		_fatal("%s: %s" % [ERR_CATALOGUE, _describe_errors(result)])
		return
	_catalogue = result.catalogue
	if _options.has("stage_id"):
		_stage_id = StringName(String(_options["stage_id"]))
	else:
		var ids: Array[StringName] = _catalogue.stage_ids()
		if ids.is_empty():
			_fatal(ERR_NO_STAGE)
			return
		_stage_id = ids[0]
	if _options.has("rng_seed"):
		_rng_seed = int(_options["rng_seed"])
	else:
		_rng_seed = int(Time.get_unix_time_from_system() * 1000.0) & 0x7FFFFFFF
		if _rng_seed == 0:
			_rng_seed = 1
	_state = AppState.IN_STAGE
	_start_battle()


func _process(_delta: float) -> void:
	if _state == AppState.FATAL:
		return
	if _app_latch.is_fatal():
		_enter_fatal()
		return
	if _retry_requested:
		_retry_requested = false
		if _state == AppState.IN_STAGE and _battle != null and _battle.is_over():
			_retry()


## Sets the retry latch only. Idempotent; frees nothing.
func request_retry() -> void:
	_retry_requested = true


## The fatal_handler given to the Builder. Sets the app latch only.
func on_fatal(cause: String) -> void:
	_app_latch.fatal(cause)


## The current state.
func state() -> AppState:
	return _state


## The live battle, or null outside IN_STAGE.
func battle() -> Battle:
	return _battle


## The live wrapper node, or null.
func wrapper() -> Node:
	return _wrapper


## The app latch.
func app_latch() -> FatalLatch:
	return _app_latch


## The fatal screen node once shown, else null.
func fatal_screen() -> Node:
	return _fatal_screen


## How many battles have been built this session (the first plus each retry).
func builds_made() -> int:
	return _builds_made


## The session seed.
func rng_seed() -> int:
	return _rng_seed


func _start_battle() -> void:
	_builds_made += 1
	_battle = BattleBuilder.build(_catalogue, _stage_id, _rng_seed, on_fatal)
	if _battle == null:
		if not _app_latch.is_fatal():
			_fatal(ERR_BUILD)
		return
	_attach_wrapper()


func _attach_wrapper() -> void:
	var scene: PackedScene = null
	if ResourceLoader.exists(_wrapper_path):
		scene = ResourceLoader.load(_wrapper_path) as PackedScene
	if scene == null:
		_battle.report_fatal("%s: %s" % [ERR_WRAPPER_LOAD, _wrapper_path])
		return
	var node: Node = scene.instantiate()
	if node == null or not node.has_method(&"attach") or not node.has_method(&"detach"):
		if node != null:
			node.queue_free()
		_battle.report_fatal("%s: %s" % [ERR_WRAPPER_LOAD, _wrapper_path])
		return
	_wrapper = node
	add_child(_wrapper)
	var reduce_motion: bool = false
	if _battle.input_record != null:
		reduce_motion = _battle.input_record.reduce_motion
	var attached: bool = bool(_wrapper.call(&"attach", _battle, reduce_motion))
	if not attached:
		_battle.report_fatal(ERR_WRAPPER_ATTACH)


func _retry() -> void:
	_teardown_wrapper()
	_battle = null
	_start_battle()


func _teardown_wrapper() -> void:
	if _battle != null and _battle.resolver != null:
		_battle.resolver.cancel()
	if _wrapper != null:
		if is_instance_valid(_wrapper):
			if _wrapper.has_method(&"detach"):
				_wrapper.call(&"detach")
			if _wrapper.get_parent() == self:
				remove_child(_wrapper)
			_wrapper.queue_free()
		_wrapper = null


## Fatal raised by AppRoot itself with no live battle (BOOT, or build returned null).
func _fatal(cause: String) -> void:
	if not _app_latch.is_fatal():
		push_error(cause)
	_app_latch.fatal(cause)
	_enter_fatal()


func _enter_fatal() -> void:
	if _state == AppState.FATAL:
		return
	_teardown_wrapper()
	_battle = null
	_state = AppState.FATAL
	_show_fatal_screen()


func _show_fatal_screen() -> void:
	var screen: Node = null
	if ResourceLoader.exists(_fatal_path):
		var scene: PackedScene = ResourceLoader.load(_fatal_path) as PackedScene
		if scene != null:
			screen = scene.instantiate()
	if screen == null:
		screen = _make_fallback_label()
	add_child(screen)
	_fatal_screen = screen
	if OS.is_debug_build():
		var cause_label: Label = screen.find_child("Cause", true, false) as Label
		if cause_label != null:
			cause_label.text = _app_latch.cause()
			cause_label.visible = true
		elif screen is Label:
			(screen as Label).text = "%s\n%s" % [FATAL_MESSAGE, _app_latch.cause()]


func _make_fallback_label() -> Label:
	var label: Label = Label.new()
	label.name = "FatalFallback"
	label.text = FATAL_MESSAGE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _describe_errors(result: LoadResult) -> String:
	if result == null or result.errors.is_empty():
		return "no errors listed"
	var parts: PackedStringArray = PackedStringArray()
	for err: ValidationError in result.errors:
		parts.append("%s|%s|%s" % [String(err.code), String(err.record_id), String(err.field)])
		if parts.size() >= 3:
			break
	return "; ".join(parts)
