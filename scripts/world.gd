class_name World
extends Node3D
## The road through Xibalba: a raised causeway that winds forward over the
## underworld floor, built in 12 m chunks a little ahead of the runner and
## freed behind him. Each chunk is one batched mesh (built on a worker thread)
## plus one MultiMesh for its sun-drops.
##
## Coordinates: the road runs toward -Z. A point on it is (s, u): [s] metres
## along, [u] metres across (+ = right). [point] turns that into the world.
## The road's centre wanders left and right ([center]); its width belongs to
## the House it passes through ([width]).
##
## The paved road holds three lanes (lane −1, 0, +1 at u = lane × LANE_W).
## What it holds (drops, dangers, braziers, jaguars) is dealt row by row, in
## order, from one seeded stream as chunks are made, so a seed always deals the
## same road — the daily dusk is the same for everyone. Every row leaves a way
## through: a free lane, or a jump, or a slide.

signal chunk_added(chunk: Chunk)

const CHUNK := 12.0
const ROW := 2.0
const COLS := 6 ## paving stones across: two per lane
const FLOOR_Y := -2.6
const CURB_W := 0.45
const CURB_H := 0.22
const AHEAD := 72.0
const BEHIND := 26.0
const PLAZA_W := 16.0
const PLAZA_BACK := -16.0
const DROP_Y := 0.65
const BRAZIER_R := 3.2
const ALL := 9 ## an obstacle's lane when it spans the road (a lintel)
## How tall each danger stands (m): a low wall is jumped, a lintel slid under,
## the rest go round. [depth] is its length along the road.
const DANGER := {
	"stela": {"depth": 0.7, "jump": false, "slide": false},
	"blades": {"depth": 0.8, "jump": false, "slide": false},
	"wall": {"depth": 0.5, "jump": true, "slide": false},
	"lintel": {"depth": 0.6, "jump": false, "slide": true},
}

class Chunk:
	extends RefCounted
	var index := 0
	var s0 := 0.0
	var s1 := 0.0
	var drops: Array[Dictionary] = [] ## {s, pos: Vector3, taken}
	var obstacles: Array[Dictionary] = [] ## {kind, s, lane (ALL = every lane), depth, pos, seed}
	var pits: Array[Dictionary] = [] ## {s0, s1, c0, c1}: road cells missing
	var braziers: Array[Dictionary] = [] ## {pos, r, curb}
	var jaguars: Array[Dictionary] = [] ## spawn points {s, pos}
	var gates: Array[Dictionary] = [] ## {s, id}
	var seed := 0
	var node: Node3D
	var drop_mm: MultiMesh
	var task := -1
	var baked: Array = []

	func has_pit(row_s: float, col: int) -> bool:
		for p in pits:
			if absf(p.s0 - row_s) < 0.01 and col >= p.c0 and col <= p.c1:
				return true
		return false

var seed := 0
var _p1 := 0.0
var _p2 := 0.0
var _chunks: Array[Chunk] = []
var _ev := RandomNumberGenerator.new()
var _next_ev := 0.0
var _pending := {} ## chunk index → {drops, obstacles, pits, braziers, jaguars}
var _coin_mesh: ArrayMesh
var _coin_angle := 0.0
var _trail_id := 0
var attached := 0 ## chunks that have joined the scene (profiling)
var _parts: Array[Chunk] = [] ## chunks with pieces still to join

func reset(run_seed: int) -> void:
	for c in _chunks:
		_free(c)
	_chunks.clear()
	_pending.clear()
	_parts.clear()
	seed = run_seed
	var r := RandomNumberGenerator.new()
	r.seed = hash([run_seed, "path"])
	_p1 = r.randf() * TAU
	_p2 = r.randf() * TAU
	_ev.seed = hash([run_seed, "road"])
	_next_ev = 0.0
	_trail_id = 0
	if _coin_mesh == null:
		_coin_mesh = Models.coin_mesh()
	ensure(0.0)
	for c in _chunks:
		_finish(c)

# ---------------------------------------------------------------- shape ---

## The road's centre line, as a lateral offset, [s] metres along.
func center(s: float) -> float:
	var ramp := smoothstep(0.0, 30.0, s)
	return ramp * (3.2 * sin(0.0717 * s + _p1) + 1.27 * sin(0.184 * s + _p2))

func slope(s: float) -> float:
	return (center(s + 0.05) - center(s - 0.05)) / 0.1

## Unit vector across the road (to the runner's right) at [s].
func right(s: float) -> Vector3:
	return Vector3(1.0, 0.0, slope(s)).normalized()

## Unit vector down the road at [s].
func forward(s: float) -> Vector3:
	return Vector3(slope(s), 0.0, -1.0).normalized()

