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
signal config_loaded(config: Dictionary)
signal account_changed ## this phone now uses another account, or a new way to sign in

## Debug builds talk to the API on the dev PC over the LAN; release builds to
## the hosted server. `files/api_base` on a device overrides both.
const DEV_BASE := "http://192.168.0.141:8395"
const PROD_BASE := "https://sunstone.pranta.dev"
const STATE_PATH := "user://online.json"
const OUTBOX_PATH := "user://outbox.json"
const ANDROID_PACKAGE := "com.pranta.sunstone"
const IOS_BUNDLE_ID := "com.pranta.sunstone"
## The Firebase project's OAuth *web* client — public, and what Google
## sign-in on Android asks for to mint a token Firebase accepts.
const GOOGLE_WEB_CLIENT_ID := "865615140000-9jk5kbkrjg2ip2lmckib1oohokvaiten.apps.googleusercontent.com"

signal _google_result(ok: bool, value: String, email: String)
signal _apple_result(ok: bool, value: String, email: String)

var base_url := DEV_BASE if OS.is_debug_build() else PROD_BASE
var player := {} ## {id, name, isAnonymous} once signed in
var reachable := false ## the last call to our server got an answer
var config := {} ## the server's switches: adsEnabled, interstitialEveryRuns, storeOpen…

var _api_key := ""
var _state := {} ## refresh_token, jwt, jwt_exp, player, save_revision, links
var _outbox: Array = []
var _events: Array = []
var _busy_session := false
var _save: SaveData
var _sync_pending := false
var _sync_running := false
var _apple_auth = null ## ASAuthorizationController (GodotApplePlugins), kept alive while it asks

func _ready() -> void:
	if FileAccess.file_exists("user://api_base"):
		base_url = FileAccess.get_file_as_string("user://api_base").strip_edges()
	_api_key = _read_api_key()
	_state = _read_json(STATE_PATH, {})
	# Older builds kept only the Google email (or an Apple label).
	if not _state.has("links") and (_state.has("google_email") or _state.has("apple_label")):
		_state.links = {"google.com": _state.google_email} if _state.has("google_email") else {"apple.com": _state.apple_label}
		_state.erase("google_email")
		_state.erase("apple_label")
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
		var c := await api(HTTPClient.METHOD_GET, "/config")
		if c.code == 200 and c.body is Dictionary:
			config = c.body
			config_loaded.emit(config)
		await sync_save()
		await _flush_outbox()
		await _refresh_links() # e.g. a sign-in method added from another phone

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
			{"grant_type": "refresh_token", "refresh_token": refresh}, _firebase_headers())
		if r.code == 200:
			_state.refresh_token = r.body.get("refresh_token", refresh)
			return str(r.body.get("id_token", ""))
		if r.code == 0:
			return "" # offline: keep the account, try later
	var s := await _http(HTTPClient.METHOD_POST, "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + _api_key,
		{"returnSecureToken": true}, _firebase_headers())
	if s.code != 200:
		return ""
	_state.refresh_token = s.body.get("refreshToken", "")
	_write_state()
	return str(s.body.get("idToken", ""))

## Firebase API keys can be restricted to our apps; say which app is asking.
func _firebase_headers() -> PackedStringArray:
	if OS.get_name() == "iOS":
		return PackedStringArray(["X-Ios-Bundle-Identifier: " + IOS_BUNDLE_ID])
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
			{"idToken": token}, _firebase_headers())
	_state = {}
	player = {}
	_outbox.clear()
	_write_state()
	_write_json(OUTBOX_PATH, _outbox)
	return true

# --------------------------------------------------------------- purchases

## {code, body}: 200 with {granted, drops, consume, entitlements}; 202 pending;
## 400/409 refused; 503/0 try later.
## store: "play" (token = Play purchase token) or "apple" (token = the
## StoreKit 2 signed transaction).
func verify_purchase(product_id: String, token: String, store := "play") -> Dictionary:
	return await api(HTTPClient.METHOD_POST, "/purchases/verify", {"productId": product_id, "purchaseToken": token, "store": store})

