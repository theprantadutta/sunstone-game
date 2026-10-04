class_name BatModel
extends Node3D
## A bat of Camazotz: a dark body, two jointed leather wings that beat, ears,
## and ember eyes that glow in the dark. Faces -Z.

const SKIN := Color("#3A2847")
const SKIN_DARK := Color("#251A30")
const MEMBRANE := Color("#5A3A6A")

var _wings: Array[Node3D] = []
var _tips: Array[Node3D] = []
var _phase := randf() * TAU

func _ready() -> void:
	scale = Vector3.ONE * 1.35
	_part(self, func(m: Mesher):
		m.blob(Models.at(Vector3.ZERO, Basis().scaled(Vector3(0.8, 0.7, 1.2))), 0.16, SKIN, 0.1, 5)
		m.blob(Models.at(Vector3(0, 0.04, -0.17)), 0.1, SKIN_DARK, 0.05, 6)
		for x in [-0.05, 0.05]:
			m.prism(Models.at(Vector3(x, 0.1, -0.17)), 0.035, 0.0, 0.11, 3, SKIN_DARK)
			m.box(Models.at(Vector3(x * 0.9, 0.05, -0.265)), Vector3(0.035, 0.025, 0.02), Color("#FF5A3A"), true, false))
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.1, 0.02, -0.02)
		add_child(wing)
		_part(wing, func(m: Mesher):
			m.box(Models.at(Vector3(side * 0.2, 0, 0)), Vector3(0.38, 0.03, 0.3), MEMBRANE)
			m.box(Models.at(Vector3(side * 0.2, 0.02, -0.12)), Vector3(0.4, 0.04, 0.04), SKIN_DARK))
		var tip := Node3D.new()
		tip.position = Vector3(side * 0.39, 0, 0)
		wing.add_child(tip)
		_part(tip, func(m: Mesher):
			m.box(Models.at(Vector3(side * 0.18, 0, 0.02)), Vector3(0.36, 0.025, 0.26), MEMBRANE)
			m.box(Models.at(Vector3(side * 0.2, 0.02, -0.09), Basis(Vector3.UP, side * 0.25)), Vector3(0.38, 0.035, 0.035), SKIN_DARK))
		_wings.append(wing)
		_tips.append(tip)

## Every bat looks the same, so each part's mesh is built once and shared:
## spawning one in the middle of a run costs nothing.
static var _meshes := {}
var _part_n := 0

func _part(parent: Node3D, build: Callable) -> void:
	_part_n += 1
	var key := _part_n
	if not _meshes.has(key):
		var m := Mesher.new()
		build.call(m)
		_meshes[key] = m.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func animate(delta: float, beat := 1.0) -> void:
	_phase += delta * TAU * 3.2 * beat
	var f := sin(_phase)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_wings[i].rotation.z = side * f * 0.75
		_tips[i].rotation.z = side * (f * 0.5 + 0.15)
