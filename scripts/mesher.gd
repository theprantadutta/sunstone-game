class_name Mesher
extends RefCounted
## Batches low-poly primitives into ONE mesh with per-vertex colours and flat
## (faceted) normals. A whole stretch of the causeway becomes a single draw (plus
## its ink-line pass), which is what keeps a mid-range phone at a steady 60.
##
## Two surfaces: a lit one (stone, leaves, wood — codex-shaded, painted only
## where there is light) and a glowing one (flames, the Sunstone, eyes, drops).
## Both get the scribe's ink outline from [Codex].
##
## Every vertex also stores the direction its outline hull pushes out (in UV
## and UV2). Corners of one primitive share a position and a direction, so the
## hull stays closed. A zero direction means "no outline" (decals, the ground).
##
## A colour with alpha below 1 marks hatched ground (see Codex).

var _lit := SurfaceTool.new()
var _glow := SurfaceTool.new()
var _flat := SurfaceTool.new() ## lit, but no ink line: ground, decals
var _lit_tris := 0
var _glow_tris := 0
var _flat_tris := 0
## Soft toon shading for characters: gentler bands than the scenery's (the
## codex shader reads it from the vertex colour's alpha).
var soft := false

func _init() -> void:
	_lit.begin(Mesh.PRIMITIVE_TRIANGLES)
	_glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	_flat.begin(Mesh.PRIMITIVE_TRIANGLES)

static func lit_material() -> Material:
	return Codex.world()

static func glow_material() -> Material:
	return Codex.glow()

static func flat_material() -> Material:
	return Codex.world_flat()

## Hatched ground colour: the same pigment, flagged for the hatch strokes.
static func hatched(c: Color) -> Color:
	return Color(c, 0.5)

const _BOX_FACES := [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]
const _BOX_CORNERS := [
	Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
	Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1),
]
const _BLOCK_FACES := [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]

# ------------------------------------------------------------ primitives ---

## Axis-aligned box of [size], centred at the transform's origin.
func box(xf: Transform3D, size: Vector3, color: Color, glow := false, outline := true) -> void:
	var h := size / 2.0
	var rot := xf.basis.orthonormalized()
	var p: Array[Vector3] = []
	var d: Array[Vector3] = []
	for c in _BOX_CORNERS:
		p.append(xf * (c * h))
		d.append(rot * c if outline else Vector3.ZERO)
	var center := xf.origin
	for f in _BOX_FACES:
		_quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]], d[f[0]], d[f[1]], d[f[2]], d[f[3]], color, center, glow)

## A six-sided block from eight world corners: bottom four then top four, each
## ring in the same order. For road cells and ribbons that follow a curve.
func block(c: Array, color: Color, glow := false, outline := true) -> void:
	var center := Vector3.ZERO
	for v in c:
		center += v
	center /= 8.0
	var d: Array[Vector3] = []
	for v in c:
		d.append((v - center).normalized() * 1.25 if outline else Vector3.ZERO)
	for f in _BLOCK_FACES:
		_quad(c[f[0]], c[f[1]], c[f[2]], c[f[3]], d[f[0]], d[f[1]], d[f[2]], d[f[3]], color, center, glow)

## Faceted frustum: [sides]-gon, base radius [r0] at y=0, top radius [r1] at
## y=[h] (local). r1 = 0 makes a cone; r0 = r1 a prism.
func prism(xf: Transform3D, r0: float, r1: float, h: float, sides: int, color: Color, glow := false, top_color := Color(0, 0, 0, 0), outline := true) -> void:
	var top_col := color if top_color.a == 0.0 else top_color
	var rot := xf.basis.orthonormalized()
	var center := xf * Vector3(0, h / 2.0, 0)
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	var db: Array[Vector3] = []
	var dt: Array[Vector3] = []
	for i in sides:
		var a := TAU * i / sides
		var dir := Vector3(cos(a), 0, sin(a))
		bottom.append(xf * (dir * r0))
		top.append(xf * (dir * r1 + Vector3(0, h, 0)))
		db.append(rot * (dir + Vector3(0, -0.8, 0)) if outline else Vector3.ZERO)
		dt.append(rot * (dir * (1.0 if r1 > 0.001 else 0.0) + Vector3(0, 0.8, 0)) if outline else Vector3.ZERO)
	var bc := xf * Vector3.ZERO
	var tc := xf * Vector3(0, h, 0)
	var dbc := rot * Vector3(0, -1, 0) if outline else Vector3.ZERO
	var dtc := rot * Vector3(0, 1, 0) if outline else Vector3.ZERO
	for i in sides:
		var j := (i + 1) % sides
		if r1 > 0.001:
			_quad(bottom[i], bottom[j], top[j], top[i], db[i], db[j], dt[j], dt[i], color, center, glow)
			_tri(tc, top[i], top[j], dtc, dt[i], dt[j], top_col, center, glow)
		else:
			_tri(bottom[i], bottom[j], tc, db[i], db[j], dtc, color, center, glow)
		_tri(bc, bottom[j], bottom[i], dbc, db[j], db[i], color, center, glow)

