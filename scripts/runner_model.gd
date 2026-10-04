class_name RunnerModel
extends Node3D
## A runner: a cute cartoon character — big round head, big shiny eyes, a
## smile, rosy cheeks, chunky hair and hat, a short rounded body, mitten hands
## and big shoes — all smooth toon shapes with the codex ink line. Real joints
## (hips, knees, shoulders, elbows, head) drive a procedural run / jump /
## slide / fall / idle cycle. Faces -Z; his right hand (+X) carries the
## Sunstone.
##
## Who they are comes from [look] (face, hair, headwear, build) and what they
## wear from [palette] (outfit colours, the Sunstone's hue): a new character
## is data (see Themes), not code. Set both before adding to the tree.
##
## Joint sign convention (rotation.x): positive swings a hanging limb FORWARD
## (toward -Z). Knees only fold back and elbows only fold forward.

## The explorer, and the fallback for any key a look leaves out.
## hair: "tuft", "bob", "ponytail", "buns", "curly", "none"
## hat: "fedora", "cap", "beanie", "santa", "crown", "band", "none"
## mouth: "smile", "grin", "o"
const DEFAULT_LOOK := {
	"skin": Color("#E8A97C"), "hair": "tuft", "hair_col": Color("#3A2416"),
	"eyes": Color("#7A4A26"), "hat": "fedora", "mouth": "smile",
	"build": 1.0, "fem": false, "blush": true, "freckles": false,
}

const SHIRT := Color("#2F8A6E") # jade
const SCARF := Color("#D2402F") # cinnabar
const TROUSERS := Color("#D8C49A")
const SHOE := Color("#5A3622")
const HAT := Color("#9A6638")
const HAT_BAND := Color("#3FA7B5") # Maya blue
const PACK := Color("#8A5630")
const STRAP := Color("#4A2E1C")
const EYE_WHITE := Color("#FFFFFF")
const DARK := Color("#21160F")
const BLUSH := Color("#F28A8A")

const HIP_H := 0.6 ## hip height in model units (the poses were written for 0.95)
const HEAD_C := Vector3(0, 0.215, 0) ## head centre in the head joint's space
const HEAD_R := Vector3(0.205, 0.2, 0.19)

enum Pose { IDLE, RUN, JUMP, SLIDE, FALL }

var palette := {}
var look := {}

func _col(key: String, fallback: Color) -> Color:
	return palette.get(key, fallback)

func _l(key: String) -> Variant:
	return look.get(key, DEFAULT_LOOK[key])

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
var _blink_t := 2.0
var _look_t := 0.0

var _body: Node3D
var _torso: Node3D
var _head: Node3D
var _lids: Node3D
var _stone: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _sh_l: Node3D
var _sh_r: Node3D
var _el_l: Node3D
var _el_r: Node3D

