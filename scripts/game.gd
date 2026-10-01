extends Node3D
## Sunstone — the run. Owns the state machine (title → running → dying →
## results), the runner's movement in path space, input, collisions, the
## jaguars, the camera, and hands numbers to the UI.

enum State { TITLE, RUNNING, PAUSED, DYING, OFFER, RESULTS }

const START_SPEED := 12.5
const MAX_SPEED := 27.0
const SPEED_RAMP := 1800.0 ## metres to approach top speed
const JUMP_VELOCITY := 9.2
const GRAVITY := 30.0
const FALL_GRAVITY := 1.35 ## heavier on the way down: snappy, not floaty
const SLAM_VELOCITY := -22.0
const SLIDE_TIME := 0.65
const LANE_STIFFNESS := 24.0 ## lane-change spring; settles in ~0.2 s
const TURN_WINDOW := 7.0 ## swipe this far before a corner to turn
const JUMP_BUFFER := 0.14 ## a jump swiped just before landing still counts
const START_S := 8.0
const STUMBLE_MEMORY := 8.0 ## a second stumble inside this window = caught
const SWIPE_DISTANCE := 42.0

# --- the dusk run: the sun sets as you go; the Sunstone is your only light ---
const DUSK_DISTANCE := 1100.0 ## metres from sunset to full night
const LIGHT_DRAIN_DAY := 0.010 ## per second, while the sun is still up
const LIGHT_DRAIN_NIGHT := 0.034
const DROP_LIGHT := 0.035 ## each sun-drop feeds the stone this much
const FLARE_COST := 0.22
const FLARE_FREEZE := 1.6 ## seconds the jaguars stand frozen as stone
const FLARE_PUSH := 7.0 ## metres a flare drives them back
const DARK_LIGHT := 0.35 ## below this the jaguars wake and close in

const LW := Models.LANE_WIDTH

var state := State.TITLE

var world: World
var runner: RunnerModel
var jaguars: Array[JaguarModel] = []
var camera: Camera3D
var ui: GameUI
var online: Online
var ads: Ads
var store: Store
var sfx: Sfx
var save := SaveData.new()

# --- run state (path space) ---
var seg_index := 0
var s := START_S
var x := 0.0
var x_vel := 0.0
var lane_target := 0
var lane_from := 0
var y := 0.0
var vy := 0.0
var slide_t := 0.0
var slide_after_land := false
var pending_turn := 0
var speed := START_SPEED
var distance := 0.0
var coins := 0
var stumble_t := 0.0
var chaser_gap := 3.0
var light := 1.0 ## the Sunstone's charge, 0..1
var dusk := 0.0 ## 0 = sunset begins, 1 = full night
var _freeze_t := 0.0
var _run_flares := 0
var _recovered := false ## survived a stumble this run (the "Close call" glyph)
var _second_wind_used := false
var _shield_t := 0.0 ## after a second wind: a moment where nothing can hit him
var daily_key := "" ## set while running the daily dusk ("yyyy-mm-dd")
var _run_time := 0.0
var _push_back := 0.0
var _flare_boost := 0.0
var _growl_cd := 0.0
var _touch_time := 0
var _stone_light: OmniLight3D
var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _applied_dusk := -1.0
## Dev: `files/dev_dusk` holding e.g. 1.0 starts every run at that much dusk.
var _dev_dusk := FileAccess.get_file_as_string("user://dev_dusk").to_float() if FileAccess.file_exists("user://dev_dusk") else 0.0
var death_cause := ""
var _death_t := 0.0
var _fell := false
var _caught := false
var _yaw := 0.0
var _jump_buffer := 0.0
var _vis_offset := Vector3.ZERO ## eases out any snap when the path changes under him
var _title_t := 0.0
var _intro_t := 0.0 ## 0→1 camera move from the title shot into the chase
var _trail: Array[Dictionary] = [] ## {d, p, dir} — camera and jaguars follow it
var _hints_shown := {}
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _cam_yaw := 0.0
var _cam_off := Vector3.ZERO
var _cam_lift := 0.0
var _fps_t := 0.0
var _backdrop: Node3D
var _prof_n := 0
var _perf_nocoins := FileAccess.file_exists("user://perf_nocoins")
var _prof_coins := 0
var _prof_step := 0
var _prof_max_dt := 0.0
var _shake := 0.0

# --- touch ---
var _touch_start := Vector2.ZERO
var _touch_active := false
var _swiped := false

## Dev-only: `-- --autopilot` plays the game by itself (for rendered checks);
## `-- --title` holds on the title screen.
## On a device, `adb shell run-as <pkg> touch files/autopilot` switches it on.
var _autopilot := OS.get_cmdline_user_args().has("--autopilot") or FileAccess.file_exists("user://autopilot")

