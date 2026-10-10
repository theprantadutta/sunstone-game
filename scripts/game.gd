extends Node3D
## Sunstone — carry the sun through Xibalba. Owns the state machine (title →
## running → dying → results), the run itself (three lanes: swipe to move,
## jump and slide, tap to flare), the light, the jaguars and bats, the camera,
## and hands numbers to the UI.
##
## The thumb rests between moves. Swipes dodge: left and right change lane, up
## jumps low walls and pits, down slides under lintels. A tap flares the
## Sunstone — its light thrown far down the road, the jaguars frozen to stone —
## but each flare spends light, and light is all that keeps the dark away.
## Hitting a danger head-on ends the run.

enum State { TITLE, RUNNING, PAUSED, DYING, OFFER, RESULTS }

## The rules a run is played by, sent with it (sunstone-api RunRules): 1 was
## hold to blaze, 2 is the lanes. Bump it when old scores stop being comparable.
const RULESET := 2
const START_S := -3.0
const DRAIN := 0.02 ## light per second
const FLARE_COST := 0.15 ## light a flare spends
const FLARE_TIME := 2.2 ## seconds a flare burns
const FLARE_CD := 0.45 ## seconds before the next flare
const FLARE_R := 11.0 ## metres of light at the height of a flare...
const FLARE_AHEAD := 8.0 ## ...centred this far down the road
const GLOW := 2.1 ## the stone's own light, times the House's ember radius
const LANE_EASE := 17.0 ## how fast he crosses to a new lane
const JUMP_V := 8.0 ## m/s up: a 1.2 m, 0.6 s leap
const GRAVITY := 26.0
const DIVE_V := -18.0 ## swiping down in the air drops him like a stone
const SLIDE_T := 0.65
const WALL_CLEAR := 0.5 ## feet higher than this clear a low wall
const STUMBLE_LIGHT := 0.12 ## light lost when he clips something
const STUMBLE_WINDOW := 6.0 ## a second stumble this soon is the end
const RUNNER_HALF := 0.35 ## half his width, for clipping
const DASH_M := 300.0 ## the head start: metres the sun carries him...
const DASH_MUL := 2.6 ## ...at this many times his speed...
const DASH_Y := 3.1 ## ...this high, over every stela and lintel
const DROP_LIGHT := 0.014 ## a sun-drop keeps the stone burning, barely
const DAWN_GIFT := 0.35 ## light the sunrise gives back
const DROP_R := 0.85
const CATCH_R := 0.75
const JAG_CREEP := 3.0 ## m/s, a jaguar in the road coming at you
const JAG_LEAP := 0.4 ## seconds a jaguar is in the air, curb to lane
const SIGHT_MIN := 8.0 ## metres past the light he sees even with a dying stone...
const SIGHT_LIGHT := 14.0 ## ...and this much more with a full one
const PACK_FAR := 13.0 ## metres behind: out of sight
const PACK_NEAR := 1.9 ## right at his heels, in view
const PACK_CATCH := 0.7
const BAT_SPEED := 7.3
const BAT_STEAL := 0.2
const BAT_HIT_R := 0.75
const AMB_FULL := 60.0 ## radius of daylight: the whole screen
const STRING_BONUS := 3 ## extra sun-drops for taking a whole trail
## What drifts in the air of each House: colour, fall speed (+ rises), size.
const MOTES := {
	"jungle": [Color("#FFE08A"), 0.05, 0.09], "jaguars": [Color("#FFC860"), 0.05, 0.09],
	"bats": [Color("#C9A0FF"), 0.0, 0.08], "gloom": [Color("#C8CCD8"), -0.15, 0.07],
	"knives": [Color("#FF8A6A"), 0.1, 0.06], "cold": [Color("#FFFFFF"), -0.9, 0.08],
	"fire": [Color("#FFA040"), 0.9, 0.07],
}
const CAM_UP := 6.6
const CAM_BACK := 6.6
const CAM_AHEAD := 10.0
const SWIPE_MIN := 0.045 ## of the screen's short side: a move this long is a swipe
const TAP_MAX_T := 0.3 ## seconds: a touch shorter than this, that didn't swipe, flares
const NIGHT_BG := Color("#0E1230")
const DUSK_BG := Color("#B9765A")
const DAWN_BG := Color("#E7AE72")

var state := State.TITLE

var world: World
var runner: RunnerModel
var camera: Camera3D
var ui: GameUI
var online: Online
var ads: Ads
var store: Store
var review: InappReview
var sfx: Sfx
var save := SaveData.new()

# --- the run ---
var s := START_S ## metres along the road
var x := 0.0 ## world x (across)
var y := 0.0 ## height, only while falling
var vy := 0.0
var speed := 0.0
var distance := 0.0
var coins := 0 ## sun-drops this run
var light := 1.0 ## the Sunstone's charge, 0..1
var blaze := 0.0 ## how much of a flare is burning, 0..1
var light_r := 2.0 ## metres of light around him right now
var amb := AMB_FULL ## daylight radius (dusk and dawn)
var daily_key := "" ## set while running the daily dusk ("yyyy-mm-dd")
var death_cause := ""
var _run_flares := 0 ## how many times he flared
var _jumps := 0
var _slides := 0
var _stumbles := 0
var _lane := 0 ## the lane he's in or heading for: −1, 0, 1
var _lane_from := 0 ## the lane he left (a clip sends him back)
var _u := 0.0 ## metres across the road, easing toward his lane
var _slide_t := 0.0
var _flare_t := 0.0
var _flare_cd := 0.0
var _stumble_t := 99.0 ## seconds since the last stumble
var _light_c := Vector3.ZERO ## the centre of his circle of light
var _sight := 1000.0 ## metres past which the night swallows the road
var _pack := PACK_FAR ## how far behind him the jaguar pack runs
var _pack_nodes: Array[JaguarModel] = []
var _pack_u: Array[float] = [] ## each cat's place across the road, eased
var _pack_caught := false
var _dash_to := 0.0 ## > 0 while the head start carries him: where it ends
var _head_start := 0.0 ## metres the head start carried him this run
var _run_time := 0.0
var _second_wind_used := false
var _shield_t := 0.0
var _fell := false
var _caught := false
var _recovered := false ## nearly went out, then lit up again
var _was_low := false
var _death_t := 0.0
var _x_vel := 0.0
var _x_vel_s := 0.0 ## smoothed: what his heading and lean follow
var _yaw := 0.0
var _lean := 0.0
var _attraction := 0.0 ## how much the bats want you
var _house_key := ""
var _hints := {}
var _coach := "" ## the move being taught right now (time runs slow until it's made)
var _act_t := -9.0 ## when he last moved, jumped or slid (close calls)
var _close := 0 ## close calls this run
var _combo := 0 ## close calls in a row without a stumble
var _growl_cd := 0.0
var _jags: Array[Dictionary] = [] ## {node, pos, frozen, linger}
var _bats: Array[Dictionary] = [] ## {node, rel, vel, gone, flee, life}
var _lights := PackedVector4Array()
var _strings := {} ## trail id → drops taken from it
var _motes: CPUParticles3D
var _mote_set := ""
var _halo: MeshInstance3D
var _halo_mat: StandardMaterial3D
var _env: Environment
var _cam_x := 0.0
var _title_t := 0.0
var _intro_t := 1.0
var _shake := 0.0
var _time := 0.0

# --- touch ---
var _touch_index := -1
var _touch_from := Vector2.ZERO ## where the current swipe began
var _touch_t0 := 0.0
var _swiped := false
var _slide_queued := false

## Dev-only: `-- --autopilot` (or `files/autopilot` on a device) plays by itself.
var _autopilot := OS.get_cmdline_user_args().has("--autopilot") or FileAccess.file_exists("user://autopilot")
## Dev: `files/dev_noflare` — the autopilot never flares.
var _dev_noflare := FileAccess.file_exists("user://dev_noflare")
## Dev: `files/dev_pack` — the pack runs at his heels the whole run.
var _dev_pack := FileAccess.file_exists("user://dev_pack")
## Dev: `files/dev_start` holding metres starts every run that far along.
var _dev_start := FileAccess.get_file_as_string("user://dev_start").to_float() if FileAccess.file_exists("user://dev_start") else 0.0
var _auto_cd := 0.0
## Profiling: a build with the "profile" feature (export preset "Android
## Profile") — or `files/profile_tour` on a debug build — tours every screen
## and runs through every House by itself, printing frame stats per phase
## ("[profile] ..." in logcat). The runner can't die during the tour.
var _tour := OS.has_feature("profile") or FileAccess.file_exists("user://profile_tour")
var _invincible := false
## Dev: `files/dev_shots` stages the store screenshots one by one (default
## look, no event, can't die), freezing each and printing "[shot] name" so
## the host can screencap it. The save is never touched.
var _shots := FileAccess.file_exists("user://dev_shots")
var _force_blaze := -1.0 ## >= 0 holds a flare at that strength (shots)
var _tour_seed := 0 ## the tour plays the same road every time
var _page_scaled := false
var _render_scale := 1.0
var _ph := ""
var _ph_frames := 0
var _ph_time := 0.0
var _ph_max := 0.0
var _ph_j20 := 0
var _ph_j33 := 0
var _ph_draws := 0.0
var _ph_prims := 0.0
var _ph_proc := 0.0
## What happened in a frame, so a slow one can say why ("[spike]" lines).
var _events: PackedStringArray = []
var _prev_events: PackedStringArray = []
var _attached_seen := 0
var _fps_t := 0.0
var _prof_n := 0
var _prof_max_dt := 0.0
var _prof_jit := 0.0 ## biggest frame-to-frame twist of his body (rad)
var _prof_last_rot := Vector3.ZERO