## A low-poly blob (icosahedron), optionally lumpy for foliage/rock.
func blob(xf: Transform3D, radius: float, color: Color, lumpiness := 0.0, seed := 0, glow := false, outline := true) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var f := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rot := xf.basis.orthonormalized()
	var pts: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	for p in v:
		var k := 1.0 + rng.randf_range(-lumpiness, lumpiness)
		pts.append(xf * (p.normalized() * radius * k))
		dirs.append(rot * p.normalized() * 1.2 if outline else Vector3.ZERO)
	var center := xf.origin
	for tri in f:
		_tri(pts[tri[0]], pts[tri[1]], pts[tri[2]], dirs[tri[0]], dirs[tri[1]], dirs[tri[2]], color, center, glow)

## A sculpted surface from rings of points: [rows][i] is a ring (all rings the
## same length), joined to the next ring quad by quad. [closed] wraps each
## ring round. Faces point away from [center]; the ink line pushes out from
## it too. [colors], if given, colours each band between two rings.
func grid(rows: Array, color: Color, center: Vector3, closed := true, outline := true, colors := []) -> void:
	var n: int = rows[0].size()
	var last := n if closed else n - 1
	for i in rows.size() - 1:
		var col: Color = colors[i] if i < colors.size() else color
		for j in last:
			var k := (j + 1) % n
			var a: Vector3 = rows[i][j]
			var b: Vector3 = rows[i][k]
			var c: Vector3 = rows[i + 1][k]
			var d: Vector3 = rows[i + 1][j]
			var z := Vector3.ZERO
			_quad(a, b, c, d,
				(a - center).normalized() * 1.1 if outline else z, (b - center).normalized() * 1.1 if outline else z,
				(c - center).normalized() * 1.1 if outline else z, (d - center).normalized() * 1.1 if outline else z,
				col, center, false)

## Like [grid], but smooth: each vertex's normal averages the quads around it,
## so the codex bands fall in soft toon curves instead of facets. For the
## rounded, cartoon shapes of characters.
func smooth_grid(rows: Array, color: Color, center: Vector3, closed := true, outline := true, glow := false) -> void:
	var nr := rows.size()
	var n: int = rows[0].size()
	var last := n if closed else n - 1
	var normals := []
	for i in nr:
		var ring := []
		ring.resize(n)
		ring.fill(Vector3.ZERO)
		normals.append(ring)
	for i in nr - 1:
		for j in last:
			var k := (j + 1) % n
			var a: Vector3 = rows[i][j]
			var c: Vector3 = rows[i + 1][k]
			var fn: Vector3 = (rows[i][k] - a).cross(rows[i + 1][j] - a) + (c - rows[i][k]).cross(rows[i + 1][j] - rows[i][k])
			if fn.dot((a + c) * 0.5 - center) < 0.0:
				fn = -fn
			for idx in [[i, j], [i, k], [i + 1, k], [i + 1, j]]:
				normals[idx[0]][idx[1]] += fn
	for i in nr - 1:
		for j in last:
			var k := (j + 1) % n
			var q := [[i, j], [i, k], [i + 1, k], [i + 1, j]]
			var p := []
			var nn := []
			var dd := []
			for idx in q:
				var v: Vector3 = rows[idx[0]][idx[1]]
				var nv: Vector3 = normals[idx[0]][idx[1]]
				nv = nv.normalized() if nv.length_squared() > 1e-12 else (v - center).normalized()
				p.append(v)
				nn.append(nv)
				dd.append(nv * 1.1 if outline else Vector3.ZERO)
			_tri_n(p[0], p[1], p[2], dd[0], dd[1], dd[2], nn[0], nn[1], nn[2], color, center, glow)
			_tri_n(p[0], p[2], p[3], dd[0], dd[2], dd[3], nn[0], nn[2], nn[3], color, center, glow)

## A smooth ellipsoid of half-sizes [radii] at [xf].
func ellipsoid(xf: Transform3D, radii: Vector3, color: Color, rings := 8, segs := 12, outline := true, glow := false) -> void:
	var rows := []
	for i in rings + 1:
		var th := PI * i / rings
		var ring := []
		for j in segs:
			var ph := TAU * j / segs
			ring.append(xf * Vector3(sin(th) * cos(ph) * radii.x, cos(th) * radii.y, sin(th) * sin(ph) * radii.z))
		rows.append(ring)
	smooth_grid(rows, color, xf.origin, true, outline, glow)