func _ready() -> void:
	var skin: Color = _l("skin")
	var build: float = _l("build")
	_body = _joint(self, Vector3(0, HIP_H, 0))

	# --- legs ---
	var hips: Array[Node3D] = []
	var knees: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var hip := _joint(_body, Vector3(0.085 * side * build, -0.02, 0))
		_part(hip, _key("thigh", [_col("trousers", TROUSERS)]), func(m: Mesher):
			m.capsule(Models.at(Vector3(0, -0.3, 0)), 0.066, 0.078, 0.32, _col("trousers", TROUSERS)))
		var knee := _joint(hip, Vector3(0, -0.27, 0))
		_part(knee, _key("shin", [_col("trousers", TROUSERS), _col("shoe", SHOE)]), func(m: Mesher):
			m.capsule(Models.at(Vector3(0, -0.25, 0)), 0.056, 0.064, 0.27, _col("trousers", TROUSERS))
			# A big rounded shoe with a pale sole.
			var shoe := _col("shoe", SHOE)
			m.ellipsoid(Models.at(Vector3(0, -0.27, -0.04)), Vector3(0.078, 0.062, 0.125), shoe, 6, 10)
			m.ellipsoid(Models.at(Vector3(0, -0.315, -0.04)), Vector3(0.082, 0.022, 0.13), Color("#EFE3C8"), 4, 10, false))
		hips.append(hip)
		knees.append(knee)
	_hip_l = hips[0]; _hip_r = hips[1]
	_knee_l = knees[0]; _knee_r = knees[1]

	# --- torso ---
	_torso = _joint(_body, Vector3.ZERO)
	_part(_torso, _key("torso", [_col("shirt", SHIRT), _col("trousers", TROUSERS), _col("pack", PACK), _col("scarf", SCARF), build]), func(m: Mesher):
		var shirt := _col("shirt", SHIRT)
		var w := build
		m.ellipsoid(Models.at(Vector3(0, 0.0, 0)), Vector3(0.15 * w, 0.1, 0.12), _col("trousers", TROUSERS), 6, 12)
		m.capsule(Models.at(Vector3(0, -0.02, 0), Basis().scaled(Vector3(1.25 * w, 1.0, 0.92))), 0.14, 0.135, 0.46, shirt, 12)
		m.ellipsoid(Models.at(Vector3(0, 0.03, 0)), Vector3(0.175 * w, 0.03, 0.135), STRAP, 3, 14) # belt
		m.ellipsoid(Models.at(Vector3(0.04, 0.03, -0.132)), Vector3(0.03, 0.024, 0.01), Models.GOLD, 3, 8, false) # buckle
		# A big rounded pack with a bedroll on top.
		var pack := _col("pack", PACK)
		m.ellipsoid(Models.at(Vector3(0, 0.24, 0.15)), Vector3(0.135, 0.15, 0.075), pack, 6, 10)
		m.ellipsoid(Models.at(Vector3(0, 0.34, 0.165)), Vector3(0.13, 0.04, 0.07), pack.darkened(0.25), 4, 10)
		m.capsule(Models.at(Vector3(-0.17, 0.42, 0.15), Basis(Vector3.FORWARD, -PI / 2.0)), 0.045, 0.045, 0.34, Color("#5E8A44"), 8)
		for x in [-0.08, 0.08]:
			m.box(Models.at(Vector3(x, 0.26, -0.135), Basis(Vector3.RIGHT, 0.12)), Vector3(0.035, 0.3, 0.02), STRAP, false, false)
		# The scarf, a fat roll round the neck with a tail flying behind.
		var sc := _col("scarf", SCARF)
		m.ellipsoid(Models.at(Vector3(0, 0.43, 0)), Vector3(0.11, 0.045, 0.1), sc, 4, 12)
		m.capsule(Models.at(Vector3(0.05, 0.42, 0.06), Basis(Vector3.RIGHT, 1.9)), 0.03, 0.02, 0.2, sc, 6))

	# --- head ---
	_head = _joint(_torso, Vector3(0, 0.43, 0))
	_part(_head, _key("head", [str(look), _col("hat", HAT), _col("band", HAT_BAND)]), func(m: Mesher): _build_head(m))
	_lids = Node3D.new()
	_head.add_child(_lids)
	_part(_lids, _key("lids", [skin]), func(m: Mesher):
		for side in [-1.0, 1.0]:
			m.ellipsoid(_on_face(0.53, side * 0.36, 0.012), Vector3(0.047, 0.056, 0.014), skin.darkened(0.06), 4, 10, false)
			m.box(_on_face(0.53, side * 0.36, 0.027), Vector3(0.07, 0.006, 0.01), DARK, false, false))
	_lids.visible = false

	# --- arms ---
	var shoulders: Array[Node3D] = []
	var elbows: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var sh := _joint(_torso, Vector3(0.175 * side * build, 0.36, 0))
		_part(sh, _key("upper", [_col("shirt", SHIRT)]), func(m: Mesher):
			m.capsule(Models.at(Vector3(0, -0.2, 0)), 0.045, 0.058, 0.22, _col("shirt", SHIRT)))
		var el := _joint(sh, Vector3(0, -0.18, 0))
		var holds_stone: bool = side > 0
		_part(el, _key("fore", [_col("shirt", SHIRT), skin, side, _col("gem", Models.GOLD)]), func(m: Mesher):
			m.capsule(Models.at(Vector3(0, -0.17, 0)), 0.04, 0.047, 0.18, skin)
			m.ellipsoid(Models.at(Vector3(0, -0.2, -0.01)), Vector3(0.058, 0.062, 0.055), skin, 6, 10) # mitten hand
			m.ellipsoid(Models.at(Vector3(-side * 0.045, -0.18, -0.03)), Vector3(0.022, 0.03, 0.022), skin, 4, 8) # thumb
			if holds_stone:
				m.blob(Models.at(Vector3(0, -0.27, -0.05)), 0.075, _col("gem", Models.GOLD), 0.1, 11, true))
		if holds_stone:
			_stone = _joint(el, Vector3(0, -0.27, -0.05))
		shoulders.append(sh)
		elbows.append(el)
	_sh_l = shoulders[0]; _sh_r = shoulders[1]
	_el_l = elbows[0]; _el_r = elbows[1]