func _ready() -> void:
	save.load_from_disk()
	online = Online.new()
	add_child(online)
	ads = Ads.new()
	add_child(ads)
	store = Store.new()
	add_child(store)
	review = InappReview.new()
	add_child(review)
	review.review_info_generated.connect(func(): review.launch_review_flow())
	online.config_loaded.connect(func(c: Dictionary):
		ads.configure(c.get("adsEnabled", false), int(c.get("interstitialEveryRuns", 4)), save.has_entitlement("no_ads"))
		store.open = c.get("storeOpen", false)
		# The server may switch a seasonal event on or off.
		var before := Themes.event_id()
		Themes.choose_event(str(c.get("event", "")))
		if Themes.event_id() != before and state == State.TITLE:
			_build_sky()
			_spawn_runner()
			_go_title())
	Themes.choose_event("")
	_make_environment()
	world = World.new()
	add_child(world)
	world.chunk_added.connect(_on_chunk)
	_make_halo()
	_make_motes()
	_spawn_runner()
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 52.0
	camera.near = 0.3
	camera.far = 140.0
	add_child(camera)
	sfx = Sfx.new()
	add_child(sfx)
	sfx.apply_settings(save)
	ui = GameUI.new()
	add_child(ui)
	ui.run_pressed.connect(_start_run)
	ui.daily_pressed.connect(_start_daily)
	ui.looks_changed.connect(_spawn_runner)
	# Signed out or deleted: a fresh save, then a new guest.
	ui.account_reset.connect(func():
		ads.no_ads = save.has_entitlement("no_ads")
		_spawn_runner()
		if state == State.TITLE:
			ui.show_title(save)
		online.start(save))
	ui.dash_pressed.connect(_dash)
	ui.second_wind_accepted.connect(_second_wind)
	ui.second_wind_by_ad.connect(func(): _second_wind(true))
	ui.second_wind_declined.connect(func():
		if state == State.OFFER:
			_finish_run())
	ui.pause_pressed.connect(_pause)
	ui.resume_pressed.connect(_resume)
	ui.home_pressed.connect(func():
		if state == State.RESULTS:
			_leave_results(_go_title)
		else:
			_go_title())
	ui.again_pressed.connect(func(): _leave_results(_restart))
	ui.settings_changed.connect(_on_settings_changed)
	ui.back_requested.connect(_on_back)
	ui.setup(save, online, ads, store)
	ui.set_flare_cost(FLARE_COST + 0.03)
	store.setup(online, save)
	store.products_changed.connect(func():
		ads.no_ads = save.has_entitlement("no_ads"))
	# Signed in to another account (or linked one): what it owns, its looks.
	online.account_changed.connect(func():
		store.restore_owned()
		ads.no_ads = save.has_entitlement("no_ads")
		if state == State.TITLE:
			_spawn_runner()
			ui.show_title(save))
	# Progress from another phone arrived: show it.
	online.save_merged.connect(func():
		if state == State.TITLE:
			_spawn_runner()
			ui.show_title(save))
	online.start(save)
	if FileAccess.file_exists("user://perf_noui"):
		ui.visible = false
	if FileAccess.file_exists("user://perf_noworld"):
		world.visible = false
	_dev_perf_flags()
	if not FileAccess.file_exists("user://perf_hz"):
		_lock_refresh()
	_go_title()
	if _shots:
		_run_shots()
	elif _tour:
		_run_tour()
	elif _autopilot:
		get_tree().create_timer(1.5).timeout.connect(_start_run)

# ------------------------------------------------------------- states ---

func _reset_run() -> void:
	for j in _jags:
		_drop_jaguar(j.node)
	_jags.clear()
	_jag_queue.clear()
	for b in _bats:
		b.node.queue_free()
	_bats.clear()
	world.reset(MayaCalendar.seed_for(daily_key) if daily_key != "" else (_tour_seed if _tour_seed != 0 else randi()))
	s = START_S
	x = 0.0
	y = 0.0
	vy = 0.0
	speed = 0.0
	distance = 0.0
	coins = 0
	light = FileAccess.get_file_as_string("user://dev_light").to_float() if FileAccess.file_exists("user://dev_light") else 1.0
	blaze = 0.0
	amb = AMB_FULL
	death_cause = ""
	_run_flares = 0
	_jumps = 0
	_slides = 0
	_stumbles = 0
	_lane = 0
	_lane_from = 0
	_u = 0.0
	_slide_t = 0.0
	_flare_t = 0.0
	_flare_cd = 0.0
	_stumble_t = 99.0
	_pack = PACK_FAR + 6.0
	_pack_caught = false
	_dash_to = 0.0
	_head_start = 0.0
	_sight = 1000.0
	_run_time = 0.0
	_second_wind_used = false
	_shield_t = 0.0
	_fell = false
	_caught = false
	_recovered = false
	_was_low = false
	_x_vel = 0.0
	_x_vel_s = 0.0
	_yaw = 0.0
	_lean = 0.0
	_attraction = 0.0
	_house_key = ""
	_strings.clear()
	_hints.clear()
	_end_coach()
	_close = 0
	_combo = 0
	_act_t = -9.0
	_touch_index = -1
	_cam_x = 0.0
	runner.rotation = Vector3.ZERO
	runner.raise = 0.0
	for n in _pack_nodes:
		n.visible = false

func _go_title() -> void:
	get_tree().paused = false
	daily_key = ""
	_reset_run()
	state = State.TITLE
	_title_t = 0.0
	runner.pose = RunnerModel.Pose.IDLE
	_place_runner()
	ui.show_title(save)
	sfx.play_music()

func _start_run() -> void:
	if state != State.TITLE:
		return
	state = State.RUNNING
	_intro_t = 0.0
	runner.pose = RunnerModel.Pose.RUN
	if _dev_start > 0.0:
		s = _dev_start
		x = world.center(s)
		world.ensure(s)
	ui.show_hud(MayaCalendar.tzolkin_name(daily_key) if daily_key != "" else "")
	sfx.play(Sfx.ROAR)
	# The head start is offered for the first moments (not on the daily dusk,
	# where everyone runs the same road from the same start).
	if save.boosts("dash") > 0 and daily_key == "" and not _shots and not _tour and not _autopilot:
		ui.show_dash(save.boosts("dash"))
		get_tree().create_timer(3.5).timeout.connect(ui.hide_dash)
	online.track("run_start", {"mode": "daily" if daily_key != "" else "free", "runs": save.runs})
	if not _shots:
		get_tree().create_timer(0.9).timeout.connect(func():
			if state == State.RUNNING:
				_hint("swipe", "Swipe left and right to change lanes", false))

## The head start: the sun lifts him over the road and carries him DASH_M
## metres, then sets him down where the road is clear.
func _dash() -> void:
	if state != State.RUNNING or _dash_to > 0.0 or _head_start > 0.0 or s > 40.0:
		return
	if not save.use_boost("dash"):
		return
	save.save_to_disk()
	_dash_to = maxf(s, 0.0) + DASH_M
	_head_start = 0.0
	ui.hide_dash()
	ui.flash_flare()
	sfx.play(Sfx.FLARE)
	online.track("boost", {"id": "dash"})

## Today's dusk: the same road for everyone, fixed for the whole run even if
## the date turns while running.
func _start_daily() -> void:
	if state != State.TITLE:
		return
	daily_key = MayaCalendar.today_utc()
	_reset_run()
	_place_runner()
	_start_run()

func _restart() -> void:
	get_tree().paused = false
	_reset_run()
	state = State.TITLE # _start_run needs TITLE
	_start_run()
	_intro_t = 1.0 # straight into the chase camera
	_update_camera(-1.0)

func _pause() -> void:
	if state != State.RUNNING:
		return
	state = State.PAUSED
	_touch_index = -1
	Engine.time_scale = 1.0
	get_tree().paused = true
	ui.show_pause()

func _resume() -> void:
	if state != State.PAUSED:
		return
	get_tree().paused = false
	state = State.RUNNING
	_touch_index = -1
	if _coach != "":
		Engine.time_scale = 0.3
	ui.show_hud(MayaCalendar.tzolkin_name(daily_key) if daily_key != "" else "")

func _die(cause: String, fell := false, caught := false) -> void:
	if state != State.RUNNING or _invincible:
		return
	state = State.DYING
	death_cause = cause
	_end_coach()
	if _autopilot:
		print("[sunstone] died at %.0f m (%.1f m/s): %s" % [s, speed, cause])
	_fell = fell
	_caught = caught
	_death_t = 0.0
	vy = 0.0
	if not fell:
		runner.start_fall()
		_shake = 0.6
		sfx.play(Sfx.CRASH)
	else:
		sfx.play(Sfx.FALL)
	sfx.vibrate(save, 160)
	ui.flash_danger()

## Second wind: pay sun-drops and rise again just past what ended the run —
## the jaguars driven off, the stone relit, a moment of safety.
## [paid_by_ad]: the player watched an ad instead of paying sun-drops.
func _second_wind(paid_by_ad := false) -> void:
	if state != State.OFFER:
		return
	if not paid_by_ad:
		if save.bank < Market.SECOND_WIND_COST:
			return
		save.bank -= Market.SECOND_WIND_COST
		save.save_to_disk()
	_second_wind_used = true
	online.track("second_wind", {"distance": int(distance)})
	if _fell:
		s += World.ROW * 1.5
	for c in world.chunks():
		for o in c.obstacles:
			if absf(o.s - s) < 6.0:
				o["hit"] = true
	# Back on his feet in a lane with no hole under it.
	for lane in [_lane, 0, -1, 1]:
		if not world.in_pit(world.point(s, World.lane_u(lane)).x, -s):
			_lane = lane
			break
	_lane_from = _lane
	_u = World.lane_u(_lane)
	x = world.point(s, _u).x
	_slide_t = 0.0
	_stumble_t = 99.0
	_pack = PACK_FAR + 6.0
	_pack_caught = false
	for j in _jags.duplicate():
		if Vector2(j.pos.x - x, j.pos.z + s).length() < 14.0:
			_drop_jaguar(j.node)
			_jags.erase(j)
	for b in _bats:
		b.flee = true
	y = 0.0
	vy = 0.0
	light = maxf(light, 0.6)
	_shield_t = 1.5
	_fell = false
	_caught = false
	runner.pose = RunnerModel.Pose.RUN
	runner.rotation = Vector3.ZERO
	state = State.RUNNING
	ui.show_hud(MayaCalendar.tzolkin_name(daily_key) if daily_key != "" else "")
	_update_camera(-1.0)
	sfx.play(Sfx.FLARE)
	ui.flash_flare()

## The run's place in the nights, as the results page and the leaderboards
## write it.
func _night_line() -> String:
	var at := Nights.locate(distance)
	if at.dawn:
		return "Night %d survived" % at.n
	var h: Dictionary = Nights.HOUSES[Nights.plan(at.n, world.seed)[at.house]]
	return "Night %d · %s" % [at.n, h.name]

func _finish_run() -> void:
	state = State.RESULTS
	var metres := int(distance)
	var is_best := metres > save.best
	if is_best:
		save.best = metres
	var dusk := clampf(Nights.progress(distance) / 3.0, 0.0, 1.0)
	save.record_run(metres, coins, _run_flares, dusk, _run_time, death_cause)
	var daily_info := {}
	if daily_key != "":
		var day_best := save.record_daily(daily_key, metres)
		daily_info = {"name": MayaCalendar.tzolkin_name(daily_key), "best": save.daily_best(daily_key), "is_best": day_best}
	var new_glyphs := Glyphs.evaluate(save, {
		"distance": metres, "drops": coins, "flares": _run_flares, "dusk": dusk,
		"daily": daily_key != "", "recovered": _recovered, "nights": Nights.progress(distance),
		"jumps": _jumps, "slides": _slides, "close": _close, "stumbles": _stumbles,
	})
	save.save_to_disk()
	ui.show_results(death_cause, metres, coins, save.best, is_best, daily_info, new_glyphs, _night_line())
	_maybe_ask_review(is_best, metres)
	online.submit_run({
		"mode": "daily" if daily_key != "" else "free", "dailyKey": daily_key if daily_key != "" else null,
		"distance": metres, "drops": coins, "flares": _run_flares, "durationMs": int(_run_time * 1000.0),
		"dusk": snappedf(dusk, 0.001), "cause": death_cause,
		"ruleset": RULESET, "jumps": _jumps, "slides": _slides, "stumbles": _stumbles,
		"headStart": int(_head_start),
	})
	online.track("run_end", {"mode": "daily" if daily_key != "" else "free", "distance": metres, "drops": coins,
		"flares": _run_flares, "cause": death_cause, "second_wind": _second_wind_used, "glyphs": new_glyphs.size(),
		"nights": snappedf(Nights.progress(distance), 0.01)})
	online.queue_sync()
	sfx.play(Sfx.RESULTS)

## Asks for the store's rating sheet right after a proud moment — a new best
## of 500 m or more, once the player knows the game — at most once a month and
## three times ever. The store decides whether it actually shows.
func _maybe_ask_review(is_best: bool, metres: int) -> void:
	if not is_best or metres < 500 or save.runs < 5 or save.review_asks >= 3 or OS.get_name() not in ["Android", "iOS"]:
		return
	var today := MayaCalendar.today_local()
	if save.review_last != "":
		var last := Time.get_unix_time_from_datetime_string(save.review_last + "T00:00:00")
		if Time.get_unix_time_from_datetime_string(today + "T00:00:00") - last < 30 * 86400:
			return
	save.review_asks += 1
	save.review_last = today
	save.save_to_disk()
	await get_tree().create_timer(1.6).timeout
	if OS.get_name() == "iOS":
		store.request_review()
	else:
		review.generate_review_info()
	online.track("review_prompt", {"distance": metres})

## Leaving a run's results: by the pacing rules, maybe an ad first. A rewarded
## interstitial is always announced by an intro the player can decline.
var _leaving := false
func _leave_results(then: Callable) -> void:
	if _leaving:
		return
	_leaving = true
	match ads.between_runs(save.runs):
		"offer":
			if await ui.show_reward_offer(Ads.BETWEEN_RUNS_REWARD) and await ads.show_rewarded_interstitial():
				save.bank += Ads.BETWEEN_RUNS_REWARD
				save.save_to_disk()
				online.queue_sync()
				online.track("ad_gift", {"reward": Ads.BETWEEN_RUNS_REWARD})
		"interstitial":
			ads.show_interstitial()
	_leaving = false
	then.call()

func _on_settings_changed() -> void:
	save.save_to_disk()
	sfx.apply_settings(save)

# -------------------------------------------------------------- frame ---

## Builds the explorer in his garb and the Sunstone in its hue. Called again
## when the player changes either in the Market.
func _spawn_runner() -> void:
	var old_pose := RunnerModel.Pose.IDLE
	if runner:
		old_pose = runner.pose
		runner.queue_free()
	var hue := Market.find(Market.HUES, save.hue)
	runner = Shop.dress(save.character, save.garb, save.hat, save.hue) if not _shots else Shop.dress("explorer", "explorer", "own", "sun")
	runner.pose = old_pose
	runner.scale = Vector3.ONE * 1.2
	add_child(runner)
	if _halo_mat:
		_halo_mat.albedo_color = Color(hue.light, 0.85)
	Codex.set_stone_color(hue.light)
	if state == State.TITLE:
		_place_runner()

func _process(delta: float) -> void:
	_time += delta
	if _tour:
		# A frame's delta arrives one frame late: the work that made it slow
		# was logged in the frame before.
		_prev_events = _events
		_events = []
		_tour_frame(delta)
	world.spin(delta)
	if _tour and world.attached != _attached_seen:
		_events.append("chunk")
		_attached_seen = world.attached
	elif _autopilot:
		_profile(delta)
	match state:
		State.TITLE:
			_title_t += delta
			runner.raise = 0.0
			runner.animate(delta, 0.0)
			light_r = 4.0
			amb = AMB_FULL
			_update_camera(delta)
			_push_codex()
		State.RUNNING:
			_step_run(delta)
		State.DYING:
			_step_death(delta)
		State.OFFER, State.RESULTS:
			runner.animate(delta, 0.0)
			_push_codex()
	_place_halo(delta)
	_place_motes()
	_apply_shake(delta)
	# Behind an open page the world is dimmed: render it at half resolution
	# and give the page the GPU.
	var page := ui.page_open()
	if page != _page_scaled:
		_page_scaled = page
		get_viewport().scaling_3d_scale = 0.5 if page else _render_scale

func _step_run(delta: float) -> void:
	_run_time += delta
	_intro_t = minf(_intro_t + delta / 1.1, 1.0)
	var at := Nights.locate(maxf(s, 0.0))
	speed = Nights.speed(at.n, at.t)
	var dashing := _dash_to > 0.0
	if dashing:
		speed *= DASH_MUL
	var s_before := s
	s += speed * delta
	if dashing:
		_head_start += (s - s_before) * (1.0 - 1.0 / DASH_MUL)
		# Set down only where the road ahead is clear for a moment.
		if s >= _dash_to and not world.clear(s + 2.0, [-1, 0, 1], speed / DASH_MUL * 1.4):
			_dash_to = s + 4.0
		if s >= _dash_to:
			_dash_to = 0.0
			_shield_t = 1.2
	distance = maxf(s, 0.0)
	world.ensure(s)
	var h: Dictionary = Themes.house("dusk") if s < 0.0 else Nights.house(s, world.seed)

	if _autopilot:
		_drive(delta)
	# A flare burns for a moment, then the light falls back to the stone.
	_flare_t = maxf(_flare_t - delta, 0.0)
	_flare_cd = maxf(_flare_cd - delta, 0.0)
	var want := clampf(_flare_t / 0.6, 0.0, 1.0)
	if _force_blaze >= 0.0:
		want = _force_blaze
	blaze += (want - blaze) * minf(1.0, delta * (12.0 if want > blaze else 3.0))

	# The light drains by itself; flares spend it in lumps.
	if s > 0.0 and not at.dawn and not dashing:
		light -= DRAIN * h.drain * Market.drain_scale(save) * delta
	light = clampf(light, 0.0, 1.0)
	var glow: float = h.ember * GLOW * (0.4 + 0.6 * sqrt(light))
	light_r = lerpf(glow, FLARE_R, blaze)
	_sight = light_r + (SIGHT_MIN + SIGHT_LIGHT * light) * h.ember / 2.05
	if light < 0.12:
		_was_low = true
	elif _was_low and light > 0.5:
		_recovered = true
	if s < 0.0:
		amb = AMB_FULL
	elif at.dawn:
		amb = smoothstep(0.05, 0.6, at.dawn_t) * AMB_FULL
	else:
		amb = (1.0 - smoothstep(0.0, 0.09 if at.n == 1 else 0.05, at.t)) * AMB_FULL

	# His lane, the leap and the slide.
	var old_x := x
	_u += (World.lane_u(_lane) - _u) * minf(1.0, delta * LANE_EASE)
	x = world.point(s, _u).x
	if dashing:
		y = lerpf(y, DASH_Y, 1.0 - exp(-4.0 * delta))
		vy = 0.0
		_lane = 0
		_lane_from = 0
		_force_blaze = 1.0
	elif _force_blaze == 1.0 and _head_start > 0.0:
		_force_blaze = -1.0
		vy = -0.01 # fall back to the road
	if not dashing and (y > 0.0 or vy > 0.0 or vy < 0.0):
		vy -= GRAVITY * delta
		y += vy * delta
		if y <= 0.0:
			y = 0.0
			vy = 0.0
			runner.land()
			if _slide_queued:
				_slide_queued = false
				_slide()
	_slide_t = maxf(_slide_t - delta, 0.0)
	_stumble_t += delta
	_x_vel = (x - old_x) / maxf(delta, 0.0001)
	_x_vel_s = lerpf(_x_vel_s, _x_vel, 1.0 - exp(-8.0 * delta))

	_check_houses(at, h)
	_shield_t = maxf(_shield_t - delta, 0.0)
	_growl_cd = maxf(_growl_cd - delta, 0.0)
	if dashing:
		_shield_t = maxf(_shield_t, 0.3)
	if _shield_t <= 0.0 and _check_hazards():
		return
	_collect()
	_check_close()
	_spawn_queued_jaguar()
	_step_jaguars(delta, h, at)
	if state != State.RUNNING:
		return
	_step_bats(delta, h, at)
	if _invincible:
		light = maxf(light, 0.25)
	if light <= 0.0 and s > 0.0 and not at.dawn and save.use_boost("shield"):
		light = 0.4
		ui.pop("Ember shield!")
		ui.flash_flare()
		sfx.play(Sfx.FLARE)
	if _step_pack(delta, at):
		return
	_teach()
	if light < 0.35:
		_hint("drops", "Sun-drops feed the stone: run through them")
	elif _run_time > 12.0:
		_hint("flare", "Tap to flare: the light reaches far ahead, but it costs light", false)

	if y > 0.02:
		runner.pose = RunnerModel.Pose.JUMP
	elif _slide_t > 0.0:
		runner.pose = RunnerModel.Pose.SLIDE
	else:
		runner.pose = RunnerModel.Pose.RUN
	runner.raise = blaze if _slide_t <= 0.0 else 0.0
	runner.animate(delta, speed)
	_place_runner(delta)
	_update_camera(delta)
	_push_codex()
	ui.set_run_numbers(int(distance), coins)
	ui.set_night(at.n, h.name, at.t, at.dawn)
	ui.set_light(light, 1.0 - amb / AMB_FULL, minf(_nearest_jaguar(), _pack + 1.0))

## Entering a House, or dawn: a banner, a sound, and on the first nights a hint.
func _check_houses(at: Dictionary, h: Dictionary) -> void:
	var key := "%d:%d:%s" % [at.n, at.house, at.dawn]
	if key == _house_key:
		return
	var first := _house_key == ""
	_house_key = key
	if _tour:
		_events.append("house")
	if at.dawn:
		ui.show_banner("Dawn", "Night %d survived" % at.n)
		sfx.play(Sfx.DAWN)
		light = minf(light + DAWN_GIFT, 1.0)
		for j in _jags:
			_drop_jaguar(j.node)
		_jags.clear()
		_jag_queue.clear()
		for b in _bats:
			b.flee = true
		return
	if at.n > 1 and at.house == 0:
		ui.show_banner(h.name, "Night %d begins" % at.n)
	elif first and Themes.event().has("name"):
		ui.show_banner(h.name, Themes.event().name)
	else:
		ui.show_banner(h.name, h.sub)
	if not first:
		sfx.play(Sfx.GATE)
	if true:
		var id: String = Nights.plan(at.n, world.seed)[at.house]
		if id == "jaguars":
			_hint("jaguars", "Jaguars move only in the dark: flare and they turn to stone")
		elif id == "bats":
			_hint("bats", "Bats dive for your light: swipe down to slide under them")

## Shows a hint until the player has learned it. [learned_on_show]: a fact,
## learned by reading it; otherwise a move, learned by making it ([_learn]).
func _hint(key: String, text: String, learned_on_show := true) -> void:
	if _hints.has(key) or save.taught.has(key) or _shots or _autopilot:
		return
	_hints[key] = true
	if learned_on_show:
		save.taught[key] = true
	ui.show_hint(text, Vector2.ZERO)

## The move [key] was made: never teach it again, and if time was slowed to
## teach it, let it run.
func _learn(key: String) -> void:
	if not save.taught.has(key) and _hints.has(key):
		save.taught[key] = true
		ui.dismiss_hint()
	if _coach == key:
		_end_coach()

## The first time each danger meets him in his lane, time slows and a hint
## says which swipe gets past it, until he makes it (or it's behind him).
const COACH := {
	"jump": "Swipe up to jump", "slide": "Swipe down to slide under",
	"dodge": "Swipe left or right to go round",
}
func _teach() -> void:
	if _shots or _autopilot or _tour or _dash_to > 0.0:
		return
	if _coach != "":
		# The danger went by without the move: let time run again.
		if _coach_s < s - 0.5:
			_hints.erase(_coach)
			_end_coach()
		return
	var near := world.occupant(s + speed * 0.75, _lane, speed * 0.4)
	if near.is_empty() or near.s - s < 3.0:
		return
	var key := "jump" if near.kind in ["wall", "pit"] else ("slide" if near.kind == "lintel" else "dodge")
	if save.taught.has(key) or _hints.has(key):
		return
	_hint(key, COACH[key], false)
	_coach = key
	_coach_s = near.s
	Engine.time_scale = 0.3

var _coach_s := 0.0
func _end_coach() -> void:
	_coach = ""
	Engine.time_scale = 1.0

const CAUSES := {
	"stela": "Ran into a stela", "blades": "Cut on obsidian blades",
	"wall": "Tripped over a low wall", "lintel": "Hit a stone lintel",
}

## Returns true when the run just ended. Meeting a danger's front face in
## its lane ends the run; clipping one from the side while changing lanes is a
## stumble, and he's thrown back to the lane he left.
func _check_hazards() -> bool:
	if _invincible:
		return false
	var z := -s
	if y <= 0.05 and world.in_pit(x, z):
		_die("Fell into a pit", true)
		return true
	var step := speed * get_process_delta_time() * 1.5 + 0.15
	for c in world.chunks():
		if c.s1 < s - 2.0 or c.s0 > s + 2.0:
			continue
		for o in c.obstacles:
			if o.get("hit", false):
				continue
			var front: float = o.s - o.depth / 2.0
			if s < front or s > front + o.depth + 0.2:
				continue
			var d: Dictionary = World.DANGER[o.kind]
			if d.jump and y > WALL_CLEAR:
				continue
			if d.slide and _slide_t > 0.0 and y < 0.3:
				continue
			var head_on := s - front < step
			if o.lane == World.ALL:
				_die(CAUSES[o.kind])
				return true
			var gap := absf(_u - World.lane_u(o.lane))
			if gap >= Nights.LANE_W * 0.4 + RUNNER_HALF:
				continue
			o["hit"] = true
			if head_on and gap < 0.8:
				_die(CAUSES[o.kind])
				return true
			if _stumble():
				return true
	return false

## Clipped something: thrown back to the lane he came from, light knocked out
## of the stone. Twice in a short while and the dark has him. Returns true when
## that ended the run.
func _stumble() -> bool:
	_stumbles += 1
	_combo = 0
	_lane = _lane_from
	_shake = 0.35
	sfx.play(Sfx.STUMBLE)
	sfx.vibrate(save, 50)
	ui.flash_danger()
	if _stumble_t < STUMBLE_WINDOW:
		_pack_caught = true
		_die("Stumbled, and the pack caught him", false, true)
		return true
	_stumble_t = 0.0
	light = maxf(0.0, light - STUMBLE_LIGHT)
	ui.pop("Stumble!")
	return false

## A danger he got past by a move made at the last moment — a lane change
## round it, a leap over it, a slide under it — is a close call: a sun-drop,
## and more for close calls in a row.
func _check_close() -> void:
	for c in world.chunks():
		if c.s1 < s - 3.0 or c.s0 > s + 1.0:
			continue
		for o in c.obstacles:
			if o.get("hit", false) or o.get("passed", false) or s < o.s + o.depth / 2.0:
				continue
			o["passed"] = true
			if _run_time - _act_t > 0.45:
				continue
			if o.lane != World.ALL and absf(_u - World.lane_u(o.lane)) > Nights.LANE_W * 1.2:
				continue
			_close += 1
			_combo += 1
			var pay := mini(_combo, 5)
			coins += pay
			light = minf(light + 0.01, 1.0)
			ui.pop("Close!" if _combo < 2 else "Close!  ×%d" % _combo)
			sfx.play(Sfx.COIN)

func _collect() -> void:
	for c in world.chunks():
		if c.s1 < s - 2.0 or c.s0 > s + 2.0:
			continue
		for d in c.drops:
			if d.taken or absf(d.s - s) > 0.8:
				continue
			var p: Vector3 = d.pos
			if absf(world.u_of(p.x, p.z) - _u) < 0.9 and absf(p.y - (y + 0.7)) < 0.95:
				d.taken = true
				coins += 1
				light = minf(light + DROP_LIGHT * Market.drop_scale(save), 1.0)
				sfx.play(Sfx.COIN)
				# A whole line: a bonus for staying on it.
				var tid: int = d.get("trail", 0)
				if tid > 0:
					_strings[tid] = _strings.get(tid, 0) + 1
					if _strings[tid] == int(d.get("of", 5)):
						coins += STRING_BONUS
						light = minf(light + DROP_LIGHT * 3.0, 1.0)
						ui.pop("Sun-string  +%d" % STRING_BONUS)
						sfx.play(Sfx.BLAZE)

func _is_lit(p: Vector3) -> bool:
	var d := Vector2(p.x - _light_c.x, p.z - _light_c.z).length()
	if d < light_r * 0.92 or Vector2(p.x - x, p.z + s).length() < amb:
		return true
	for l in _lights:
		if l.w > 0.0 and Vector2(p.x - l.x, p.z - l.z).length() < l.w:
			return true
	return false

func _on_chunk(c: World.Chunk) -> void:
	for spawn in c.jaguars:
		_jag_queue.append(spawn.pos)

## Jaguars wait in a queue and join one per frame; gone ones are kept to be
## used again rather than freed and rebuilt.
var _jag_queue: Array[Vector3] = []
var _jag_pool: Array[JaguarModel] = []

func _spawn_queued_jaguar() -> void:
	if not _jag_queue.is_empty():
		_add_jaguar(_jag_queue.pop_front())

func _drop_jaguar(node: JaguarModel) -> void:
	node.visible = false
	_jag_pool.append(node)

func _add_jaguar(pos: Vector3) -> void:
	if _tour:
		_events.append("jaguar")
	var node: JaguarModel
	if not _jag_pool.is_empty():
		node = _jag_pool.pop_back()
		node.visible = true
	else:
		node = JaguarModel.new()
		node.scale = Vector3.ONE * 1.15
		add_child(node)
	node.position = pos
	node.rotation.y = randf() * TAU
	node.frozen = true
	_jags.append({"node": node, "pos": pos, "frozen": true, "linger": 0.0, "state": "wait", "lane": 0, "t": 0.0,
		"from": pos, "to": pos})

## The stone jaguars by the road: frozen wherever there is light. In the dark
## one waits crouched at the curb until he comes near, then leaps into his
## lane and comes at him; light turns it back to stone where it stands, and a
## stone jaguar in the road is just one more thing to go round.
func _step_jaguars(delta: float, _h: Dictionary, _at: Dictionary) -> void:
	for j in _jags.duplicate():
		var p: Vector3 = j.pos
		var js := -p.z
		var ahead := js - s
		if ahead < -1.5:
			# Passed: gone, so nothing stands between him and the camera.
			_drop_jaguar(j.node)
			_jags.erase(j)
			continue
		if ahead > 40.0:
			continue
		var lit := _is_lit(p)
		if lit:
			j.linger = Market.freeze_bonus(save)
		elif j.linger > 0.0:
			j.linger -= delta
			lit = true
		match j.state:
			"wait":
				if not lit and ahead < speed * 1.05 + 2.0 and ahead > 3.0:
					# It leaps only where it can land: every lane between the
					# curb and his must be clear of stone and holes there.
					var side := 1 if world.u_of(p.x, p.z) > 0.0 else -1
					var over: Array = range(_lane, side + 1) if side > 0 else range(side, _lane + 1)
					for back in [1.0, 3.0, 5.0]:
						var land: float = js - back
						if land - s > 2.5 and world.clear(land, over, 1.4):
							j.state = "leap"
							j.t = 0.0
							j.from = p
							j.lane = _lane
							j.to = world.point(land, World.lane_u(_lane))
							if _growl_cd <= 0.0:
								sfx.play(Sfx.ROAR)
								_growl_cd = 2.5
							break
			"leap":
				lit = false # a leap, once begun, lands
				j.t = minf(j.t + delta / JAG_LEAP, 1.0)
				p = j.from.lerp(j.to, j.t)
				p.y = sin(PI * j.t) * 1.3
				if j.t >= 1.0:
					j.state = "road"
					p.y = 0.0
			"road":
				# Coming at him down its lane — but never through stone or over
				# a hole: it stops behind whatever stands in the way.
				var next := js - JAG_CREEP * delta
				if not lit and world.occupant(next - 1.1, j.lane, 0.1).is_empty():
					p = world.point(next, World.lane_u(j.lane))
		j.frozen = lit
		j.node.frozen = lit
		j.pos = p
		j.node.position = p
		if not lit:
			var to := Vector3(x, 0.0, -s) - p
			j.node.rotation.y = lerp_angle(j.node.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-10.0 * delta))
			j.node.animate(delta, JAG_CREEP if j.state == "road" else 6.0)
		# In the road, where he is: head-on ends the run, a side clip stumbles.
		if j.state == "wait" or j.get("hit", false) or absf(ahead) > 0.75 or _shield_t > 0.0 or _invincible:
			continue
		var gap := absf(_u - World.lane_u(j.lane))
		if gap >= Nights.LANE_W * 0.4 + RUNNER_HALF:
			continue
		j.hit = true
		if save.use_boost("ward"):
			# The ward: this one is stone for good, and out of the way.
			_drop_jaguar(j.node)
			_jags.erase(j)
			ui.pop("Jaguar ward!")
			ui.flash_flare()
			sfx.play(Sfx.FLARE)
			_shield_t = 1.0
			continue
		if gap < 0.8:
			if lit:
				_die("Ran into a stone jaguar")
			else:
				_die("Caught by a jaguar in the dark", false, true)
			return
		if _stumble():
			return

## The pack behind him: out of sight while the stone burns bright, closer as
## it dims, at his heels after a stumble. A flare turns them to stone and they
## fall back. When the light is gone they catch him. Returns true when they did.
func _step_pack(delta: float, at: Dictionary) -> bool:
	var want := PACK_FAR + 6.0
	if s > Nights.START_CLEAR and not at.dawn:
		want = lerpf(PACK_NEAR + 0.9, PACK_FAR, smoothstep(0.08, 0.5, light))
		if _stumble_t < STUMBLE_WINDOW:
			want = minf(want, PACK_NEAR)
		if light <= 0.0:
			want = 0.0
	if _dev_pack:
		want = PACK_NEAR
	var frozen := blaze > 0.5
	if frozen:
		want = maxf(want, _pack) + 4.0
	var rate := 9.0 if want > _pack else (6.0 if light <= 0.0 else 2.6)
	_pack = move_toward(_pack, want, rate * delta)
	_place_pack(delta, frozen)
	if _pack < PACK_NEAR + 1.0 and _growl_cd <= 0.0 and not frozen:
		sfx.play(Sfx.ROAR)
		_growl_cd = 4.0
	if _pack <= PACK_CATCH and not _invincible:
		_pack_caught = true
		_die("The light went out, and the pack caught him", false, true)
		return true
	return false

## Three stone cats running at his heels, staggered across the lanes. They
## run the same road he did: round stelae and blades, over walls and holes,
## low under lintels — never through stone.
const PACK_SPOTS := [Vector2(-1.4, 0.4), Vector2(1.4, 1.0), Vector2(0.0, 1.8)]
func _place_pack(delta: float, frozen: bool) -> void:
	var show := _pack < PACK_FAR + 1.0 and state == State.RUNNING or _pack_caught
	if _pack_nodes.is_empty():
		if not show:
			return
		for i in PACK_SPOTS.size():
			var n := JaguarModel.new()
			n.scale = Vector3.ONE * 0.95
			add_child(n)
			_pack_nodes.append(n)
			_pack_u.append(_u + PACK_SPOTS[i].x)
	for i in _pack_nodes.size():
		var n: JaguarModel = _pack_nodes[i]
		n.visible = show
		if not show:
			continue
		var spot: Vector2 = PACK_SPOTS[i]
		var ps := s - _pack - spot.y
		var want_u := clampf(_u + spot.x, -Nights.ROAD_W / 2.0 + 0.5, Nights.ROAD_W / 2.0 - 0.5)
		var lane := clampi(roundi(want_u / Nights.LANE_W), -1, 1)
		var ahead: Dictionary = world.occupant(ps + 1.0, lane, 1.6)
		if not ahead.is_empty() and ahead.kind in ["stela", "blades"]:
			# Stone in its lane: swerve to the nearest lane that's clear.
			for l in [lane - 1, lane + 1, lane - 2, lane + 2]:
				if l >= -1 and l <= 1:
					var o: Dictionary = world.occupant(ps + 1.0, l, 1.6)
					if o.is_empty() or not o.kind in ["stela", "blades"]:
						want_u = World.lane_u(l)
						lane = l
						break
		if _pack_u.size() <= i:
			_pack_u.append(want_u)
		_pack_u[i] = lerpf(_pack_u[i], want_u, 1.0 - exp(-9.0 * delta))
		var hop := 0.0
		var squash := 1.0
		var here: Dictionary = world.occupant(ps, roundi(_pack_u[i] / Nights.LANE_W), 1.8)
		if not here.is_empty():
			var d: float = (ps - here.s) / 1.8
			if here.kind in ["wall", "pit"]:
				hop = maxf(0.0, 1.0 - d * d) * (1.0 if here.kind == "wall" else 0.8)
			elif here.kind == "lintel":
				squash = lerpf(1.0, 0.72, clampf(1.6 - absf(d) * 1.8, 0.0, 1.0))
		n.position = world.point(ps, _pack_u[i], hop)
		n.scale = Vector3(0.95, 0.95 * squash, 0.95)
		n.rotation.y = atan2(-world.slope(ps), 1.0)
		n.frozen = frozen
		if not frozen:
			n.animate(delta, speed)

func _nearest_jaguar() -> float:
	var best := 24.0
	for j in _jags:
		if not j.frozen and j.state != "wait":
			best = minf(best, Vector2(j.pos.x - x, j.pos.z + s).length())
	return best

