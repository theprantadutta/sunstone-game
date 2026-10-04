class_name JaguarModel
extends Node3D
## A stone jaguar of Xibalba: a long, low cat of pale carved stone, painted
## rosettes, a Maya-blue collar, cinnabar jaws. In the dark it wakes — its eyes
## burn gold and it gallops on four jointed legs; caught in light it is stone
## again, eyes dead, frozen mid-stride. Faces -Z.

const STONE := Color("#BDB59C")
const STONE_DARK := Color("#8F8873")
const ROSETTE := Color("#3B342C")

## Held as stone by light. Set every frame by the game.
var frozen := false:
	set(v):
		frozen = v
		if _eyes:
			_eyes.visible = not v

var _phase := randf() * TAU
var _body: Node3D
var _head: Node3D
var _eyes: Node3D
var _legs: Array[Node3D] = []
var _tail: Node3D
var _tail_tip: Node3D

func _ready() -> void:
	_body = Node3D.new()
	_body.position = Vector3(0, 0.72, 0)
	add_child(_body)
	_part(_body, func(m: Mesher):
		m.blob(Models.at(Vector3(0, 0, 0.1), Basis().scaled(Vector3(0.62, 0.55, 1.35))), 0.55, STONE, 0.06, 3)
		m.blob(Models.at(Vector3(0, 0.06, -0.45), Basis().scaled(Vector3(0.75, 0.7, 0.75))), 0.45, STONE, 0.06, 4) # shoulders
		m.box(Models.at(Vector3(0, 0.02, -0.78)), Vector3(0.62, 0.16, 0.14), Models.MAYA_BLUE) # collar
		var spots := [
			Vector3(0.16, 0.3, 0.3), Vector3(-0.14, 0.3, -0.05), Vector3(0.05, 0.31, 0.6), Vector3(-0.2, 0.26, 0.45),
			Vector3(0.18, 0.28, -0.3), Vector3(0.32, 0.05, 0.2), Vector3(-0.32, 0.05, 0.0), Vector3(0.3, 0.0, 0.55), Vector3(-0.31, 0.0, 0.5)]
		for p in spots:
			# A rosette: a dark ring with the stone showing through.
			var n: Vector3 = Vector3(p.x * 2.0, 1.0, 0.0).normalized()
			var basis := Basis.looking_at(-n, Vector3.FORWARD if absf(n.y) > 0.9 else Vector3.UP)
			m.box(Models.at(p, basis), Vector3(0.12, 0.12, 0.02), ROSETTE, false, false))

	_head = Node3D.new()
	_head.position = Vector3(0, 0.22, -0.82)
	_body.add_child(_head)
	_part(_head, func(m: Mesher):
		m.box(Models.at(Vector3(0, 0.02, -0.12)), Vector3(0.46, 0.4, 0.44), STONE)
		m.box(Models.at(Vector3(0, -0.08, -0.4)), Vector3(0.3, 0.22, 0.2), STONE_DARK) # muzzle
		m.box(Models.at(Vector3(0, -0.2, -0.43)), Vector3(0.26, 0.05, 0.12), Models.CINNABAR) # jaws
		for x in [-0.08, 0.08]:
			m.prism(Models.at(Vector3(x, -0.24, -0.47), Basis(Vector3.RIGHT, PI)), 0.025, 0.0, 0.08, 3, Models.BONE) # fangs
		for x in [-0.15, 0.15]:
			m.prism(Models.at(Vector3(x, 0.2, -0.04)), 0.08, 0.0, 0.17, 4, STONE_DARK) # ears
			m.box(Models.at(Vector3(x, 0.08, -0.345)), Vector3(0.11, 0.05, 0.02), ROSETTE, false, false)) # dead stone eyes
	_eyes = Node3D.new()
	_head.add_child(_eyes)
	_part(_eyes, func(m: Mesher):
		for x in [-0.14, 0.14]:
			m.box(Models.at(Vector3(x, 0.08, -0.35)), Vector3(0.12, 0.07, 0.03), Models.GOLD, true, false))

	for corner in [Vector3(-0.2, 0, -0.5), Vector3(0.2, 0, -0.5), Vector3(-0.2, 0, 0.55), Vector3(0.2, 0, 0.55)]:
		var leg := Node3D.new()
		leg.position = corner + Vector3(0, -0.12, 0)
		_body.add_child(leg)
		_part(leg, func(m: Mesher):
			m.prism(Models.at(Vector3(0, -0.6, 0)), 0.07, 0.12, 0.6, 5, STONE_DARK)
			m.box(Models.at(Vector3(0, -0.62, -0.06)), Vector3(0.15, 0.08, 0.22), STONE))
		_legs.append(leg)

	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.1, 0.78)
	_body.add_child(_tail)
	_part(_tail, func(m: Mesher):
		m.prism(Models.at(Vector3.ZERO, Basis(Vector3.RIGHT, PI / 2.0 - 0.5)), 0.06, 0.045, 0.55, 5, STONE))
	_tail_tip = Node3D.new()
	_tail_tip.position = Vector3(0, 0.27, 0.48)
	_tail.add_child(_tail_tip)
	_part(_tail_tip, func(m: Mesher):
		m.prism(Models.at(Vector3.ZERO, Basis(Vector3.RIGHT, -0.3)), 0.045, 0.03, 0.45, 5, STONE)
		m.box(Models.at(Vector3(0, 0.36, -0.1)), Vector3(0.08, 0.1, 0.08), ROSETTE))
	_eyes.visible = not frozen

## Every jaguar looks the same, so each part's mesh is built once and shared:
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

## Gallop: front and back legs move in pairs, the spine rocks, the tail lashes.
func animate(delta: float, speed: float) -> void:
	if frozen:
		return # turned back to stone mid-stride
	_phase += delta * TAU * clampf(speed / 4.0, 0.9, 3.0)
	var s := sin(_phase)
	_legs[0].rotation.x = s * 0.9
	_legs[1].rotation.x = s * 0.7
	_legs[2].rotation.x = -s * 0.9
	_legs[3].rotation.x = -s * 0.7
	_body.rotation.x = s * 0.1
	_body.position.y = 0.72 + absf(s) * 0.16
	_head.rotation.x = -s * 0.12
	_tail.rotation.y = sin(_phase * 0.5) * 0.45
	_tail_tip.rotation.x = sin(_phase * 0.5 + 1.0) * 0.4