func _ready() -> void:
	save.load_from_disk()
	online = Online.new()
	add_child(online)
	ads = Ads.new()
	add_child(ads)
	store = Store.new()
	add_child(store)
	online.config_loaded.connect(func(c: Dictionary):
		ads.configure(c.get("adsEnabled", false), int(c.get("interstitialEveryRuns", 4)), save.has_entitlement("no_ads"))
		store.open = c.get("storeOpen", false))
	_make_environment()
	world = World.new()
	add_child(world)
	_spawn_runner()
	for i in 2:
		var j := JaguarModel.new()
		add_child(j)
		jaguars.append(j)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 66.0
	camera.far = 420.0
	add_child(camera)
	sfx = Sfx.new()
	add_child(sfx)
	sfx.apply_settings(save)
	ui = GameUI.new()
	add_child(ui)
	ui.run_pressed.connect(_start_run)
	ui.daily_pressed.connect(_start_daily)
	ui.looks_changed.connect(_spawn_runner)
	ui.account_deleted.connect(func():
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
	ui.home_pressed.connect(_go_title)
	ui.again_pressed.connect(_restart)
	ui.settings_changed.connect(_on_settings_changed)
	ui.back_requested.connect(_on_back)
	ui.setup(save, online, ads, store)
	store.setup(online, save)
	store.products_changed.connect(func():
		ads.no_ads = save.has_entitlement("no_ads"))
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
	_go_title()
	if _autopilot:
		get_tree().create_timer(1.2).timeout.connect(_start_run)

# ------------------------------------------------------------- states ---

func _reset_run() -> void:
	world.reset(MayaCalendar.seed_for(daily_key) if daily_key != "" else randi())
	seg_index = 0
	s = START_S
	x = 0.0
	x_vel = 0.0
	_vis_offset = Vector3.ZERO
	_jump_buffer = 0.0
	lane_target = 0
	lane_from = 0
	y = 0.0
	vy = 0.0
	slide_t = 0.0
	slide_after_land = false
	pending_turn = 0
	speed = START_SPEED
	distance = 0.0
	coins = 0
	stumble_t = 0.0
	chaser_gap = 2.6
	light = FileAccess.get_file_as_string("user://dev_light").to_float() if FileAccess.file_exists("user://dev_light") else 1.0
	dusk = _dev_dusk
	_freeze_t = 0.0
	_run_flares = 0
	_recovered = false
	_second_wind_used = false
	_shield_t = 0.0
	_run_time = 0.0
	_push_back = 0.0
	_flare_boost = 0.0
	_growl_cd = 0.0
	_apply_dusk(true)
	death_cause = ""
	_fell = false
	_caught = false
	_hints_shown.clear()
	var seg := world.get_segment(0)
	_yaw = _yaw_of(seg.dir)
	_cam_yaw = _yaw
	_cam_off = Vector3.ZERO
	_cam_lift = 0.0
	_trail.clear()
	# Seed the trail behind the start so the chase camera has somewhere to sit.
	for i in 12:
		var d := -6.0 + i * 0.5
		_trail.append({"d": d, "p": seg.point(START_S + d), "dir": seg.dir})
	for j in jaguars:
		j.visible = false

func _go_title() -> void:
	get_tree().paused = false
	if state == State.RESULTS:
		ads.after_run(save.runs)
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
	for j in jaguars:
		j.visible = true
	ui.show_hud(MayaCalendar.tzolkin_name(daily_key) if daily_key != "" else "")
	sfx.play(Sfx.ROAR)
	online.track("run_start", {"mode": "daily" if daily_key != "" else "free", "runs": save.runs})

## Today's dusk: the same causeway for everyone, fixed for the whole run even
## if the date turns while running.
func _start_daily() -> void:
	if state != State.TITLE:
		return
	daily_key = MayaCalendar.today_utc()
	_reset_run()
	_place_runner()
	_start_run()

func _restart() -> void:
	get_tree().paused = false
	if state == State.RESULTS:
		ads.after_run(save.runs)
	_reset_run()
	state = State.TITLE # _start_run needs TITLE
	_start_run()
	_intro_t = 1.0 # straight into the chase camera
	_snap_camera()

func _pause() -> void:
	if state != State.RUNNING:
		return
	state = State.PAUSED
	get_tree().paused = true
	ui.show_pause()

func _resume() -> void:
	if state != State.PAUSED:
		return
	get_tree().paused = false
	state = State.RUNNING
	ui.show_hud()

func _die(cause: String, fell := false, caught := false) -> void:
	if state != State.RUNNING:
		return
	state = State.DYING
	death_cause = cause
	_fell = fell
	_caught = caught
	_death_t = 0.0
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
	var seg := world.get_segment(seg_index)
	if _fell and s > seg.length:
		# Ran off the end: rise at the start of the next stretch.
		seg_index += 1
		world.ensure_ahead(seg_index)
		s = 1.5
		x = 0.0
	elif _fell:
		for g in seg.gaps:
			if s >= g.x - 1.0 and s <= g.y + 4.0:
				s = g.y + 1.5
	else:
		s += 1.5
		for o in seg.obstacles:
			if absf(o.s - s) < 3.0:
				o["hit"] = true
	lane_target = clampi(roundi(x / LW), -1, 1)
	x = lane_target * LW
	x_vel = 0.0
	y = 0.0
	vy = 0.0
	slide_t = 0.0
	pending_turn = 0
	_vis_offset = Vector3.ZERO
	light = maxf(light, 0.6)
	chaser_gap = 24.0
	_freeze_t = 2.0
	stumble_t = 0.0
	_shield_t = 1.5
	_fell = false
	_caught = false
	runner.pose = RunnerModel.Pose.RUN
	state = State.RUNNING
	ui.show_hud(MayaCalendar.tzolkin_name(daily_key) if daily_key != "" else "")
	_snap_camera()
	sfx.play(Sfx.FLARE)
	_spawn_flare_ring()

func _finish_run() -> void:
	state = State.RESULTS
	var metres := int(distance)
	var is_best := metres > save.best
	if is_best:
		save.best = metres
	save.record_run(metres, coins, _run_flares, dusk, _run_time, death_cause)
	var daily_info := {}
	if daily_key != "":
		var day_best := save.record_daily(daily_key, metres)
		daily_info = {"name": MayaCalendar.tzolkin_name(daily_key), "best": save.daily_best(daily_key), "is_best": day_best}
	var new_glyphs := Glyphs.evaluate(save, {
		"distance": metres, "drops": coins, "flares": _run_flares, "dusk": dusk,
		"daily": daily_key != "", "recovered": _recovered,
	})
	save.save_to_disk()
	ui.show_results(death_cause, metres, coins, save.best, is_best, daily_info, new_glyphs)
	online.submit_run({
		"mode": "daily" if daily_key != "" else "free", "dailyKey": daily_key if daily_key != "" else null,
		"distance": metres, "drops": coins, "flares": _run_flares, "durationMs": int(_run_time * 1000.0),
		"dusk": snappedf(dusk, 0.001), "cause": death_cause,
	})
	online.track("run_end", {"mode": "daily" if daily_key != "" else "free", "distance": metres, "drops": coins,
		"flares": _run_flares, "cause": death_cause, "second_wind": _second_wind_used, "glyphs": new_glyphs.size()})
	online.queue_sync()
	sfx.play(Sfx.RESULTS)

func _on_settings_changed() -> void:
	save.save_to_disk()
	sfx.apply_settings(save)

# -------------------------------------------------------------- frame ---

## Builds the explorer in his garb, the Sunstone in its hue, and its light.
## Called again when the player changes either in the Market.
func _spawn_runner() -> void:
	var old_pose := RunnerModel.Pose.IDLE
	if runner:
		old_pose = runner.pose
		runner.queue_free()
	var hue := Market.find(Market.HUES, save.hue)
	runner = RunnerModel.new()
	runner.palette = Market.find(Market.GARBS, save.garb).palette.duplicate()
	runner.palette["gem"] = hue.gem
	runner.pose = old_pose
	add_child(runner)
	_stone_light = OmniLight3D.new()
	_stone_light.light_color = hue.light
	_stone_light.omni_attenuation = 1.3
	_stone_light.shadow_enabled = false
	_stone_light.position = Vector3(0.4, 1.2, -0.5)
	runner.add_child(_stone_light)
	if state == State.TITLE and world.get_segment(seg_index) != null:
		_place_runner()
	_apply_dusk(true)

func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	if not _perf_nocoins:
		world.spin_coins(delta)
	var t1 := Time.get_ticks_usec()
	if _autopilot:
		_fps_t += delta
		_prof_n += 1
		_prof_max_dt = maxf(_prof_max_dt, delta)
		if _fps_t > 2.0:
			var vp := get_viewport().get_viewport_rid()
			RenderingServer.viewport_set_measure_render_time(vp, true)
			print("[sunstone] proc %.1fms fps %d cpu %.1fms gpu %.1fms coins %dus step %dus maxdt %.1fms draws %d prims %dk" % [
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Engine.get_frames_per_second(),
				RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
				RenderingServer.viewport_get_measured_render_time_gpu(vp),
				_prof_coins / _prof_n, _prof_step / _prof_n,
				_prof_max_dt * 1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0])
			_fps_t = 0.0
			_prof_n = 0
			_prof_coins = 0
			_prof_step = 0
			_prof_max_dt = 0.0
	_prof_coins += t1 - t0
	match state:
		State.TITLE:
			_title_t += delta
			runner.animate(delta, 0.0)
			_apply_dusk()
			_update_title_camera(delta)
		State.RUNNING:
			_step_run(delta)
		State.DYING:
			_step_death(delta)
		State.RESULTS:
			runner.animate(delta, 0.0)
	_apply_shake(delta)
	_backdrop.position = Vector3(camera.global_position.x, 0.0, camera.global_position.z)
	_prof_step += Time.get_ticks_usec() - t1

func _step_run(delta: float) -> void:
	_run_time += delta
	if _autopilot:
		_drive(world.get_segment(seg_index))
	_intro_t = minf(_intro_t + delta / 0.9, 1.0)
	speed = START_SPEED + (MAX_SPEED - START_SPEED) * (1.0 - exp(-distance / SPEED_RAMP))
	# A stumble costs a beat, then he recovers over a second.
	var stagger := clampf(stumble_t - (STUMBLE_MEMORY - 1.0), 0.0, 1.0)
	speed *= 1.0 - 0.3 * stagger

	var seg := world.get_segment(seg_index)
	var ds := speed * delta
	s += ds
	distance += ds

	# Corner: turn the moment he reaches his pivot, otherwise run off the edge.
	if pending_turn != 0 and s >= _pivot_s(seg):
		_do_turn(seg, s - _pivot_s(seg))
		seg = world.get_segment(seg_index)
	elif s > seg.end_s() - 0.2:
		_die("Ran off the causeway", true)
		return

	_step_lane(delta)
	if y > 0.0 or vy > 0.0:
		vy -= GRAVITY * (FALL_GRAVITY if vy < 0.0 else 1.0) * delta
		y += vy * delta
		if y <= 0.0:
			y = 0.0
			vy = 0.0
			runner.land()
			if slide_after_land:
				slide_after_land = false
				_begin_slide()
			elif _jump_buffer > 0.0:
				_jump()
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if slide_t > 0.0:
		slide_t -= delta
	_vis_offset *= exp(-14.0 * delta)

	_shield_t = maxf(_shield_t - delta, 0.0)
	if y <= 0.01 and seg.in_gap(s) and _shield_t <= 0.0:
		_die("Fell into the jungle", true)
		return

	if _shield_t <= 0.0 and _check_obstacles(seg):
		return
	_collect_coins(seg)
	_maybe_hint(seg)

	if stumble_t > 0.0 and stumble_t - delta <= 0.0:
		_recovered = true # outlasted the stumble's memory
	stumble_t = maxf(stumble_t - delta, 0.0)
	if _step_dark(delta):
		return

	runner.pose = RunnerModel.Pose.SLIDE if slide_t > 0.0 else (RunnerModel.Pose.JUMP if y > 0.05 else RunnerModel.Pose.RUN)
	runner.animate(delta, speed)
	_place_runner(delta)
	_push_trail()
	_place_jaguars(delta)
	camera.fov = lerpf(66.0, 74.0, (speed - START_SPEED) / (MAX_SPEED - START_SPEED))
	_update_chase_camera(delta)
	ui.set_run_numbers(int(distance), coins)
	ui.set_light(light, dusk, chaser_gap)

## Lane changes ride a critically damped spring: quick off the mark, eased
## into the lane, never overshooting. Substepped so a slow frame stays stable.
func _step_lane(delta: float) -> void:
	var goal := lane_target * LW
	var steps := maxi(ceili(delta * 120.0), 1)
	var h := delta / steps
	for i in steps:
		x_vel += (LANE_STIFFNESS * LANE_STIFFNESS * (goal - x) - 2.0 * LANE_STIFFNESS * x_vel) * h
		x += x_vel * h
	if absf(goal - x) < 0.003 and absf(x_vel) < 0.05:
		x = goal
		x_vel = 0.0

## The dusk: light drains (faster as night falls), the sky darkens, and in the
## dark the stone jaguars wake and close in. Returns true when they catch him.
func _step_dark(delta: float) -> bool:
	dusk = maxf(clampf(distance / DUSK_DISTANCE, 0.0, 1.0), _dev_dusk)
	light = clampf(light - lerpf(LIGHT_DRAIN_DAY, LIGHT_DRAIN_NIGHT, dusk) * Market.drain_scale(save) * delta, 0.0, 1.0)
	_apply_dusk()
	_flare_boost = maxf(_flare_boost - delta * 1.8, 0.0)
	_growl_cd = maxf(_growl_cd - delta, 0.0)
	if _push_back > 0.0:
		var d := minf(_push_back, 22.0 * delta)
		chaser_gap = minf(chaser_gap + d, 24.0)
		_push_back -= d
	if _freeze_t > 0.0:
		_freeze_t -= delta # frozen as stone: they hold their ground
	elif light >= DARK_LIGHT:
		chaser_gap = move_toward(chaser_gap, 24.0, 2.6 * delta)
	else:
		var hunger := (DARK_LIGHT - light) / DARK_LIGHT
		var was := chaser_gap
		chaser_gap = move_toward(chaser_gap, 0.0, (0.8 + 3.6 * hunger) * delta)
		if was >= 9.0 and chaser_gap < 9.0 and _growl_cd <= 0.0:
			sfx.play(Sfx.ROAR) # you hear them before you see them
			_growl_cd = 6.0
		if chaser_gap < 1.0:
			_die("Caught in the dark", false, true)
			return true
	for j in jaguars:
		j.frozen = _freeze_t > 0.0
	return false

## Tap: the Sunstone flares. Frozen-to-stone jaguars, driven back.
func _flare() -> void:
	if state != State.RUNNING:
		return
	if light < FLARE_COST:
		sfx.play(Sfx.FIZZLE)
		return
	light -= FLARE_COST
	_run_flares += 1
	_freeze_t = FLARE_FREEZE + Market.freeze_bonus(save)
	_push_back = FLARE_PUSH
	_flare_boost = 1.0
	sfx.play(Sfx.FLARE)
	sfx.vibrate(save, 30)
	ui.flash_flare()
	_spawn_flare_ring()

func _spawn_flare_ring() -> void:
	var ring := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	ring.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glow: Color = Market.find(Market.HUES, save.hue).light
	mat.albedo_color = Color(glow, 0.55)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = _stone_light.global_position
	ring.scale = Vector3.ONE * 0.3
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3.ONE * 9.0, 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(ring.queue_free)

## Sunset → twilight → moonlit night, driven by [dusk]. The sky only updates
## in small steps (it re-bakes); the stone's light every frame.
func _apply_dusk(force := false) -> void:
	var lit := smoothstep(0.2, 0.75, dusk)
	_stone_light.light_energy = lerpf(0.35, 2.6, lit) * lerpf(0.3, 1.0, light) + _flare_boost * 6.0
	_stone_light.omni_range = lerpf(4.0, 12.0, light) + _flare_boost * 14.0
	if not force and absf(dusk - _applied_dusk) < 0.005:
		return
	_applied_dusk = dusk
	var sunset := smoothstep(0.0, 0.55, dusk) # the sun going down
	var night := smoothstep(0.55, 1.0, dusk)
	var top := Color("#46285C").lerp(Color("#2A1846"), sunset).lerp(Color("#090B1F"), night)
	var horizon := Color("#F09A5E").lerp(Color("#E0603A"), sunset).lerp(Color("#22264A"), night)
	_sky_mat.sky_top_color = top
	_sky_mat.sky_horizon_color = horizon
	_sky_mat.ground_horizon_color = horizon.darkened(0.35)
	_env.fog_light_color = horizon
	_env.fog_light_energy = lerpf(0.95, 0.7, night)
	_env.ambient_light_color = Color("#A08CB4").lerp(Color("#8A5E8C"), sunset).lerp(Color("#2E3566"), night)
	_env.ambient_light_energy = lerpf(0.7, 0.32, night)
	_env.tonemap_exposure = lerpf(0.92, 1.0, night)
	if dusk < 0.6:
		# The sun sinks and reddens, then is gone.
		_sun.rotation_degrees = Vector3(lerpf(-32.0, -7.0, sunset), 140.0, 0.0)
		_sun.light_color = Color("#FFC890").lerp(Color("#FF7A3A"), sunset)
		_sun.light_energy = lerpf(1.0, 0.05, smoothstep(0.3, 0.6, dusk))
		_sky_mat.sun_angle_max = 18.0
	else:
		# The moon rises on the other side: pale, blue, and dim.
		_sun.rotation_degrees = Vector3(-42.0, 290.0, 0.0)
		_sun.light_color = Color("#9DB4FF")
		_sun.light_energy = lerpf(0.0, 0.16, smoothstep(0.6, 0.85, dusk))
		_sky_mat.sun_angle_max = 6.0

func _step_death(delta: float) -> void:
	_death_t += delta
	if _fell:
		# Keep sailing forward and drop into the canopy; the camera holds.
		var seg := world.get_segment(seg_index)
		s += speed * 0.6 * delta
		vy -= GRAVITY * delta
		y += vy * delta
		runner.position = seg.point(s, x, y) + _vis_offset
		runner.rotation.x = minf(runner.rotation.x + delta * 2.0, 1.2)
		camera.look_at(runner.global_position + Vector3.UP * 0.5)
	else:
		speed = move_toward(speed, 0.0, 30.0 * delta)
		runner.animate(delta, 0.0)
		# The jaguars close the last few metres and pounce.
		chaser_gap = move_toward(chaser_gap, 0.9 if _caught else 3.0, 10.0 * delta)
		_place_jaguars(delta)
	if _death_t > 1.35:
		if not _second_wind_used and (save.bank >= Market.SECOND_WIND_COST or ads.rewarded_ready()):
			state = State.OFFER
			ui.show_second_wind(Market.SECOND_WIND_COST, save.bank)
		else:
			_finish_run()

# ------------------------------------------------------------ mechanics ---

## Where on the corner square he turns: each lane pivots exactly where it meets
## the same lane of the next stretch, so a turn is a clean 90° with no sideways
## jump — only the heading changes.
func _pivot_s(seg: World.Segment) -> float:
	return clampf(seg.corner_s() - x * seg.turn, seg.length + 0.2, seg.end_s() - 0.2)

## [overshoot] is how far past the pivot this frame carried him; it is replayed
## along the new heading so nothing jumps.
func _do_turn(seg: World.Segment, overshoot: float) -> void:
	var before := seg.point(s, x)
	var pivot := seg.point(s - overshoot, x)
	seg_index += 1
	world.ensure_ahead(seg_index)
	var next := world.get_segment(seg_index)
	var rel := pivot - next.origin
	s = rel.dot(next.dir) + overshoot
	x = clampf(rel.dot(next.right), -LW, LW)
	x_vel = 0.0
	lane_target = clampi(roundi(x / LW), -1, 1)
	lane_from = lane_target
	pending_turn = 0
	# Late swipes (or the clamp) can leave a small gap; ease it out visually.
	# The overshoot itself is a real change of heading, not a gap.
	_vis_offset += (before - seg.dir * overshoot) - (next.point(s, x) - next.dir * overshoot)

func _begin_slide() -> void:
	slide_t = SLIDE_TIME
	sfx.play(Sfx.SLIDE)

func _jump() -> void:
	if y > 0.01:
		_jump_buffer = JUMP_BUFFER
		return
	slide_t = 0.0
	vy = JUMP_VELOCITY
	y = 0.001
	sfx.play(Sfx.JUMP)

## Returns true when the run just ended.
func _check_obstacles(seg: World.Segment) -> bool:
	for o in seg.obstacles:
		if o.get("hit", false):
			continue # already stumbled on this one
		var depth := 0.55 if o.kind != "statue" else 0.75
		if absf(o.s - s) > depth:
			continue
		var lane_x: float = 0.0 if o.lane == World.ALL else o.lane * LW
		if o.lane != World.ALL and absf(lane_x - x) > 1.05:
			continue
		match o.kind:
			"log":
				if y < 0.72:
					_die("Hit a fallen log")
					return true
			"wall":
				if y < 0.82:
					_die("Hit a stone wall")
					return true
			"arch":
				if slide_t <= 0.0:
					_die("Clipped the archway")
					return true
			"statue":
				if absf(lane_x - x) < 0.5:
					_die("Ran into a statue")
					return true
				# Clipped it mid lane-change: bounce back and stumble.
				o["hit"] = true
				lane_target = lane_from
				_stumble()
				return state != State.RUNNING
	return false

func _stumble() -> void:
	if stumble_t > 0.0:
		_die("Caught by the jaguars", false, true)
		return
	stumble_t = STUMBLE_MEMORY
	chaser_gap = 2.2
	_shake = 0.35
	sfx.play(Sfx.STUMBLE)
	sfx.vibrate(save, 60)
	ui.flash_danger()

func _collect_coins(seg: World.Segment) -> void:
	var head := y + 0.9
	for c in seg.coins:
		if c.taken:
			continue
		if absf(c.s - s) < 0.75 and absf(c.x - x) < 0.85 and absf(c.y - head) < 1.0:
			c.taken = true
			coins += 1
			light = minf(light + DROP_LIGHT * Market.drop_scale(save), 1.0)
			sfx.play(Sfx.COIN)

## First-runs coaching: name the move the moment it's needed.
func _maybe_hint(seg: World.Segment) -> void:
	if save.tutorial_runs >= 2:
		return
	if light < DARK_LIGHT + 0.05 and chaser_gap < 14.0 and not _hints_shown.has("flare"):
		_hints_shown["flare"] = true
		ui.show_hint("Tap to flare the Sunstone", Vector2.ZERO)
		return
	if light < 0.6 and not _hints_shown.has("drops"):
		_hints_shown["drops"] = true
		ui.show_hint("Sun-drops keep the stone lit", Vector2.ZERO)
		return
	if s > seg.length - TURN_WINDOW - 2.0 and not _hints_shown.has("turn%d" % seg.index):
		_hints_shown["turn%d" % seg.index] = true
		if _hints_shown.size() <= 3:
			ui.show_hint("Swipe %s to turn" % ("right" if seg.turn > 0 else "left"), Vector2(seg.turn, 0))
	for o in seg.obstacles:
		var ahead: float = o.s - s
		if ahead < 0.0 or ahead > 14.0 or _hints_shown.has(o.kind):
			continue
		_hints_shown[o.kind] = true
		match o.kind:
			"log", "wall":
				ui.show_hint("Swipe up to jump", Vector2.UP)
			"arch":
				ui.show_hint("Swipe down to slide", Vector2.DOWN)
			"statue":
				ui.show_hint("Swipe sideways to dodge", Vector2.RIGHT)
		return

# ---------------------------------------------------------------- input ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_touch_active = true
			_swiped = false
			_touch_time = Time.get_ticks_msec()
		else:
			# A short touch that didn't travel is a tap: flare.
			if _touch_active and not _swiped and (event.position - _touch_start).length() < SWIPE_DISTANCE * 0.6 \
					and Time.get_ticks_msec() - _touch_time < 350:
				_flare()
			_touch_active = false
	elif event is InputEventScreenDrag and _touch_active and not _swiped:
		var d: Vector2 = event.position - _touch_start
		if d.length() > SWIPE_DISTANCE:
			_swiped = true
			if absf(d.x) > absf(d.y):
				_swipe(Vector2.RIGHT if d.x > 0.0 else Vector2.LEFT)
			else:
				_swipe(Vector2.DOWN if d.y > 0.0 else Vector2.UP)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A: _swipe(Vector2.LEFT)
			KEY_RIGHT, KEY_D: _swipe(Vector2.RIGHT)
			KEY_UP, KEY_W, KEY_SPACE: _swipe(Vector2.UP)
			KEY_DOWN, KEY_S: _swipe(Vector2.DOWN)
			KEY_ESCAPE, KEY_P: _pause()
			KEY_F, KEY_E: _flare()

func _swipe(dir: Vector2) -> void:
	if state != State.RUNNING:
		return
	var seg := world.get_segment(seg_index)
	match dir:
		Vector2.UP:
			_jump()
		Vector2.DOWN:
			if y > 0.05:
				vy = SLAM_VELOCITY
				slide_after_land = true
			else:
				_begin_slide()
		_:
			var side := int(dir.x)
			if side == seg.turn and s >= seg.length - TURN_WINDOW:
				if pending_turn == 0:
					sfx.play(Sfx.TURN) # answer the swipe now, not at the pivot
					ui.dismiss_hint()
				pending_turn = side
				if s >= _pivot_s(seg):
					_do_turn(seg, 0.0) # swiped late: turn on the spot
				return
			var target := clampi(lane_target + side, -1, 1)
			if target == lane_target:
				return
			lane_from = lane_target
			lane_target = target
			sfx.play(Sfx.LANE)

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
		_go_title()

# --------------------------------------------------------------- placing ---

func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)