## The bats of Camazotz: blaze long and they come; let go and they lose you.
## They live in the runner's frame, so a chase reads the same at any speed.
func _step_bats(delta: float, h: Dictionary, at: Dictionary) -> void:
	if s > Nights.START_CLEAR and not at.dawn:
		if blaze > 0.55:
			_attraction += delta * 0.42 * h.bat * (1.0 + 0.08 * (at.n - 1))
		else:
			_attraction = maxf(0.0, _attraction - delta * 0.8)
		if _attraction >= 1.0:
			_attraction = 0.3
			var node := BatModel.new()
			add_child(node)
			if _tour:
				_events.append("bat")
			_bats.append({"node": node, "rel": Vector3(randf_range(-6.0, 6.0), 4.5, -randf_range(16.0, 21.0)),
				"vel": Vector3.ZERO, "gone": false, "flee": false, "life": 0.0})
			sfx.play(Sfx.BAT)
	for b in _bats.duplicate():
		b.life += delta
		var hunting: bool = not b.gone and not b.flee and b.life < 3.5
		var rel: Vector3 = b.rel
		var vel: Vector3 = b.vel
		if hunting:
			var to := Vector3(0.0, 1.4, 0.0) - rel
			var dist := to.length()
			var sp: float = BAT_SPEED + 0.59 * (at.n - 1)
			vel = vel.lerp(to / maxf(dist, 0.01) * sp, 1.0 - exp(-3.0 * delta))
			if dist < BAT_HIT_R * 1.6 and _slide_t > 0.0:
				# Ducked under it: it sweeps over his back and away.
				b.gone = true
				vel = Vector3(randf_range(-3.0, 3.0), 4.0, 6.0)
			elif dist < BAT_HIT_R and _shield_t <= 0.0:
				light = maxf(0.0, light - BAT_STEAL)
				b.gone = true
				vel = Vector3(randf_range(-4.0, 4.0), 5.0, -3.0)
				ui.flash_danger()
				sfx.play(Sfx.STUMBLE)
				sfx.vibrate(save, 40)
		else:
			var away := Vector3(signf(rel.x + 0.01) * 7.0, 4.0, -5.0)
			vel = vel.lerp(away, 1.0 - exp(-2.0 * delta))
		rel += vel * delta
		b.rel = rel
		b.vel = vel
		var node: BatModel = b.node
		node.position = Vector3(x, 0.0, -s) + rel
		if vel.length() > 0.1:
			node.rotation.y = atan2(-vel.x, -vel.z)
		node.animate(delta, 1.5 if hunting else 1.0)
		if b.life > 0.5 and (rel.length() > 30.0 or rel.y > 14.0):
			node.queue_free()
			_bats.erase(b)

func _step_death(delta: float) -> void:
	_death_t += delta
	if _fell:
		s += speed * 0.4 * delta
		vy -= 22.0 * delta
		y += vy * delta
		runner.position = Vector3(x, y, -s)
		runner.rotation.x = minf(runner.rotation.x + delta * 2.0, 1.2)
	else:
		runner.animate(delta, 0.0)
		if _caught and _pack_caught and not _pack_nodes.is_empty():
			# The pack: the leader pounces from behind.
			var lead: JaguarModel = _pack_nodes[2]
			lead.position = lead.position.lerp(Vector3(x, 0.0, -s + 0.6), 1.0 - exp(-8.0 * delta))
			lead.animate(delta, 6.0)
		elif _caught:
			# The nearest one pounces.
			var best: Dictionary = {}
			var bd := INF
			for j in _jags:
				var d := Vector2(j.pos.x - x, j.pos.z + s).length()
				if d < bd:
					bd = d
					best = j
			if not best.is_empty():
				var target := Vector3(x, 0.0, -s + 0.6)
				best.pos = best.pos.lerp(target, 1.0 - exp(-8.0 * delta))
				best.node.position = best.pos
				best.node.animate(delta, 6.0)
	light_r = maxf(0.0, light_r - delta * 5.0)
	blaze = 0.0
	runner.raise = 0.0
	for b in _bats:
		b.flee = true
	_step_bats(delta, Nights.HOUSES["dusk"], {"n": 1, "dawn": true})
	_update_camera(delta)
	_push_codex()
	if _death_t > 1.35:
		if not _second_wind_used and (save.bank >= Market.SECOND_WIND_COST or ads.rewarded_ready()):
			state = State.OFFER
			ui.show_second_wind(Market.SECOND_WIND_COST, save.bank)
		else:
			_finish_run()

# ---------------------------------------------------------------- light ---

## Tells the codex shading where the light is this frame: the Sunstone, the
## nearest braziers, and the dusk/dawn flood.
func _push_codex() -> void:
	var cands: Array = []
	for c in world.chunks():
		if c.s1 < s - 20.0 or c.s0 > s + 44.0:
			continue
		for b in c.braziers:
			var p: Vector3 = b.pos
			cands.append(Vector4(p.x, p.y, p.z, b.r))
	cands.sort_custom(func(a: Vector4, b: Vector4): return absf(a.z + s) < absf(b.z + s))
	_lights.resize(Codex.MAX_LIGHTS)
	for i in Codex.MAX_LIGHTS:
		_lights[i] = cands[i] if i < cands.size() else Vector4.ZERO
	var day := clampf(amb / AMB_FULL, 0.0, 1.0)
	var at := Nights.locate(maxf(s, 0.0))
	var bg := NIGHT_BG.lerp(DAWN_BG if at.dawn else DUSK_BG, day * 0.85)
	_env.background_color = bg
	# A flare throws the circle of light down the road.
	_light_c = Vector3(x, 0.0, -s) + world.forward(maxf(s, 0.0)) * FLARE_AHEAD * blaze
	Codex.update(Vector4(_light_c.x, 0.0, _light_c.z, light_r), amb, _lights, bg, _time, _sight if state == State.RUNNING else 1000.0)

func _make_halo() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.9))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	grad.add_point(0.25, Color(1, 1, 1, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_mat.no_depth_test = true
	_halo_mat.albedo_texture = tex
	_halo_mat.albedo_color = Color(1.0, 0.8, 0.45, 0.85)
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	_halo = MeshInstance3D.new()
	_halo.mesh = quad
	_halo.material_override = _halo_mat
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)

## Motes drifting in the air around the road: fireflies, ash, snow, embers —
## whatever the House breathes. They glow, so they show in the dark.
func _make_motes() -> void:
	_motes = CPUParticles3D.new()
	_motes.amount = 46
	_motes.lifetime = 6.0
	_motes.preprocess = 6.0
	_motes.local_coords = false
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(11.0, 2.5, 16.0)
	_motes.direction = Vector3(0, 1, 0)
	_motes.spread = 180.0
	_motes.initial_velocity_min = 0.05
	_motes.initial_velocity_max = 0.35
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _halo_mat.albedo_texture
	quad.material = mat
	_motes.mesh = quad
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_motes.color_ramp = fade
	add_child(_motes)
	_set_motes("jungle")

func _set_motes(set_id: String) -> void:
	var key := set_id + "/" + Themes.event_id()
	if key == _mote_set or not MOTES.has(set_id):
		return
	_mote_set = key
	var m: Array = Themes.motes(MOTES, set_id)
	_motes.color = m[0]
	_motes.gravity = Vector3(0.0, m[1], 0.0)
	_motes.scale_amount_min = m[2] * 0.7
	_motes.scale_amount_max = m[2] * 1.5

func _place_motes() -> void:
	_motes.global_position = Vector3(x, 1.6, -s - 7.0)
	if s > 0.0:
		_set_motes(Nights.house(s, world.seed).decor)

## The Sunstone's glow in his hand: small embers low at his side, a blaze held
## high.
func _place_halo(_delta: float) -> void:
	_halo.global_position = runner.stone_global()
	var size := lerpf(0.9, 2.6, blaze) * (0.35 + 0.65 * light)
	if state == State.TITLE:
		size = 1.6
	elif state == State.DYING or state == State.OFFER or state == State.RESULTS:
		size = 0.4
	_halo.scale = Vector3.ONE * size

# --------------------------------------------------------------- input ---

## One thumb: a swipe is a move (one per touch), a short touch that didn't
## swipe is a flare.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1:
				_touch_index = event.index
				_touch_from = event.position
				_touch_t0 = Time.get_ticks_msec() / 1000.0
				_swiped = false
		elif event.index == _touch_index:
			_touch_index = -1
			if not _swiped:
				_track_swipe(event.position)
			if not _swiped and Time.get_ticks_msec() / 1000.0 - _touch_t0 < TAP_MAX_T:
				_flare()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index and not _swiped:
			_track_swipe(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_move(-1)
			KEY_RIGHT, KEY_D:
				_move(1)
			KEY_UP, KEY_W:
				_jump()
			KEY_DOWN, KEY_S:
				_slide()
			KEY_SPACE:
				_flare()
			KEY_ESCAPE, KEY_P:
				_pause()

func _track_swipe(pos: Vector2) -> void:
	var d := pos - _touch_from
	var vp := get_viewport().get_visible_rect().size
	if d.length() < SWIPE_MIN * minf(vp.x, vp.y):
		return
	_swiped = true
	if absf(d.x) > absf(d.y):
		_move(1 if d.x > 0.0 else -1)
	elif d.y < 0.0:
		_jump()
	else:
		_slide()

func _move(dir: int) -> void:
	if state != State.RUNNING:
		return
	var to := clampi(_lane + dir, -1, 1)
	if to == _lane:
		# Against the curb: a bump, nothing more.
		_shake = maxf(_shake, 0.12)
		return
	_lane_from = _lane
	_lane = to
	_act_t = _run_time
	sfx.play(Sfx.LANE)
	_learn("swipe")
	_learn("dodge")

func _jump() -> void:
	if state != State.RUNNING or y > 0.0 or vy > 0.0:
		return
	_slide_t = 0.0
	_slide_queued = false
	vy = JUMP_V
	_jumps += 1
	_act_t = _run_time
	sfx.play(Sfx.JUMP)
	_learn("jump")

## On the ground: a slide. In the air: dive back down and slide on landing.
func _slide() -> void:
	if state != State.RUNNING:
		return
	if y > 0.0 or vy > 0.0:
		vy = minf(vy, DIVE_V)
		_slide_queued = true
		_learn("slide")
		return
	if _slide_t <= 0.0:
		_slides += 1
		sfx.play(Sfx.SLIDE)
	_slide_t = SLIDE_T
	_act_t = _run_time
	_learn("slide")

## A tap: the Sunstone flares, throwing its light far down the road. It costs
## light, so with too little left it only fizzles.
func _flare() -> void:
	if state != State.RUNNING or _flare_cd > 0.0:
		return
	_flare_cd = FLARE_CD
	if light <= FLARE_COST + 0.03 and not _invincible:
		sfx.play(Sfx.FIZZLE)
		ui.pop("Too little light")
		return
	light = maxf(light - FLARE_COST, 0.02)
	_flare_t = FLARE_TIME
	_run_flares += 1
	sfx.play(Sfx.FLARE)
	_learn("flare")

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_pause()
		NOTIFICATION_APPLICATION_RESUMED:
			# Android forgets a surface's frame-rate wish when it comes back.
			if not FileAccess.file_exists("user://perf_hz"):
				_lock_refresh()

## Android back (routed through the UI layer, which keeps listening while the
## tree is paused): pause, resume, close a modal, or leave.
func _on_back() -> void:
	if state == State.RUNNING:
		_pause()
	elif state == State.PAUSED:
		_resume()
	elif state == State.TITLE:
		if not ui.close_modal():
			get_tree().quit()
	elif state == State.OFFER:
		_finish_run() # back declines the second wind
	elif state == State.RESULTS:
		_leave_results(_go_title)

# -------------------------------------------------------------- placing ---

## [delta] < 0 snaps everything into place (title, restarts).
func _place_runner(delta := -1.0) -> void:
	runner.position = Vector3(x, y, -s)
	if state == State.TITLE:
		runner.rotation = Vector3.ZERO
		return
	# He faces the way he's actually moving: down the road, plus his drift.
	# Both follow a smoothed velocity, eased again, so frame-time noise never
	# reaches his body.
	var dxds := clampf(_x_vel_s / maxf(speed, 1.0), -1.0, 1.0)
	var target_yaw := atan2(-dxds * 0.45, 1.0)
	var target_lean := clampf(-_x_vel_s * 0.025, -0.22, 0.22)
	if delta < 0.0:
		_yaw = target_yaw
		_lean = target_lean
	else:
		_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-7.0 * delta))
		_lean = lerpf(_lean, target_lean, 1.0 - exp(-6.0 * delta))
	runner.rotation = Vector3(0.0, _yaw, _lean)

