extends Node3D
## Sunstone — the run. Owns the state machine (title → running → dying →
## results), the runner's movement in path space, input, collisions, the
## jaguars, the camera, and hands numbers to the UI.

enum State { TITLE, RUNNING, PAUSED, DYING, RESULTS }

const START_SPEED := 11.0
const MAX_SPEED := 25.0
const SPEED_RAMP := 1800.0 ## metres to approach top speed
const JUMP_VELOCITY := 7.6
const GRAVITY := 21.0
const SLAM_VELOCITY := -20.0
const SLIDE_TIME := 0.72
const LANE_SPEED := 13.0 ## sideways units per second
const TURN_WINDOW := 10.0 ## swipe this far before a corner to turn
const START_S := 8.0
const STUMBLE_MEMORY := 8.0 ## a second stumble inside this window = caught
const SWIPE_DISTANCE := 42.0

const LW := Models.LANE_WIDTH

var state := State.TITLE

var world: World
var runner: RunnerModel
var jaguars: Array[JaguarModel] = []
var camera: Camera3D
var ui: GameUI
var sfx: Sfx
var save := SaveData.new()

# --- run state (path space) ---
var seg_index := 0
var s := START_S
var x := 0.0
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
var death_cause := ""
var _death_t := 0.0
var _fell := false
var _caught := false
var _yaw := 0.0
var _title_t := 0.0
var _intro_t := 0.0 ## 0→1 camera move from the title shot into the chase
var _trail: Array[Dictionary] = [] ## {d, p, dir} — camera and jaguars follow it
var _hints_shown := {}
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
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
	_make_environment()
	world = World.new()
	add_child(world)
	runner = RunnerModel.new()
	add_child(runner)
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
	ui.pause_pressed.connect(_pause)
	ui.resume_pressed.connect(_resume)
	ui.home_pressed.connect(_go_title)
	ui.again_pressed.connect(_restart)
	ui.settings_changed.connect(_on_settings_changed)
	ui.setup(save)
	_go_title()
	if _autopilot:
		get_tree().create_timer(1.2).timeout.connect(_start_run)

# ------------------------------------------------------------- states ---

func _reset_run() -> void:
	world.reset(randi())
	seg_index = 0
	s = START_S
	x = 0.0
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
	death_cause = ""
	_fell = false
	_caught = false
	_hints_shown.clear()
	var seg := world.get_segment(0)
	_yaw = _yaw_of(seg.dir)
	_trail.clear()
	# Seed the trail behind the start so the chase camera has somewhere to sit.
	for i in 12:
		var d := -6.0 + i * 0.5
		_trail.append({"d": d, "p": seg.point(START_S + d), "dir": seg.dir})
	for j in jaguars:
		j.visible = false

func _go_title() -> void:
	get_tree().paused = false
	_reset_run()
	state = State.TITLE
	_title_t = 0.0
	runner.pose = RunnerModel.Pose.IDLE
	_place_runner()
	ui.show_title(save.best)
	sfx.play_music()

func _start_run() -> void:
	if state != State.TITLE:
		return
	state = State.RUNNING
	_intro_t = 0.0
	runner.pose = RunnerModel.Pose.RUN
	for j in jaguars:
		j.visible = true
	ui.show_hud()
	sfx.play(Sfx.ROAR)

func _restart() -> void:
	get_tree().paused = false
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

func _finish_run() -> void:
	state = State.RESULTS
	var metres := int(distance)
	var is_best := metres > save.best
	if is_best:
		save.best = metres
	save.bank += coins
	save.runs += 1
	if save.tutorial_runs < 2:
		save.tutorial_runs += 1
	save.save_to_disk()
	ui.show_results(death_cause, metres, coins, save.best, is_best)
	sfx.play(Sfx.RESULTS)

func _on_settings_changed() -> void:
	save.save_to_disk()
	sfx.apply_settings(save)

# -------------------------------------------------------------- frame ---

func _process(delta: float) -> void:
	world.spin_coins(delta)
	match state:
		State.TITLE:
			_title_t += delta
			runner.animate(delta, 0.0)
			_update_title_camera(delta)
		State.RUNNING:
			_step_run(delta)
		State.DYING:
			_step_death(delta)
		State.RESULTS:
			runner.animate(delta, 0.0)
	_apply_shake(delta)

func _step_run(delta: float) -> void:
	if _autopilot:
		_drive(world.get_segment(seg_index))
	_intro_t = minf(_intro_t + delta / 0.9, 1.0)
	speed = START_SPEED + (MAX_SPEED - START_SPEED) * (1.0 - exp(-distance / SPEED_RAMP))
	if stumble_t > STUMBLE_MEMORY - 0.8:
		speed *= 0.75 # a stumble costs a beat
	world.difficulty = clampf(distance / 2600.0, 0.0, 1.0)

	var seg := world.get_segment(seg_index)
	var ds := speed * delta
	s += ds
	distance += ds

	# Corner: turn if a turn is queued, otherwise run off the edge.
	if pending_turn != 0 and s >= seg.corner_s():
		_do_turn(seg)
		seg = world.get_segment(seg_index)
	elif s > seg.end_s() - 0.2:
		_die("Ran off the causeway", true)
		return

	# Sideways, vertical, slide.
	x = move_toward(x, lane_target * LW, LANE_SPEED * delta)
	if y > 0.0 or vy > 0.0:
		vy -= GRAVITY * delta
		y += vy * delta
		if y <= 0.0:
			y = 0.0
			vy = 0.0
			if slide_after_land:
				slide_after_land = false
				_begin_slide()
	if slide_t > 0.0:
		slide_t -= delta

	if y <= 0.01 and seg.in_gap(s):
		_die("Fell into the jungle", true)
		return

	if _check_obstacles(seg):
		return
	_collect_coins(seg)
	_maybe_hint(seg)

	stumble_t = maxf(stumble_t - delta, 0.0)
	chaser_gap = move_toward(chaser_gap, 24.0, 2.6 * delta)

	runner.pose = RunnerModel.Pose.SLIDE if slide_t > 0.0 else (RunnerModel.Pose.JUMP if y > 0.05 else RunnerModel.Pose.RUN)
	runner.animate(delta, speed)
	_place_runner()
	_push_trail()
	_place_jaguars(delta)
	_update_chase_camera(delta)
	ui.set_run_numbers(int(distance), coins)