## Where the Sunstone is, in the world.
func stone_global() -> Vector3:
	return _stone.global_position if _stone else global_position + Vector3(0, 1.2, 0)

# ----------------------------------------------------------------- head ---

## A point on the head: [t] from the crown (0) to the chin (1), [phi] round
## from the face (0) toward his right (+). [out] lifts it off the skin.
func _head_point(t: float, phi: float, out := 0.0) -> Vector3:
	var a := t * PI
	var ring := sin(a)
	var front := maxf(cos(phi), 0.0)
	# Round, with soft full cheeks and a small rounded chin.
	var cheeks := 1.0 + 0.06 * exp(-pow((t - 0.66) / 0.12, 2.0))
	var chin := 1.0 - 0.18 * smoothstep(0.75, 1.0, t) * front
	var p := Vector3(sin(phi) * ring * HEAD_R.x * cheeks * chin, cos(a) * HEAD_R.y, -cos(phi) * ring * HEAD_R.z * (1.0 - 0.06 * front))
	var n := Vector3(p.x / HEAD_R.x, p.y / HEAD_R.y, p.z / HEAD_R.z).normalized()
	return HEAD_C + p + n * out

## A transform on the face at ([t], [phi]): +X toward his right, +Y up the
## face, and -Z out of the skin (so ellipsoids placed here lie on the face
## and boxes face outward, as everywhere else).
func _on_face(t: float, phi: float, out := 0.0) -> Transform3D:
	var p := _head_point(t, phi, out)
	var outward := (_head_point(t, phi, 0.01) - _head_point(t, phi, 0.0)).normalized()
	var east := (_head_point(t, phi + 0.05) - _head_point(t, phi - 0.05)).normalized()
	var x := (east - outward * east.dot(outward)).normalized()
	var up := outward.cross(x).normalized()
	return Transform3D(Basis(x, up, -outward), p)

