class_name Firebase
extends Node
## Firebase Analytics and Crashlytics, through our Android plugin
## (SunstoneGoogleSignIn: logEvent, setUser, setCollection, recordError).
## Every event the game tracks for our server (Online.track) is also an
## Analytics event, so the store funnel continues into the game: app_open →
## title_shown → howto_open / lesson → run_start → run_end. Script and engine
## errors become Crashlytics non-fatals; native crashes are Crashlytics' own.
## Release builds only: a debug build switches collection off (and its
## manifest starts with it off, see addons/sunstone_google_signin), and sends
## nothing. Android only; elsewhere every call is a no-op.

const MAX_ERRORS := 25 ## per session, so a broken frame can't flood Crashlytics

## Errors caught by the logger, which may run on any thread: drained on the
## main thread in _process.
static var _pending: Array = []
static var _lock := Mutex.new()

var _plugin: Object
var _sent := 0
var _seen := {} ## "file:line" → true: each place reported once a session

func _ready() -> void:
	# (has_method is no use here: it can be false for plugin methods on Android.)
	if Engine.has_singleton("SunstoneGoogleSignIn"):
		_plugin = Engine.get_singleton("SunstoneGoogleSignIn")
	if _plugin and OS.is_debug_build():
		_plugin.call("setCollection", false)
		_plugin = null
	if _plugin == null:
		set_process(false)
		return
	_plugin.call("setCollection", true)
	OS.add_logger(ErrorLogger.new())

func event(name: String, props: Dictionary) -> void:
	if _plugin == null:
		return
	var flat := {}
	for k in props:
		var v: Variant = props[k]
		flat[str(k)] = v if (v is int or v is float or v is bool or v is String) else str(v)
	_plugin.call("logEvent", name, flat)

## Our player id on events and crashes ("" when signed out).
func set_user(id: String) -> void:
	if _plugin:
		_plugin.call("setUser", id)

func _process(_delta: float) -> void:
	_lock.lock()
	var batch := _pending.duplicate()
	_pending.clear()
	_lock.unlock()
	for e in batch:
		var where: String = e[1]
		if _sent >= MAX_ERRORS or _seen.has(where):
			continue
		_seen[where] = true
		_sent += 1
		_plugin.call("recordError", e[0], where)

## Hands every error Godot prints (script, engine, shader) to Firebase.
class ErrorLogger:
	extends Logger

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var message := rationale if rationale != "" else code
		Firebase._lock.lock()
		if Firebase._pending.size() < 50:
			Firebase._pending.append([message.left(300), "%s:%d %s" % [file.get_file(), line, function]])
		Firebase._lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass
