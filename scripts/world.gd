class_name World
extends Node3D
## The endless causeway: straight stretches ("segments") joined by 90° corners
## where the runner must turn. Segments are generated a few ahead and freed
## behind, each built as two batched meshes (shadow casters + scenery) and one
## coin MultiMesh — a handful of draw calls per stretch. The geometry is built
## on a worker thread, so a new stretch never stalls a frame.
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
	var prev_turn := 0 ## the corner we came out of (0 for the first stretch)
	var heading := 0 ## -1/0/+1: net quarter-turns from the start direction
	var obstacles: Array[Dictionary] = [] ## {s, lane, kind}
	var gaps: Array[Vector2] = [] ## floor missing across all lanes, (s0, s1)
	var coins: Array[Dictionary] = [] ## {s, x, y, taken}
	var node: Node3D
	var coin_mm: MultiMesh ## every coin of the stretch in one draw
	var rng := RandomNumberGenerator.new() ## scenery dice, so it can build off-thread
	var task := -1 ## WorkerThreadPool task building the meshes
	var baked: Array = [] ## [path arrays, scenery arrays] from the worker

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
var _coin_angle := 0.0

func reset(seed: int) -> void:
	for seg in _segments:
		_finish_task(seg)
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
	first.rng.seed = _rng.randi()
	_bake(first, true)
	_attach(first)
	_segments.append(first)
	ensure_ahead(0)
	# A fresh run starts on finished scenery.
	for seg in _segments:
		_finish_task(seg)

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
		_finish_task(old)
		if old.node:
			old.node.queue_free()

func _next_after(prev: Segment) -> Segment:
	var seg := Segment.new()
	seg.index = prev.index + 1
	seg.dir = prev.exit_dir()
	seg.right = seg.dir.cross(Vector3.UP)
	seg.heading = prev.heading + prev.turn
	seg.prev_turn = prev.turn
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
	seg.rng.seed = _rng.randi()
	seg.task = WorkerThreadPool.add_task(_bake.bind(seg, false), false, "segment")
	return seg

## Attaches any stretch whose worker has finished; called each frame.
func poll() -> void:
	for seg in _segments:
		if seg.task >= 0 and WorkerThreadPool.is_task_completed(seg.task):
			_finish_task(seg)

func _finish_task(seg: Segment) -> void:
	if seg.task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(seg.task)
	seg.task = -1
	_attach(seg)

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

