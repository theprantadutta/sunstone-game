extends Node3D
## Sunstone — carry the sun through Xibalba. Owns the state machine (title →
## running → dying → results), the run itself (hold to blaze and steer, let go
## for embers), the light, the jaguars and bats, the camera, and hands numbers
## to the UI.
##
## One thumb, one decision: how bright to be. Holding blazes the Sunstone —
## colour floods back into the world, the jaguars freeze to stone, you can
## steer — but it burns light and draws the bats. Letting go dims it to embers:
## the road leads you, the light lasts, and the dark closes in.

enum State { TITLE, RUNNING, PAUSED, DYING, OFFER, RESULTS }

const START_S := -3.0
const BLAZE_R := 8.4 ## metres of light at full blaze
const DRAIN_EMBER := 0.014 ## light per second, let go
const DRAIN_BLAZE := 0.075 ## extra light per second, blazing
const DROP_LIGHT := 0.055
const DAWN_GIFT := 0.35 ## light the sunrise gives back
const STEER_SPAN := 11.5 ## metres a finger crossing the whole screen moves him
const DROP_R := 0.85
const CATCH_R := 0.75
const JAG_CREEP := 3.0 ## m/s, a waking jaguar coming at you
const JAG_CHASE := 2.7 ## m/s faster than you, one hunting from behind
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
const CAM_UP := 13.0
const CAM_BACK := 9.5
const CAM_AHEAD := 6.0
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
var blaze := 0.0 ## 0 = embers, 1 = blazing
var light_r := 2.0 ## metres of light around him right now
var amb := AMB_FULL ## daylight radius (dusk and dawn)
var daily_key := "" ## set while running the daily dusk ("yyyy-mm-dd")
var death_cause := ""
var _run_flares := 0 ## how many times he blazed
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
var _dark_t := 0.0 ## how long you've been dim
var _house_key := ""
var _hints := {}
var _hold_total := 0.0
var _was_touching := false
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
var _touching := false
var _touch_index := -1
var _anchor_finger := 0.0
var _anchor_u := 0.0 ## where across the road he was when the thumb went down
var _finger := 0.0
var _key_left := false
var _key_right := false
var _key_blaze := false

## Dev-only: `-- --autopilot` (or `files/autopilot` on a device) plays by itself.
var _autopilot := OS.get_cmdline_user_args().has("--autopilot") or FileAccess.file_exists("user://autopilot")
## Dev: `files/dev_noflare` — the autopilot never blazes unless it must steer.
var _dev_noflare := FileAccess.file_exists("user://dev_noflare")
## Dev: `files/dev_start` holding metres starts every run that far along.
var _dev_start := FileAccess.get_file_as_string("user://dev_start").to_float() if FileAccess.file_exists("user://dev_start") else 0.0
var _auto_touch := false
var _auto_tx := 0.0
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
	_go_title()
	if _autopilot:
		get_tree().create_timer(1.5).timeout.connect(_start_run)

# ------------------------------------------------------------- states ---

func _reset_run() -> void:
	for j in _jags:
		j.node.queue_free()
	_jags.clear()
	for b in _bats:
		b.node.queue_free()
	_bats.clear()
	world.reset(MayaCalendar.seed_for(daily_key) if daily_key != "" else randi())
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
	_dark_t = 0.0
	_house_key = ""
	_strings.clear()
	_hints.clear()
	_hold_total = 0.0
	_was_touching = false
	_touching = false
	_touch_index = -1
	_cam_x = 0.0
	runner.rotation = Vector3.ZERO
	runner.raise = 0.0

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
	online.track("run_start", {"mode": "daily" if daily_key != "" else "free", "runs": save.runs})
	if save.tutorial_runs < 2:
		get_tree().create_timer(0.9).timeout.connect(func():
			if state == State.RUNNING and _hold_total < 0.5:
				ui.show_hint("Touch and hold: the Sunstone blazes and you can steer", Vector2.ZERO))

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
	_touching = false
	_touch_index = -1
	get_tree().paused = true
	ui.show_pause()

