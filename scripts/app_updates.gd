class_name AppUpdates
extends Node
## Play in-app updates, through our Android plugin (SunstoneGoogleSignIn:
## checkUpdate / startUpdate / completeUpdate). Two ways in:
##
## - Required: this build is older than the server's minimum (/config
##   "minBuild", GAME_MIN_BUILD in sunstone-api) or the release was published
##   with update priority 4-5. Play's immediate flow takes over until it's
##   installed.
## - Offered: any other new build. Play's flexible flow asks once and then
##   downloads in the background, at most once a day; when the download is
##   done, [downloaded] fires and the title offers "Restart to update".
##
## Builds not installed from Play (debug, sideloaded) hear "nothing new".

signal downloaded ## an update waits for a restart

const OFFER_FILE := "user://update_offered"

var _plugin: Object
var _min_build := 0
var _info := {} ## the last answer: {available, priority, stale, flexible, immediate}
var _started := false
var is_ready := false

func _ready() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("SunstoneGoogleSignIn"):
		return
	_plugin = Engine.get_singleton("SunstoneGoogleSignIn")
	_plugin.connect("update_checked", _on_checked)
	_plugin.connect("update_downloaded", _on_downloaded)
	_plugin.connect("update_failed", func(reason: String): print("[update] %s" % reason))
	_plugin.call("checkUpdate")

## The server's oldest playable build: below it, the update is required.
func set_min_build(build: int) -> void:
	_min_build = build
	_decide()

## Installs the downloaded update; the app restarts into the new build.
func restart_into_update() -> void:
	if _plugin and is_ready:
		_plugin.call("completeUpdate")

func _on_checked(available: bool, priority: int, stale: int, flexible: bool, immediate: bool) -> void:
	_info = {"available": available, "priority": priority, "stale": stale, "flexible": flexible, "immediate": immediate}
	print("[update] available %s, priority %d, %d days old" % [available, priority, stale])
	_decide()

func _decide() -> void:
	if _plugin == null or _started or not _info.get("available", false):
		return
	var code := int(_plugin.call("versionCode"))
	var required: bool = (_min_build > 0 and code < _min_build) or int(_info.priority) >= 4
	if required and _info.immediate:
		_started = bool(_plugin.call("startUpdate", true))
		return
	if not _info.flexible:
		return
	# Offered at most once a day: the flexible flow asks before downloading.
	var today := MayaCalendar.today_local()
	var last := FileAccess.get_file_as_string(OFFER_FILE).strip_edges() if FileAccess.file_exists(OFFER_FILE) else ""
	if last == today:
		return
	var f := FileAccess.open(OFFER_FILE, FileAccess.WRITE)
	if f:
		f.store_string(today)
	_started = bool(_plugin.call("startUpdate", false))

func _on_downloaded() -> void:
	is_ready = true
	downloaded.emit()
