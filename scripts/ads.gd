class_name Ads
extends Node
## Ads, only ever as an offer or a pause between runs — never during play.
##
## - Rewarded: the player chooses to watch (Second wind, double sun-drops,
##   double today's offering) and gets the reward only if they finish it.
## - Between runs (paced: never in the first runs, at most every Nth run, never
##   twice within a few minutes, never for players who removed ads):
##     * a rewarded interstitial when one is loaded — announced first by an
##       intro with the reward and a clear "No thanks" (AdMob policy), or
##     * a plain interstitial otherwise.
## - Consent (Google's UMP form, GDPR/CCPA) is asked before any ad is requested.
## - The server's /config switches ads on or off without a release.
## Debug builds always use Google's test ad units; live units come from the
## gitignored res://ads_config.json, per platform.

signal rewarded_ready_changed(ready: bool)

## Google's public test units — safe to load as often as you like.
const TEST_UNITS := {
	"android": {
		"rewarded": "ca-app-pub-3940256099942544/5224354917",
		"interstitial": "ca-app-pub-3940256099942544/1033173712",
		"rewarded_interstitial": "ca-app-pub-3940256099942544/5354046379",
	},
	"ios": {
		"rewarded": "ca-app-pub-3940256099942544/1712485313",
		"interstitial": "ca-app-pub-3940256099942544/4411468910",
		"rewarded_interstitial": "ca-app-pub-3940256099942544/6978759866",
	},
}
## Live units: {"android": {"rewarded", "interstitial", "rewarded_interstitial"},
## "ios": {…}} — gitignored, shipped with release builds. Missing → no ads.
const LIVE_CONFIG := "res://ads_config.json"

const FIRST_RUNS_FREE := 3 ## no ads between runs during a player's first runs
const MIN_GAP_SECONDS := 180.0
const BETWEEN_RUNS_REWARD := 50 ## sun-drops for watching a rewarded interstitial

var enabled := false ## from the server's /config
var interstitial_every := 4
var no_ads := false ## bought "Remove ads" (offers the player chooses stay)

var _live := {}
var _started := false
var _ready_to_load := false
var _rewarded: RewardedAd
var _interstitial: InterstitialAd
var _rewarded_interstitial: RewardedInterstitialAd
var _rewarded_loader: RewardedAdLoader
var _interstitial_loader: InterstitialAdLoader
var _ri_loader: RewardedInterstitialAdLoader
var _runs_since := 0
var _last_shown := -1000.0
## Dev: `files/dev_ads_eager` offers the between-runs ad after every run.
var _eager := FileAccess.file_exists("user://dev_ads_eager")

func _ready() -> void:
	if FileAccess.file_exists(LIVE_CONFIG):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIVE_CONFIG))
		_live = parsed if parsed is Dictionary else {}

func _platform() -> String:
	return "ios" if OS.get_name() == "iOS" else "android"

func _unit(kind: String) -> String:
	if OS.is_debug_build():
		return TEST_UNITS[_platform()][kind]
	var units: Variant = _live.get(_platform(), {})
	return str(units.get(kind, "")) if units is Dictionary else ""

## Called once the server config is known. Asks for consent, then starts ads.
func configure(ads_enabled: bool, every: int, removed: bool) -> void:
	enabled = ads_enabled and OS.get_name() in ["Android", "iOS"] and _unit("rewarded") != ""
	interstitial_every = maxi(every, 2)
	no_ads = removed
	if not enabled or _started:
		return
	_started = true
	# Google's consent flow: refresh what we know, show the form if this
	# player still has to choose, then start the SDK.
	var info := UserMessagingPlatform.consent_information
	info.update(ConsentRequestParameters.new(), func() -> void:
		if info.get_is_consent_form_available() and info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
			UserMessagingPlatform.load_consent_form(
				func(form: ConsentForm) -> void: form.show(func(_e: FormError) -> void: _init_sdk()),
				func(_e: FormError) -> void: _init_sdk())
		else:
			_init_sdk(),
		func(_e: FormError) -> void: _init_sdk())

## Lets the player revisit their ad privacy choices (from Settings).
func show_privacy_options() -> void:
	if _started:
		UserMessagingPlatform.show_privacy_options_form(func(_e: FormError) -> void: pass)

func privacy_options_required() -> bool:
	if not _started:
		return false
	var status := UserMessagingPlatform.consent_information.get_privacy_options_requirement_status()
	return status == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