func _step_death(delta: float) -> void:
	_death_t += delta
	if _fell:
		# Keep sailing forward and drop into the canopy; the camera holds.
		var seg := world.get_segment(seg_index)
		s += speed * 0.6 * delta
		vy -= GRAVITY * delta
		y += vy * delta
		runner.position = seg.point(s, x, y)
		runner.rotation.x = minf(runner.rotation.x + delta * 2.0, 1.2)
		camera.look_at(runner.global_position + Vector3.UP * 0.5)
	else:
		speed = move_toward(speed, 0.0, 30.0 * delta)
		runner.animate(delta, 0.0)
		# The jaguars close the last few metres and pounce.
		chaser_gap = move_toward(chaser_gap, 0.9 if _caught else 3.0, 10.0 * delta)
		_place_jaguars(delta)
	if _death_t > 1.35:
		_finish_run()

# ------------------------------------------------------------ mechanics ---

func _do_turn(seg: World.Segment) -> void:
	var world_pos := seg.point(s, x)
	seg_index += 1
	world.ensure_ahead(seg_index)
	var next := world.get_segment(seg_index)
	s = (world_pos - next.origin).dot(next.dir)
	x = clampf((world_pos - next.origin).dot(next.right), -LW, LW)
	lane_target = int(round(x / LW))
	lane_from = lane_target
	pending_turn = 0
	sfx.play(Sfx.TURN)

func _begin_slide() -> void:
	slide_t = SLIDE_TIME
	sfx.play(Sfx.SLIDE)

func _jump() -> void:
	if y > 0.01:
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
			c.node.visible = false
			coins += 1
			sfx.play(Sfx.COIN)

## First-runs coaching: name the move the moment it's needed.
func _maybe_hint(seg: World.Segment) -> void:
	if save.tutorial_runs >= 2:
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
		else:
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
				pending_turn = side
				if s >= seg.corner_s():
					_do_turn(seg)
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
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if state == State.RUNNING:
				_pause()
			elif state == State.PAUSED:
				_resume()
			elif state == State.TITLE:
				get_tree().quit()
			else:
				_go_title()

# --------------------------------------------------------------- placing ---

func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)

func _place_runner() -> void:
	var seg := world.get_segment(seg_index)
	runner.position = seg.point(s, x, y)
	var target_yaw := _yaw_of(seg.dir)
	_yaw = lerp_angle(_yaw, target_yaw, 0.25)
	var lean := (lane_target * LW - x) * -0.12
	runner.rotation = Vector3(0, _yaw, lean)

func _push_trail() -> void:
	var seg := world.get_segment(seg_index)
	_trail.append({"d": distance, "p": seg.point(s, x * 0.5), "dir": seg.dir})
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
		j.rotation.y = _yaw_of(dir)
		j.animate(delta, speed)
		j.visible = back < 4.4 or state == State.DYING

# ---------------------------------------------------------------- camera ---

func _snap_camera() -> void:
	_cam_pos = _chase_position()
	_cam_look = _chase_look()
	camera.position = _cam_pos
	camera.look_at(_cam_look)

## Close behind and above — the runner owns the lower third of the screen.
func _chase_position() -> Vector3:
	var at := _trail_at(3.9)
	return at.p + Vector3.UP * 2.6

func _chase_look() -> Vector3:
	var seg := world.get_segment(seg_index)
	return seg.point(s + 10.0, x * 0.5, 1.45)

func _update_chase_camera(delta: float) -> void:
	var k := 1.0 - exp(-12.0 * delta)
	_cam_pos = _cam_pos.lerp(_chase_position(), k)
	_cam_look = _cam_look.lerp(_chase_look(), minf(k * 1.4, 1.0))
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
	_cam_pos = _chase_position()
	_cam_look = _chase_look()
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
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.06
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("#D99A6C")
	env.fog_density = 0.0042
	env.fog_sky_affect = 0.0
	env.fog_height = -4.0
	env.fog_height_density = 0.18
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#FFB678")
	sun.light_energy = 1.5
	sun.rotation_degrees = Vector3(-16.0, 140.0, 0.0) # low, raking from the side
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	# The jungle floor far below, lost in mist.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#1E3A2C")
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position = Vector3(0, -16.0, 0)
	add_child(ground)

	# Distant pyramids on the skyline.
	var m := Mesher.new()
	for spot in [Vector3(-160, -14, -320), Vector3(210, -14, -260), Vector3(-40, -14, -420), Vector3(330, -14, -60), Vector3(-300, -14, -120)]:
		Models.far_pyramid(m, Models.at(spot), randf_range(1.4, 2.2))
	add_child(m.to_instance())

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