func _resume() -> void:
	if state != State.PAUSED:
		return
	get_tree().paused = false
	state = State.RUNNING
	_touching = false
	_touch_index = -1
	ui.show_hud(MayaCalendar.tzolkin_name(daily_key) if daily_key != "" else "")

func _die(cause: String, fell := false, caught := false) -> void:
	if state != State.RUNNING:
		return
	state = State.DYING
	death_cause = cause
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
		if world.in_pit(x, -s):
			s += World.ROW * 1.5
		x = world.center(s)
		if world.in_pit(x, -s):
			s += World.ROW * 1.5
	for c in world.chunks():
		for o in c.obstacles:
			if absf(o.s - s) < 3.0:
				o["hit"] = true
	for j in _jags.duplicate():
		if Vector2(j.pos.x - x, j.pos.z + s).length() < 14.0:
			j.node.queue_free()
			_jags.erase(j)
	for b in _bats:
		b.flee = true
	y = 0.0
	vy = 0.0
	light = maxf(light, 0.6)
	_shield_t = 1.5
	_fell = false
	_caught = false
	_dark_t = 0.0
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
	})
	save.save_to_disk()
	ui.show_results(death_cause, metres, coins, save.best, is_best, daily_info, new_glyphs, _night_line())
	_maybe_ask_review(is_best, metres)
	online.submit_run({
		"mode": "daily" if daily_key != "" else "free", "dailyKey": daily_key if daily_key != "" else null,
		"distance": metres, "drops": coins, "flares": _run_flares, "durationMs": int(_run_time * 1000.0),
		"dusk": snappedf(dusk, 0.001), "cause": death_cause,
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
	runner = Shop.dress(save.character, save.garb, save.hat, save.hue)
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
	world.spin(delta)
	if _autopilot:
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

func _step_run(delta: float) -> void:
	_run_time += delta
	_intro_t = minf(_intro_t + delta / 1.1, 1.0)
	var at := Nights.locate(maxf(s, 0.0))
	speed = Nights.speed(at.n, at.t)
	s += speed * delta
	distance = maxf(s, 0.0)
	world.ensure(s)
	var h: Dictionary = Themes.house("dusk") if s < 0.0 else Nights.house(s, world.seed)

	# The thumb: holding blazes (and steers), letting go dims to embers.
	if _autopilot:
		_drive()
	var steering := _touching or _key_left or _key_right or (_autopilot and _auto_touch)
	var touching := steering or _key_blaze
	var want := 1.0 if touching and light > 0.0 else 0.0
	blaze += (want - blaze) * minf(1.0, delta * (9.0 if want > blaze else 5.0))
	if touching and not _was_touching:
		_run_flares += 1
		sfx.play(Sfx.BLAZE if light > 0.05 else Sfx.FIZZLE)
	if touching:
		_hold_total += delta
	elif _was_touching and _hold_total > 1.0 and save.tutorial_runs < 2:
		_hint("release", "Let go to save light: the road leads you, but the dark comes closer")
	_was_touching = touching

	# The light: embers barely drain, a blaze burns.
	if s > 0.0 and not at.dawn:
		light -= (DRAIN_EMBER + DRAIN_BLAZE * blaze) * h.drain * Market.drain_scale(save) * delta
	light = clampf(light, 0.0, 1.0)
	light_r = lerpf(h.ember, BLAZE_R, blaze) * (0.5 + 0.5 * sqrt(light))
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

	# Steering: while touching he keeps his place across the road and the thumb
	# moves him over; let go and the road leads him back to its middle.
	var old_x := x
	if _autopilot and _auto_touch:
		x += (_auto_tx - x) * minf(1.0, delta * 11.0)
	elif _touching:
		var vp_w := get_viewport().get_visible_rect().size.x
		var tu := _anchor_u + (_finger - _anchor_finger) / vp_w * STEER_SPAN
		var tx := world.point(s + speed * 0.1, tu).x
		x += (tx - x) * minf(1.0, delta * 8.0)
	elif _key_left or _key_right:
		var ku := world.u_of(x, -s) + ((1.0 if _key_right else 0.0) - (1.0 if _key_left else 0.0)) * 6.5 * delta
		x = world.point(s + speed * 0.1, ku).x
	else:
		x += (world.center(s + speed * 0.15) - x) * minf(1.0, delta * 4.0)
	_x_vel = (x - old_x) / maxf(delta, 0.0001)
	_x_vel_s = lerpf(_x_vel_s, _x_vel, 1.0 - exp(-8.0 * delta))

	_check_houses(at, h)
	_shield_t = maxf(_shield_t - delta, 0.0)
	_growl_cd = maxf(_growl_cd - delta, 0.0)
	if _shield_t <= 0.0 and _check_hazards():
		return
	_collect()
	_step_jaguars(delta, h, at)
	if state != State.RUNNING:
		return
	_step_bats(delta, h, at)
	if light <= 0.0 and s > 0.0 and not at.dawn:
		if save.use_boost("shield"):
			light = 0.4
			ui.pop("Ember shield!")
			ui.flash_flare()
			sfx.play(Sfx.FLARE)
		else:
			_die("The Sunstone went out")
			return
	if save.tutorial_runs < 2 and light < 0.35:
		_hint("drops", "Sun-drops feed the stone: steer through them")

	runner.pose = RunnerModel.Pose.RUN
	runner.raise = blaze
	runner.animate(delta, speed)
	_place_runner(delta)
	_update_camera(delta)
	_push_codex()
	ui.set_run_numbers(int(distance), coins)
	ui.set_night(at.n, h.name, at.t, at.dawn)
	ui.set_light(light, 1.0 - amb / AMB_FULL, _nearest_jaguar())

## Entering a House, or dawn: a banner, a sound, and on the first nights a hint.
func _check_houses(at: Dictionary, h: Dictionary) -> void:
	var key := "%d:%d:%s" % [at.n, at.house, at.dawn]
	if key == _house_key:
		return
	var first := _house_key == ""
	_house_key = key
	if at.dawn:
		ui.show_banner("Dawn", "Night %d survived" % at.n)
		sfx.play(Sfx.DAWN)
		light = minf(light + DAWN_GIFT, 1.0)
		for j in _jags:
			j.node.queue_free()
		_jags.clear()
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
	if save.tutorial_runs < 2:
		var id: String = Nights.plan(at.n, world.seed)[at.house]
		if id == "jaguars":
			_hint("jaguars", "Jaguars move only in the dark: blaze and they turn to stone")
		elif id == "bats":
			_hint("bats", "Bats hunt bright light: let go and they lose you")

func _hint(key: String, text: String) -> void:
	if _hints.has(key):
		return
	_hints[key] = true
	ui.show_hint(text, Vector2.ZERO)

## Returns true when the run just ended.
func _check_hazards() -> bool:
	var z := -s
	if absf(world.u_of(x, z)) > world.width(s) / 2.0 - 0.12:
		_die("Stepped off the road into Xibalba", true)
		return true
	if world.in_pit(x, z):
		_die("Fell into a pit", true)
		return true
	for c in world.chunks():
		if c.s1 < s - 2.0 or c.s0 > s + 2.0:
			continue
		for o in c.obstacles:
			if o.get("hit", false):
				continue
			var p: Vector3 = o.pos
			if Vector2(p.x - x, p.z - z).length() < o.r:
				_die("Ran into a fallen stela" if o.kind == "stela" else "Cut on obsidian blades")
				return true
	return false

func _collect() -> void:
	for c in world.chunks():
		if c.s1 < s - 2.0 or c.s0 > s + 2.0:
			continue
		for d in c.drops:
			if d.taken:
				continue
			var p: Vector3 = d.pos
			if Vector2(p.x - x, p.z + s).length() < DROP_R:
				d.taken = true
				coins += 1
				light = minf(light + DROP_LIGHT * Market.drop_scale(save), 1.0)
				sfx.play(Sfx.COIN)
				# The whole string of five: a bonus for steering well.
				var tid: int = d.get("trail", 0)
				if tid > 0:
					_strings[tid] = _strings.get(tid, 0) + 1
					if _strings[tid] == 5:
						coins += STRING_BONUS
						light = minf(light + DROP_LIGHT, 1.0)
						ui.pop("Sun-string  +%d" % STRING_BONUS)
						sfx.play(Sfx.BLAZE)

func _is_lit(p: Vector3) -> bool:
	var d := Vector2(p.x - x, p.z + s).length()
	if d < light_r * 0.92 or d < amb:
		return true
	for l in _lights:
		if l.w > 0.0 and Vector2(p.x - l.x, p.z - l.z).length() < l.w:
			return true
	return false

func _on_chunk(c: World.Chunk) -> void:
	for spawn in c.jaguars:
		_add_jaguar(spawn.pos)

func _add_jaguar(pos: Vector3) -> void:
	var node := JaguarModel.new()
	node.scale = Vector3.ONE * 1.15
	add_child(node)
	node.position = pos
	node.rotation.y = randf() * TAU
	node.frozen = true
	_jags.append({"node": node, "pos": pos, "frozen": true, "linger": 0.0})

## The stone jaguars: frozen wherever there is light, and in the dark they
## come for you — from ahead at a creep, from behind at a run.
func _step_jaguars(delta: float, h: Dictionary, at: Dictionary) -> void:
	var me := Vector3(x, 0.0, -s)
	for j in _jags.duplicate():
		var p: Vector3 = j.pos
		var ahead := -p.z - s
		if ahead < -16.0:
			j.node.queue_free()
			_jags.erase(j)
			continue
		if ahead > 32.0:
			continue
		var lit := _is_lit(p)
		if lit:
			j.linger = Market.freeze_bonus(save)
		elif j.linger > 0.0:
			j.linger -= delta
			lit = true
		j.frozen = lit
		j.node.frozen = lit
		if lit:
			continue
		var to := me - p
		to.y = 0.0
		var dist := to.length()
		var sp: float = speed + JAG_CHASE if ahead < 0.2 else JAG_CREEP + 0.49 * Nights.progress(s)
		if dist > 0.01:
			p += to / dist * sp * delta
		j.pos = p
		j.node.position = p
		j.node.rotation.y = lerp_angle(j.node.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-10.0 * delta))
		j.node.animate(delta, sp)
		if dist < 9.0 and _growl_cd <= 0.0:
			sfx.play(Sfx.ROAR)
			_growl_cd = 6.0
		if dist < CATCH_R and _shield_t <= 0.0:
			if save.use_boost("ward"):
				# The ward: this one is stone for good.
				j.node.frozen = true
				_jags.erase(j)
				ui.pop("Jaguar ward!")
				ui.flash_flare()
				sfx.play(Sfx.FLARE)
				_shield_t = 1.0
				continue
			_die("Caught by a jaguar in the dark", false, true)
			return
	# Stay dim too long and one finds your trail from behind.
	if blaze < 0.3 and s > Nights.START_CLEAR and not at.dawn:
		_dark_t += delta
	else:
		_dark_t = maxf(0.0, _dark_t - delta * 2.0)
	if _dark_t > 2.2 and randf() < delta * 0.5 * h.w_jag:
		_dark_t = 0.8
		_add_jaguar(Vector3(x + randf_range(-2.4, 2.4), 0.0, -(s - 9.0)))

func _nearest_jaguar() -> float:
	var best := 24.0
	for j in _jags:
		if not j.frozen:
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
			_bats.append({"node": node, "rel": Vector3(randf_range(-6.0, 6.0), 4.5, -randf_range(16.0, 21.0)),
				"vel": Vector3.ZERO, "gone": false, "flee": false, "life": 0.0})
			sfx.play(Sfx.BAT)
	for b in _bats.duplicate():
		b.life += delta
		var hunting: bool = not b.gone and not b.flee and blaze > 0.35
		var rel: Vector3 = b.rel
		var vel: Vector3 = b.vel
		if hunting:
			var to := Vector3(0.0, 1.4, 0.0) - rel
			var dist := to.length()
			var sp: float = BAT_SPEED + 0.59 * (at.n - 1)
			vel = vel.lerp(to / maxf(dist, 0.01) * sp, 1.0 - exp(-3.0 * delta))
			if dist < BAT_HIT_R and _shield_t <= 0.0:
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
		if _caught:
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
	Codex.update(Vector4(x, 0.0, -s, light_r), amb, _lights, bg, _time)

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1:
				_touch_index = event.index
				_touching = true
				_anchor_finger = event.position.x
				_finger = event.position.x
				_anchor_u = world.u_of(x, -s)
		elif event.index == _touch_index:
			_touching = false
			_touch_index = -1
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_finger = event.position.x
	elif event is InputEventKey and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_key_left = event.pressed
			KEY_RIGHT, KEY_D:
				_key_right = event.pressed
			KEY_SPACE, KEY_UP, KEY_W:
				_key_blaze = event.pressed
			KEY_ESCAPE, KEY_P:
				if event.pressed:
					_pause()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_pause()

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
	var target_yaw := atan2(-dxds, 1.0)
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
	var want := lerpf(world.center(maxf(s, 0.0)), x, 0.55)
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
	# The page: bark-paper grain over the whole 3D view (under the UI).
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var grain := TextureRect.new()
	grain.texture = _grain_texture()
	grain.stretch_mode = TextureRect.STRETCH_TILE
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	grain.material = mat
	layer.add_child(grain)
	grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if FileAccess.file_exists("user://perf_nograin"):
		layer.visible = false
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

## A simple bot for device checks: dodges what's ahead, takes drops when it
## can, blazes when a jaguar wakes, lets go when bats come.
func _drive() -> void:
	var tx := world.center(s + speed * 0.15)
	var steer := false
	for c in world.chunks():
		if c.s1 < s - 1.0 or c.s0 > s + 9.0:
			continue
		for o in c.obstacles:
			var ahead: float = o.s - s
			var p: Vector3 = o.pos
			if ahead > -0.6 and ahead < 6.5 and absf(p.x - x) < o.r + 0.9:
				var side := -1.0 if world.u_of(p.x, p.z) > 0.0 else 1.0
				tx = p.x + side * (o.r + 1.4)
				steer = true
		for pit in c.pits:
			var ahead: float = pit.s0 + 1.0 - s
			if ahead > -1.2 and ahead < 6.5:
				var w := world.width(pit.s0)
				var u0: float = (float(pit.c0) / World.COLS - 0.5) * w
				var u1: float = (float(pit.c1 + 1) / World.COLS - 0.5) * w
				var pu := world.u_of(x, -s)
				if pu > u0 - 0.9 and pu < u1 + 0.9:
					var go := u0 - 1.2 if absf(u0) < absf(u1) or u1 > w / 2.0 - 1.5 else u1 + 1.2
					if u0 < -w / 2.0 + 1.5:
						go = u1 + 1.2
					tx = world.point(pit.s0 + 1.0, go).x
					steer = true
	if not steer and light < 0.92:
		for c in world.chunks():
			if c.s1 < s or c.s0 > s + 8.0:
				continue
			for d in c.drops:
				var ahead: float = d.s - s
				if not d.taken and ahead > 1.0 and ahead < 6.0 and absf(d.pos.x - x) > 0.35:
					tx = d.pos.x
					steer = true
					break
			if steer:
				break
	var danger := _nearest_jaguar() < 8.0
	var bats_near := false
	for b in _bats:
		if not b.gone and b.rel.length() < 6.0:
			bats_near = true
	var want := steer or (danger and not _dev_noflare)
	if bats_near and not danger and not steer:
		want = false
	var w := world.width(s)
	var cx := world.center(s)
	_auto_tx = clampf(tx, cx - w / 2.0 + 0.8, cx + w / 2.0 - 0.8)
	_auto_touch = want

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

## Dev-only perf switches, read from user:// flag files so a device build can be
## profiled without rebuilding: perf_nomsaa, perf_novsync, perf_scale (file
## contents = 3D render scale, e.g. 0.8), perf_nograin.
func _dev_perf_flags() -> void:
	if FileAccess.file_exists("user://perf_nomsaa"):
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	if FileAccess.file_exists("user://perf_novsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if FileAccess.file_exists("user://perf_scale"):
		get_viewport().scaling_3d_scale = clampf(FileAccess.get_file_as_string("user://perf_scale").to_float(), 0.5, 1.0)
