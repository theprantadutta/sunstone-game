class_name JaguarModel
extends Node3D
## A stone jaguar guardian: faceted grey-green stone with a painted collar and
## glowing gold eyes, galloping on four jointed legs. Faces -Z.

const STONE := Color("#A3AC92")
const STONE_DARK := Color("#76806C")
const SPOTS := Color("#3E463B")

var _phase := randf() * TAU
var _body: Node3D
var _legs: Array[Node3D] = []
var _tail: Node3D
var _head: Node3D

func _ready() -> void:
	_body = Node3D.new()
	_body.position = Vector3(0, 0.75, 0)
	add_child(_body)
	_part(_body, func(m: Mesher):
		m.box(Models.at(Vector3(0, 0, 0)), Vector3(0.62, 0.55, 1.5), STONE)
		m.box(Models.at(Vector3(0, 0.05, -0.55)), Vector3(0.7, 0.62, 0.5), STONE_DARK) # shoulders
		m.box(Models.at(Vector3(0, -0.02, -0.82)), Vector3(0.72, 0.2, 0.12), Models.MAYA_BLUE) # collar
		for p in [Vector3(0.2, 0.28, 0.1), Vector3(-0.15, 0.28, 0.4), Vector3(0.05, 0.28, -0.2)]:
			m.box(Models.at(p), Vector3(0.14, 0.02, 0.14), SPOTS))

	_head = Node3D.new()
	_head.position = Vector3(0, 0.25, -0.95)
	_body.add_child(_head)
	_part(_head, func(m: Mesher):
		m.box(Models.at(Vector3(0, 0, -0.15)), Vector3(0.5, 0.42, 0.5), STONE)
		m.box(Models.at(Vector3(0, -0.08, -0.45)), Vector3(0.34, 0.24, 0.24), STONE_DARK) # muzzle
		for x in [-0.15, 0.15]:
			m.box(Models.at(Vector3(x, 0.08, -0.41)), Vector3(0.11, 0.07, 0.03), Models.GOLD, true) # eyes
			m.prism(Models.at(Vector3(x, 0.2, -0.1)), 0.08, 0.0, 0.16, 4, STONE_DARK) # ears
		m.box(Models.at(Vector3(0, -0.2, -0.5)), Vector3(0.26, 0.04, 0.05), Models.CINNABAR)) # snarl

	for corner in [Vector3(-0.22, 0, -0.55), Vector3(0.22, 0, -0.55), Vector3(-0.22, 0, 0.55), Vector3(0.22, 0, 0.55)]:
		var leg := Node3D.new()
		leg.position = corner + Vector3(0, -0.15, 0)
		_body.add_child(leg)
		_part(leg, func(m: Mesher):
			m.prism(Models.at(Vector3(0, -0.6, 0)), 0.08, 0.11, 0.6, 5, STONE_DARK)
			m.box(Models.at(Vector3(0, -0.62, -0.06)), Vector3(0.16, 0.08, 0.22), STONE))
		_legs.append(leg)

	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.15, 0.75)
	_body.add_child(_tail)
	_part(_tail, func(m: Mesher):
		m.prism(Models.at(Vector3(0, 0, 0), Basis(Vector3.RIGHT, PI / 2.0)), 0.06, 0.03, 0.8, 5, STONE_DARK))

func _part(parent: Node3D, build: Callable) -> void:
	var m := Mesher.new()
	build.call(m)
	parent.add_child(m.to_instance())

## Gallop: front and back legs move in pairs, the spine rocks, the tail lashes.
func animate(delta: float, speed: float) -> void:
	# Bounds of about 2.4 m, so the paws keep pace with the ground.
	_phase += delta * TAU * clampf(speed / 4.8, 0.8, 3.0)
	var s := sin(_phase)
	_legs[0].rotation.x = s * 0.9
	_legs[1].rotation.x = s * 0.7
	_legs[2].rotation.x = -s * 0.9
	_legs[3].rotation.x = -s * 0.7
	_body.rotation.x = s * 0.12
	_body.position.y = 0.75 + absf(s) * 0.18
	_head.rotation.x = -s * 0.1
	_tail.rotation.y = sin(_phase * 0.5) * 0.5