# --------------------------------------------------------------- camera ---

## High and behind: the road unrolls up the screen and the circle of light
## around him is always in view. It drifts toward him, not all the way, so
## steering reads as movement. [delta] < 0 snaps.
func _chase(delta: float) -> Array:
	var want := lerpf(world.center(maxf(s, 0.0)), x, 0.7)
	_cam_x = want if delta < 0.0 else lerpf(_cam_x, want, 1.0 - exp(-4.0 * delta))
	var base := Vector3(_cam_x, 0.0, -s)
	return [base + Vector3(0.0, CAM_UP, CAM_BACK), base + Vector3(0.0, 0.0, -CAM_AHEAD)]

## Dev: `files/dev_face` puts the title camera right at his face.
var _dev_face := FileAccess.file_exists("user://dev_face")

## The title shot: low, in front of him, the temple rising behind.
func _title_shot() -> Array:
	var sway := sin(_title_t * 0.3) * 0.6
	var base := Vector3(0.0, 0.0, -s)
	if _dev_face:
		return [base + Vector3(0.2, 1.55, -1.0), base + Vector3(0.0, 1.5, 0.0)]
	return [base + Vector3(0.9 + sway * 0.6, 1.5, -3.9), base + Vector3(-0.1, 1.45, 2.0)]

func _update_camera(delta: float) -> void:
	var shot: Array
	if state == State.TITLE:
		shot = _title_shot()
	else:
		shot = _chase(delta)
		if _intro_t < 1.0:
			var t := _intro_t * _intro_t * (3.0 - 2.0 * _intro_t)
			var from := _title_shot()
			shot = [from[0].lerp(shot[0], t) + Vector3(0, sin(PI * t) * 2.0, 0), from[1].lerp(shot[1], t)]
	camera.position = shot[0]
	camera.look_at(shot[1])

func _apply_shake(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(_shake - delta * 1.6, 0.0)
	var m := _shake * _shake * 0.35
	camera.position += Vector3(randf_range(-m, m), randf_range(-m, m), randf_range(-m, m))

# ----------------------------------------------------------- environment ---

func _make_environment() -> void:
	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = DUSK_BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.fog_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The page: bark-paper grain, multiplied in by the world's own shader (a
	# separate full-screen layer cost a whole pass of fill on big phones).
	# 256 px of grain per tile at the UI's scale.
	var ui_scale := get_viewport().get_visible_rect().size.x / 720.0
	Codex.set_grain(_grain_texture(), 0.0 if FileAccess.file_exists("user://perf_nograin") else 1.0, 256.0 * maxf(ui_scale, 1.0) * float(DisplayServer.screen_get_size().x) / get_viewport().get_visible_rect().size.x)
	_build_sky()

## The painted sky behind the temple (seen from the title shot), in the
## colours of the season.
var _sky: MeshInstance3D
func _build_sky() -> void:
	if _sky:
		_sky.queue_free()
	var sky := Mesher.new()
	Models.sky(sky, Models.at(Vector3(0, 0, 110)))
	_sky = sky.to_instance()
	var sky_mat := StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.vertex_color_use_as_albedo = true
	sky_mat.vertex_color_is_srgb = true
	_sky.material_override = sky_mat
	add_child(_sky)

## White paper with the fibres and specks of beaten bark: multiplied over the
## world it leaves colours alone and adds the grain.
static func _grain_texture() -> Texture2D:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color(1, 1, 1))
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 2600:
		var v := r.randf_range(0.84, 0.95)
		img.set_pixel(r.randi() % n, r.randi() % n, Color(v, v * 0.97, v * 0.92))
	for i in 90:
		var px := r.randi() % n
		var py := r.randi() % n
		var len := r.randi_range(8, 30)
		var v := r.randf_range(0.9, 0.96)
		for k in len:
			img.set_pixel(posmod(px + k, n), posmod(py + int(k * r.randf_range(-0.2, 0.2)), n), Color(v, v * 0.97, v * 0.93))
	return ImageTexture.create_from_image(img)

# ------------------------------------------------------------ autopilot ---

## A simple bot for device checks: reads each lane ahead, changes lane round
## what blocks it, jumps walls and pits, slides under lintels, takes sun-drop
## lines when it's safe, and flares when a jaguar wakes.
func _drive(delta: float) -> void:
	_auto_cd = maxf(_auto_cd - delta, 0.0)
	var look := speed * 0.8 + 3.0
	# Per lane: [metres to the nearest danger, what it needs].
	var lanes := {-1: [99.0, ""], 0: [99.0, ""], 1: [99.0, ""]}
	var drops := {-1: 99.0, 0: 99.0, 1: 99.0}
	for c in world.chunks():
		if c.s1 < s - 2.0 or c.s0 > s + look + 2.0:
			continue
		for o in c.obstacles:
			if o.get("hit", false):
				continue
			var ahead: float = o.s - o.depth / 2.0 - s
			if ahead < -o.depth - 0.3 or ahead > look:
				continue
			var d: Dictionary = World.DANGER[o.kind]
			var need := "jump" if d.jump else ("slide" if d.slide else "block")
			for lane in ([-1, 0, 1] if o.lane == World.ALL else [o.lane]):
				if ahead < lanes[lane][0]:
					lanes[lane] = [ahead, need]
		for pit in c.pits:
			var ahead: float = pit.s0 - s
			if ahead < -World.ROW or ahead > look:
				continue
			var lane: int = pit.c0 / 2 - 1
			if ahead < lanes[lane][0]:
				lanes[lane] = [ahead, "jump"]
		for d in c.drops:
			var ahead: float = d.s - s
			if not d.taken and ahead > 0.5 and ahead < look:
				var lane := clampi(roundi(world.u_of(d.pos.x, d.pos.z) / Nights.LANE_W), -1, 1)
				drops[lane] = minf(drops[lane], ahead)
	var wakes := false
	for j in _jags:
		var ahead: float = -j.pos.z - s
		if j.state == "wait":
			wakes = wakes or (ahead > 2.0 and ahead < speed * 1.3 + 4.0)
		elif ahead > -1.0 and ahead < look and ahead < lanes[j.lane][0]:
			lanes[j.lane] = [ahead, "block"]
	var here: Array = lanes[_lane]
	# Blocked ahead: go round, to the side lane that's clear longest.
	if here[1] == "block":
		var best := _lane
		var best_d := -1.0
		for to in [_lane - 1, _lane + 1]:
			if to < -1 or to > 1:
				continue
			var l: Array = lanes[to]
			var free: float = 99.0 if l[1] != "block" else l[0]
			if l[0] < 1.0 and l[0] > -2.0 and l[1] == "block":
				continue # alongside it: changing now would clip it
			if free > best_d:
				best_d = free
				best = to
		if best != _lane:
			_move(best - _lane)
			_auto_cd = 0.25
	elif here[1] == "jump" and here[0] < speed * 0.2 + 0.4 and here[0] > -0.5:
		_jump()
	elif here[1] == "slide" and here[0] < speed * 0.3 + 0.6:
		_slide()
	elif _auto_cd <= 0.0 and drops[_lane] > 50.0:
		# Nothing here: drift toward a line of sun-drops if its lane is clear.
		for to in [_lane - 1, _lane + 1]:
			if to < -1 or to > 1:
				continue
			if drops[to] < look and lanes[to][0] > drops[to] + 4.0 and absf(lanes[to][0]) > 2.0:
				_move(to - _lane)
				_auto_cd = 0.6
				break
	if not _dev_noflare and blaze < 0.2 and (wakes or (light > 0.7 and randf() < delta * 0.2)):
		_flare()

# --------------------------------------------------------------- profiling ---

func _tour_frame(delta: float) -> void:
	if _ph == "":
		return
	_ph_frames += 1
	_ph_time += delta
	if delta > 0.025:
		print("[spike] %5.1fms %-12s %s" % [delta * 1000.0, _ph, ",".join(_prev_events) if not _prev_events.is_empty() else "-"])
	_ph_max = maxf(_ph_max, delta)
	if delta > 0.020:
		_ph_j20 += 1
	if delta > 0.034:
		_ph_j33 += 1
	_ph_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_ph_prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_ph_proc += Performance.get_monitor(Performance.TIME_PROCESS)