func point(s: float, u := 0.0, y := 0.0) -> Vector3:
	return Vector3(center(s), y, -s) + right(s) * u

## The centre of [lane] (−1, 0, 1) across the road, in metres.
static func lane_u(lane: int) -> float:
	return lane * Nights.LANE_W

func width(s: float) -> float:
	if s < 0.0:
		return PLAZA_W
	return Nights.width(s, seed)

## How far across the road a world point at ([x], [z]) is (+ = right).
func u_of(x: float, z: float) -> float:
	var s := -z
	return (x - center(s)) / sqrt(1.0 + slope(s) * slope(s))

## True where the road has fallen away under ([x], [z]).
func in_pit(x: float, z: float) -> bool:
	var s := -z
	var c := chunk_at(s)
	if c == null or c.pits.is_empty():
		return false
	var u := u_of(x, z)
	var w := width(s)
	for p in c.pits:
		# A little forgiveness: the edge of a hole doesn't swallow you.
		if s < p.s0 + 0.25 or s > p.s1 - 0.25:
			continue
		var u0: float = (float(p.c0) / COLS - 0.5) * w + 0.25
		var u1: float = (float(p.c1 + 1) / COLS - 0.5) * w - 0.25
		if u > u0 and u < u1:
			return true
	return false

func chunk_at(s: float) -> Chunk:
	var i := floori(s / CHUNK)
	for c in _chunks:
		if c.index == i:
			return c
	return null

func chunks() -> Array[Chunk]:
	return _chunks

# ------------------------------------------------------------ streaming ---

## Keeps chunks built from a little behind [s] to well ahead of it.
func ensure(s: float) -> void:
	var first := floori((s - BEHIND) / CHUNK)
	var last := floori((s + AHEAD) / CHUNK)
	first = mini(first, -2) if s < 30.0 else first
	while not _chunks.is_empty() and _chunks.front().index < first:
		_free(_chunks.pop_front())
	for i in _pending.keys():
		if i < first:
			_pending.erase(i)
	var next: int = first if _chunks.is_empty() else _chunks.back().index + 1
	while next <= last:
		_chunks.append(_make(next))
		next += 1

## Attaches chunks whose worker has finished; call once a frame.
func poll() -> void:
	# One upload per frame: the rest of a chunk already on its way first, then
	# the next finished chunk.
	while not _parts.is_empty():
		var p: Chunk = _parts.front()
		if p.node == null or not is_instance_valid(p.node) or p.baked.is_empty():
			_parts.pop_front()
			continue
		_attach_part(p)
		if p.baked.is_empty():
			_parts.pop_front()
		return
	for c in _chunks:
		if c.task >= 0 and WorkerThreadPool.is_task_completed(c.task):
			_finish(c)
			return

func _free(c: Chunk) -> void:
	if c.task >= 0:
		WorkerThreadPool.wait_for_task_completion(c.task)
		c.task = -1
	if c.node:
		c.node.queue_free()
		c.node = null

func _finish(c: Chunk) -> void:
	if c.task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(c.task)
	c.task = -1
	_attach(c)

func _make(i: int) -> Chunk:
	var c := Chunk.new()
	c.index = i
	c.s0 = i * CHUNK
	c.s1 = c.s0 + CHUNK
	c.seed = hash([seed, i, "decor"])
	_deal_until(c.s1 + 10.0)
	var p: Dictionary = _pending.get(i, {})
	_pending.erase(i)
	for key in ["drops", "obstacles", "pits", "braziers", "jaguars"]:
		if p.has(key):
			c.get(key).append_array(p[key])
	for g in _gates_in(c.s0, c.s1):
		c.gates.append(g)
		var w := width(g.s)
		for side in [-1.0, 1.0]:
			c.braziers.append({"pos": point(g.s, side * (w / 2.0 + CURB_W + 1.4), 3.4), "r": 3.0, "curb": false})
	chunk_added.emit(c)
	c.task = WorkerThreadPool.add_task(_bake.bind(c), false, "chunk")
	return c

# --------------------------------------------------------------- dealing ---

func _slot(i: int) -> Dictionary:
	if not _pending.has(i):
		_pending[i] = {"drops": [], "obstacles": [], "pits": [], "braziers": [], "jaguars": []}
	return _pending[i]

func _put(kind: String, s: float, item: Dictionary) -> void:
	_slot(floori(s / CHUNK))[kind].append(item)