## Builds the stretch's geometry. Runs on a worker thread: touches nothing but
## its own Meshers and the segment's dice.
func _bake(seg: Segment, first: bool) -> void:
	var m := Mesher.new() # the path and anything that should shadow it
	var sc := Mesher.new() # jungle and piers far below: no shadows, half the cost
	var f := seg.frame()

	# Floor + kerbs along the straight, tile by tile (gaps simply skip tiles).
	var s := 0.0
	while s < seg.length:
		var mid := s + Models.TILE_LENGTH / 2.0
		if not seg.in_gap(mid):
			for lane in [-1, 0, 1]:
				Models.floor_tile(m, Models.sub(f, Vector3(lane * LW, 0, -mid)), seg.rng.randf())
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

	# The embankment the road stands on, tile-aligned so it breaks exactly where
	# the floor does. Alternate stretches sit a hair apart so corners never flicker.
	var dy := 0.02 * (seg.index % 2)
	var span_from := -1.0
	var e := 0.0
	while e < seg.length:
		var solid := not seg.in_gap(e + Models.TILE_LENGTH / 2.0)
		if solid and span_from < 0.0:
			span_from = e
		elif not solid and span_from >= 0.0:
			_embankment(m, f, span_from, e, dy)
			span_from = -1.0
		if not solid and seg.in_gap(e + Models.TILE_LENGTH / 2.0) and not seg.in_gap(e - Models.TILE_LENGTH / 2.0):
			# Where a stretch collapsed, its blocks lie in the jungle below.
			Models.rubble(sc, Models.sub(f, Vector3(0, Models.GROUND_Y, -(e + 1.0))), seg.rng.randi())
		e += Models.TILE_LENGTH
	_embankment(m, f, span_from if span_from >= 0.0 else seg.length, seg.end_s() + 0.9, dy)

	# Dressing along the walls: pillars on buttresses, torches on the parapet,
	# vines spilling over, growth on the tier ledges.
	var k := 8.0
	while k < seg.length - 4.0:
		for side in [-1.0, 1.0]:
			var at := Models.sub(f, Vector3(0, 0, -k))
			if seg.in_gap(k - 1.5) or seg.in_gap(k + 1.5):
				continue
			var roll := seg.rng.randf()
			if roll < 0.4:
				Models.buttress(m, at, side)
				Models.pillar(m, Models.sub(f, Vector3(side * (Models.WALL_HALF + 0.9), 0, -k)), seg.rng.randf_range(2.6, 3.6), seg.rng.randf() < 0.3)
			elif roll < 0.75:
				Models.torch(m, Models.sub(f, Vector3(side * (W / 2.0 + 0.22), 0.4, -k)))
			else:
				Models.vines(sc, at, side, seg.rng.randi())
		k += seg.rng.randf_range(7.0, 11.0)
	var v := 3.0
	while v < seg.length:
		var side := -1.0 if seg.rng.randf() < 0.5 else 1.0
		if not seg.in_gap(v):
			if seg.rng.randf() < 0.5:
				Models.vines(sc, Models.sub(f, Vector3(0, 0, -v)), side, seg.rng.randi())
			# Bushes rooted on a tier ledge.
			var tier := seg.rng.randi_range(0, 2)
			var lx := Models.WALL_HALF + Models.TIER_STEP * tier + 0.35
			var ly := Models.TIER_TOP - Models.TIER_H * tier + (0.1 if tier == 0 else 0.0)
			Models.bush(sc, Models.sub(f, Vector3(side * lx, ly, -(v + seg.rng.randf_range(0.0, 2.0)))), seg.rng.randf_range(0.6, 0.9), seg.rng.randi_range(0, 99))
		v += seg.rng.randf_range(3.0, 6.0)

	# The jungle: trees rooted on the floor in two rows — lower near the wall,
	# taller behind — with undergrowth at the foot of the embankment.
	var base := Models.WALL_HALF + Models.TIER_STEP * 3.0
	for row in 2:
		var t := 0.0
		while t < seg.end_s():
			for side in [-1.0, 1.0]:
				# Past the corner, the turn side is where the next stretch runs;
				# near the start, the side we came from is where the last one ran.
				if t > seg.length - 3.0 and side == float(seg.turn):
					continue
				if t < 10.0 + 8.0 * row and side == float(seg.prev_turn):
					continue
				var off := seg.rng.randf_range(1.6, 4.5) if row == 0 else seg.rng.randf_range(5.0, 15.0)
				var size := seg.rng.randf_range(0.7, 0.95) if row == 0 else seg.rng.randf_range(1.0, 1.5)
				var along := t + seg.rng.randf_range(0.0, 3.0)
				Models.tree(sc, Models.sub(f, Vector3(side * (base + off), Models.GROUND_Y, -along)), size, seg.rng.randi_range(0, 99))
				if row == 0 and seg.rng.randf() < 0.6:
					Models.bush(sc, Models.sub(f, Vector3(side * (base + 0.6), Models.GROUND_Y, -(along + 1.5))), seg.rng.randf_range(1.0, 1.6), seg.rng.randi_range(0, 99))
			t += seg.rng.randf_range(3.5, 5.5) if row == 0 else seg.rng.randf_range(5.0, 8.0)

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

	seg.baked = [m.bake(), sc.bake()]

## Embankment under the road from [s0] to [s1].
func _embankment(m: Mesher, f: Transform3D, s0: float, s1: float, dy: float) -> void:
	if s1 - s0 < 0.01:
		return
	Models.embankment(m, Models.sub(f, Vector3(0, 0, -(s0 + s1) / 2.0)), s1 - s0, dy)

## Main thread: turns the baked arrays into nodes.
func _attach(seg: Segment) -> void:
	var node := Node3D.new()
	var path := MeshInstance3D.new()
	path.mesh = Mesher.from_arrays(seg.baked[0])
	node.add_child(path)
	var scenery := MeshInstance3D.new()
	scenery.mesh = Mesher.from_arrays(seg.baked[1])
	scenery.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(scenery)
	seg.baked = []
	if not seg.coins.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _coin_mesh
		mm.instance_count = seg.coins.size()
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi)
		seg.coin_mm = mm
	seg.node = node
	add_child(node)
	_spin(seg)

## Spins every coin and hides the collected ones; called each frame.
func spin_coins(delta: float) -> void:
	poll()
	_coin_angle = fmod(_coin_angle + delta * 3.0, TAU)
	for seg in _segments:
		_spin(seg)

func _spin(seg: Segment) -> void:
	if seg.coin_mm == null:
		return
	for i in seg.coins.size():
		var c := seg.coins[i]
		var pos := seg.point(c.s, c.x, c.y)
		if c.taken:
			seg.coin_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), pos))
		else:
			# Offset by s so neighbouring coins don't spin in lockstep.
			seg.coin_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _coin_angle + c.s), pos))
