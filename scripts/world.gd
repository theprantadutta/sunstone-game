class_name World
extends Node3D
## The endless causeway: straight stretches ("segments") joined by 90° corners
## where the runner must turn. Segments are generated a few ahead and freed
## behind, each built as ONE batched mesh plus its coin nodes.
##
## Path space: a segment has an origin, a forward [dir] and a [right] vector.
## A point is (s along dir, x across, y up). The straight run is s ∈ [0, length];
## the corner square is s ∈ [length, length + PATH_WIDTH].

const W := Models.PATH_WIDTH
const LW := Models.LANE_WIDTH
const ALL := 2 ## obstacle lane value meaning "the full width"

class Segment:
	extends RefCounted
	var index := 0
	var origin := Vector3.ZERO
	var dir := Vector3.FORWARD
	var right := Vector3.RIGHT
	var length := 60.0
	var turn := 1 ## -1 = corner turns left, +1 = right
	var heading := 0 ## -1/0/+1: net quarter-turns from the start direction
	var obstacles: Array[Dictionary] = [] ## {s, lane, kind}
	var gaps: Array[Vector2] = [] ## floor missing across all lanes, (s0, s1)
	var coins: Array[Dictionary] = [] ## {s, x, y, node, taken}
	var node: Node3D

	func point(s: float, x := 0.0, y := 0.0) -> Vector3:
		return origin + dir * s + right * x + Vector3.UP * y

	func frame() -> Transform3D:
		# Local x = right, y = up, z = -dir: models face -Z, i.e. down the path.
		return Transform3D(Basis(right, Vector3.UP, -dir), origin)

	func end_s() -> float:
		return length + W

	func corner_s() -> float:
		return length + W / 2.0

	func exit_dir() -> Vector3:
		return right if turn > 0 else -right

	func in_gap(s: float) -> bool:
		for g in gaps:
			if s >= g.x and s <= g.y:
				return true
		return false

var difficulty := 0.0 ## 0..1, set by the game from distance run
var _segments: Array[Segment] = []
var _rng := RandomNumberGenerator.new()
var _coin_mesh: ArrayMesh

func reset(seed: int) -> void:
	for seg in _segments:
		if seg.node:
			seg.node.queue_free()
	_segments.clear()
	_rng.seed = seed
	difficulty = 0.0
	if _coin_mesh == null:
		_coin_mesh = Models.coin_mesh()
	var first := Segment.new()
	first.index = 0
	first.length = 52.0
	first.turn = 1 if _rng.randf() < 0.5 else -1
	_populate(first, true)
	_build(first, true)
	_segments.append(first)
	ensure_ahead(0)

func get_segment(index: int) -> Segment:
	for seg in _segments:
		if seg.index == index:
			return seg
	return null

## Keeps four segments generated ahead of [current] and two behind.
func ensure_ahead(current: int) -> void:
	while _segments.back().index < current + 4:
		_segments.append(_next_after(_segments.back()))
	while _segments.front().index < current - 2:
		var old: Segment = _segments.pop_front()
		if old.node:
			old.node.queue_free()

func _next_after(prev: Segment) -> Segment:
	var seg := Segment.new()
	seg.index = prev.index + 1
	seg.dir = prev.exit_dir()
	seg.right = seg.dir.cross(Vector3.UP)
	seg.heading = prev.heading + prev.turn
	seg.origin = prev.point(prev.corner_s()) + seg.dir * (W / 2.0)
	seg.length = _rng.randf_range(lerpf(70.0, 46.0, difficulty), lerpf(110.0, 72.0, difficulty))
	# Stay within ±90° of the starting heading: the causeway zig-zags forward
	# and can never curl back across itself.
	if seg.heading > 0:
		seg.turn = -1
	elif seg.heading < 0:
		seg.turn = 1
	else:
		seg.turn = 1 if _rng.randf() < 0.5 else -1
	_populate(seg, false)
	_build(seg, false)
	return seg

# ------------------------------------------------------------- content ---

func _populate(seg: Segment, first: bool) -> void:
	var s := 24.0 if first else 10.0
	var end := seg.length - 12.0
	while s < end:
		var d := difficulty
		var pick := _rng.randf()
		var lane := _rng.randi_range(-1, 1)
		var other := _other_lane(lane)
		if d < 0.12 or pick < 0.18:
			# Breather: just a coin trail.
			_coin_line(seg, s, other, 6)
		elif pick < 0.36:
			_obstacle(seg, s, ALL, "log")
			_coin_arc(seg, s, lane)
		elif pick < 0.52:
			_obstacle(seg, s, lane, "statue")
			if d > 0.3 and _rng.randf() < 0.5:
				_obstacle(seg, s, other, "statue") # one lane left open
				_coin_line(seg, s - 4.0, -lane - other, 5)
			else:
				_coin_line(seg, s - 4.0, other, 5)
		elif pick < 0.68:
			_obstacle(seg, s, lane, "wall")
			if d > 0.2 and _rng.randf() < 0.5:
				_obstacle(seg, s, other, "wall")
			_coin_arc(seg, s, lane)
		elif pick < 0.84 and d > 0.15:
			_obstacle(seg, s, ALL, "arch")
			_coin_line(seg, s - 2.0, lane, 4, 0.45)
		elif d > 0.3:
			var length := lerpf(2.2, 3.4, d)
			seg.gaps.append(Vector2(s - length / 2.0, s + length / 2.0))
			_coin_arc(seg, s, lane)
		else:
			_coin_line(seg, s, lane, 6)
		s += _rng.randf_range(lerpf(17.0, 9.5, difficulty), lerpf(22.0, 13.0, difficulty))