## Where Houses begin (their gates) inside [s0, s1).
func _gates_in(s0: float, s1: float) -> Array:
	var out := []
	if s1 <= 0.0:
		return out
	var n0: int = Nights.locate(maxf(s0, 0.0)).n
	var n1: int = Nights.locate(maxf(s1, 0.0)).n + 1
	for n in range(n0, n1 + 1):
		var starts := Nights.house_starts(n)
		var plan := Nights.plan(n, seed)
		for k in 3:
			if n == 1 and k == 0:
				continue
			var gs: float = starts[k] + 2.0
			if gs >= s0 and gs < s1:
				out.append({"s": gs, "id": plan[k]})
	return out

func _near_gate(s: float) -> bool:
	var n: int = Nights.locate(maxf(s, 0.0)).n
	for k in 3:
		if n == 1 and k == 0:
			continue
		if absf(s - (Nights.house_starts(n)[k] + 2.0)) < 6.0:
			return true
	return false

## Deals what the road holds, row by row, up to [upto]. Rows come about a
## second apart at the speed the runner will have there (closer as the nights
## go on), so there is always time to read one and move.
func _deal_until(upto: float) -> void:
	while _next_ev < upto:
		var s := _next_ev
		var at := Nights.locate(maxf(s, 0.0))
		var prog: float = (at.n - 1) + at.t
		var v := Nights.speed(at.n, at.t)
		_next_ev += v * _ev.randf_range(0.95, 1.45) / (1.0 + 0.06 * minf(prog, 6.0))
		if s < Nights.START_CLEAR:
			if s > 8.0:
				_drop_line(s, 0, 5)
			continue
		if at.dawn:
			if _ev.randf() < 0.6:
				_drop_line(s, _ev.randi_range(-1, 1), 6)
			continue
		if s > Nights.start(at.n) + Nights.length(at.n) - 8.0 or _near_gate(s):
			continue
		var h := Nights.house(s, seed)
		var mix: Dictionary = h.mix
		var total := 0.0
		for k in mix:
			total += mix[k]
		var roll := _ev.randf() * total
		var pick := "drop"
		for k in mix:
			roll -= mix[k]
			if roll <= 0.0:
				pick = k
				break
		_row(pick, s, prog)

## One row of road: [pick] is what the House's mix chose; harder nights mix
## more into a row. Always leaves a way through.
func _row(pick: String, s: float, prog: float) -> void:
	var lanes := [-1, 0, 1]
	_shuffle(lanes)
	# How likely the row carries a second danger (night 1: rarely).
	var busy := clampf(0.12 + 0.13 * prog, 0.0, 0.7)
	match pick:
		"drop":
			_drop_line(s, lanes[0], 6)
		"stela", "blades":
			# One lane blocked, or two; never three.
			var n := 2 if _ev.randf() < busy else 1
			for i in n:
				_danger(pick, s, lanes[i])
			if n == 2 and _ev.randf() < busy:
				# The open lane holds a low wall: jump it there.
				_danger("wall", s, lanes[2])
				_drop_arc(s, lanes[2])
			elif _ev.randf() < 0.5:
				_drop_line(s - 2.0, lanes[n], 5)
		"wall":
			var n := 1 + int(_ev.randf() < busy) + int(_ev.randf() < busy * 0.6)
			for i in n:
				_danger("wall", s, lanes[i])
			_drop_arc(s, lanes[0])
		"lintel":
			_danger("lintel", s, ALL)
			if _ev.randf() < busy:
				_danger("stela", s, lanes[0])
			elif _ev.randf() < 0.5:
				_drop_line(s - 3.0, lanes[1], 5)
		"pit":
			var row_s := floorf(s / ROW) * ROW
			var n := 1 + int(_ev.randf() < 0.35 + busy) + int(_ev.randf() < busy)
			var picked := lanes.slice(0, n)
			for lane in picked:
				var c0: int = (int(lane) + 1) * 2
				_put("pits", row_s, {"s0": row_s, "s1": row_s + ROW, "c0": c0, "c1": c0 + 1})
			_drop_arc(row_s + ROW / 2.0, picked[0])
		"jag":
			var side := -1.0 if _ev.randf() < 0.5 else 1.0
			var n := 2 if _ev.randf() < 0.25 + 0.1 * prog else 1
			for k in n:
				var sd := side if k == 0 else -side
				var js := s + _ev.randf_range(-1.2, 1.2)
				var pos := point(js, sd * (width(js) / 2.0 + _ev.randf_range(-0.2, 0.3)))
				_put("jaguars", js, {"s": js, "pos": pos})
		"brazier":
			var side := -1.0 if _ev.randf() < 0.5 else 1.0
			_put("braziers", s, {"pos": point(s, side * (width(s) / 2.0 + CURB_W / 2.0), CURB_H), "r": BRAZIER_R, "curb": true, "seed": _ev.randi()})
			_drop_line(s - 2.0, int(side), 5)

