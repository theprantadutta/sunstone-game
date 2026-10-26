class_name Push
extends Node
## Notifications: this phone's Firebase Cloud Messaging token, the player's
## switch (save.push_on) and the phone's clock, kept current on the server
## (PUT /push/device), which decides what to send and when (sunstone-api
## Push/PushPlanner: dusk reminders, come-back nudges, being passed on the
## daily dusk, seasonal events — never at night, at most one a day).
##
## Android only for now, through our plugin (initPush, requestPushPermission,
## pushAllowed, openNotificationSettings). The game asks once, after the
## second run, with its own page first; Settings has the switch after that.

signal changed ## the switch or the permission changed (Settings redraws)

const SENT_PATH := "user://push.json" ## what the server last heard: skip repeats

var token := ""
var _plugin: Object
var _online: Online
var _save: SaveData

func setup(online: Online, save: SaveData) -> void:
	_online = online
	_save = save
	if OS.get_name() != "Android" or not Engine.has_singleton("SunstoneGoogleSignIn"):
		return
	_plugin = Engine.get_singleton("SunstoneGoogleSignIn")
	_plugin.connect("push_token", _on_token)
	_plugin.connect("push_permission", _on_permission)
	# Another account on this phone: register it for that one.
	_online.signed_in.connect(func(_p: Dictionary): register())
	_online.account_changed.connect(register)
	var cfg := _firebase_config()
	if not cfg.is_empty():
		_plugin.call("initPush", cfg.app_id, cfg.api_key, cfg.project_id, cfg.sender_id)

## True where notifications exist at all (the Settings switch shows only then).
func available() -> bool:
	return _plugin != null

## Whether the phone lets them show (permission given, not blocked).
func allowed() -> bool:
	return _plugin != null and bool(_plugin.call("pushAllowed"))

## The player said yes (the ask page, or the Settings switch turned on).
func turn_on() -> void:
	if _plugin == null:
		return
	_save.push_asked = true
	if allowed():
		_switch(true)
		return
	if _save.push_denied:
		# Android won't ask twice: the phone's own settings page instead.
		_plugin.call("openNotificationSettings")
		_switch(true)
		return
	_plugin.call("requestPushPermission")

func turn_off() -> void:
	_save.push_asked = true
	_switch(false)

## Tells the server about this phone when anything it knows has changed.
func register(force := false) -> void:
	if _plugin == null or token == "" or _online == null or _online.player.is_empty():
		return
	var body := {
		"token": token, "platform": "android", "enabled": _save.push_on and allowed(),
		"tzOffsetMinutes": int(Time.get_time_zone_from_system().get("bias", 0)),
		"appVersion": str(ProjectSettings.get_setting("application/config/version", "")),
	}
	var key := JSON.stringify([body, _online.player.get("id", "")])
	if not force and FileAccess.file_exists(SENT_PATH) and FileAccess.get_file_as_string(SENT_PATH) == key:
		return
	var res: Dictionary = await _online.api(HTTPClient.METHOD_PUT, "/push/device", body)
	if res.code == 204:
		var f := FileAccess.open(SENT_PATH, FileAccess.WRITE)
		if f:
			f.store_string(key)

func _switch(on: bool) -> void:
	_save.push_on = on
	_save.save_to_disk()
	register(true)
	changed.emit()

func _on_token(t: String) -> void:
	token = t
	_online.push_token = t
	if t != "":
		register()

func _on_permission(granted: bool) -> void:
	if not granted:
		_save.push_denied = true
	_switch(granted)

## Firebase's ids for this app, from google-services.json (shipped, gitignored).
func _firebase_config() -> Dictionary:
	if not FileAccess.file_exists("res://google-services.json"):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://google-services.json"))
	if not d is Dictionary or not d.has("client"):
		return {}
	for c in d.client:
		if c.client_info.android_client_info.package_name == Online.ANDROID_PACKAGE and not c.api_key.is_empty():
			return {"app_id": str(c.client_info.mobilesdk_app_id), "api_key": str(c.api_key[0].current_key),
				"project_id": str(d.project_info.project_id), "sender_id": str(d.project_info.project_number)}
	return {}