func _build_head(m: Mesher) -> void:
	var skin: Color = _l("skin")
	var hair_col: Color = _l("hair_col")
	var fem: bool = _l("fem")
	var rows := []
	for k in 17:
		var ring := []
		for j in 24:
			ring.append(_head_point(k / 16.0, TAU * j / 24.0))
		rows.append(ring)
	m.smooth_grid(rows, skin, HEAD_C)
	m.capsule(Models.at(Vector3(0, -0.04, 0.0)), 0.06, 0.06, 0.1, skin.darkened(0.05), 8, false) # neck
	for side in [-1.0, 1.0]:
		var e := _head_point(0.56, side * (PI / 2.0 - 0.05), 0.0)
		m.ellipsoid(Models.at(e, Basis(Vector3.UP, side * 0.25)), Vector3(0.026, 0.045, 0.035), skin.darkened(0.04), 4, 8)
	# Eyes: big and shiny — white, a large dark iris, two highlights.
	var eye_col: Color = _l("eyes")
	for side in [-1.0, 1.0]:
		var xf := _on_face(0.53, side * 0.36, 0.004)
		m.ellipsoid(xf, Vector3(0.042, 0.052, 0.012), EYE_WHITE, 5, 12, false)
		m.ellipsoid(xf.translated_local(Vector3(side * -0.003, -0.008, -0.008)), Vector3(0.024, 0.031, 0.008), eye_col, 4, 12, false)
		m.ellipsoid(xf.translated_local(Vector3(side * -0.003, -0.009, -0.013)), Vector3(0.012, 0.015, 0.005), DARK, 3, 10, false)
		m.ellipsoid(xf.translated_local(Vector3(side * 0.006 - 0.003, 0.006, -0.017)), Vector3(0.009, 0.01, 0.004), EYE_WHITE, 3, 8, false)
		m.ellipsoid(xf.translated_local(Vector3(side * -0.011, -0.02, -0.016)), Vector3(0.004, 0.004, 0.003), EYE_WHITE, 2, 6, false)
		if fem:
			# Lashes: three little strokes at the outer corner.
			for k in 3:
				var a: float = side * (0.6 + k * 0.35)
				m.box(xf.translated_local(Vector3(side * 0.038, 0.035 - k * 0.012, -0.006)) * Transform3D(Basis(Vector3.BACK, a)), Vector3(0.022, 0.006, 0.004), DARK, false, false)
		# Brows: chunky little arcs.
		var bx := _on_face(0.37, side * 0.37, 0.006)
		m.ellipsoid(bx * Transform3D(Basis(Vector3.BACK, -side * 0.15)), Vector3(0.036, 0.009, 0.006), hair_col.darkened(0.15), 2, 8, false)
		if _l("blush"):
			m.ellipsoid(_on_face(0.67, side * 0.58, 0.002), Vector3(0.034, 0.02, 0.004), skin.lerp(BLUSH, 0.55), 2, 10, false)
		if _l("freckles"):
			for k in 3:
				m.ellipsoid(_on_face(0.64 + (k % 2) * 0.03, side * (0.42 + k * 0.08), 0.003), Vector3(0.005, 0.005, 0.002), skin.darkened(0.3), 2, 6, false)
	# A small button nose.
	m.ellipsoid(_on_face(0.63, 0.0, 0.004), Vector3(0.024, 0.018, 0.016), skin.darkened(0.05), 4, 8)
	# The mouth.
	var lip := Color("#8E3B32")
	match _l("mouth"):
		"grin":
			_smile(m, 0.72, 0.3, 0.035, 0.012, lip)
			m.ellipsoid(_on_face(0.745, 0.0, 0.003), Vector3(0.045, 0.018, 0.004), Color("#5A1E18"), 3, 10, false)
			m.ellipsoid(_on_face(0.735, 0.0, 0.005), Vector3(0.036, 0.008, 0.003), Color.WHITE, 2, 8, false)
		"o":
			m.ellipsoid(_on_face(0.75, 0.0, 0.003), Vector3(0.018, 0.022, 0.004), Color("#5A1E18"), 3, 10, false)
		_:
			_smile(m, 0.735, 0.26, 0.028, 0.008, lip)
	_build_hair(m, hair_col)
	_build_hat(m)

## A curved smile across the face: [t] its height, [half] how far round it
## reaches (radians), [curve] how much the corners lift, [w] its thickness.
func _smile(m: Mesher, t: float, half: float, curve: float, w: float, col: Color) -> void:
	var n := 7
	for k in n:
		var u0 := lerpf(-1.0, 1.0, float(k) / n)
		var u1 := lerpf(-1.0, 1.0, float(k + 1) / n)
		var a := _head_point(t - curve * u0 * u0, u0 * half, 0.004)
		var b := _head_point(t - curve * u1 * u1, u1 * half, 0.004)
		var mid := (a + b) / 2.0
		var dir := b - a
		var outward := (mid - HEAD_C).normalized()
		var basis := Basis(dir.normalized(), outward.cross(dir).normalized(), -outward)
		m.box(Transform3D(basis.orthonormalized(), mid), Vector3(dir.length() * 1.15, w, 0.006), col, false, false)

