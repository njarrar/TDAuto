class_name DevLogs extends RefCounted
## Development log session (ADR-0010 Decision 10). AppRoot makes one in debug
## builds at boot. Holds the two file sinks, the launch id and the build hash.
## Holds no battle object or Callable, so it may live for the session. AppRoot
## calls close() on NOTIFICATION_WM_CLOSE_REQUEST and in its teardown.

const RUN_LOG_PATH: String = "user://run_log.jsonl"
const GESTURE_LOG_PATH: String = "user://gesture_log.jsonl"

## Milliseconds since the Unix epoch at launch.
var launch_id: int = 0
## Build stamp from BuildInfo.
var build_hash: String = BuildInfo.BUILD_HASH
## Sink for RunLog lines. Null if the open failed or in release builds.
var run_sink: JsonlFileSink = null
## Sink for GestureLog lines. Null if the open failed or in release builds.
var gesture_sink: JsonlFileSink = null


## Opens both sinks. A failed open in a debug build is reported once per file
## through `dev_error` (if valid); it is never fatal.
func _init(dev_error: Callable = Callable(), run_path: String = RUN_LOG_PATH, gesture_path: String = GESTURE_LOG_PATH) -> void:
	launch_id = int(Time.get_unix_time_from_system() * 1000.0)
	run_sink = _open(run_path, dev_error)
	gesture_sink = _open(gesture_path, dev_error)


## Closes both files. Safe to call twice.
func close() -> void:
	if run_sink != null:
		run_sink.close()
	if gesture_sink != null:
		gesture_sink.close()
	run_sink = null
	gesture_sink = null


func _open(path: String, dev_error: Callable) -> JsonlFileSink:
	var sink: JsonlFileSink = JsonlFileSink.open(path)
	if sink == null and OS.is_debug_build() and dev_error.is_valid():
		var code: int = FileAccess.get_open_error()
		dev_error.call("dev_logs: cannot open %s (error %d)" % [path, code])
	return sink