## [delta] < 0 snaps everything into place (title, restarts).
func _place_runner(delta := -1.0) -> void:
	var seg := world.get_segment(seg_index)
	runner.position = seg.point(s, x, y) + _vis_offset
	# A queued turn already shows: he twists toward it before the pivot.
	var target_yaw := _yaw_of(seg.dir) - pending_turn * 0.35
	_yaw = target_yaw if delta < 0.0 else lerp_angle(_yaw, target_yaw, 1.0 - exp(-20.0 * delta))
	var lean := clampf(-x_vel * 0.028, -0.32, 0.32)
	runner.rotation = Vector3(0, _yaw, lean)

func _push_trail() -> void:
	var seg := world.get_segment(seg_index)
	_trail.append({"d": distance, "p": seg.point(s, x * 0.5) + _vis_offset, "dir": seg.dir})
	while _trail.size() > 2 and _trail[1].d < distance - 60.0:
		_trail.pop_front()

## Where the runner was [back] metres ago.
func _trail_at(back: float) -> Dictionary:
	var target := distance - back
	for i in range(_trail.size() - 1, 0, -1):
		var a: Dictionary = _trail[i - 1]
		if a.d <= target:
			var b: Dictionary = _trail[i]
			var t := 0.0 if b.d == a.d else clampf((target - a.d) / (b.d - a.d), 0.0, 1.0)
			return {"p": a.p.lerp(b.p, t), "dir": b.dir}
	return _trail[0]