## Hair: a soft cap over the skull with chunky bangs, plus the style's extra.
func _build_hair(m: Mesher, col: Color) -> void:
	var style: String = _l("hair")
	if style == "none":
		return
	var rows := []
	for k in 8:
		var ring := []
		for j in 18:
			var phi := TAU * j / 18.0
			var back := (1.0 - cos(phi)) / 2.0
			var tmax := lerpf(0.3, 0.74 if style != "bob" else 0.8, back * back * (3.0 - 2.0 * back))
			ring.append(_head_point(tmax * k / 7.0, phi, 0.018 + 0.02 * (1.0 - k / 7.0)))
		rows.append(ring)
	m.smooth_grid(rows, col, HEAD_C)
	# Bangs: a few fat locks over the forehead.
	for k in 4:
		var phi := lerpf(-0.55, 0.55, k / 3.0)
		var p := _on_face(0.3, phi, 0.02)
		m.ellipsoid(p * Transform3D(Basis(Vector3.BACK, phi * 0.8)), Vector3(0.05, 0.045, 0.03), col, 5, 8)
	match style:
		"tuft":
			for k in 3:
				var tip := Basis(Vector3.FORWARD, (k - 1) * 0.45) * Basis(Vector3.RIGHT, -0.4)
				m.capsule(Models.at(HEAD_C + Vector3((k - 1) * 0.04, HEAD_R.y * 0.85, 0.02), tip), 0.035, 0.012, 0.12, col, 6)
		"bob":
			for side in [-1.0, 1.0]:
				m.ellipsoid(Models.at(HEAD_C + Vector3(side * 0.17, -0.06, 0.03)), Vector3(0.06, 0.11, 0.12), col, 5, 10)
		"ponytail":
			m.ellipsoid(Models.at(HEAD_C + Vector3(0, 0.08, 0.2)), Vector3(0.03, 0.03, 0.03), Models.CINNABAR, 3, 8)
			m.capsule(Models.at(HEAD_C + Vector3(0, 0.07, 0.22), Basis(Vector3.RIGHT, 2.6)), 0.055, 0.025, 0.3, col, 8)
		"buns":
			for side in [-1.0, 1.0]:
				m.ellipsoid(Models.at(HEAD_C + Vector3(side * 0.14, 0.15, 0.04)), Vector3(0.07, 0.07, 0.07), col, 5, 10)
		"curly":
			for k in 9:
				var a := TAU * k / 9.0
				m.ellipsoid(Models.at(HEAD_C + Vector3(sin(a) * 0.17, 0.1 + cos(a * 2.0) * 0.03, cos(a) * 0.16 + 0.02)), Vector3(0.06, 0.06, 0.06), col, 4, 8)

func _build_hat(m: Mesher) -> void:
	var hat := _col("hat", HAT)
	var top := HEAD_C + Vector3(0, HEAD_R.y * 0.62, 0.01)
	var tilt := Basis(Vector3.RIGHT, -0.12)
	match _l("hat"):
		"fedora":
			var hx := Models.at(top, tilt)
			m.ellipsoid(hx, Vector3(0.31, 0.022, 0.29), hat, 3, 20)
			m.ellipsoid(hx.translated_local(Vector3(0, 0.075, 0)), Vector3(0.16, 0.1, 0.145), hat, 6, 16)
			m.ellipsoid(hx.translated_local(Vector3(0, 0.155, 0)), Vector3(0.045, 0.02, 0.09), hat.darkened(0.2), 3, 10, false) # the crease
			m.ellipsoid(hx.translated_local(Vector3(0, 0.03, 0)), Vector3(0.166, 0.032, 0.152), _col("band", HAT_BAND), 3, 16)
		"cap":
			m.ellipsoid(Models.at(top + Vector3(0, -0.01, 0)), Vector3(0.215, 0.13, 0.205), hat, 6, 14)
			m.ellipsoid(Models.at(top + Vector3(0, -0.03, -0.2), Basis(Vector3.RIGHT, 0.15)), Vector3(0.15, 0.018, 0.12), hat.darkened(0.15), 3, 12)
		"beanie":
			m.ellipsoid(Models.at(top + Vector3(0, -0.02, 0)), Vector3(0.22, 0.15, 0.21), hat, 6, 14)
			m.ellipsoid(Models.at(top + Vector3(0, -0.07, 0)), Vector3(0.225, 0.04, 0.215), _col("band", HAT_BAND), 3, 14)
			m.ellipsoid(Models.at(top + Vector3(0, 0.15, 0)), Vector3(0.05, 0.05, 0.05), Color.WHITE, 4, 8)
		"santa":
			m.ellipsoid(Models.at(top + Vector3(0, -0.06, 0)), Vector3(0.23, 0.05, 0.22), Color.WHITE, 3, 14)
			m.capsule(Models.at(top + Vector3(0, -0.04, 0), Basis(Vector3.RIGHT, 0.5)), 0.2, 0.03, 0.34, Color("#C8202A"), 12)
			m.ellipsoid(Models.at(top + Vector3(0, 0.22, 0.2)), Vector3(0.05, 0.05, 0.05), Color.WHITE, 4, 8)
		"band":
			m.ellipsoid(Models.at(HEAD_C + Vector3(0, HEAD_R.y * 0.45, 0)), Vector3(HEAD_R.x * 1.08, 0.025, HEAD_R.z * 1.08), _col("band", HAT_BAND), 3, 16)
		"crown":
			# A quetzal-feather crown: a jade band with a gold jewel and a fan of
			# long green, blue and red plumes.
			var band_y := HEAD_C + Vector3(0, HEAD_R.y * 0.42, 0)
			m.ellipsoid(Models.at(band_y), Vector3(HEAD_R.x * 1.1, 0.04, HEAD_R.z * 1.1), Color("#2FA07A"), 3, 18)
			m.ellipsoid(Models.at(band_y + Vector3(0, 0.0, -HEAD_R.z * 1.1)), Vector3(0.04, 0.04, 0.02), Models.GOLD, 3, 8)
			var plumes := [Color("#1F8A5A"), Color("#3FA7B5"), Color("#2FB86A"), Color("#D2402F"), Color("#2FB86A"), Color("#3FA7B5"), Color("#1F8A5A")]
			for k in plumes.size():
				var a := lerpf(-1.0, 1.0, k / 6.0)
				var ptilt := Basis(Vector3.FORWARD, -a * 0.6) * Basis(Vector3.RIGHT, 0.35)
				m.capsule(Models.at(band_y + Vector3(a * 0.12, 0.02, 0.06), ptilt), 0.03, 0.012, 0.42 - absf(a) * 0.12, plumes[k], 6)

