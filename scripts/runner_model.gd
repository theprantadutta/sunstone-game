class_name RunnerModel
extends Node3D
## The explorer: a faceted low-poly figure with real joints (hips, knees,
## shoulders, elbows) and a procedural run / jump / slide / fall / idle cycle.
## Faces -Z (Godot's forward), so the chase camera sees his back and pack.
##
## Joint sign convention (rotation.x): positive swings a hanging limb FORWARD
## (toward -Z). Knees only fold back and elbows only fold forward.

const SKIN := Color("#C98B62")
const SHIRT := Color("#2F6B5A") # jade
const SCARF := Color("#B8322A") # cinnabar
const TROUSERS := Color("#C9B68E")
const BOOT := Color("#3B2618")
const HAT := Color("#8A5A34")
const HAT_BAND := Color("#3FA7B5") # Maya blue
const PACK := Color("#6B4426")
const STRAP := Color("#3B2618")

enum Pose { IDLE, RUN, JUMP, SLIDE, FALL }

## Set before adding to the tree to dress him: keys shirt, scarf, trousers,
## hat, band, pack (garbs) and gem (the Sunstone's hue). Missing keys keep
## the explorer's own colours.
var palette := {}

func _col(key: String, fallback: Color) -> Color:
	return palette.get(key, fallback)

var pose := Pose.IDLE
## 0..1: how high he holds the Sunstone (1 while it blazes).
var raise := 0.0
var _phase := 0.0
var _fall_t := 0.0
var _hold_up := 0.0 # idle: the Sunstone raised overhead
var _last_pose := Pose.IDLE
var _since_change := 1.0
var _pose_now := PackedFloat32Array()
var _squash := 0.0

var _body: Node3D
var _torso: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _sh_l: Node3D
var _sh_r: Node3D
var _el_l: Node3D
var _el_r: Node3D

func _ready() -> void:
	_body = _joint(self, Vector3(0, 0.95, 0))

	var hips: Array[Node3D] = []
	var knees: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var hip := _joint(_body, Vector3(0.13 * side, 0, 0))
		_part(hip, func(m: Mesher):
			m.prism(Models.at(Vector3(0, -0.48, 0)), 0.09, 0.115, 0.5, 6, _col("trousers", TROUSERS)))
		var knee := _joint(hip, Vector3(0, -0.47, 0))
		_part(knee, func(m: Mesher):
			m.prism(Models.at(Vector3(0, -0.4, 0)), 0.075, 0.09, 0.42, 6, _col("trousers", TROUSERS))
			m.box(Models.at(Vector3(0, -0.43, -0.05)), Vector3(0.18, 0.13, 0.3), BOOT))
		hips.append(hip)
		knees.append(knee)
	_hip_l = hips[0]; _hip_r = hips[1]
	_knee_l = knees[0]; _knee_r = knees[1]

	_torso = _joint(_body, Vector3.ZERO)
	_part(_torso, func(m: Mesher):
		m.box(Models.at(Vector3(0, 0.31, 0)), Vector3(0.46, 0.6, 0.27), _col("shirt", SHIRT))
		m.box(Models.at(Vector3(0, 0.03, 0)), Vector3(0.48, 0.09, 0.29), STRAP) # belt
		m.box(Models.at(Vector3(0.12, 0.03, -0.15)), Vector3(0.1, 0.08, 0.02), Models.GOLD) # buckle
		# Pack, bedroll and straps — what the camera sees most.
		m.box(Models.at(Vector3(0, 0.34, 0.22)), Vector3(0.36, 0.44, 0.2), _col("pack", PACK))
		m.box(Models.at(Vector3(0, 0.6, 0.22)), Vector3(0.38, 0.1, 0.22), _col("pack", PACK).darkened(0.3))
		m.prism(Models.at(Vector3(-0.22, 0.12, 0.27), Basis(Vector3.FORWARD, PI / 2.0)), 0.08, 0.08, 0.44, 6, Color("#4C6B3A"))
		for x in [-0.14, 0.14]:
			m.box(Models.at(Vector3(x, 0.38, -0.14)), Vector3(0.06, 0.55, 0.02), STRAP)
		# Scarf knot at the neck, tails flying behind.
		m.prism(Models.at(Vector3(0, 0.6, 0)), 0.17, 0.15, 0.1, 8, _col("scarf", SCARF))
		m.box(Models.at(Vector3(0.06, 0.55, 0.2), Basis(Vector3.RIGHT, 0.5)), Vector3(0.1, 0.04, 0.28), _col("scarf", SCARF)))

	var head := _joint(_torso, Vector3(0, 0.72, 0))
	_part(head, func(m: Mesher):
		m.blob(Models.at(Vector3(0, 0.08, 0)), 0.15, SKIN, 0.05, 7)
		m.prism(Models.at(Vector3(0, 0.15, 0)), 0.32, 0.3, 0.03, 10, _col("hat", HAT))
		m.prism(Models.at(Vector3(0, 0.17, 0)), 0.17, 0.14, 0.17, 8, _col("hat", HAT))
		m.prism(Models.at(Vector3(0, 0.18, 0)), 0.175, 0.17, 0.045, 8, _col("band", HAT_BAND)))

	var shoulders: Array[Node3D] = []
	var elbows: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var sh := _joint(_torso, Vector3(0.3 * side, 0.56, 0))
		_part(sh, func(m: Mesher):
			m.prism(Models.at(Vector3(0, -0.32, 0)), 0.06, 0.075, 0.34, 6, _col("shirt", SHIRT)))
		var el := _joint(sh, Vector3(0, -0.3, 0))
		var holds_stone: bool = side > 0
		_part(el, func(m: Mesher):
			m.prism(Models.at(Vector3(0, -0.3, 0)), 0.05, 0.06, 0.3, 6, SKIN)
			m.blob(Models.at(Vector3(0, -0.33, 0)), 0.065, SKIN, 0.0, 2)
			if holds_stone:
				# The Sunstone: a glowing faceted gem in his right hand.
				m.blob(Models.at(Vector3(0, -0.42, -0.04)), 0.12, _col("gem", Models.GOLD), 0.1, 11, true))
		shoulders.append(sh)
		elbows.append(el)
	_sh_l = shoulders[0]; _sh_r = shoulders[1]
	_el_l = elbows[0]; _el_r = elbows[1]

