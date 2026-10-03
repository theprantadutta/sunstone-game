extends Node
## StoreKit 2 for Store (iOS), through GodotApplePlugins' StoreKit addon.
## The plugin's classes exist only on Apple platforms, so this script never
## names them: everything is untyped and found with ClassDB, and it parses
## (and quietly does nothing) on Android.
##
## Every transaction — a purchase, one left unfinished last time, a restore —
## comes out of `transaction` with its signed JWS. Store sends that to our
## server and calls finish() once the grant is safe; until then StoreKit hands
## it back at every launch.

signal prices_changed
signal transaction(product_id: String, jws: String, handle: Object)
signal purchase_failed(product_id: String, message: String) ## message "" = cancelled

## StoreKitManager.StoreKitStatus
const OK := 0
const USER_CANCELLED := 4
const PURCHASE_PENDING := 5

var prices := {} ## product id → localized price
var _kit = null ## StoreKitManager
var _products := {} ## product id → StoreProduct (only these can be bought)

## Starts listening for transactions and asks for the products' prices.
## False when StoreKit isn't here (not iOS, or the addon isn't installed).
func start(ids: PackedStringArray) -> bool:
	if not ClassDB.class_exists("StoreKitManager"):
		return false
	_kit = ClassDB.instantiate("StoreKitManager")
	_kit.connect("products_request_completed", _on_products)
	_kit.connect("purchase_completed", _on_purchase)
	_kit.connect("transaction_updated", _on_transaction)
	_kit.connect("restore_completed", func(_status: int, _message: String) -> void: _kit.fetch_current_entitlements())
	_kit.start() # also re-delivers unfinished transactions
	_kit.request_products(ids)
	return true

func ready_to_sell() -> bool:
	return _kit != null and not _products.is_empty()

func buy(product_id: String) -> void:
	var product = _products.get(product_id)
	if product == null:
		purchase_failed.emit(product_id, "The App Store doesn't know that offering yet.")
		return
	_kit.purchase(product)

## Restore purchases: syncs with the App Store, then replays what this Apple
## ID owns (remove ads, patron) through `transaction`.
func restore() -> void:
	if _kit != null:
		_kit.restore_purchases()

func finish(handle: Object) -> void:
	if handle != null:
		handle.call("finish")

## The App Store's rating sheet. Not in the plugin's desktop stubs, hence call().
func request_review() -> void:
	if _kit != null and _kit.has_method("request_review"):
		_kit.call("request_review")

func _on_products(products: Array, _status: int) -> void:
	for p in products:
		_products[str(p.product_id)] = p
		prices[str(p.product_id)] = str(p.display_price)
	prices_changed.emit()

func _on_purchase(t, status: int, error_message: String) -> void:
	match status:
		OK:
			if t != null:
				transaction.emit(str(t.product_id), str(t.jws_representation), t)
		USER_CANCELLED:
			purchase_failed.emit("", "")
		PURCHASE_PENDING:
			purchase_failed.emit("", "Waiting for approval. It'll arrive once it's approved.")
		_:
			purchase_failed.emit("", "The App Store couldn't finish the purchase. %s" % error_message)

func _on_transaction(t) -> void:
	if t == null:
		return
	if float(t.revocation_date) > 0.0:
		t.call("finish") # refunded: nothing to grant (the server would refuse it anyway)
		return
	transaction.emit(str(t.product_id), str(t.jws_representation), t)