## What this player owns on the server, or null when it can't be reached.
func entitlements() -> Variant:
	var r := await api(HTTPClient.METHOD_GET, "/purchases/entitlements")
	return r.body.get("entitlements", []) if r.code == 200 and r.body is Dictionary else null

# --------------------------------------------------------------- accounts
#
# Every player starts as a guest (an anonymous Firebase account). To keep
# progress on any phone they add a way to sign in: Google (Android), Apple
# (iOS) or an email and password (everywhere). Adding one to a guest keeps
# the same account. Signing in to an account that already exists switches
# this phone to it, and the cloud save merges both, so nothing is lost.
# Signing out saves first, then the phone starts fresh as a new guest.

const IDENTITY := "https://identitytoolkit.googleapis.com/v1/accounts:"
const PROVIDERS := {"google.com": "Google", "apple.com": "Apple", "password": "email"}

## Who players keep their progress with here, besides email: Apple on iOS
## (App Store rule 4.8, and the natural choice there), Google elsewhere.
func provider_name() -> String:
	return "Apple" if OS.get_name() == "iOS" else "Google"

## The ways this account can sign in: Firebase provider id ("google.com",
## "apple.com", "password") → its email. Empty for a guest.
func links() -> Dictionary:
	var l: Variant = _state.get("links", {})
	return l if l is Dictionary else {}

func is_guest() -> bool:
	return links().is_empty()

## "Kept with Google: …" for the Account page; "" for a guest.
func linked_summary() -> String:
	var l := links()
	if l.has("google.com"):
		return "Kept with Google: %s" % l["google.com"]
	if l.has("apple.com"):
		return "Kept with Apple: %s" % l["apple.com"]
	if l.has("password"):
		return "Kept with your email: %s" % l["password"]
	return ""

## Signs in with this platform's provider (Google, or Apple on iOS).
## "" on success or a cancel, otherwise a sentence for the player.
func link_account() -> String:
	return await link_apple() if OS.get_name() == "iOS" else await link_google()

## Sign in with Apple (GodotApplePlugins' AuthenticationServices addon, iOS
## only; untyped so this script still parses where it doesn't exist), then
## link that Apple ID like a Google account. The plugin sets no nonce, so the
## token carries none and Firebase gets none.
func link_apple() -> String:
	if not ClassDB.class_exists("ASAuthorizationController"):
		return "Sign in with Apple isn't available on this device."
	_apple_auth = ClassDB.instantiate("ASAuthorizationController")
	var on_ok := func(credential) -> void:
		if credential == null or not ("identity_token" in credential):
			_apple_result.emit(false, "no Apple ID came back", "")
			return
		var token: String = (credential.identity_token as PackedByteArray).get_string_from_utf8()
		_apple_result.emit(token != "", token if token != "" else "no identity token", str(credential.email))
	var on_fail := func(error: String) -> void: _apple_result.emit(false, error, "")
	_apple_auth.connect("authorization_completed", on_ok)
	_apple_auth.connect("authorization_failed", on_fail)
	_apple_auth.signin_with_scopes(["email"])
	var got: Array = await _apple_result
	_apple_auth = null
	if not got[0]:
		# Apple reports a dismissed sheet as error 1001 ("canceled").
		var reason := str(got[1])
		return "" if "1001" in reason or "cancel" in reason.to_lower() else "Sign in with Apple didn't work: %s" % reason
	return await _link_idp("id_token=%s&providerId=apple.com" % got[1], "Apple")

## Signs in with Google (our Credential Manager plugin, Android).
func link_google() -> String:
	if not Engine.has_singleton("SunstoneGoogleSignIn"):
		return "Google sign-in isn't available on this device."
	var plugin := Engine.get_singleton("SunstoneGoogleSignIn")
	var on_ok := func(token: String, email: String): _google_result.emit(true, token, email)
	var on_fail := func(reason: String): _google_result.emit(false, reason, "")
	plugin.connect("signed_in", on_ok)
	plugin.connect("sign_in_failed", on_fail)
	plugin.signIn(GOOGLE_WEB_CLIENT_ID)
	var got: Array = await _google_result
	plugin.disconnect("signed_in", on_ok)
	plugin.disconnect("sign_in_failed", on_fail)
	if not got[0]:
		return "" if got[1] == "cancelled" else "Google sign-in didn't work: %s" % got[1]
	return await _link_idp("id_token=%s&providerId=google.com" % got[1], "Google")

