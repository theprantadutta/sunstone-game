class_name Ads
extends Node
## Ads, only ever as an offer or a pause between runs — never during play.
##
## - Rewarded: the player chooses to watch (Second wind, double sun-drops,
##   double today's offering) and gets the reward only if they finish it.
## - Interstitial: between runs, paced (never in the first runs, at most every
##   Nth run, and never twice within a few minutes), and never for players who
##   removed ads.
## - Consent (Google's UMP form, GDPR/CCPA) is asked before any ad is requested.
## - The server's /config switches ads on or off without a release.
## Debug builds always use Google's test ad units.

signal rewarded_ready_changed(ready: bool)

## Google's public test units — safe to load as often as you like.
const TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"
## Real units: filled in when the AdMob app exists (release builds only).
const LIVE_REWARDED := ""
const LIVE_INTERSTITIAL := ""

const FIRST_RUNS_FREE := 3 ## no interstitials during a player's first runs
const MIN_GAP_SECONDS := 180.0

var enabled := false ## from the server's /config
var interstitial_every := 4
var no_ads := false ## bought "Remove ads" (rewarded offers stay — they're the player's choice)

var _started := false
var _ready_to_load := false
var _rewarded: RewardedAd
var _interstitial: InterstitialAd
var _rewarded_loader: RewardedAdLoader
var _interstitial_loader: InterstitialAdLoader
var _runs_since := 0
var _last_shown := -1000.0

func _rewarded_unit() -> String:
	return TEST_REWARDED if OS.is_debug_build() else LIVE_REWARDED

func _interstitial_unit() -> String:
	return TEST_INTERSTITIAL if OS.is_debug_build() else LIVE_INTERSTITIAL

## Called once the server config is known. Asks for consent, then starts ads.
func configure(ads_enabled: bool, every: int, removed: bool) -> void:
	enabled = ads_enabled and OS.get_name() == "Android" and _rewarded_unit() != ""
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
	return _started and UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() 		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

func _init_sdk() -> void:
	# Never request ads while consent is still required and not given.
	if UserMessagingPlatform.consent_information.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		return
	var on_init := OnInitializationCompleteListener.new()
	on_init.on_initialization_complete = func(_s: InitializationStatus) -> void:
		_ready_to_load = true
		_load_rewarded()
		_load_interstitial()
	MobileAds.initialize(on_init)

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
	print("[ads] rewarded %s: %s" % [placement, "earned" if outcome.earned else "skipped"])
	_load_rewarded()
	return outcome.earned

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
	_rewarded_loader.load(_rewarded_unit(), AdRequest.new(), cb)

# ------------------------------------------------------------- interstitial

## After a run ends: maybe show an interstitial, by the pacing rules.
## [total_runs] is the player's lifetime run count.
func after_run(total_runs: int) -> void:
	_runs_since += 1
	if not enabled or no_ads or _interstitial == null:
		return
	if total_runs <= FIRST_RUNS_FREE or _runs_since < interstitial_every:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_shown < MIN_GAP_SECONDS:
		return
	_runs_since = 0
	_last_shown = now
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
	if not _ready_to_load or no_ads or _interstitial != null:
		return
	if _interstitial_loader == null:
		_interstitial_loader = InterstitialAdLoader.new()
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void: _interstitial = ad
	cb.on_ad_failed_to_load = func(e: LoadAdError) -> void:
		print("[ads] interstitial failed to load: %s" % e.message)
		get_tree().create_timer(60.0).timeout.connect(_load_interstitial)
	_interstitial_loader.load(_interstitial_unit(), AdRequest.new(), cb)