func _place_jaguars(delta: float) -> void:
	for i in jaguars.size():
		var j := jaguars[i]
		var back := chaser_gap + i * 1.1
		var at := _trail_at(back)
		var dir: Vector3 = at.dir
		# They flank the path so they never block the view of the runner.
		var side := dir.cross(Vector3.UP) * (1.25 if i == 0 else -1.25)
		j.position = at.p + side
		j.rotation.y = lerp_angle(j.rotation.y, _yaw_of(dir), 1.0 - exp(-10.0 * delta))
		j.animate(delta, speed)
		j.visible = back < 4.4 or state == State.DYING

# ---------------------------------------------------------------- camera ---

func _snap_camera() -> void:
	_chase_target(-1.0)
	camera.position = _cam_pos
	camera.look_at(_cam_look)

## Close behind and above — the runner owns the lower third of the screen.
## The camera hangs off his position on a heading of its own that swings
## round after him at corners (fast, but never a cut). [delta] < 0 snaps.
func _chase_target(delta: float) -> void:
	var seg := world.get_segment(seg_index)
	var ground := seg.point(s, x) + _vis_offset
	# Sit nearer the centre line than he does, so lane changes read as movement.
	var want_off := -seg.right * (x * 0.45)
	var want_yaw := _yaw_of(seg.dir) - pending_turn * 0.12
	if delta < 0.0:
		_cam_off = want_off
		_cam_yaw = want_yaw
		_cam_lift = y * 0.35
	else:
		_cam_off = _cam_off.lerp(want_off, 1.0 - exp(-10.0 * delta))
		_cam_yaw = lerp_angle(_cam_yaw, want_yaw, 1.0 - exp(-9.0 * delta))
		_cam_lift = lerpf(_cam_lift, y * 0.35, 1.0 - exp(-6.0 * delta))
	var fwd := Vector3(-sin(_cam_yaw), 0.0, -cos(_cam_yaw))
	var base := ground + _cam_off
	_cam_pos = base - fwd * 4.3 + Vector3.UP * (2.6 + _cam_lift)
	_cam_look = base + fwd * 10.0 + Vector3.UP * (1.45 + _cam_lift * 0.6)

