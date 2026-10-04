class_name Store
extends Node
## In-app purchases: Google Play Billing on Android, StoreKit 2 on iOS
## (apple_store.gd). Nothing is granted on the phone's word: every purchase
## goes to our server, which checks it (with Google, or Apple's signature) and
## grants it once; only then is it consumed / acknowledged on Play, or
## finished on the App Store. Unfinished purchases come back at launch, so a
## paid purchase is never lost.
##
## Product ids (the catalog in shop.gd) must match sunstone-api
## Purchases/Products.cs, Play Console and App Store Connect.

signal products_changed ## prices arrived (or the store closed)
signal purchase_finished(product_id: String, message: String)

const PRODUCTS := [
	{"id": "sunstone_remove_ads", "title": "Remove ads", "text": "No more ads between runs. Offers you choose stay.", "drops": 0},
	{"id": "sunstone_patron", "title": "Patron of the temple", "text": "No ads, 2,500 sun-drops and the Obsidian hue, yours alone.", "drops": 2500},
	{"id": "sunstone_drops_small", "title": "A pouch of sun-drops", "text": "1,000 sun-drops.", "drops": 1000},
	{"id": "sunstone_drops_medium", "title": "A jar of sun-drops", "text": "5,500 sun-drops.", "drops": 5500},
	{"id": "sunstone_drops_large", "title": "A chest of sun-drops", "text": "12,000 sun-drops.", "drops": 12000},
]

var open := false ## the server's switch (GAME_STORE_OPEN)
var prices := {} ## product id → formatted price from the store
var _billing: BillingClient
var _apple: Node ## apple_store.gd, on iOS
var _online: Online
var _save: SaveData

func setup(online: Online, save: SaveData) -> void:
	_online = online
	_save = save
	if OS.get_name() == "iOS":
		_apple = preload("res://scripts/apple_store.gd").new()
		add_child(_apple)
		_apple.prices_changed.connect(func():
			prices = _apple.prices
			products_changed.emit())
		_apple.transaction.connect(_finish_apple)
		_apple.purchase_failed.connect(func(id: String, message: String): purchase_finished.emit(id, message))
		if _apple.start(Shop.product_ids()):
			restore_owned()
		return
	if not Engine.has_singleton("GodotGooglePlayBilling"):
		return
	_billing = BillingClient.new()
	_billing.connected.connect(_on_connected)
	_billing.query_product_details_response.connect(_on_product_details)
	_billing.on_purchase_updated.connect(_on_purchases)
	_billing.query_purchases_response.connect(_on_purchases)
	_billing.start_connection()

## The store can sell right now.
func ready_to_sell() -> bool:
	if _apple != null:
		return open and _apple.ready_to_sell()
	return open and _billing != null and _billing.is_ready() and not prices.is_empty()

func buy(product_id: String) -> void:
	if not ready_to_sell():
		purchase_finished.emit(product_id, "The treasury is closed right now.")
		return
	if _apple != null:
		_apple.buy(product_id)
		return
	var r: Dictionary = _billing.purchase(product_id)
	if int(r.get("response_code", 0)) != BillingClient.BillingResponseCode.OK:
		purchase_finished.emit(product_id, "Google Play couldn't start the purchase.")

## Asks Play for anything bought but not finished (and the server for what
## this player owns) — the "Restore purchases" button, and every launch.
func restore() -> void:
	if _billing and _billing.is_ready():
		_billing.query_purchases(BillingClient.ProductType.INAPP)
	if _apple != null:
		_apple.restore()
	restore_owned()

## The App Store's rating sheet (iOS only; Android uses InappReview).
func request_review() -> void:
	if _apple != null:
		_apple.request_review()

## What the server says this player owns (no store involved).
func restore_owned() -> void:
	if _online:
		var owned: Variant = await _online.entitlements()
		if owned != null and _save.set_entitlements(owned):
			_save.save_to_disk()
			products_changed.emit()

func _on_connected() -> void:
	_billing.query_product_details(Shop.product_ids(), BillingClient.ProductType.INAPP)
	restore()

func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		return
	for d in response.get("product_details", []):
		var offer: Dictionary = d.get("one_time_purchase_offer_details", {})
		prices[str(d.get("product_id", ""))] = str(offer.get("formatted_price", ""))
	products_changed.emit()

func _on_purchases(response: Dictionary) -> void:
	var code := int(response.get("response_code", -1))
	if code == BillingClient.BillingResponseCode.USER_CANCELED:
		purchase_finished.emit("", "")
		return
	if code != BillingClient.BillingResponseCode.OK:
		return
	for p in response.get("purchases", []):
		await _finish(p)

## Verifies one purchase with the server, applies the grant, then completes
## it on Play. A pending payment is left alone until it clears.
func _finish(p: Dictionary) -> void:
	if int(p.get("purchase_state", 0)) != BillingClient.PurchaseState.PURCHASED:
		return
	var token := str(p.get("purchase_token", ""))
	var ids: Array = p.get("product_ids", [])
	if ids.is_empty() or token == "":
		return
	var product_id := str(ids[0])
	var r := await _verify(product_id, token, "play")
	if r.code != 200:
		return
	var body: Dictionary = r.body
	if body.get("consume", false):
		_billing.consume_purchase(token)
	elif not p.get("is_acknowledged", false):
		_billing.acknowledge_purchase(token)
	_granted(product_id, body)

## The App Store's version of _finish: verify the signed transaction, grant,
## then finish it so StoreKit stops handing it back.
func _finish_apple(product_id: String, jws: String, handle: Object) -> void:
	var r := await _verify(product_id, jws, "apple")
	# Refused for good (already granted to another account, or not genuine):
	# finish it too, or StoreKit replays it — and the error — every launch.
	if r.code == 200 or r.code == 400 or r.code == 409:
		_apple.finish(handle)
	if r.code == 200:
		_granted(product_id, r.body)

## Asks the server and applies the grant; returns {code, body}. Anything but
## 200 leaves the purchase to come back later (202 pending, 503 unavailable,
## 0 offline) or refused (400 not genuine, 409 someone else's).
func _verify(product_id: String, token: String, store_name: String) -> Dictionary:
	var res := await _online.verify_purchase(product_id, token, store_name)
	if res.code != 200:
		if res.code == 400 or res.code == 409:
			purchase_finished.emit(product_id, "That purchase couldn't be verified.")
		return res
	var body: Dictionary = res.body
	if body.get("granted", false):
		_save.bank += int(body.get("drops", 0))
	_save.set_entitlements(body.get("entitlements", []))
	_save.save_to_disk()
	_online.queue_sync()
	return res

func _granted(product_id: String, body: Dictionary) -> void:
	_online.track("purchase", {"product": product_id, "granted": body.get("granted", false)})
	products_changed.emit()
	purchase_finished.emit(product_id, "Thank you, patron." if product_id == "sunstone_patron" else "Received.")