func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j

## Built meshes, keyed by part and by every look/outfit value that part
## uses. Trying on a hat rebuilds only the head; trying it on again is free.
static var _meshes := {}

func _part(parent: Node3D, key: String, build: Callable) -> void:
	if not _meshes.has(key):
		var m := Mesher.new()
		m.soft = true
		build.call(m)
		_meshes[key] = m.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func _key(part: String, colors: Array) -> String:
	var k := part
	for c in colors:
		k += "|" + (c.to_html() if c is Color else str(c))
	return k

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
		var dip := sin(_squash * PI) * 0.09
		_body.position.y -= dip
		_knee_l.rotation.x -= dip * 3.0
		_knee_r.rotation.x -= dip * 3.0
		_hip_l.rotation.x += dip * 1.5
		_hip_r.rotation.x += dip * 1.5
	# Blinks, and at rest looks about.
	_blink_t -= delta
	if _blink_t <= 0.0:
		_lids.visible = true
		if _blink_t < -0.12:
			_lids.visible = false
			_blink_t = randf_range(2.2, 5.0)
	_look_t += delta
	if pose == Pose.IDLE:
		_head.rotation = Vector3(-0.06 + sin(_look_t * 0.7) * 0.05, sin(_look_t * 0.45) * 0.28, sin(_look_t * 0.6) * 0.05)
	else:
		_head.rotation = Vector3(0.08 if pose == Pose.RUN else 0.0, -_torso.rotation.y * 0.8, 0.0)

## The pose this frame wants, as [hip l, hip r, knee l, knee r, shoulder l,
## shoulder r, elbow l, elbow r, body y, body pitch, torso pitch, torso twist].
## Body heights were written for a hip of 0.95 and are scaled to [HIP_H].
func _target(delta: float, run_speed: float) -> PackedFloat32Array:
	match pose:
		Pose.IDLE:
			_phase += delta * 1.6
			_hold_up = minf(_hold_up + delta * 1.5, 1.0)
			return PackedFloat32Array([0.0, 0.0, 0.04, 0.04,
				0.15, lerpf(0.2, 2.9, _hold_up), 0.2, lerpf(0.4, 0.1, _hold_up),
				0.95 + sin(_phase) * 0.012, 0.0, 0.04, 0.0])
		Pose.RUN:
			_hold_up = 0.0
			# Short cartoon legs take quick steps.
			var step := 1.0 + run_speed * 0.04
			var hz := minf(run_speed / (2.0 * step), 3.6)
			_phase += delta * TAU * maxf(hz, 1.4)
			var s := sin(_phase)
			var c := cos(_phase)
			var kl := maxf(0.0, -c) * 1.6 + 0.18
			var kr := maxf(0.0, c) * 1.6 + 0.18
			return PackedFloat32Array([s * 0.85, -s * 0.85, kl, kr,
				-s * 0.9, s * 0.9, 1.2, 1.2,
				0.93 + absf(s) * 0.07, 0.0, -0.18, s * 0.13])
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
	_body.position.y = p[8] * HIP_H / 0.95
	_body.rotation = Vector3(p[9], 0.0, 0.0)
	_torso.rotation = Vector3(p[10], p[11], 0.0)