func _danger(kind: String, s: float, lane: int) -> void:
	var u := 0.0 if lane == ALL else lane_u(lane)
	_put("obstacles", s, {"kind": kind, "s": s, "lane": lane, "depth": DANGER[kind].depth,
		"pos": point(s, u), "seed": _ev.randi()})

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _ev.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp

## A line of [n] sun-drops down one lane.
func _drop_line(s: float, lane: int, n: int) -> void:
	_trail_id += 1
	for i in n:
		var si := s + i * 1.6
		_put("drops", si, {"s": si, "pos": point(si, lane_u(lane), DROP_Y), "taken": false, "trail": _trail_id})

## Five sun-drops arched over a jump at [s] in [lane]: they follow the leap.
func _drop_arc(s: float, lane: int) -> void:
	_trail_id += 1
	for i in 5:
		var k := (i - 2) / 2.0
		var si := s + k * 2.6
		_put("drops", si, {"s": si, "pos": point(si, lane_u(lane), DROP_Y + 1.0 * (1.0 - k * k)), "taken": false, "trail": _trail_id})

# ----------------------------------------------------------------- build ---

const DECOR := {
	"jungle": {
		"near": [["bush", 3.0], ["fern", 3.0], ["grass", 4.0], ["maize", 1.5], ["rock", 1.5], ["urn", 0.6], ["skull_rack", 0.4], ["stela", 0.5], ["altar", 0.4]],
		"mid": [["ceiba", 4.0], ["stela", 1.0], ["banner", 1.0], ["temple", 0.45], ["bush", 1.5]],
		"far": [["ceiba", 4.0], ["temple", 1.0], ["rock_big", 1.0]],
	},
	"jaguars": {
		"near": [["brazier", 1.0], ["urn", 1.0], ["bush", 2.0], ["grass", 3.0], ["rock", 1.0], ["banner_ochre", 1.0], ["fern", 1.5]],
		"mid": [["jaguar_statue", 2.5], ["ceiba", 2.5], ["stela", 1.0], ["altar", 1.0]],
		"far": [["temple", 1.2], ["ceiba", 2.5], ["jaguar_big", 1.0]],
	},
	"bats": {
		"near": [["stalagmite_small", 2.0], ["crystals", 2.0], ["bones", 1.5], ["cave_stone", 1.5]],
		"mid": [["stalagmite", 2.5], ["roost", 2.0], ["cave_rock", 2.0], ["crystals_big", 1.0]],
		"far": [["cave_rock_big", 2.5], ["stalagmite_big", 2.0]],
	},
	"gloom": {
		"near": [["mist_shrub", 3.0], ["bones", 1.5], ["stone_small", 1.5], ["grey_rock", 1.5]],
		"mid": [["dead_tree", 3.0], ["standing_stone", 2.0], ["broken_pillar", 2.0]],
		"far": [["dead_tree_big", 2.0], ["standing_big", 1.5]],
	},
	"knives": {
		"near": [["obsidian_small", 3.0], ["dark_rock", 1.5], ["bones", 1.5]],
		"mid": [["obsidian", 3.0], ["red_spire", 2.0], ["skull_rack", 1.0]],
		"far": [["red_spire_big", 2.5], ["obsidian_big", 1.0]],
	},
	"cold": {
		"near": [["snow_mound", 3.0], ["ice_small", 2.0], ["grey_rock", 1.0]],
		"mid": [["ice_spikes", 2.5], ["frozen_stela", 1.5], ["white_tree", 1.5]],
		"far": [["ice_big", 2.0], ["snow_big", 1.5]],
	},
	"fire": {
		"near": [["lava_small", 2.0], ["basalt_small", 2.0], ["fire_pit", 1.0], ["char_rock", 1.5]],
		"mid": [["basalt", 2.5], ["char_tree", 2.0], ["brazier", 1.0], ["lava", 1.0]],
		"far": [["basalt_big", 2.5], ["lava_big", 1.0]],
	},
}