## Links a Google / Apple token to this guest, or switches to the account
## that already owns it. postBody is the signInWithIdp body for it.
func _link_idp(post_body: String, provider: String) -> String:
	var body := {
		"postBody": post_body,
		"requestUri": "http://localhost", "returnSecureToken": true, "returnIdpCredential": true,
	}
	var current := await _firebase_id_token()
	if current != "":
		body["idToken"] = current # link to this guest instead of making a new account
	var r := await _http(HTTPClient.METHOD_POST, IDENTITY + "signInWithIdp?key=" + _api_key, body, _firebase_headers())
	var switched := false
	if r.code != 200:
		var message := _auth_message(r)
		if message.begins_with("FEDERATED_USER_ID_ALREADY_LINKED") or message.begins_with("EMAIL_EXISTS"):
			# That Google / Apple ID already has a Sunstone account: switch to it.
			body.erase("idToken")
			r = await _http(HTTPClient.METHOD_POST, IDENTITY + "signInWithIdp?key=" + _api_key, body, _firebase_headers())
			switched = true
		if r.code != 200:
			if r.code == 0:
				return "Couldn't reach %s right now. Try again in a moment." % provider
			return "%s sign-in was refused (%s)." % [provider, _auth_message(r)]
	print("[online] %s %s" % ["switched to the account of" if switched else "linked", provider])
	return await _adopt_session(str(r.body.get("refreshToken", "")), provider)

## Signs in to an existing email account. This phone switches to it; its
## progress so far merges into that account's save.
func email_sign_in(email: String, password: String) -> String:
	var bad := _check_credentials(email, password)
	if bad != "":
		return bad
	var r := await _http(HTTPClient.METHOD_POST, IDENTITY + "signInWithPassword?key=" + _api_key,
		{"email": email.strip_edges(), "password": password, "returnSecureToken": true}, _firebase_headers())
	if r.code != 200:
		return _auth_error(r)
	print("[online] signed in with email")
	return await _adopt_session(str(r.body.get("refreshToken", "")), "your email")

## Gives this guest an email and password: the same account, the same
## progress, now reachable from any phone.
func email_create(email: String, password: String) -> String:
	var bad := _check_credentials(email, password)
	if bad != "":
		return bad
	var token := await _firebase_id_token()
	if token == "":
		return "Can't reach the temple right now. Try again in a moment."
	# signUp with the guest's idToken links the email to it (the same uid).
	# accounts:update can't: with email enumeration protection on, Firebase
	# refuses to set an email that way ("verify the new email first").
	var r := await _http(HTTPClient.METHOD_POST, IDENTITY + "signUp?key=" + _api_key,
		{"idToken": token, "email": email.strip_edges(), "password": password, "returnSecureToken": true}, _firebase_headers())
	if r.code != 200:
		return _auth_error(r)
	print("[online] added an email to this account")
	return await _adopt_session(str(r.body.get("refreshToken", _state.get("refresh_token", ""))), "your email")

## Mails a password-reset link. Answers the same whether or not the email
## has an account, so nobody can probe for accounts.
func email_reset(email: String) -> String:
	if not _looks_like_email(email):
		return "Type the email you signed up with first."
	var r := await _http(HTTPClient.METHOD_POST, IDENTITY + "sendOobCode?key=" + _api_key,
		{"requestType": "PASSWORD_RESET", "email": email.strip_edges()}, _firebase_headers())
	if r.code == 200 or _auth_message(r).begins_with("EMAIL_NOT_FOUND"):
		return ""
	return _auth_error(r)

## Signs this phone out. Its progress goes to the cloud first; if it can't,
## nothing happens (so nothing is lost). The caller then starts the phone
## fresh: a new guest, a new save.
func sign_out() -> String:
	if is_guest():
		return "This phone isn't signed in to an account."
	await _flush_outbox()
	if not _outbox.is_empty() or not await sync_save():
		return "Can't reach the temple, so your latest progress isn't saved yet. Try again when you're online."
	print("[online] signed out")
	_state = {}
	player = {}
	_write_state()
	return ""

