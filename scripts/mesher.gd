class_name Mesher
extends RefCounted
## Batches low-poly primitives into ONE mesh with per-vertex colours and flat
## (faceted) normals. A whole stretch of temple becomes a single draw call, which
## is what keeps a mid-range phone at a steady frame rate.
##
## Two surfaces: a lit one (stone, leaves, wood) and a glowing one (flames, the
## Sunstone, jaguar eyes) that is unshaded and bright enough to bloom.

var _lit := SurfaceTool.new()
var _glow := SurfaceTool.new()
var _lit_tris := 0
var _glow_tris := 0

static var _lit_material: StandardMaterial3D
static var _glow_material: ShaderMaterial

func _init() -> void:
	_lit.begin(Mesh.PRIMITIVE_TRIANGLES)
	_glow.begin(Mesh.PRIMITIVE_TRIANGLES)

static func lit_material() -> StandardMaterial3D:
	if _lit_material == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.92
		_lit_material = m
	return _lit_material

static func glow_material() -> ShaderMaterial:
	if _glow_material == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded;
uniform float strength = 3.0;
void fragment() {
	// Vertex colours are sRGB; push them past 1.0 so the glow pass picks them up.
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * strength;
}
"""
		_glow_material = ShaderMaterial.new()
		_glow_material.shader = sh
	return _glow_material

# ------------------------------------------------------------ primitives ---

## Axis-aligned box of [size], centred at the transform's origin.
func box(xf: Transform3D, size: Vector3, color: Color, glow := false) -> void:
	var h := size / 2.0
	var c := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var p: Array[Vector3] = []
	for v in c:
		p.append(xf * v)
	var faces := [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]
	var center := xf.origin
	for f in faces:
		_quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]], color, center, glow)

## Faceted frustum: [sides]-gon, base radius [r0] at y=0, top radius [r1] at
## y=[h] (local). r1 = 0 makes a cone; r0 = r1 a prism.
func prism(xf: Transform3D, r0: float, r1: float, h: float, sides: int, color: Color, glow := false, top_color := Color(0, 0, 0, 0)) -> void:
	var top_col := color if top_color.a == 0.0 else top_color
	var center := xf * Vector3(0, h / 2.0, 0)
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i in sides:
		var a := TAU * i / sides
		var d := Vector3(cos(a), 0, sin(a))
		bottom.append(xf * (d * r0))
		top.append(xf * (d * r1 + Vector3(0, h, 0)))
	var bc := xf * Vector3.ZERO
	var tc := xf * Vector3(0, h, 0)
	for i in sides:
		var j := (i + 1) % sides
		if r1 > 0.001:
			_quad(bottom[i], bottom[j], top[j], top[i], color, center, glow)
			_tri(tc, top[i], top[j], top_col, center, glow)
		else:
			_tri(bottom[i], bottom[j], tc, color, center, glow)
		_tri(bc, bottom[j], bottom[i], color, center, glow)

## A low-poly blob (subdivided icosahedron), optionally lumpy for foliage/rock.
func blob(xf: Transform3D, radius: float, color: Color, lumpiness := 0.0, seed := 0, glow := false) -> void:
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
	var pts: Array[Vector3] = []
	for p in v:
		var k := 1.0 + rng.randf_range(-lumpiness, lumpiness)
		pts.append(xf * (p.normalized() * radius * k))
	var center := xf.origin
	for tri in f:
		_tri(pts[tri[0]], pts[tri[1]], pts[tri[2]], color, center, glow)

# --------------------------------------------------------------- output ---

func is_empty() -> bool:
	return _lit_tris == 0 and _glow_tris == 0

## Builds the ArrayMesh (lit surface first, glow second when present).
func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _lit_tris > 0:
		_lit.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, lit_material())
	if _glow_tris > 0:
		_glow.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, glow_material())
	return mesh

func to_instance() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = commit()
	return mi

# ------------------------------------------------------------- internals ---

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, center: Vector3, glow: bool) -> void:
	_tri(a, b, c, color, center, glow)
	_tri(a, c, d, color, center, glow)

## One flat-shaded triangle facing away from [center]. Godot treats CLOCKWISE
## triangles (seen from outside) as front faces, so the winding is fixed here
## from the outward direction — callers never have to think about it.
func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color, center: Vector3, glow: bool) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	var mid := (a + b + c) / 3.0
	if n.dot(mid - center) > 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	var normal := -n.normalized()
	var st := _glow if glow else _lit
	for p in [a, b, c]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(p)
	if glow:
		_glow_tris += 1
	else:
		_lit_tris += 1