## Builds a chunk's geometry. Runs on a worker thread: touches nothing but the
## chunk, a fresh Mesher and the pure shape functions above.
func _bake(c: Chunk) -> void:
	# Four meshes, joined to the scene one per frame: the road, the scenery on
	# each side, the dangers. One big upload made a phone miss frames.
	var m := Mesher.new()
	var left := Mesher.new()
	var right_m := Mesher.new()
	var items := Mesher.new()
	var r := RandomNumberGenerator.new()
	r.seed = c.seed
	var mid := c.s0 + CHUNK / 2.0
	var h: Dictionary = Themes.house("dusk") if c.s0 < 0.0 else Nights.house(mid, seed)
	# The underworld floor: hatched earth in the House's colour.
	m.box(Models.at(Vector3(center(mid), FLOOR_Y - 0.25, -mid)), Vector3(150.0, 0.5, CHUNK + 0.02), Mesher.hatched(h.earth), false, false)
	var row_s := c.s0
	while row_s < c.s1 - 0.001:
		if row_s >= PLAZA_BACK:
			_road_row(m, c, row_s, h, r)
		row_s += ROW
	if c.s1 > 0.0:
		_decor([left, right_m], c, h, r)
	for o in c.obstacles:
		var s: float = o.s
		var basis := Basis.looking_at(forward(s), Vector3.UP)
		var xf := Models.at(o.pos, basis)
		match o.kind:
			"stela": Models.lane_stela(items, xf, o.seed)
			"blades": Models.lane_blades(items, xf, o.seed)
			"wall": Models.low_wall(items, xf, Nights.LANE_W - 0.25, h.accent, o.seed)
			"lintel": Models.lintel(items, xf, width(s) + 2.0 * CURB_W, h.accent, o.seed)
	for b in c.braziers:
		if b.curb:
			Models.brazier(items, Models.at(b.pos + Vector3(0, 0.09, 0)), b.get("seed", 0))
	for g in c.gates:
		var w := width(g.s)
		var hh: Dictionary = Themes.house(g.id)
		for side in [-1.0, 1.0]:
			var pos := point(g.s, side * (w / 2.0 + CURB_W + 1.4), FLOOR_Y)
			var basis := Basis.looking_at(-side * right(g.s), Vector3.UP)
			Models.gate_pylon(items, Models.at(pos, basis.scaled(Vector3.ONE * 1.3)), hh.accent, c.seed + int(side))
	if c.index == floori(PLAZA_BACK / CHUNK):
		Models.start_temple(items, Models.at(Vector3(0, 0, -PLAZA_BACK)))
	c.baked = [m.bake(), left.bake(), right_m.bake(), items.bake()]

## One 2 m row of road: paving stones (missing over a pit), the bed under
## them, and the painted walls down to the floor on both sides.
func _road_row(m: Mesher, c: Chunk, s0: float, h: Dictionary, r: RandomNumberGenerator) -> void:
	var s1 := s0 + ROW
	var plaza := s1 <= 0.001
	var cols := 8 if plaza else COLS
	var w0 := width(s0) if not plaza else PLAZA_W
	var w1 := width(s1) if not plaza else PLAZA_W
	if plaza:
		w0 = PLAZA_W
		w1 = PLAZA_W
	var ins := 0.04
	for k in cols:
		var f0 := float(k) / cols - 0.5
		var f1 := float(k + 1) / cols - 0.5
		if not plaza and c.has_pit(s0, k):
			_pit(m, s0, s1, f0, f1, w0, w1)
			continue
		var col: Color = h.tile.lerp(h.tile2, r.randf() * 0.8) if not plaza else Models.STUCCO.lerp(Models.STUCCO_SHADE, r.randf() * 0.7)
		var roll := r.randf()
		if roll < 0.03:
			col = col.lerp(h.accent, 0.45)
		# Every fifth row is a band of darker stone across the road.
		if not plaza and int(roundf(s0 / ROW)) % 5 == 0:
			col = col.darkened(0.12)
		var quad := [
			point(s0 + ins, f0 * w0 + ins), point(s0 + ins, f1 * w0 - ins),
			point(s1 - ins, f1 * w1 - ins), point(s1 - ins, f0 * w1 + ins),
		]
		var down := Vector3(0, -0.3, 0)
		m.block([quad[0] + down, quad[1] + down, quad[2] + down, quad[3] + down, quad[0], quad[1], quad[2], quad[3]], col)
		var bed := [point(s0, f0 * w0, -0.56), point(s0, f1 * w0, -0.56), point(s1, f1 * w1, -0.56), point(s1, f0 * w1, -0.56)]
		var bed_top := Vector3(0, 0.26, 0)
		m.block([bed[0], bed[1], bed[2], bed[3], bed[0] + bed_top, bed[1] + bed_top, bed[2] + bed_top, bed[3] + bed_top], Models.STONE_DARK, false, false)
		var mark_p := 0.025 if h.mark == "kin" else 0.11
		if roll > 1.0 - mark_p:
			var sm := (s0 + s1) / 2.0
			var um := (f0 + f1) / 2.0 * (w0 + w1) / 2.0
			Models.road_mark(m, "kin" if plaza else h.mark, point(sm, um), 0.9, right(sm), forward(sm), r)
	for side in [-1.0, 1.0]:
		var e0: float = side * w0 / 2.0
		var e1: float = side * w1 / 2.0
		var o0: float = e0 + side * CURB_W
		var o1: float = e1 + side * CURB_W
		var wall := [point(s0, e0, FLOOR_Y), point(s0, o0, FLOOR_Y), point(s1, o1, FLOOR_Y), point(s1, e1, FLOOR_Y)]
		var top := Vector3(0, CURB_H - FLOOR_Y, 0)
		m.block([wall[0], wall[1], wall[2], wall[3], wall[0] + top, wall[1] + top, wall[2] + top, wall[3] + top], Models.STONE)
		# The curb's painted cap in the House's colour.
		var cap := [point(s0, e0 - side * 0.03, CURB_H), point(s0, o0 + side * 0.03, CURB_H), point(s1, o1 + side * 0.03, CURB_H), point(s1, e1 - side * 0.03, CURB_H)]
		var lift := Vector3(0, 0.09, 0)
		m.block([cap[0], cap[1], cap[2], cap[3], cap[0] + lift, cap[1] + lift, cap[2] + lift, cap[3] + lift], h.accent)
		# The frieze on the outer face: a cinnabar band over a Maya-blue line.
		for band in [[-1.15, -0.7, Models.CINNABAR], [-1.42, -1.3, Models.MAYA_BLUE]]:
			var a := [point(s0, o0, band[0]), point(s0, o0 + side * 0.02, band[0]), point(s1, o1 + side * 0.02, band[0]), point(s1, o1, band[0])]
			var up := Vector3(0, band[1] - band[0], 0)
			m.block([a[0], a[1], a[2], a[3], a[0] + up, a[1] + up, a[2] + up, a[3] + up], band[2], false, false)