## Ends the phase being measured (printing it) and starts [name].
func _phase(name: String) -> void:
	if _ph != "" and _ph_frames > 0:
		var n := float(_ph_frames)
		print("[profile] %-16s fps %5.1f  avg %5.1fms  worst %5.1fms  >20ms %3d  >34ms %3d  draws %4d  prims %4dk  script %4.1fms  mem %dMB" % [
			_ph, n / _ph_time, _ph_time / n * 1000.0, _ph_max * 1000.0, _ph_j20, _ph_j33,
			int(_ph_draws / n), int(_ph_prims / n / 1000.0), _ph_proc / n * 1000.0,
			int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)])
	_ph = name
	_ph_frames = 0
	_ph_time = 0.0
	_ph_max = 0.0
	_ph_j20 = 0
	_ph_j33 = 0
	_ph_draws = 0.0
	_ph_prims = 0.0
	_ph_proc = 0.0

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

## The tour: title, every shop shelf, every page, runs through each House
## (and a dawn), the results page — twice, so the second lap shows the game
## warm (shaders compiled, caches full).
func _run_tour() -> void:
	print("[profile] screen %s, refresh %.0f Hz, renderer %s" % [
		str(DisplayServer.screen_get_size()), DisplayServer.screen_get_refresh_rate(),
		RenderingServer.get_current_rendering_method()])
	await _wait(3.0)
	_tour_seed = 777
	for lap in 2:
		print("[profile] --- lap %d ---" % (lap + 1))
		_phase("title")
		await _wait(5.0)
		for i in Shop.SHELVES.size():
			ui._market_tab = i
			if i == 0:
				ui._open_market()
			else:
				ui._fill_market()
			_phase("shop:" + Shop.SHELVES[i])
			await _wait(3.0)
		ui._market.visible = false
		ui._free_preview()
		for page in [["glyphs", ui._open_glyphs], ["records", ui._open_records], ["daily", ui._open_daily],
				["offerings", ui._open_offerings], ["settings", ui._open_settings], ["ranks", ui._open_ranks]]:
			page[1].call()
			_phase(page[0])
			await _wait(3.0)
			ui.close_modal()
		_phase("title-again")
		await _wait(2.0)
		_autopilot = true
		_invincible = true
		for start in [0.0, 140.0, 280.0, 400.0, 455.0, 625.0, 795.0]:
			_dev_start = start
			_start_run()
			_phase("run@%dm" % int(start))
			await _wait(12.0)
			_phase("")
			_go_title()
			await _wait(1.0)
		# The end of a run: the results page.
		_invincible = false
		_dev_start = 30.0
		_start_run()
		await _wait(2.0)
		_die("Profiling")
		await _wait(1.4)
		if state == State.OFFER or state == State.DYING:
			_finish_run()
		_phase("results")
		await _wait(4.0)
		_phase("")
		_autopilot = false
		_go_title()
		await _wait(1.0)
	# What the GPU spends its time on: the same stretch of road with one
	# feature off at a time.
	print("[profile] --- experiments (same road) ---")
	_autopilot = true
	_invincible = true
	for exp in ["base", "msaa-2x", "no-msaa", "no-grain", "no-ink", "scale-0.8", "base"]:
		_set_experiment(exp, true)
		_dev_start = 140.0
		_start_run()
		await _wait(1.5)
		_phase("exp:" + exp)
		await _wait(9.0)
		_phase("")
		_set_experiment(exp, false)
		_go_title()
		await _wait(1.0)
	_autopilot = false
	_invincible = false
	print("[profile] done")

func _set_experiment(name: String, on: bool) -> void:
	match name:
		"no-msaa":
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED if on else Viewport.MSAA_4X
		"msaa-2x":
			get_viewport().msaa_3d = Viewport.MSAA_2X if on else Viewport.MSAA_4X
		"no-grain":
			Codex.set_grain(_grain_texture(), 0.0 if on else 1.0)
		"no-ink":
			Codex.world().next_pass = null if on else Codex.outline()
			Codex.glow().next_pass = null if on else Codex.outline()
		"scale-0.8":
			get_viewport().scaling_3d_scale = 0.8 if on else 1.0

# ------------------------------------------------------------ store shots ---

## Freezes the frame for the host to capture, then carries on.
func _hold(name: String) -> void:
	get_tree().paused = true
	print("[shot] " + name)
	await get_tree().create_timer(3.0, true, false, true).timeout
	get_tree().paused = false

func _shot_run(start: float, blaze: float, light_v: float) -> void:
	_go_title()
	_dev_start = start
	_autopilot = true
	_invincible = true
	_force_blaze = blaze
	_start_run()
	_intro_t = 1.0
	light = light_v

## Jaguars staged round the runner: [offsets] are (across, ahead) metres.
func _shot_jaguars(offsets: Array) -> void:
	for o in offsets:
		_add_jaguar(Vector3(x + o.x, 0.0, -(s + o.y)))

func _run_shots() -> void:
	Themes.choose_event("none")
	_spawn_runner()
	_tour_seed = 2024
	await _wait(4.0)
	_go_title()
	await _wait(4.0)
	await _hold("01_title")
	# Blazing in the House of Jaguars: they stand frozen in the light.
	_shot_run(180.0, 1.0, 0.95)
	await _wait(1.2)
	_shot_jaguars([Vector2(-2.4, 2.5), Vector2(2.6, 4.0), Vector2(-1.2, 6.5), Vector2(3.4, 9.5)])
	await _wait(1.8)
	await _hold("02_blaze")
	# Embers: eyes in the dark, coming.
	_shot_run(200.0, 0.0, 0.8)
	await _wait(2.5)
	_shot_jaguars([Vector2(-3.0, 7.0), Vector2(3.4, 9.0), Vector2(0.4, 12.5), Vector2(-4.2, 14.5), Vector2(4.6, 15.5)])
	await _wait(0.35)
	await _hold("03_dark")
	# The House of Bats: a blaze, and they come.
	_shot_run(300.0, 1.0, 0.8)
	await _wait(2.5)
	for k in 4:
		var node := BatModel.new()
		add_child(node)
		var rel: Vector3 = [Vector3(-2.2, 4.2, 1.5), Vector3(2.6, 3.6, 0.0), Vector3(-0.6, 3.0, -2.5), Vector3(3.2, 4.8, -4.0)][k]
		_bats.append({"node": node, "rel": rel, "vel": Vector3.ZERO, "gone": false, "flee": false, "life": 0.0})
		node.scale = Vector3.ONE * 2.0
	await _wait(0.25)
	await _hold("04_bats")
	# The House of Fire, wherever this seed puts it.
	var fire_s := 0.0
	for n in range(2, 6):
		var plan := Nights.plan(n, _tour_seed)
		var k := plan.find("fire")
		if k >= 0:
			fire_s = Nights.house_starts(n)[k] + 30.0
			break
	_shot_run(fire_s, 0.6, 0.9)
	await _wait(3.5)
	await _hold("05_fire")
	# Dawn.
	_shot_run(Nights.start(2) - 22.0, 0.0, 0.7)
	await _wait(0.9)
	await _hold("06_dawn")
	_force_blaze = -1.0
	_invincible = false
	_autopilot = false
	_go_title()
	await _wait(1.5)
	# The shop, Ixchel in the preview.
	ui._market_tab = 0
	ui._shop_sel["Runners"] = "ixchel"
	ui._open_market()
	await _wait(2.5)
	await _hold("07_shop")
	ui._market.visible = false
	ui._free_preview()
	ui._open_glyphs()
	await _wait(1.5)
	await _hold("08_glyphs")
	ui.close_modal()
	print("[shot] done")

func _profile(delta: float) -> void:
	_fps_t += delta
	_prof_n += 1
	_prof_max_dt = maxf(_prof_max_dt, delta)
	if state == State.RUNNING:
		var rot := runner.rotation
		_prof_jit = maxf(_prof_jit, maxf(absf(angle_difference(rot.y, _prof_last_rot.y)), absf(rot.z - _prof_last_rot.z)))
		_prof_last_rot = rot
	if _fps_t > 2.0:
		var vp := get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		print("[sunstone] fps %d cpu %.1fms gpu %.1fms proc %.1fms maxdt %.1fms draws %d prims %dk s %.0f jit %.3f" % [
			Engine.get_frames_per_second(),
			RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
			RenderingServer.viewport_get_measured_render_time_gpu(vp),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			_prof_max_dt * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0, s, _prof_jit])
		_prof_jit = 0.0
		_fps_t = 0.0
		_prof_n = 0
		_prof_max_dt = 0.0

## Asks a 90/120 Hz screen to run at 60 Hz, so every frame shows for the
## same time (a game rendering 60–80 fps on a 90 Hz screen judders).
func _lock_refresh() -> void:
	var hz := DisplayServer.screen_get_refresh_rate()
	if hz > 61.0 and Engine.has_singleton("SunstoneGoogleSignIn"):
		# (Android plugin objects don't list their methods to has_method().)
		var plugin := Engine.get_singleton("SunstoneGoogleSignIn")
		var rates := str(plugin.call("setRefreshRate", 60.0))
		print("[sunstone] display offers %s Hz; asked for 60" % rates)
		if "60" in rates.split(","):
			# The screen will run at 60: render exactly that, evenly.
			Engine.max_fps = 60

## Dev-only perf switches, read from user:// flag files so a device build can be
## profiled without rebuilding: perf_nomsaa, perf_novsync, perf_scale (file
## contents = 3D render scale, e.g. 0.8), perf_nograin.
func _dev_perf_flags() -> void:
	if FileAccess.file_exists("user://perf_nomsaa"):
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	if FileAccess.file_exists("user://perf_novsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if FileAccess.file_exists("user://perf_scale"):
		_render_scale = clampf(FileAccess.get_file_as_string("user://perf_scale").to_float(), 0.5, 1.0)
		get_viewport().scaling_3d_scale = _render_scale