func _init_sdk() -> void:
	# Never request ads while consent is still required and not given.
	if UserMessagingPlatform.consent_information.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		return
	var on_init := OnInitializationCompleteListener.new()
	on_init.on_initialization_complete = func(_s: InitializationStatus) -> void:
		_ready_to_load = true
		_load_rewarded()
		_load_interstitial()
		_load_rewarded_interstitial()
	MobileAds.initialize(on_init)

## Shows a full-screen ad that can pay a reward; returns true if it was earned.
func _show_paying(ad: Variant, placement: String) -> bool:
	var outcome := {"earned": false}
	var done := [false]
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content = func() -> void: done[0] = true
	callbacks.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: done[0] = true
	ad.full_screen_content_callback = callbacks
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void: outcome.earned = true
	ad.show(listener)
	while not done[0]:
		await get_tree().process_frame
	ad.destroy()
	print("[ads] %s: %s" % [placement, "earned" if outcome.earned else "skipped"])
	return outcome.earned

# ----------------------------------------------------------------- rewarded

func rewarded_ready() -> bool:
	return enabled and _rewarded != null

## Shows a rewarded ad; returns true only if the player earned the reward.
func show_rewarded(placement: String) -> bool:
	if not rewarded_ready():
		return false
	var ad := _rewarded
	_rewarded = null
	rewarded_ready_changed.emit(false)
	var earned := await _show_paying(ad, "rewarded " + placement)
	_load_rewarded()
	return earned

func _load_rewarded() -> void:
	if not _ready_to_load or _rewarded != null:
		return
	if _rewarded_loader == null:
		_rewarded_loader = RewardedAdLoader.new()
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded = ad
		rewarded_ready_changed.emit(true)
	cb.on_ad_failed_to_load = func(e: LoadAdError) -> void:
		print("[ads] rewarded failed to load: %s" % e.message)
		get_tree().create_timer(30.0).timeout.connect(_load_rewarded)
	_rewarded_loader.load(_unit("rewarded"), AdRequest.new(), cb)

# --------------------------------------------------------------- between runs

## What, if anything, to show as the player leaves a run's results:
## "offer" (a rewarded interstitial — show its intro first), "interstitial",
## or "" (nothing). Applies the pacing rules; call once per finished run.
func between_runs(total_runs: int) -> String:
	_runs_since += 1
	if not enabled or no_ads:
		return ""
	var now := Time.get_ticks_msec() / 1000.0
	if not _eager:
		if total_runs <= FIRST_RUNS_FREE or _runs_since < interstitial_every:
			return ""
		if now - _last_shown < MIN_GAP_SECONDS:
			return ""
	if _rewarded_interstitial == null and _interstitial == null:
		return ""
	_runs_since = 0
	_last_shown = now
	return "offer" if _rewarded_interstitial != null else "interstitial"

## The rewarded interstitial, after the player let its intro run out (or
## tapped Watch). Returns true when the reward was earned.
func show_rewarded_interstitial() -> bool:
	if _rewarded_interstitial == null:
		return false
	var ad := _rewarded_interstitial
	_rewarded_interstitial = null
	var earned := await _show_paying(ad, "rewarded interstitial")
	_load_rewarded_interstitial()
	return earned

func show_interstitial() -> void:
	if _interstitial == null:
		return
	var ad := _interstitial
	_interstitial = null
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_load_interstitial()
	callbacks.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		ad.destroy()
		_load_interstitial()
	ad.full_screen_content_callback = callbacks
	ad.show()

func _load_interstitial() -> void:
	if not _ready_to_load or no_ads or _interstitial != null or _unit("interstitial") == "":
		return
	if _interstitial_loader == null:
		_interstitial_loader = InterstitialAdLoader.new()
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void: _interstitial = ad
	cb.on_ad_failed_to_load = func(e: LoadAdError) -> void:
		print("[ads] interstitial failed to load: %s" % e.message)
		get_tree().create_timer(60.0).timeout.connect(_load_interstitial)
	_interstitial_loader.load(_unit("interstitial"), AdRequest.new(), cb)

func _load_rewarded_interstitial() -> void:
	if not _ready_to_load or no_ads or _rewarded_interstitial != null or _unit("rewarded_interstitial") == "":
		return
	if _ri_loader == null:
		_ri_loader = RewardedInterstitialAdLoader.new()
	var cb := RewardedInterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedInterstitialAd) -> void: _rewarded_interstitial = ad
	cb.on_ad_failed_to_load = func(e: LoadAdError) -> void:
		print("[ads] rewarded interstitial failed to load: %s" % e.message)
		get_tree().create_timer(60.0).timeout.connect(_load_rewarded_interstitial)
	_ri_loader.load(_unit("rewarded_interstitial"), AdRequest.new(), cb)