func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j

func _part(parent: Node3D, build: Callable) -> void:
	var m := Mesher.new()
	build.call(m)
	parent.add_child(m.to_instance())

func start_fall() -> void:
	pose = Pose.FALL
	_fall_t = 0.0

## A quick knee-bend when he touches down from a jump.
func land() -> void:
	_squash = 1.0

## Advances the animation. [run_speed] (units/s) sets the stride rate.
func animate(delta: float, run_speed: float) -> void:
	if pose != _last_pose:
		_last_pose = pose
		_since_change = 0.0
	_since_change += delta
	var t := _target(delta, run_speed)
	# Pose changes blend over ~0.15 s; a settled pose tracks its target exactly,
	# so the run cycle never lags or loses amplitude.
	var k := lerpf(1.0 - exp(-22.0 * delta), 1.0, smoothstep(0.08, 0.28, _since_change))
	if _pose_now.is_empty():
		_pose_now = t
	else:
		for i in t.size():
			_pose_now[i] = lerpf(_pose_now[i], t[i], k)
	_apply(_pose_now)
	# Blazing: the Sunstone held high over his head, whatever his legs do.
	if raise > 0.001 and pose != Pose.FALL:
		_sh_r.rotation.x = lerpf(_sh_r.rotation.x, 2.95, raise)
		_el_r.rotation.x = lerpf(_el_r.rotation.x, 0.12, raise)
		_torso.rotation.z = lerpf(0.0, -0.08, raise)
	if _squash > 0.0:
		_squash = maxf(_squash - delta * 6.0, 0.0)
		var dip := sin(_squash * PI) * 0.13
		_body.position.y -= dip
		_knee_l.rotation.x -= dip * 3.0
		_knee_r.rotation.x -= dip * 3.0
		_hip_l.rotation.x += dip * 1.5
		_hip_r.rotation.x += dip * 1.5

## The pose this frame wants, as [hip l, hip r, knee l, knee r, shoulder l,
## shoulder r, elbow l, elbow r, body y, body pitch, torso pitch, torso twist].
func _target(delta: float, run_speed: float) -> PackedFloat32Array:
	match pose:
		Pose.IDLE:
			_phase += delta * 1.6
			_hold_up = minf(_hold_up + delta * 1.5, 1.0)
			# Left arm at ease, right arm lifting the Sunstone to the sky.
			return PackedFloat32Array([0.0, 0.0, 0.04, 0.04,
				0.15, lerpf(0.2, 2.9, _hold_up), 0.2, lerpf(0.4, 0.1, _hold_up),
				0.95 + sin(_phase) * 0.012, 0.0, 0.04, 0.0])
		Pose.RUN:
			_hold_up = 0.0
			# Stride matched to ground speed so the feet plant instead of skating:
			# one full cycle (two steps) covers 2 × step metres.
			var step := 1.6 + run_speed * 0.06
			var hz := minf(run_speed / (2.0 * step), 3.3)
			_phase += delta * TAU * maxf(hz, 1.2)
			var s := sin(_phase)
			var c := cos(_phase)
			# Knees fold hardest as each leg swings through (recovery).
			var kl := maxf(0.0, -c) * 1.7 + 0.18
			var kr := maxf(0.0, c) * 1.7 + 0.18
			return PackedFloat32Array([s * 0.85, -s * 0.85, kl, kr,
				-s * 0.9, s * 0.9, 1.2, 1.2,
				0.93 + absf(s) * 0.07, 0.0, -0.22, s * 0.13])
		Pose.JUMP:
			return PackedFloat32Array([1.2, 0.55, 1.95, 1.3,
				2.2, 1.9, 0.5, 0.5,
				0.95, 0.0, -0.28, 0.0])
		Pose.SLIDE:
			return PackedFloat32Array([0.5, 0.25, 0.2, 0.6,
				-0.7, 1.1, 0.4, 0.9,
				0.42, 1.0, 0.0, 0.0])
		_: # FALL
			_fall_t += delta
			return PackedFloat32Array([0.4, -0.3, 0.6, 0.9,
				-2.8, -2.5, 0.2, 0.3,
				maxf(0.25, 0.95 - _fall_t * 2.5), minf(_fall_t * 5.0, 1.45), 0.0, 0.0])

func _apply(p: PackedFloat32Array) -> void:
	_hip_l.rotation.x = p[0]
	_hip_r.rotation.x = p[1]
	_knee_l.rotation.x = -p[2]
	_knee_r.rotation.x = -p[3]
	_sh_l.rotation.x = p[4]
	_sh_r.rotation.x = p[5]
	_el_l.rotation.x = p[6]
	_el_r.rotation.x = p[7]
	_body.position.y = p[8]
	_body.rotation = Vector3(p[9], 0.0, 0.0)
	_torso.rotation = Vector3(p[10], p[11], 0.0)