func _update_chase_camera(delta: float) -> void:
	_chase_target(delta)
	if _intro_t < 1.0:
		# Swing AROUND the runner from the title shot (in front of him) to the
		# chase (behind) — never through him.
		var t := _intro_t * _intro_t * (3.0 - 2.0 * _intro_t)
		var pivot := runner.position
		var a := _title_cam_position() - pivot
		var b := _cam_pos - pivot
		var ang_a := atan2(a.x, a.z)
		var ang_b := atan2(b.x, b.z)
		var turn := wrapf(ang_b - ang_a, -PI, PI)
		if absf(turn) > PI * 0.9:
			turn = -absf(turn) # always sweep the same way round
		var ang := ang_a + turn * t
		var r := lerpf(Vector2(a.x, a.z).length(), Vector2(b.x, b.z).length(), t)
		var h := lerpf(a.y, b.y, t) + sin(PI * t) * 0.8
		camera.position = pivot + Vector3(sin(ang) * r, h, cos(ang) * r)
		camera.look_at(_title_cam_look().lerp(_cam_look, t))
	else:
		camera.position = _cam_pos
		camera.look_at(_cam_look)

func _title_cam_position() -> Vector3:
	var seg := world.get_segment(0)
	var sway := sin(_title_t * 0.35) * 1.4
	return seg.point(START_S + 3.6, 0.9 + sway, 1.35)