## Takes the session Firebase just handed us (another account, or this one
## with a new sign-in method): our JWT again, which methods it has, then the
## save merged both ways.
func _adopt_session(refresh_token: String, what: String) -> String:
	if refresh_token != "":
		_state.refresh_token = refresh_token
	_state.jwt = "" # re-exchange: the server records the account's new state
	_write_state()
	if not await ensure_session():
		return "Signed in with %s, but the temple can't be reached right now." % what
	await _refresh_links()
	await sync_save()
	account_changed.emit()
	return ""

## Asks Firebase which sign-in methods this account has (accounts:lookup).
func _refresh_links() -> void:
	var token := await _firebase_id_token()
	if token == "":
		return
	var r := await _http(HTTPClient.METHOD_POST, IDENTITY + "lookup?key=" + _api_key, {"idToken": token}, _firebase_headers())
	if r.code != 200 or not r.body is Dictionary or r.body.get("users", []).is_empty():
		return
	var found := {}
	for p in r.body.users[0].get("providerUserInfo", []):
		var id := str(p.get("providerId", ""))
		if PROVIDERS.has(id):
			var email := str(p.get("email", ""))
			found[id] = email if email != "" else ("your Apple ID" if id == "apple.com" else "your account")
	_state.links = found
	_write_state()

func _check_credentials(email: String, password: String) -> String:
	if not _looks_like_email(email):
		return "That doesn't look like an email address."
	if password.length() < 6:
		return "Passwords are at least 6 characters."
	return ""

static func _looks_like_email(email: String) -> bool:
	var e := email.strip_edges()
	var at := e.find("@")
	return at > 0 and e.find(".", at) > at + 1 and not e.ends_with(".") and not " " in e

static func _auth_message(r: Dictionary) -> String:
	return str(r.body.get("error", {}).get("message", "")) if r.body is Dictionary else ""

## Firebase's error codes, as sentences for a player.
static func _auth_error(r: Dictionary) -> String:
	if r.code == 0:
		return "Can't reach the temple right now. Try again in a moment."
	var m := _auth_message(r)
	if m.begins_with("INVALID_LOGIN_CREDENTIALS") or m.begins_with("INVALID_PASSWORD") or m.begins_with("EMAIL_NOT_FOUND"):
		return "That email and password don't match."
	if m.begins_with("EMAIL_EXISTS"):
		return "That email already has an account. Sign in instead."
	if m.begins_with("WEAK_PASSWORD"):
		return "Passwords are at least 6 characters."
	if m.begins_with("INVALID_EMAIL"):
		return "That doesn't look like an email address."
	if m.begins_with("TOO_MANY_ATTEMPTS"):
		return "Too many tries. Wait a little, then try again."
	if m.begins_with("USER_DISABLED"):
		return "This account has been switched off."
	if m.begins_with("OPERATION_NOT_ALLOWED"):
		return "Email sign-in isn't available right now."
	if m.begins_with("CREDENTIAL_TOO_OLD"):
		return "Please sign in again, then try that once more."
	return "Sign-in was refused (%s)." % m

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
## True when the cloud holds this phone's progress afterwards. A call made
## while one is running waits for it, then syncs again (it may have missed
## something newer).
func sync_save() -> bool:
	if _save == null:
		return false
	while _sync_running:
		await get_tree().process_frame
	_sync_running = true
	var ok := false
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
			ok = true
			break
		if put.code != 409:
			break
	_sync_running = false
	return ok

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

## The Firebase web API key: on iOS from GoogleService-Info.plist (the iOS
## app's config), otherwise — or if that's missing — from google-services.json.
## Both are gitignored and shipped with exports.
func _read_api_key() -> String:
	if OS.get_name() == "iOS" and FileAccess.file_exists("res://GoogleService-Info.plist"):
		var plist := FileAccess.get_file_as_string("res://GoogleService-Info.plist")
		var re := RegEx.create_from_string("<key>API_KEY</key>\\s*<string>([^<]+)</string>")
		var m := re.search(plist)
		if m:
			return m.get_string(1)
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