## A hole where road stones fell into the dark: black shaft walls going down.
func _pit(m: Mesher, s0: float, s1: float, f0: float, f1: float, w0: float, w1: float) -> void:
	var y0 := -2.2
	var q := [point(s0, f0 * w0, y0), point(s0, f1 * w0, y0), point(s1, f1 * w1, y0), point(s1, f0 * w1, y0)]
	var low := Vector3(0, -0.4, 0)
	m.block([q[0] + low, q[1] + low, q[2] + low, q[3] + low, q[0], q[1], q[2], q[3]], Models.PIT, false, false)
	var t := 0.06
	var walls := [
		[point(s0, f0 * w0, y0), point(s0, f1 * w0, y0), point(s0 + t, f1 * w0, y0), point(s0 + t, f0 * w0, y0)],
		[point(s1 - t, f0 * w1, y0), point(s1 - t, f1 * w1, y0), point(s1, f1 * w1, y0), point(s1, f0 * w1, y0)],
		[point(s0, f0 * w0, y0), point(s0, f0 * w0 + t, y0), point(s1, f0 * w1 + t, y0), point(s1, f0 * w1, y0)],
		[point(s0, f1 * w0 - t, y0), point(s0, f1 * w0, y0), point(s1, f1 * w1, y0), point(s1, f1 * w1 - t, y0)],
	]
	var lift := Vector3(0, -y0 - 0.3, 0)
	for wq in walls:
		m.block([wq[0], wq[1], wq[2], wq[3], wq[0] + lift, wq[1] + lift, wq[2] + lift, wq[3] + lift], Color("#241612"), false, false)

func _decor(sides: Array, c: Chunk, h: Dictionary, r: RandomNumberGenerator) -> void:
	var set_id: String = h.decor if c.s0 >= 0.0 else "jungle"
	for side in [-1.0, 1.0]:
		for band in [["near", 0.5, 3.6, 1.0, 1.9, 0.9], ["mid", 3.8, 9.0, 2.4, 3.8, 0.8], ["far", 9.5, 21.0, 3.0, 5.0, 0.75]]:
			var s := c.s0 + r.randf_range(0.0, band[3])
			while s < c.s1:
				if s > 1.0 and r.randf() < band[5]:
					var kind := _pick(Themes.decor(DECOR, set_id, band[0]), r)
					_place(sides[0] if side < 0.0 else sides[1], kind, s, side, r.randf_range(band[1], band[2]), r)
				s += r.randf_range(band[3], band[4])
	# Vines and roots spilling down the causeway walls.
	if set_id in ["jungle", "jaguars", "bats"]:
		var vine_col: Color = Models.LEAF if set_id != "bats" else Models.CAVE_DARK
		for side in [-1.0, 1.0]:
			var s := c.s0 + r.randf_range(0.0, 2.0)
			while s < c.s1:
				if s > 0.5 and r.randf() < 0.55:
					var top := point(s, side * (width(s) / 2.0 + CURB_W + 0.02), CURB_H)
					Models.vines(sides[0] if side < 0.0 else sides[1], Models.at(top, Basis.looking_at(side * right(s), Vector3.UP)), r.randi(), vine_col)
				s += r.randf_range(1.6, 3.2)
	if c.s0 > 0.0 and r.randf() < 0.2:
		var side := -1.0 if r.randf() < 0.5 else 1.0
		var s := r.randf_range(c.s0, c.s1)
		var pos := point(s, side * (width(s) / 2.0 + r.randf_range(26.0, 36.0)), FLOOR_Y)
		var faces := Basis.looking_at(-side * right(s), Vector3.UP)
		var m: Mesher = sides[0] if side < 0.0 else sides[1]
		if set_id in ["jungle", "jaguars", "fire"]:
			Models.pyramid(m, Models.at(pos, faces), r.randf_range(0.8, 1.2))
		elif set_id == "bats":
			Models.cave_rock(m, Models.at(pos, faces), r.randf_range(3.5, 5.0), r.randi())
		else:
			Models.standing_stone(m, Models.at(pos, faces), r.randf_range(4.0, 6.0), r.randi())

