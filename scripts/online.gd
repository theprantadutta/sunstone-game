class_name Online
extends Node
## Everything that talks to the outside world: Firebase Auth (over its REST
## API — there is no Firebase SDK in Godot) and our server, sunstone-api.
##
## - Sign-in is silent: a first launch becomes an anonymous Firebase user; the
##   Firebase ID token is exchanged for our own JWT (POST /auth/firebase).
## - Finished runs go to an outbox on disk and are sent when the server can be
##   reached; the server ignores a run it has already seen.
## - The save follows the player: merged with the server copy, written back
##   with the revision it was based on (409 → merge again).
## - Analytics events are batched.
## Nothing here ever blocks play: offline, the game simply keeps going.

signal signed_in(player: Dictionary)
signal save_merged ## the local save took in progress from the cloud

## Debug builds talk to the API on the dev PC over the LAN; release builds to
## the hosted server. `files/api_base` on a device overrides both.
const DEV_BASE := "http://192.168.0.141:8395"
const PROD_BASE := "https://sunstone.pranta.dev"
const STATE_PATH := "user://online.json"
const OUTBOX_PATH := "user://outbox.json"
const ANDROID_PACKAGE := "com.pranta.sunstone"

var base_url := DEV_BASE if OS.is_debug_build() else PROD_BASE
var player := {} ## {id, name, isAnonymous} once signed in
var reachable := false ## the last call to our server got an answer

var _api_key := ""
var _state := {} ## refresh_token, jwt, jwt_exp, player, save_revision
var _outbox: Array = []
var _events: Array = []
var _busy_session := false
var _save: SaveData
var _sync_pending := false
var _sync_running := false

func _ready() -> void:
	if FileAccess.file_exists("user://api_base"):
		base_url = FileAccess.get_file_as_string("user://api_base").strip_edges()
	_api_key = _read_api_key()
	_state = _read_json(STATE_PATH, {})
	var ob: Variant = _read_json(OUTBOX_PATH, [])
	_outbox = ob if ob is Array else []
	player = _state.get("player", {})
	var flush := Timer.new()
	flush.wait_time = 30.0
	flush.autostart = true
	flush.timeout.connect(func(): _flush_events())
	add_child(flush)

## Starts the session and the first save sync. Call once at launch.
func start(save: SaveData) -> void:
	_save = save
	if await ensure_session():
		await sync_save()
		await _flush_outbox()

# ----------------------------------------------------------------- session

## Makes sure we hold a valid JWT, signing in silently if needed.
func ensure_session() -> bool:
	if _state.get("jwt", "") != "" and float(_state.get("jwt_exp", 0.0)) > Time.get_unix_time_from_system() + 120.0:
		return true
	if _busy_session:
		while _busy_session:
			await get_tree().process_frame
		return _state.get("jwt", "") != ""
	_busy_session = true
	var ok := await _sign_in()
	_busy_session = false
	return ok

func _sign_in() -> bool:
	if _api_key == "":
		return false
	var id_token := await _firebase_id_token()
	if id_token == "":
		return false
	var res := await _http(HTTPClient.METHOD_POST, base_url + "/api/v1/auth/firebase", {"idToken": id_token}, [])
	reachable = res.code != 0
	if res.code != 200:
		return false
	var body: Dictionary = res.body
	_state.jwt = body.token
	# Our tokens live 7 days; renew after 6 without parsing the server's clock.
	_state.jwt_exp = Time.get_unix_time_from_system() + 6.0 * 86400.0
	player = body.player
	_state.player = player
	_write_state()
	print("[online] signed in as %s (guest: %s)" % [player.get("name", "?"), player.get("isAnonymous", "?")])
	signed_in.emit(player)
	return true

## A fresh Firebase ID token: from the stored refresh token, or a new
## anonymous account on first launch.
func _firebase_id_token() -> String:
	var refresh: String = _state.get("refresh_token", "")
	if refresh != "":
		var r := await _http(HTTPClient.METHOD_POST, "https://securetoken.googleapis.com/v1/token?key=" + _api_key,
			{"grant_type": "refresh_token", "refresh_token": refresh}, _android_headers())
		if r.code == 200:
			_state.refresh_token = r.body.get("refresh_token", refresh)
			return str(r.body.get("id_token", ""))
		if r.code == 0:
			return "" # offline: keep the account, try later
	var s := await _http(HTTPClient.METHOD_POST, "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + _api_key,
		{"returnSecureToken": true}, _android_headers())
	if s.code != 200:
		return ""
	_state.refresh_token = s.body.get("refreshToken", "")
	_write_state()
	return str(s.body.get("idToken", ""))

func _android_headers() -> PackedStringArray:
	return PackedStringArray(["X-Android-Package: " + ANDROID_PACKAGE])

## An authorized call to our API; retries once with a fresh session on 401.
## Returns {code, body}; code 0 = unreachable.
func api(method: int, path: String, body: Variant = null) -> Dictionary:
	if not await ensure_session():
		return {"code": 0, "body": {}}
	var res := await _http(method, base_url + "/api/v1" + path, body, ["Authorization: Bearer " + str(_state.jwt)])
	if res.code == 401:
		_state.jwt = ""
		if await ensure_session():
			res = await _http(method, base_url + "/api/v1" + path, body, ["Authorization: Bearer " + str(_state.jwt)])
	reachable = res.code != 0
	return res