## A smooth capsule along +Y from 0 to [h]: radius [r0] at the bottom, [r1]
## at the top, rounded ends. Limbs, fingers, hat crowns.
func capsule(xf: Transform3D, r0: float, r1: float, h: float, color: Color, segs := 10, outline := true) -> void:
	var prof := []
	for k in 4:
		var a := -PI / 2.0 + PI / 2.0 * k / 3.0
		prof.append(Vector2(r0 * cos(a), r0 + r0 * sin(a)))
	for k in 4:
		var a := PI / 2.0 * k / 3.0
		prof.append(Vector2(r1 * cos(a), h - r1 + r1 * sin(a)))
	var rows := []
	for pr in prof:
		var ring := []
		for j in segs:
			var ph := TAU * j / segs
			ring.append(xf * Vector3(cos(ph) * pr.x, pr.y, sin(ph) * pr.x))
		rows.append(ring)
	smooth_grid(rows, color, xf * Vector3(0, h / 2.0, 0), true, outline)

## A flat quad painted on a surface (a decal): four corners, no outline.
## Visible from the side its corners wind clockwise toward [up].
func decal(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, glow := false, up := Vector3.UP) -> void:
	var z := Vector3.ZERO
	var center := (a + b + c + d) / 4.0 - up * 0.5
	_quad(a, b, c, d, z, z, z, z, color, center, glow)

# --------------------------------------------------------------- output ---

func is_empty() -> bool:
	return _lit_tris == 0 and _glow_tris == 0 and _flat_tris == 0

func triangles() -> int:
	return _lit_tris + _glow_tris + _flat_tris

## Builds the ArrayMesh: lit, glow and flat surfaces, whichever have triangles.
func commit() -> ArrayMesh:
	return from_arrays(bake())

## The raw surface arrays, without touching the RenderingServer — safe to call
## on a worker thread. Turn them into a mesh on the main thread with [from_arrays].
func bake() -> Array:
	return [
		_lit.commit_to_arrays() if _lit_tris > 0 else [],
		_glow.commit_to_arrays() if _glow_tris > 0 else [],
		_flat.commit_to_arrays() if _flat_tris > 0 else [],
	]

static func from_arrays(baked: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var mats := [lit_material(), glow_material(), flat_material()]
	for i in baked.size():
		if not baked[i].is_empty():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, baked[i])
			mesh.surface_set_material(mesh.get_surface_count() - 1, mats[i])
	return mesh

func to_instance() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# ------------------------------------------------------------- internals ---

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, da: Vector3, db: Vector3, dc: Vector3, dd: Vector3, color: Color, center: Vector3, glow: bool) -> void:
	_tri(a, b, c, da, db, dc, color, center, glow)
	_tri(a, c, d, da, dc, dd, color, center, glow)

## One flat-shaded triangle facing away from [center]. Godot treats CLOCKWISE
## triangles (seen from outside) as front faces, so the winding is fixed here
## from the outward direction — callers never have to think about it.
func _tri(a: Vector3, b: Vector3, c: Vector3, da: Vector3, db: Vector3, dc: Vector3, color: Color, center: Vector3, glow: bool) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	var mid := (a + b + c) / 3.0
	if n.dot(mid - center) > 0.0:
		var tmp := b
		b = c
		c = tmp
		var td := db
		db = dc
		dc = td
		n = -n
	var normal := -n.normalized()
	var st := _lit
	if glow:
		st = _glow
		_glow_tris += 1
	elif da == Vector3.ZERO and db == Vector3.ZERO and dc == Vector3.ZERO:
		st = _flat
		_flat_tris += 1
	else:
		_lit_tris += 1
	_vert(st, a, da, normal, color)
	_vert(st, b, db, normal, color)
	_vert(st, c, dc, normal, color)

## A triangle with its own vertex normals (smooth shading). Winding is fixed
## from [center] like [_tri].
func _tri_n(a: Vector3, b: Vector3, c: Vector3, da: Vector3, db: Vector3, dc: Vector3, na: Vector3, nb: Vector3, nc: Vector3, color: Color, center: Vector3, glow: bool) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	if n.dot((a + b + c) / 3.0 - center) > 0.0:
		var t := b
		b = c
		c = t
		var td := db
		db = dc
		dc = td
		var tn := nb
		nb = nc
		nc = tn
	var st := _lit
	if glow:
		st = _glow
		_glow_tris += 1
	elif da == Vector3.ZERO and db == Vector3.ZERO and dc == Vector3.ZERO:
		st = _flat
		_flat_tris += 1
	else:
		_lit_tris += 1
	_vert(st, a, da, na, color)
	_vert(st, b, db, nb, color)
	_vert(st, c, dc, nc, color)

func _vert(st: SurfaceTool, p: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	st.set_color(Color(color, 0.95) if soft and color.a > 0.99 else color)
	st.set_normal(normal)
	st.set_uv(Vector2(d.x, d.y))
	st.set_uv2(Vector2(d.z, 0.0))
	st.add_vertex(p)