func _pick(list: Array, r: RandomNumberGenerator) -> String:
	var total := 0.0
	for e in list:
		total += e[1]
	var roll := r.randf() * total
	for e in list:
		roll -= e[1]
		if roll <= 0.0:
			return e[0]
	return list[0][0]

## Puts one piece of scenery [d] metres out from the wall on [side], facing
## the road.
func _place(m: Mesher, kind: String, s: float, side: float, d: float, r: RandomNumberGenerator) -> void:
	var u := side * (width(s) / 2.0 + CURB_W + d)
	var pos := point(s, u, FLOOR_Y)
	var faces := Basis.looking_at(-side * right(s), Vector3.UP)
	var xf := Models.at(pos, faces)
	var loose := Models.at(pos, Basis(Vector3.UP, r.randf() * TAU))
	var sd := r.randi()
	match kind:
		"bush": Models.bush(m, loose, r.randf_range(0.8, 1.4), sd)
		"grass": Models.grass(m, loose, r.randf_range(0.8, 1.4), sd)
		"fern": Models.fern(m, loose, r.randf_range(0.8, 1.3), sd)
		"maize": Models.maize(m, loose, sd)
		"rock": Models.rock(m, loose, r.randf_range(0.7, 1.5), sd)
		"rock_big": Models.rock(m, loose, r.randf_range(2.5, 4.0), sd)
		"urn": Models.urn(m, xf, sd)
		"skull_rack": Models.skull_rack(m, xf, sd)
		"stela": Models.stela(m, xf, r.randf_range(0.8, 1.15), sd)
		"altar": Models.altar(m, loose, sd)
		"ceiba": Models.ceiba(m, loose, r.randf_range(0.9, 1.4), sd)
		"temple": Models.temple(m, xf, r.randf_range(0.8, 1.2), sd)
		"banner": Models.banner(m, xf, [Models.CINNABAR, Models.MAYA_BLUE, Models.JADE][sd % 3], sd)
		"banner_ochre": Models.banner(m, xf, Models.OCHRE, sd)
		"brazier": Models.brazier(m, loose, sd)
		"jaguar_statue": Models.jaguar_statue(m, xf, r.randf_range(1.0, 1.3))
		"jaguar_big": Models.jaguar_statue(m, xf, r.randf_range(2.0, 2.8))
		"stalagmite_small": Models.stalagmite(m, loose, r.randf_range(0.4, 0.7), sd)
		"stalagmite": Models.stalagmite(m, loose, r.randf_range(0.8, 1.3), sd)
		"stalagmite_big": Models.stalagmite(m, loose, r.randf_range(1.6, 2.4), sd)
		"crystals": Models.crystals(m, loose, r.randf_range(0.7, 1.1), sd)
		"crystals_big": Models.crystals(m, loose, r.randf_range(1.5, 2.2), sd)
		"bones": Models.bones(m, loose, sd)
		"cave_stone": Models.rock(m, loose, r.randf_range(0.7, 1.4), sd, Models.CAVE)
		"cave_rock": Models.cave_rock(m, loose, r.randf_range(0.8, 1.3), sd)
		"cave_rock_big": Models.cave_rock(m, loose, r.randf_range(1.8, 2.8), sd)
		"roost": Models.dead_tree(m, loose, r.randf_range(0.9, 1.2), sd, Models.CAVE_DARK, true)
		"mist_shrub": Models.mist_shrub(m, loose, r.randf_range(0.8, 1.3), sd)
		"stone_small": Models.standing_stone(m, xf, r.randf_range(0.4, 0.6), sd)
		"grey_rock": Models.rock(m, loose, r.randf_range(0.7, 1.4), sd, Color("#8C8A92"))
		"dead_tree": Models.dead_tree(m, loose, r.randf_range(0.9, 1.3), sd)
		"dead_tree_big": Models.dead_tree(m, loose, r.randf_range(1.8, 2.6), sd)
		"standing_stone": Models.standing_stone(m, xf, r.randf_range(0.9, 1.3), sd)
		"standing_big": Models.standing_stone(m, xf, r.randf_range(2.0, 3.0), sd)
		"broken_pillar": Models.broken_pillar(m, loose, r.randf_range(0.9, 1.3), sd)
		"obsidian_small": Models.obsidian(m, loose, r.randf_range(0.5, 0.8), sd)
		"obsidian": Models.obsidian(m, loose, r.randf_range(1.0, 1.5), sd)
		"obsidian_big": Models.obsidian(m, loose, r.randf_range(2.2, 3.0), sd)
		"dark_rock": Models.rock(m, loose, r.randf_range(0.7, 1.4), sd, Color("#4A3A3A"))
		"red_spire": Models.red_spire(m, loose, r.randf_range(0.9, 1.3), sd)
		"red_spire_big": Models.red_spire(m, loose, r.randf_range(2.0, 3.0), sd)
		"snow_mound": Models.snow_mound(m, loose, r.randf_range(0.8, 1.3), sd)
		"snow_big": Models.snow_mound(m, loose, r.randf_range(2.0, 3.0), sd)
		"ice_small": Models.ice_spikes(m, loose, r.randf_range(0.5, 0.8), sd)
		"ice_spikes": Models.ice_spikes(m, loose, r.randf_range(0.9, 1.3), sd)
		"ice_big": Models.ice_spikes(m, loose, r.randf_range(1.8, 2.6), sd)
		"frozen_stela": Models.frozen_stela(m, xf, r.randf_range(0.9, 1.15), sd)
		"white_tree": Models.dead_tree(m, loose, r.randf_range(0.9, 1.3), sd, Color("#D8E2E4"))
		"lava_small": Models.lava_pool(m, loose, r.randf_range(0.5, 0.8), sd)
		"lava": Models.lava_pool(m, loose, r.randf_range(1.0, 1.5), sd)
		"lava_big": Models.lava_pool(m, loose, r.randf_range(2.0, 3.0), sd)
		"basalt_small": Models.basalt(m, loose, r.randf_range(0.5, 0.8), sd)
		"basalt": Models.basalt(m, loose, r.randf_range(0.9, 1.3), sd)
		"basalt_big": Models.basalt(m, loose, r.randf_range(1.8, 2.6), sd)
		"fire_pit": Models.fire_pit(m, loose, sd)
		"char_rock": Models.rock(m, loose, r.randf_range(0.7, 1.4), sd, Models.CHAR)
		"char_tree": Models.dead_tree(m, loose, r.randf_range(0.9, 1.3), sd, Models.CHAR)
		"pine": Models.pine(m, loose, r.randf_range(0.9, 1.5), sd)
		"snowman": Models.snowman(m, xf, r.randf_range(0.9, 1.2), sd)
		"gift": Models.gift(m, loose, sd)