# -------------------------------------------------------------------- runs

## Queues a finished run and tries to send it (and anything older) now.
func submit_run(run: Dictionary) -> void:
	run.runId = _uuid()
	run.endedAt = Time.get_datetime_string_from_system(true) + "Z"
	run.appVersion = str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	_outbox.append(run)
	_write_json(OUTBOX_PATH, _outbox)
	await _flush_outbox()

func _flush_outbox() -> void:
	while not _outbox.is_empty():
		var res := await api(HTTPClient.METHOD_POST, "/runs", _outbox[0])
		if res.code == 0 or res.code >= 500 or res.code == 401:
			return # try again later
		print("[online] run sent: %d" % res.code)
		_outbox.pop_front() # accepted, duplicate, or rejected as impossible
		_write_json(OUTBOX_PATH, _outbox)

# ------------------------------------------------------------ leaderboards

## {name, period, players, top[], me} or {} when the server can't be reached.
func leaderboard(board: String, period := "") -> Dictionary:
	var path := "/leaderboards/" + board + ("?period=" + period if period != "" else "")
	var res := await api(HTTPClient.METHOD_GET, path)
	return res.body if res.code == 200 and res.body is Dictionary else {}

func rename(new_name: String) -> String:
	var res := await api(HTTPClient.METHOD_PATCH, "/me", {"name": new_name})
	if res.code == 200:
		player = res.body
		_state.player = player
		_write_state()
		return ""
	if res.code == 0:
		return "Can't reach the temple right now."
	return "Use 3 to 28 letters, digits or spaces."

## Deletes the account everywhere: our server, then the Firebase user, then
## the session on this phone. True when the server confirmed.
func delete_account() -> bool:
	var res := await api(HTTPClient.METHOD_DELETE, "/me")
	if res.code != 204 and res.code != 404:
		return false
	var token := await _firebase_id_token()
	if token != "":
		await _http(HTTPClient.METHOD_POST, "https://identitytoolkit.googleapis.com/v1/accounts:delete?key=" + _api_key,
			{"idToken": token}, _android_headers())
	_state = {}
	player = {}
	_outbox.clear()
	_write_state()
	_write_json(OUTBOX_PATH, _outbox)
	return true

# -------------------------------------------------------------- cloud save

## Asks for a save sync soon (coalesces bursts, e.g. several claims).
func queue_sync() -> void:
	if _sync_pending:
		return
	_sync_pending = true
	await get_tree().create_timer(4.0).timeout
	_sync_pending = false
	await sync_save()

## Merges the cloud copy into the local save and writes the result back.
func sync_save() -> void:
	if _save == null or _sync_running:
		return
	_sync_running = true
	for attempt in 3:
		var got := await api(HTTPClient.METHOD_GET, "/save")
		if got.code == 0:
			break
		var rev := 0
		if got.code == 200:
			rev = int(got.body.get("revision", 0))
			if _save.merge_from(got.body.get("data", {})):
				_save.save_to_disk()
				save_merged.emit()
		var put := await api(HTTPClient.METHOD_PUT, "/save", {"data": _save.to_dict(), "baseRevision": rev})
		if put.code == 200:
			print("[online] cloud save at revision %s" % put.body.get("revision", "?"))
			_state.save_revision = int(put.body.get("revision", rev + 1))
			_write_state()
			break
		if put.code != 409:
			break
	_sync_running = false

# --------------------------------------------------------------- analytics

func track(event: String, props := {}) -> void:
	_events.append({"name": event, "at": Time.get_datetime_string_from_system(true) + "Z", "props": props})
	if _events.size() >= 20:
		_flush_events()

func _flush_events() -> void:
	if _events.is_empty() or _state.get("jwt", "") == "":
		return
	var batch := _events.slice(0, 50)
	_events = _events.slice(50)
	var res := await api(HTTPClient.METHOD_POST, "/events", batch)
	if res.code == 0:
		_events = batch + _events # keep them for the next try
		if _events.size() > 200:
			_events = _events.slice(_events.size() - 200)

# ----------------------------------------------------------------- plumbing

## One HTTP call. Returns {code, body}: code 0 when nothing answered.
func _http(method: int, url: String, body: Variant, headers: Array) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 12.0
	add_child(req)
	var h := PackedStringArray(headers)
	var payload := ""
	if body != null:
		h.append("Content-Type: application/json")
		payload = JSON.stringify(body)
	if req.request(url, h, method, payload) != OK:
		req.queue_free()
		return {"code": 0, "body": {}}
	var r: Array = await req.request_completed
	req.queue_free()
	var result: int = r[0]
	var code: int = r[1]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": {}}
	var text := (r[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if text.length() > 0 else {}
	return {"code": code, "body": parsed if parsed != null else {}}

func _read_api_key() -> String:
	var d: Variant = _read_json("res://google-services.json", {})
	if d is Dictionary and d.has("client"):
		for c in d.client:
			if c.client_info.android_client_info.package_name == ANDROID_PACKAGE and not c.api_key.is_empty():
				return str(c.api_key[0].current_key)
	return ""

static func _uuid() -> String:
	var b := PackedByteArray()
	for i in 16:
		b.append(randi() % 256)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

func _write_state() -> void:
	_write_json(STATE_PATH, _state)

static func _read_json(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		return fallback
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v != null else fallback

static func _write_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
