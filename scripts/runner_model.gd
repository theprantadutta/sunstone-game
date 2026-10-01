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

var pose := Pose.IDLE
var _phase := 0.0
var _fall_t := 0.0
var _hold_up := 0.0 # idle: the Sunstone raised overhead

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
			m.prism(Models.at(Vector3(0, -0.48, 0)), 0.09, 0.115, 0.5, 6, TROUSERS))
		var knee := _joint(hip, Vector3(0, -0.47, 0))
		_part(knee, func(m: Mesher):
			m.prism(Models.at(Vector3(0, -0.4, 0)), 0.075, 0.09, 0.42, 6, TROUSERS)
			m.box(Models.at(Vector3(0, -0.43, -0.05)), Vector3(0.18, 0.13, 0.3), BOOT))
		hips.append(hip)
		knees.append(knee)
	_hip_l = hips[0]; _hip_r = hips[1]
	_knee_l = knees[0]; _knee_r = knees[1]

	_torso = _joint(_body, Vector3.ZERO)
	_part(_torso, func(m: Mesher):
		m.box(Models.at(Vector3(0, 0.31, 0)), Vector3(0.46, 0.6, 0.27), SHIRT)
		m.box(Models.at(Vector3(0, 0.03, 0)), Vector3(0.48, 0.09, 0.29), STRAP) # belt
		m.box(Models.at(Vector3(0.12, 0.03, -0.15)), Vector3(0.1, 0.08, 0.02), Models.GOLD) # buckle
		# Pack, bedroll and straps — what the camera sees most.
		m.box(Models.at(Vector3(0, 0.34, 0.22)), Vector3(0.36, 0.44, 0.2), PACK)
		m.box(Models.at(Vector3(0, 0.6, 0.22)), Vector3(0.38, 0.1, 0.22), PACK.darkened(0.3))
		m.prism(Models.at(Vector3(-0.22, 0.12, 0.27), Basis(Vector3.FORWARD, PI / 2.0)), 0.08, 0.08, 0.44, 6, Color("#4C6B3A"))
		for x in [-0.14, 0.14]:
			m.box(Models.at(Vector3(x, 0.38, -0.14)), Vector3(0.06, 0.55, 0.02), STRAP)
		# Scarf knot at the neck, tails flying behind.
		m.prism(Models.at(Vector3(0, 0.6, 0)), 0.17, 0.15, 0.1, 8, SCARF)
		m.box(Models.at(Vector3(0.06, 0.55, 0.2), Basis(Vector3.RIGHT, 0.5)), Vector3(0.1, 0.04, 0.28), SCARF))

	var head := _joint(_torso, Vector3(0, 0.72, 0))
	_part(head, func(m: Mesher):
		m.blob(Models.at(Vector3(0, 0.08, 0)), 0.15, SKIN, 0.05, 7)
		m.prism(Models.at(Vector3(0, 0.15, 0)), 0.32, 0.3, 0.03, 10, HAT)
		m.prism(Models.at(Vector3(0, 0.17, 0)), 0.17, 0.14, 0.17, 8, HAT)
		m.prism(Models.at(Vector3(0, 0.18, 0)), 0.175, 0.17, 0.045, 8, HAT_BAND))

	var shoulders: Array[Node3D] = []
	var elbows: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var sh := _joint(_torso, Vector3(0.3 * side, 0.56, 0))
		_part(sh, func(m: Mesher):
			m.prism(Models.at(Vector3(0, -0.32, 0)), 0.06, 0.075, 0.34, 6, SHIRT))
		var el := _joint(sh, Vector3(0, -0.3, 0))
		var holds_stone: bool = side > 0
		_part(el, func(m: Mesher):
			m.prism(Models.at(Vector3(0, -0.3, 0)), 0.05, 0.06, 0.3, 6, SKIN)
			m.blob(Models.at(Vector3(0, -0.33, 0)), 0.065, SKIN, 0.0, 2)
			if holds_stone:
				# The Sunstone: a glowing faceted gem in his right hand.
				m.blob(Models.at(Vector3(0, -0.42, -0.04)), 0.12, Models.GOLD, 0.1, 11, true))
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

## Advances the animation. [run_speed] (units/s) sets the stride rate.
func animate(delta: float, run_speed: float) -> void:
	match pose:
		Pose.IDLE:
			_phase += delta * 1.6
			_hold_up = minf(_hold_up + delta * 1.5, 1.0)
			_set_legs(0.0, 0.0, 0.04, 0.04)
			# Left arm at ease, right arm lifting the Sunstone to the sky.
			_set_arms(0.15, lerpf(0.2, 2.9, _hold_up), 0.2, lerpf(0.4, 0.1, _hold_up))
			_body.position.y = 0.95 + sin(_phase) * 0.012
			_body.rotation = Vector3.ZERO
			_torso.rotation.x = 0.04
		Pose.RUN:
			_hold_up = 0.0
			_phase += delta * (5.5 + run_speed * 0.34)
			var s := sin(_phase)
			var c := cos(_phase)
			_set_legs(s * 0.9, -s * 0.9, maxf(0.0, -c) * 1.5 + 0.15, maxf(0.0, c) * 1.5 + 0.15)
			_set_arms(-s * 0.95, s * 0.95, 1.15, 1.15)
			_body.position.y = 0.95 + absf(c) * 0.09
			_body.rotation = Vector3.ZERO
			_torso.rotation.x = -0.2 # lean into the run
		Pose.JUMP:
			_set_legs(1.15, 0.65, 1.9, 1.4)
			_set_arms(2.3, 2.0, 0.5, 0.5)
			_body.position.y = 0.95
			_body.rotation = Vector3.ZERO
			_torso.rotation.x = -0.3
		Pose.SLIDE:
			_body.position.y = 0.42
			_body.rotation = Vector3(1.0, 0, 0) # lean far back
			_set_legs(0.45, 0.25, 0.2, 0.55)
			_set_arms(-0.7, 1.1, 0.4, 0.9)
			_torso.rotation.x = 0.0
		Pose.FALL:
			_fall_t += delta
			_body.rotation.x = minf(_fall_t * 5.0, 1.45)
			_body.position.y = maxf(0.25, 0.95 - _fall_t * 2.5)
			_set_legs(0.4, -0.3, 0.6, 0.9)
			_set_arms(-2.8, -2.5, 0.2, 0.3)

func _set_legs(hl: float, hr: float, kl: float, kr: float) -> void:
	_hip_l.rotation.x = hl
	_hip_r.rotation.x = hr
	_knee_l.rotation.x = -kl
	_knee_r.rotation.x = -kr

func _set_arms(sl: float, sr: float, el: float, er: float) -> void:
	_sh_l.rotation.x = sl
	_sh_r.rotation.x = sr
	_el_l.rotation.x = el
	_el_r.rotation.x = er