func _other_lane(lane: int) -> int:
	var o := _rng.randi_range(-1, 1)
	while o == lane:
		o = _rng.randi_range(-1, 1)
	return o

func _obstacle(seg: Segment, s: float, lane: int, kind: String) -> void:
	seg.obstacles.append({"s": s, "lane": lane, "kind": kind})

func _coin_line(seg: Segment, s: float, lane: int, count: int, y := 0.8) -> void:
	for i in count:
		seg.coins.append({"s": s + i * 1.7, "x": lane * LW, "y": y, "taken": false})

## Coins tracing a jump arc over [s].
func _coin_arc(seg: Segment, s: float, lane: int) -> void:
	for i in 5:
		var t := (i - 2) / 2.0
		seg.coins.append({"s": s + t * 2.6, "x": lane * LW, "y": 0.9 + (1.0 - t * t) * 0.9, "taken": false})

# ---------------------------------------------------------------- build ---

func _build(seg: Segment, first: bool) -> void:
	var m := Mesher.new()
	var f := seg.frame()

	# Floor + kerbs along the straight, tile by tile (gaps simply skip tiles).
	var s := 0.0
	while s < seg.length:
		var mid := s + Models.TILE_LENGTH / 2.0
		if not seg.in_gap(mid):
			for lane in [-1, 0, 1]:
				Models.floor_tile(m, Models.sub(f, Vector3(lane * LW, 0, -mid)), _rng.randf())
			for side in [-1.0, 1.0]:
				Models.kerb(m, Models.sub(f, Vector3(side * (W / 2.0 + 0.22), 0, -mid)), Models.TILE_LENGTH, side)
		s += Models.TILE_LENGTH

	# Corner square: open toward the turn, kerb on the other side, altar ahead.
	for row in 3:
		for col in [-1, 0, 1]:
			var tile := Models.sub(f, Vector3(col * LW, 0, -(seg.length + LW * (row + 0.5))))
			m.box(tile * Transform3D(Basis(), Vector3(0, -0.3, 0)), Vector3(LW - 0.06, 0.6, LW - 0.06), Models.STONE_LIGHT if (row + col) % 2 == 0 else Models.STONE)
	var closed_side := -float(seg.turn)
	Models.kerb(m, Models.sub(f, Vector3(closed_side * (W / 2.0 + 0.22), 0, -(seg.length + W / 2.0))), W, closed_side)
	Models.corner_altar(m, Models.sub(f, Vector3(0, 0, -(seg.end_s() + 0.4))))

	# Piers into the jungle.
	var p := 6.0
	while p < seg.end_s():
		if not seg.in_gap(p):
			Models.pier(m, Models.sub(f, Vector3(0, 0, -p)))
		p += 14.0

	# Pillars, torches and the jungle canopy on both flanks.
	var k := 8.0
	while k < seg.length - 4.0:
		for side in [-1.0, 1.0]:
			if _rng.randf() < 0.55:
				Models.pillar(m, Models.sub(f, Vector3(side * (W / 2.0 + 1.3), 0, -k)), _rng.randf_range(2.6, 3.6), _rng.randf() < 0.3)
			elif _rng.randf() < 0.6:
				Models.torch(m, Models.sub(f, Vector3(side * (W / 2.0 + 0.9), 0, -k)))
			else:
				Models.fern(m, Models.sub(f, Vector3(side * (W / 2.0 + 0.9), 0, -k)), _rng.randi())
		k += _rng.randf_range(7.0, 11.0)
	var t := 0.0
	while t < seg.end_s():
		for side in [-1.0, 1.0]:
			# Past the corner, the turn side is where the next stretch runs.
			if t > seg.length - 3.0 and side == float(seg.turn):
				continue
			var off := _rng.randf_range(5.5, 14.0)
			var size := _rng.randf_range(0.85, 1.3)
			Models.tree(m, Models.sub(f, Vector3(side * (W / 2.0 + off), -9.5, -(t + _rng.randf_range(0.0, 4.0)))), size, _rng.randi_range(0, 99))
		t += _rng.randf_range(3.5, 6.0)

	# Obstacles.
	for o in seg.obstacles:
		var x: float = 0.0 if o.lane == ALL else o.lane * LW
		var at := Models.sub(f, Vector3(x, 0, -o.s))
		match o.kind:
			"log": Models.log_barrier(m, at, W)
			"wall": Models.low_wall(m, at, LW)
			"arch": Models.arch(m, at, W)
			"statue": Models.statue(m, at)

	if first:
		Models.start_temple(m, f)

	var node := Node3D.new()
	node.add_child(m.to_instance())
	for c in seg.coins:
		var coin := MeshInstance3D.new()
		coin.mesh = _coin_mesh
		coin.position = seg.point(c.s, c.x, c.y)
		coin.rotation.y = c.s # desync spins
		node.add_child(coin)
		c.node = coin
	seg.node = node
	add_child(node)

## Spins every coin; called each frame.
func spin_coins(delta: float) -> void:
	for seg in _segments:
		for c in seg.coins:
			if not c.taken and c.node:
				c.node.rotate_y(delta * 3.0)