## Main thread: turns the baked arrays into nodes.
func _attach(c: Chunk) -> void:
	var node := Node3D.new()
	c.node = node
	_attach_part(c)
	if not c.drops.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _coin_mesh
		mm.instance_count = c.drops.size()
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi)
		c.drop_mm = mm
	add_child(node)
	attached += 1
	_spin(c)
	if not c.baked.is_empty():
		_parts.append(c)

## Joins the next baked piece of [c] to its node.
func _attach_part(c: Chunk) -> void:
	var piece: Array = c.baked.pop_front()
	var empty := true
	for surf in piece:
		if not surf.is_empty():
			empty = false
	if empty:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = Mesher.from_arrays(piece)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.node.add_child(mi)

## Spins every sun-drop and hides the taken ones; call once a frame.
func spin(delta: float) -> void:
	poll()
	_coin_angle = fmod(_coin_angle + delta * 3.0, TAU)
	for c in _chunks:
		_spin(c)

func _spin(c: Chunk) -> void:
	if c.drop_mm == null:
		return
	for i in c.drops.size():
		var d: Dictionary = c.drops[i]
		var pos: Vector3 = d.pos
		if d.taken:
			c.drop_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), pos))
		else:
			pos.y += sin(_coin_angle * 2.0 + d.s) * 0.08
			c.drop_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _coin_angle + d.s), pos))