func _title_cam_look() -> Vector3:
	var seg := world.get_segment(0)
	return seg.point(START_S - 2.0, -0.3, 1.75)

func _update_title_camera(_delta: float) -> void:
	_chase_target(-1.0)
	camera.position = _title_cam_position()
	camera.look_at(_title_cam_look())

func _apply_shake(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(_shake - delta * 1.6, 0.0)
	var m := _shake * _shake * 0.35
	camera.position += Vector3(randf_range(-m, m), randf_range(-m, m), randf_range(-m, m))

# ----------------------------------------------------------- environment ---

func _make_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	_sky_mat = sky_mat
	sky_mat.sky_top_color = Color("#46285C")
	sky_mat.sky_horizon_color = Color("#F09A5E")
	sky_mat.sky_curve = 0.22
	sky_mat.sky_energy_multiplier = 1.15
	sky_mat.ground_bottom_color = Color("#14271F")
	sky_mat.ground_horizon_color = Color("#8A5A4E")
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	_env = env
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Shade is a muted dusk violet, not the sky's saturated purple.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#A08CB4")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.06
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	# Fog is the horizon colour, so land melts into sky with no seam; a little
	# extra mist pools on the jungle floor.
	env.fog_light_color = sky_mat.sky_horizon_color
	env.fog_light_energy = 0.95
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.0
	env.fog_height = -5.0
	env.fog_height_density = 0.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.light_color = Color("#FFC890")
	sun.light_energy = 1.0
	# Late afternoon from the side: long enough to model the stones, short
	# enough that shadows stay crisp.
	sun.rotation_degrees = Vector3(-32.0, 140.0, 0.0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	# One orthogonal map over the stretch around him is all a runner needs.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 22.0
	add_child(sun)
	_dev_perf_flags(env, sun)

	# The backdrop rides along under the camera (position only), so the jungle
	# floor never ends and the skyline sits at the horizon however far he runs.
	_backdrop = Node3D.new()
	add_child(_backdrop)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2400, 2400)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Models.JUNGLE
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position = Vector3(0, Models.GROUND_Y, 0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_backdrop.add_child(ground)

	# Skyline: temple pyramids rising out of forested hills, hazed by distance.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var m := Mesher.new()
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(190.0, 250.0)
		Models.far_pyramid(m, Models.at(Vector3(sin(a) * r, Models.GROUND_Y - 2.0, cos(a) * r)), rng.randf_range(1.2, 2.0))
	for i in 16:
		var a := TAU * i / 16.0 + rng.randf_range(-0.15, 0.15)
		var r := rng.randf_range(240.0, 320.0)
		Models.far_hill(m, Models.at(Vector3(sin(a) * r, Models.GROUND_Y - 6.0, cos(a) * r), Basis(Vector3.UP, a)), rng.randf_range(35.0, 60.0), i)
	var skyline := m.to_instance()
	skyline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_backdrop.add_child(skyline)

# -------------------------------------------------------------- autopilot ---

## A simple bot: reads the next few metres and swipes like a player would.
func _drive(seg: World.Segment) -> void:
	if s >= seg.length - 5.0 and pending_turn == 0:
		_swipe(Vector2(seg.turn, 0))
		return
	var lane := lane_target
	for o in seg.obstacles:
		var ahead: float = o.s - s
		if ahead < 0.0 or ahead > 4.2:
			continue
		var blocks: bool = o.lane == World.ALL or o.lane == lane
		if not blocks:
			continue
		match o.kind:
			"log", "wall":
				if y <= 0.01:
					_swipe(Vector2.UP)
			"arch":
				if slide_t <= 0.0:
					_swipe(Vector2.DOWN)
			"statue":
				for side in [-1, 1]:
					var free := true
					for p in seg.obstacles:
						if absf(p.s - o.s) < 1.0 and (p.lane == lane + side or p.lane == World.ALL):
							free = false
					if free and absi(lane + side) <= 1:
						_swipe(Vector2(side, 0))
						break
	for g in seg.gaps:
		var ahead: float = g.x - s
		if ahead > 0.0 and ahead < 2.2 and y <= 0.01:
			_swipe(Vector2.UP)
	if _freeze_t <= 0.0 and light >= FLARE_COST and (chaser_gap < 5.0 or (light < DARK_LIGHT and chaser_gap < 10.0)):
		_flare()
	# Drift toward the nearest sun-drop when the lane over is clear.
	if lane != lane_target or s > seg.length - TURN_WINDOW - 1.0:
		return
	for c in seg.coins:
		var ahead: float = c.s - s
		if c.taken or ahead < 2.0 or ahead > 16.0:
			continue
		var want := clampi(roundi(c.x / LW), -1, 1)
		if want == lane:
			return
		var step := signi(want - lane)
		for o in seg.obstacles:
			var oa: float = o.s - s
			if oa > -1.0 and oa < 9.0 and (o.lane == lane + step or o.lane == World.ALL) and o.kind == "statue":
				return
		_swipe(Vector2(step, 0))
		return

## Dev-only perf switches, read from user:// flag files so a device build can be
## profiled without rebuilding: perf_noglow, perf_noshadow, perf_nomsaa,
## perf_scale (file contents = 3D render scale, e.g. 0.8).
func _dev_perf_flags(env: Environment, sun: DirectionalLight3D) -> void:
	if FileAccess.file_exists("user://perf_noglow"):
		env.glow_enabled = false
	if FileAccess.file_exists("user://perf_noshadow"):
		sun.shadow_enabled = false
	if FileAccess.file_exists("user://perf_nomsaa"):
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	if FileAccess.file_exists("user://perf_novsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if FileAccess.file_exists("user://perf_nosky"):
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("#C98A6A")
		env.fog_enabled = false
	if FileAccess.file_exists("user://perf_shadow"):
		# "<atlas size> <soft filter quality 0-5>"
		var parts := FileAccess.get_file_as_string("user://perf_shadow").split(" ")
		RenderingServer.directional_shadow_atlas_set_size(parts[0].to_int(), true)
		RenderingServer.directional_soft_shadow_filter_set_quality(parts[1].to_int() as RenderingServer.ShadowQuality)
	if FileAccess.file_exists("user://perf_scale"):
		get_viewport().scaling_3d_scale = clampf(FileAccess.get_file_as_string("user://perf_scale").to_float(), 0.5, 1.0)
