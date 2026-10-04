class_name Models
## Every 3D asset in the underworld, written into a [Mesher] at a transform.
## No imported models: shapes and pigments are tuned here. The colours are
## codex pigments (stucco, cinnabar, ochre, Maya blue) plus the stuff of each
## House of Xibalba. Codex shading turns them flat and banded, and the ink
## line comes for free from the Mesher.
##
## Convention: a transform's origin sits on the ground the thing stands on,
## +Y up, and the side that matters faces -Z (down the road, toward the
## runner's heading) unless a note says otherwise.

const STUCCO := Color("#EFE3C8")
const STUCCO_SHADE := Color("#DCCBA6")
const STONE := Color("#B9AC94")
const STONE_DARK := Color("#8C7F6C")
const STONE_LIGHT := Color("#D2C5A8")
const CINNABAR := Color("#B8322A")
const OCHRE := Color("#E3A82F")
const MAYA_BLUE := Color("#3FA7B5")
const JADE := Color("#3E8A6A")
const INKY := Color("#2A201A")
const LEAF := Color("#4C7A4F")
const LEAF_DARK := Color("#2E5236")
const LEAF_LIGHT := Color("#78A35A")
const BARK := Color("#6B4A33")
const MOSS := Color("#6F8A3E")
const BONE := Color("#E8DCC0")
const OBSIDIAN := Color("#221B2E")
const OBSIDIAN_SHINE := Color("#8FA7D8")
const ICE := Color("#C4E8EF")
const ICE_DEEP := Color("#78BBCB")
const SNOW := Color("#F2F4F0")
const AMETHYST := Color("#9A66B0")
const CAVE := Color("#5A4A63")
const CAVE_DARK := Color("#3E3346")
const DEAD_WOOD := Color("#857868")
const CHAR := Color("#3A2E2A")
const BASALT := Color("#45403F")
const LAVA := Color("#FF7A2A")
const EMBER := Color("#FFC45A")
const FLAME := Color("#FF9A3A")
const FLAME_CORE := Color("#FFE7A0")
const PIT := Color("#140C0A")
const GOLD := Color("#F4B732")

static func at(origin: Vector3, basis := Basis()) -> Transform3D:
	return Transform3D(basis, origin)

## A transform at local position [p] inside the frame [xf].
static func sub(xf: Transform3D, p: Vector3, basis := Basis()) -> Transform3D:
	return xf * Transform3D(basis, p)

static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r

# ============================================================ the road ===

## A flat glyph painted on a road stone: the k'in sun as four petals round a
## dot. [c] is the centre on the surface, [r] the radius, [right]/[fwd] the
## stone's axes.
static func kin_decal(m: Mesher, c: Vector3, r: float, right: Vector3, fwd: Vector3, col: Color) -> void:
	var up := Vector3(0, 0.012, 0)
	for k in 4:
		var a := PI / 4.0 + k * PI / 2.0
		var d := (right * cos(a) + fwd * sin(a))
		var n := (right * -sin(a) + fwd * cos(a))
		var p := c + d * r * 0.55 + up
		m.decal(p - d * r * 0.42, p + n * r * 0.25, p + d * r * 0.42, p - n * r * 0.25, col)
	var q := r * 0.18
	m.decal(c + up - right * q, c + up + fwd * q, c + up + right * q, c + up - fwd * q, col)
	# The cartouche ring round it.
	for k in 12:
		var a0 := TAU * k / 12.0
		var a1 := TAU * (k + 1) / 12.0
		var d0 := right * cos(a0) + fwd * sin(a0)
		var d1 := right * cos(a1) + fwd * sin(a1)
		m.decal(c + up + d0 * r * 1.05, c + up + d1 * r * 1.05, c + up + d1 * r * 1.22, c + up + d0 * r * 1.22, col)

## A mark on a road stone, by House: [kind] is the House's "mark". [c] is the
## stone's centre on its top face, [right]/[fwd] its axes, [r] about half its
## size, [rng] for variety.
static func road_mark(m: Mesher, kind: String, c: Vector3, r: float, right: Vector3, fwd: Vector3, rng: RandomNumberGenerator) -> void:
	var up := Vector3(0, 0.012, 0)
	c += up
	match kind:
		"rosette":
			# Jaguar rosettes: broken rings of ink with a dot inside.
			for i in rng.randi_range(2, 4):
				var o := right * rng.randf_range(-0.6, 0.6) * r + fwd * rng.randf_range(-0.6, 0.6) * r
				var rr := rng.randf_range(0.18, 0.26) * r
				for k in 5:
					var a0 := TAU * k / 6.0 + rng.randf()
					var a1 := a0 + TAU / 9.0
					var d0 := right * cos(a0) + fwd * sin(a0)
					var d1 := right * cos(a1) + fwd * sin(a1)
					m.decal(c + o + d0 * rr, c + o + d1 * rr, c + o + d1 * rr * 1.35, c + o + d0 * rr * 1.35, INKY)
				m.decal(c + o - right * rr * 0.25, c + o + fwd * rr * 0.25, c + o + right * rr * 0.25, c + o - fwd * rr * 0.25, Color("#7A4A22"))
		"crack", "lava":
			# A zig-zag crack across the stone; in the House of Fire it glows.
			var col := LAVA if kind == "lava" else INKY
			var p := c - right * r * 0.8 + fwd * rng.randf_range(-0.5, 0.5) * r
			var w := 0.035 if kind == "crack" else 0.06
			for k in 4:
				var q := p + right * r * 0.4 + fwd * rng.randf_range(-0.35, 0.35) * r
				var n := (q - p).cross(Vector3.UP).normalized() * w
				m.decal(p - n, q - n, q + n, p + n, col, kind == "lava")
				p = q
		"frost":
			# Frost: pale feathered patches.
			for i in rng.randi_range(2, 4):
				var o := right * rng.randf_range(-0.5, 0.5) * r + fwd * rng.randf_range(-0.5, 0.5) * r
				var rr := rng.randf_range(0.2, 0.45) * r
				var a := rng.randf() * TAU
				var d := right * cos(a) + fwd * sin(a)
				var n := right * -sin(a) + fwd * cos(a)
				m.decal(c + o - d * rr, c + o + n * rr * 0.5, c + o + d * rr, c + o - n * rr * 0.5, SNOW)
		"shard", "obsidian":
			# Chips scattered on the stone: crystal or obsidian.
			var col := AMETHYST if kind == "shard" else OBSIDIAN
			for i in rng.randi_range(2, 4):
				var o := right * rng.randf_range(-0.6, 0.6) * r + fwd * rng.randf_range(-0.6, 0.6) * r
				var a := rng.randf() * TAU
				var d := right * cos(a) + fwd * sin(a)
				var n := right * -sin(a) + fwd * cos(a)
				var rr := rng.randf_range(0.1, 0.2) * r
				m.decal(c + o - d * rr, c + o + n * rr * 0.4, c + o + d * rr * 1.4, c + o - n * rr * 0.4, col)
		_:
			kin_decal(m, c - up, r * 0.55, right, fwd, CINNABAR)

## A glyph block carved into a stone face: a square cartouche with a few dots
## and a bar, as raised thin slabs (no ink line — the carving IS ink).
static func carve(m: Mesher, xf: Transform3D, w: float, h: float, seed: int, col := INKY) -> void:
	# Local frame: the face is the XY plane at z = 0, outward is -Z, and the
	# cartouche hangs from y = 0 down to y = -h.
	var r := _rng(seed)
	m.box(sub(xf, Vector3(0, -h * 0.04, -0.01)), Vector3(w, h * 0.08, 0.02), col, false, false)
	m.box(sub(xf, Vector3(0, -h * 0.96, -0.01)), Vector3(w, h * 0.08, 0.02), col, false, false)
	m.box(sub(xf, Vector3(-w * 0.46, -h * 0.5, -0.01)), Vector3(w * 0.08, h, 0.02), col, false, false)
	m.box(sub(xf, Vector3(w * 0.46, -h * 0.5, -0.01)), Vector3(w * 0.08, h, 0.02), col, false, false)
	for i in r.randi_range(2, 4):
		m.box(sub(xf, Vector3(r.randf_range(-0.25, 0.25) * w, -r.randf_range(0.25, 0.65) * h, -0.012)), Vector3(w * 0.16, w * 0.16, 0.02), col, false, false)
	if r.randf() < 0.6:
		m.box(sub(xf, Vector3(0, -h * 0.8, -0.012)), Vector3(w * 0.6, h * 0.09, 0.02), CINNABAR, false, false)

# ============================================================== jungle ===

## A ceiba, the Maya world tree: a straight trunk, flared roots and canopy in
## flat layered tiers, like the trees painted in the codices.
static func ceiba(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	var r := _rng(seed)
	var h := 4.2 * s
	m.prism(xf, 0.36 * s, 0.22 * s, h, 6, BARK)
	for i in 3:
		var a := TAU * i / 3.0 + r.randf()
		m.box(sub(xf, Vector3(sin(a) * 0.38 * s, 0.32 * s, cos(a) * 0.38 * s), Basis(Vector3.UP, a)), Vector3(0.16 * s, 0.64 * s, 0.7 * s), BARK.darkened(0.15))
	var cols := [LEAF, LEAF_DARK, LEAF_LIGHT]
	var tiers := [[0.0, 2.3], [0.7, 1.75], [1.3, 1.15]]
	for i in 3:
		var t: Array = tiers[i]
		var o := Vector3(r.randf_range(-0.3, 0.3), h + t[0] * s, r.randf_range(-0.3, 0.3))
		m.blob(sub(xf, o, Basis().scaled(Vector3(1.0, 0.42, 1.0))), t[1] * s, cols[(seed + i) % 3], 0.18, seed + i)

static func bush(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	var col: Color = [LEAF, LEAF_DARK, LEAF_LIGHT][seed % 3]
	m.blob(sub(xf, Vector3(0, 0.35 * s, 0), Basis().scaled(Vector3(1.3, 0.75, 1.1))), 0.7 * s, col, 0.3, seed)
	m.blob(sub(xf, Vector3(0.5 * s, 0.3 * s, 0.3 * s)), 0.45 * s, LEAF_DARK, 0.3, seed + 3)

static func fern(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	for i in 7:
		var a := TAU * i / 7.0 + seed
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.75)
		m.box(xf * Transform3D(b.scaled(Vector3(s, s, s)), Vector3(sin(a) * 0.35 * s, 0.3 * s, cos(a) * 0.35 * s)),
			Vector3(0.22, 0.05, 1.15), LEAF_LIGHT if i % 2 == 0 else LEAF)

## Maize, the plant the first people were made from: stalks with long leaves
## and a gold ear.
static func maize(m: Mesher, xf: Transform3D, seed: int) -> void:
	var r := _rng(seed)
	for i in r.randi_range(3, 5):
		var p := Vector3(r.randf_range(-0.6, 0.6), 0, r.randf_range(-0.6, 0.6))
		var h := r.randf_range(1.3, 1.9)
		m.prism(sub(xf, p), 0.05, 0.03, h, 4, LEAF)
		for k in 3:
			var a := r.randf() * TAU
			m.box(sub(xf, p + Vector3(sin(a) * 0.25, h * (0.35 + k * 0.2), cos(a) * 0.25), Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.9)), Vector3(0.1, 0.03, 0.6), LEAF_LIGHT)
		m.prism(sub(xf, p + Vector3(0.06, h * 0.6, 0)), 0.07, 0.04, 0.3, 5, GOLD)

## A tuft of grass: a few narrow blades leaning out.
static func grass(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	var r := _rng(seed)
	for i in r.randi_range(4, 7):
		var a := r.randf() * TAU
		var lean := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, r.randf_range(0.2, 0.6))
		m.prism(sub(xf, Vector3(cos(a) * 0.15 * s, 0, sin(a) * 0.15 * s), lean), 0.06 * s, 0.0, r.randf_range(0.4, 0.8) * s, 3, LEAF_LIGHT if i % 2 == 0 else MOSS)

## Vines spilling down the outer face of the causeway wall. [xf] sits at the
## top of the wall, -Z pointing out from it.
static func vines(m: Mesher, xf: Transform3D, seed: int, col := LEAF) -> void:
	var r := _rng(seed)
	for i in r.randi_range(3, 6):
		var x := r.randf_range(-0.8, 0.8)
		var drop := r.randf_range(0.6, 2.0)
		var c: Color = [col, LEAF_LIGHT, LEAF_DARK][i % 3]
		m.box(sub(xf, Vector3(x, -drop / 2.0, -0.05)), Vector3(0.06, drop, 0.06), c)
		m.blob(sub(xf, Vector3(x, -drop, -0.08), Basis().scaled(Vector3(1.0, 0.8, 0.6))), 0.14, c, 0.3, seed + i)
	m.blob(sub(xf, Vector3(0, 0.05, 0.0), Basis().scaled(Vector3(1.8, 0.5, 0.8))), 0.45, col, 0.3, seed)

static func rock(m: Mesher, xf: Transform3D, s: float, seed: int, col := STONE_DARK) -> void:
	m.blob(sub(xf, Vector3(0, 0.25 * s, 0), Basis().scaled(Vector3(1.3, 0.7, 1.0))), 0.5 * s, col, 0.3, seed)

## A carved standing stela with glyph blocks on the face toward the road.
static func stela(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	m.box(sub(xf, Vector3(0, 0.15, 0)), Vector3(1.2 * s, 0.3, 0.7 * s), STONE_DARK)
	m.box(sub(xf, Vector3(0, 0.3 + 1.2 * s, 0)), Vector3(0.9 * s, 2.4 * s, 0.35 * s), STONE)
	m.prism(sub(xf, Vector3(0, 0.3 + 2.4 * s, 0)), 0.45 * s, 0.3 * s, 0.25 * s, 6, STONE_LIGHT)
	for row in 3:
		for col in 2:
			carve(m, sub(xf, Vector3((col - 0.5) * 0.4 * s, 0.3 + (2.2 - row * 0.65) * s, -0.18 * s)), 0.32 * s, 0.5 * s, seed + row * 2 + col)

## A round altar drum with a carved band and a glowing offering bowl.
static func altar(m: Mesher, xf: Transform3D, seed: int) -> void:
	m.prism(xf, 0.75, 0.72, 0.55, 10, STONE)
	m.prism(sub(xf, Vector3(0, 0.22, 0)), 0.77, 0.77, 0.12, 10, CINNABAR, false, Color(0, 0, 0, 0), false)
	m.prism(sub(xf, Vector3(0, 0.55, 0)), 0.3, 0.38, 0.14, 8, STONE_DARK)
	m.blob(sub(xf, Vector3(0, 0.68, 0), Basis().scaled(Vector3(1.0, 0.5, 1.0))), 0.2, EMBER, 0.2, seed, true)

## A skull rack (tzompantli): two posts, two poles, a row of skulls on each.
static func skull_rack(m: Mesher, xf: Transform3D, seed: int) -> void:
	var r := _rng(seed)
	for x in [-1.0, 1.0]:
		m.box(sub(xf, Vector3(x, 0.8, 0)), Vector3(0.14, 1.6, 0.14), BARK)
	for y in [0.7, 1.3]:
		m.box(sub(xf, Vector3(0, y, 0)), Vector3(2.2, 0.08, 0.08), CINNABAR)
		for k in 5:
			var p := Vector3(-0.8 + k * 0.4, y + 0.02, 0)
			skull(m, sub(xf, p, Basis(Vector3.UP, r.randf_range(-0.3, 0.3))), 0.15)

static func skull(m: Mesher, xf: Transform3D, s: float) -> void:
	m.blob(sub(xf, Vector3(0, 0.0, 0)), s, BONE, 0.08, 3)
	m.box(sub(xf, Vector3(0, -s * 0.75, -s * 0.15)), Vector3(s * 1.1, s * 0.5, s * 1.0), BONE)
	for x in [-0.4, 0.4]:
		m.box(sub(xf, Vector3(x * s, 0.0, -s * 0.95)), Vector3(s * 0.4, s * 0.38, 0.02), INKY, false, false)

## A small temple: a stepped platform, a stair facing the road, a shrine on
## top with a roof comb, all painted.
static func temple(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	var r := _rng(seed)
	var tiers := r.randi_range(3, 4)
	var w := 5.5 * s
	for i in tiers:
		var tw := w - i * 1.2 * s
		var y := i * 0.9 * s
		m.box(sub(xf, Vector3(0, y + 0.45 * s, 0)), Vector3(tw, 0.9 * s, tw), STONE if i % 2 == 0 else STONE_LIGHT)
		m.box(sub(xf, Vector3(0, y + 0.72 * s, -tw / 2.0 - 0.01)), Vector3(tw - 0.2, 0.14 * s, 0.03), CINNABAR if i % 2 == 0 else MAYA_BLUE, false, false)
	var top := tiers * 0.9 * s
	# The stair down the road-facing side.
	for k in tiers * 3:
		var y := k * 0.3 * s
		m.box(sub(xf, Vector3(0, y + 0.15 * s, -w / 2.0 - 0.15 * s + y * 0.66)), Vector3(1.4 * s, 0.3 * s, 0.4 * s), STONE_LIGHT)
	var sw := w - tiers * 1.2 * s
	m.box(sub(xf, Vector3(0, top + 0.8 * s, 0)), Vector3(sw * 0.9, 1.6 * s, sw * 0.8), STUCCO)
	m.box(sub(xf, Vector3(0, top + 0.6 * s, -sw * 0.4 - 0.02)), Vector3(0.7 * s, 1.1 * s, 0.04), PIT, false, false)
	m.box(sub(xf, Vector3(0, top + 1.75 * s, 0)), Vector3(sw, 0.3 * s, sw * 0.9), CINNABAR)
	m.box(sub(xf, Vector3(0, top + 2.4 * s, 0.1 * s)), Vector3(sw * 0.6, 1.0 * s, 0.3 * s), STONE_LIGHT) # roof comb
	m.box(sub(xf, Vector3(0, top + 2.4 * s, -0.06 * s)), Vector3(sw * 0.5, 0.2 * s, 0.03), MAYA_BLUE, false, false)

## A big distant stepped pyramid — a silhouette at the edge of sight.
static func pyramid(m: Mesher, xf: Transform3D, s: float) -> void:
	for i in 6:
		var w := (16.0 - i * 2.4) * s
		m.box(sub(xf, Vector3(0, (i * 2.0 + 1.0) * s, 0)), Vector3(w, 2.0 * s, w), STONE_DARK if i % 2 == 0 else STONE)
	m.box(sub(xf, Vector3(0, 13.2 * s, 0)), Vector3(3.0 * s, 2.4 * s, 3.0 * s), CINNABAR)
	for k in 12:
		m.box(sub(xf, Vector3(0, k * 1.0 * s + 0.5 * s, -8.0 * s + k * 0.55 * s)), Vector3(2.4 * s, 1.0 * s, 0.6 * s), STONE_LIGHT)

## A banner on a pole: painted cloth with a glyph.
static func banner(m: Mesher, xf: Transform3D, col: Color, seed: int) -> void:
	m.prism(xf, 0.06, 0.05, 3.0, 5, BARK)
	m.box(sub(xf, Vector3(0.0, 2.35, 0)), Vector3(0.9, 0.06, 0.06), BARK)
	m.box(sub(xf, Vector3(0.0, 1.85, 0)), Vector3(0.8, 1.0, 0.04), col)
	m.box(sub(xf, Vector3(0.0, 1.27, 0)), Vector3(0.8, 0.16, 0.04), STUCCO)
	carve(m, sub(xf, Vector3(0, 2.15, -0.03)), 0.42, 0.55, seed, STUCCO if col.get_luminance() < 0.5 else INKY)

## The feathered serpent's head, jaws open, at the foot of a wall or stair.
static func serpent_head(m: Mesher, xf: Transform3D) -> void:
	m.box(sub(xf, Vector3(0, 0.45, 0)), Vector3(0.8, 0.6, 1.0), STONE)
	m.box(sub(xf, Vector3(0, 0.15, -0.15)), Vector3(0.75, 0.25, 0.9), STONE_DARK) # jaw
	m.box(sub(xf, Vector3(0, 0.78, 0.15)), Vector3(0.9, 0.14, 0.7), JADE) # brow plumes
	for x in [-0.28, 0.28]:
		m.box(sub(xf, Vector3(x, 0.55, -0.51)), Vector3(0.16, 0.12, 0.02), OCHRE, false, false)
		m.prism(sub(xf, Vector3(x * 0.8, 0.28, -0.42), Basis(Vector3.RIGHT, PI)), 0.05, 0.0, 0.14, 4, BONE)
	for k in 4:
		m.box(sub(xf, Vector3(-0.45 + k * 0.3, 0.95, 0.35), Basis(Vector3.RIGHT, -0.5)), Vector3(0.14, 0.04, 0.6), [JADE, MAYA_BLUE, CINNABAR, JADE][k])

## A clay incense burner with a face, a coal glowing in its mouth.
static func urn(m: Mesher, xf: Transform3D, seed: int) -> void:
	m.prism(xf, 0.28, 0.36, 0.5, 8, Color("#B06A3F"))
	m.prism(sub(xf, Vector3(0, 0.5, 0)), 0.36, 0.3, 0.2, 8, Color("#8E5232"))
	m.box(sub(xf, Vector3(0, 0.3, -0.33)), Vector3(0.3, 0.2, 0.03), INKY, false, false)
	m.blob(sub(xf, Vector3(0, 0.72, 0), Basis().scaled(Vector3(1.0, 0.6, 1.0))), 0.16, EMBER, 0.2, seed, true)

## A brazier stand: a stone bowl on a short pillar with a live flame.
static func brazier(m: Mesher, xf: Transform3D, seed: int) -> void:
	m.prism(xf, 0.22, 0.18, 0.55, 6, STONE_DARK)
	m.prism(sub(xf, Vector3(0, 0.55, 0)), 0.2, 0.42, 0.22, 8, STONE)
	m.prism(sub(xf, Vector3(0, 0.77, 0)), 0.42, 0.42, 0.06, 8, CINNABAR, false, Color(0, 0, 0, 0), false)
	flame(m, sub(xf, Vector3(0, 0.78, 0)), 1.0, seed)

static func flame(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	var r := _rng(seed)
	var fire := Themes.flame()
	m.prism(xf, 0.26 * s, 0.0, 0.85 * s, 5, fire[0], true)
	m.prism(sub(xf, Vector3(0.08 * s, 0, 0.04 * s), Basis(Vector3.UP, r.randf())), 0.15 * s, 0.0, 0.6 * s, 5, fire[1], true)
	m.prism(sub(xf, Vector3(-0.1 * s, 0, -0.05 * s)), 0.12 * s, 0.0, 0.5 * s, 4, LAVA, true)

## A seated stone jaguar on its plinth, jade eyes, painted rosettes.
static func jaguar_statue(m: Mesher, xf: Transform3D, s: float) -> void:
	m.box(sub(xf, Vector3(0, 0.3 * s, 0)), Vector3(1.0 * s, 0.6 * s, 1.4 * s), STONE_DARK)
	m.box(sub(xf, Vector3(0, 0.62 * s, -0.71 * s)), Vector3(0.9 * s, 0.1 * s, 0.03), CINNABAR, false, false)
	var body := Color("#C9A25A")
	m.box(sub(xf, Vector3(0, 1.0 * s, 0.2 * s)), Vector3(0.6 * s, 0.7 * s, 0.9 * s), body) # haunches
	m.box(sub(xf, Vector3(0, 1.35 * s, -0.2 * s), Basis(Vector3.RIGHT, -0.3)), Vector3(0.55 * s, 0.9 * s, 0.5 * s), body) # chest
	for x in [-0.18, 0.18]:
		m.box(sub(xf, Vector3(x * s, 0.95 * s, -0.42 * s)), Vector3(0.14 * s, 0.7 * s, 0.16 * s), body) # forelegs
	m.box(sub(xf, Vector3(0, 1.95 * s, -0.38 * s)), Vector3(0.55 * s, 0.45 * s, 0.5 * s), body) # head
	m.box(sub(xf, Vector3(0, 1.85 * s, -0.68 * s)), Vector3(0.32 * s, 0.22 * s, 0.2 * s), body.darkened(0.15)) # muzzle
	for x in [-0.17, 0.17]:
		m.prism(sub(xf, Vector3(x * s, 2.15 * s, -0.3 * s)), 0.08 * s, 0.0, 0.18 * s, 4, body.darkened(0.2)) # ears
		m.box(sub(xf, Vector3(x * s, 2.0 * s, -0.64 * s)), Vector3(0.12 * s, 0.07 * s, 0.02), JADE, false, false)
	var spots := [Vector3(0.31, 1.1, 0.1), Vector3(0.31, 0.9, 0.4), Vector3(-0.31, 1.05, 0.25), Vector3(-0.31, 0.85, -0.05), Vector3(0.28, 1.45, -0.2), Vector3(-0.28, 1.4, -0.25)]
	for p in spots:
		m.box(sub(xf, p * s), Vector3(0.02, 0.12 * s, 0.12 * s), INKY, false, false)
	m.box(sub(xf, Vector3(0.25 * s, 0.75 * s, 0.7 * s), Basis(Vector3.UP, 0.6)), Vector3(0.1 * s, 0.1 * s, 0.6 * s), body) # tail

# ================================================================= bats ===

static func stalagmite(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	var r := _rng(seed)
	for i in r.randi_range(2, 4):
		var p := Vector3(r.randf_range(-0.6, 0.6) * s, 0, r.randf_range(-0.6, 0.6) * s)
		var h := r.randf_range(1.2, 3.2) * s * (1.0 if i == 0 else 0.6)
		m.prism(sub(xf, p), r.randf_range(0.3, 0.5) * s, 0.0, h, 6, CAVE if i % 2 == 0 else CAVE_DARK)
		m.prism(sub(xf, p + Vector3(0, h * 0.35, 0)), 0.24 * s, 0.24 * s, 0.08, 6, CAVE.lightened(0.15), false, Color(0, 0, 0, 0), false)

static func crystals(m: Mesher, xf: Transform3D, s: float, seed: int, col := AMETHYST) -> void:
	var r := _rng(seed)
	for i in r.randi_range(3, 6):
		var lean := Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(0.0, 0.55))
		var h := r.randf_range(0.5, 1.5) * s
		var rad := r.randf_range(0.1, 0.2) * s
		var base := sub(xf, Vector3(r.randf_range(-0.3, 0.3) * s, 0, r.randf_range(-0.3, 0.3) * s), lean)
		m.prism(base, rad, rad, h, 5, col)
		m.prism(sub(base, Vector3(0, h, 0)), rad, 0.0, rad * 2.0, 5, col.lightened(0.3))

static func cave_rock(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	m.blob(sub(xf, Vector3(0, 0.9 * s, 0), Basis().scaled(Vector3(1.4, 1.0, 1.1))), 1.4 * s, CAVE_DARK, 0.3, seed)
	m.blob(sub(xf, Vector3(0.9 * s, 0.5 * s, 0.4 * s)), 0.9 * s, CAVE, 0.3, seed + 1)

## A dead tree; with [roost], bats hang from the branches.
static func dead_tree(m: Mesher, xf: Transform3D, s: float, seed: int, wood := DEAD_WOOD, roost := false) -> void:
	var r := _rng(seed)
	var h := r.randf_range(2.6, 3.6) * s
	m.prism(xf, 0.22 * s, 0.12 * s, h, 5, wood)
	for i in r.randi_range(3, 5):
		var y := h * r.randf_range(0.45, 0.95)
		var a := r.randf() * TAU
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, r.randf_range(0.7, 1.2))
		var len := r.randf_range(0.8, 1.6) * s
		var bx := sub(xf, Vector3(0, y, 0), b)
		m.prism(bx, 0.08 * s, 0.03 * s, len, 4, wood)
		if roost and r.randf() < 0.7:
			var tip := bx * Vector3(0, len * 0.8, 0)
			bat_hanging(m, at(tip + Vector3(0, -0.22, 0), Basis(Vector3.UP, a)))

static func bat_hanging(m: Mesher, xf: Transform3D) -> void:
	m.box(sub(xf, Vector3(0, 0, 0)), Vector3(0.14, 0.3, 0.12), Color("#2A1E33"))
	m.box(sub(xf, Vector3(0, -0.02, 0)), Vector3(0.32, 0.22, 0.04), Color("#3A2847"))

static func bones(m: Mesher, xf: Transform3D, seed: int) -> void:
	var r := _rng(seed)
	for i in r.randi_range(3, 6):
		m.box(sub(xf, Vector3(r.randf_range(-0.5, 0.5), 0.05, r.randf_range(-0.5, 0.5)), Basis(Vector3.UP, r.randf() * TAU)), Vector3(0.08, 0.08, r.randf_range(0.4, 0.7)), BONE)
	skull(m, sub(xf, Vector3(0.1, 0.16, 0), Basis(Vector3.UP, r.randf_range(-1.0, 1.0))), 0.17)

# ================================================================ gloom ===

static func standing_stone(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	var r := _rng(seed)
	var lean := Basis(Vector3.FORWARD, r.randf_range(-0.12, 0.12))
	m.box(sub(xf, Vector3(0, 1.1 * s, 0), lean), Vector3(0.7 * s, 2.2 * s, 0.5 * s), Color("#8C8A92"))
	m.box(sub(xf, Vector3(0, 2.25 * s, 0), lean), Vector3(0.55 * s, 0.15 * s, 0.4 * s), Color("#A4A2AA"))

static func broken_pillar(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	var r := _rng(seed)
	var h := r.randf_range(0.8, 2.2) * s
	m.box(sub(xf, Vector3(0, 0.15, 0)), Vector3(1.0 * s, 0.3, 1.0 * s), STONE_DARK)
	m.prism(sub(xf, Vector3(0, 0.3, 0)), 0.38 * s, 0.34 * s, h, 6, STONE)
	m.prism(sub(xf, Vector3(0, 0.55, 0)), 0.4 * s, 0.4 * s, 0.18, 6, CINNABAR.darkened(0.25), false, Color(0, 0, 0, 0), false)
	m.blob(sub(xf, Vector3(0.9 * s, 0.25 * s, 0.3 * s), Basis().scaled(Vector3(1.0, 0.6, 1.0))), 0.35 * s, STONE, 0.3, seed)

static func mist_shrub(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	m.blob(sub(xf, Vector3(0, 0.4 * s, 0), Basis().scaled(Vector3(1.4, 0.6, 1.2))), 0.7 * s, Color("#7E8A84"), 0.35, seed)
	m.blob(sub(xf, Vector3(0.5 * s, 0.3 * s, -0.3 * s)), 0.4 * s, Color("#646E6A"), 0.3, seed + 1)

# =============================================================== knives ===

## A cluster of obsidian blades bursting from the ground.
static func obsidian(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	var r := _rng(seed)
	for i in r.randi_range(4, 6):
		var lean := Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(0.1, 0.6))
		var h := r.randf_range(0.7, 1.6) * s
		var base := sub(xf, Vector3(r.randf_range(-0.35, 0.35) * s, 0, r.randf_range(-0.35, 0.35) * s), lean)
		m.prism(base, r.randf_range(0.12, 0.2) * s, 0.0, h, 3, OBSIDIAN if i % 2 == 0 else OBSIDIAN.lightened(0.12))
		m.box(sub(base, Vector3(0.05 * s, h * 0.35, 0)), Vector3(0.02, h * 0.5, 0.02), OBSIDIAN_SHINE, false, false)

static func red_spire(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	var r := _rng(seed)
	var col := Color("#8E4434")
	m.prism(xf, 0.6 * s, 0.25 * s, r.randf_range(1.8, 3.2) * s, 5, col)
	m.prism(sub(xf, Vector3(0.6 * s, 0, 0.2 * s)), 0.35 * s, 0.1 * s, r.randf_range(0.9, 1.6) * s, 5, col.darkened(0.2))

# ================================================================= cold ===

static func ice_spikes(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	crystals(m, xf, s * 1.4, seed, ICE)
	m.blob(sub(xf, Vector3(0, 0.05, 0), Basis().scaled(Vector3(1.6, 0.35, 1.4))), 0.6 * s, SNOW, 0.25, seed + 9)

static func snow_mound(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	m.blob(sub(xf, Vector3(0, 0.1, 0), Basis().scaled(Vector3(1.6, 0.45, 1.3))), 0.8 * s, SNOW, 0.25, seed)
	m.blob(sub(xf, Vector3(0.6 * s, 0.1, 0.3 * s), Basis().scaled(Vector3(1.2, 0.5, 1.0))), 0.45 * s, ICE, 0.25, seed + 1)

static func frozen_stela(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	stela(m, xf, s, seed)
	m.box(sub(xf, Vector3(0, 0.3 + 2.45 * s, 0)), Vector3(1.0 * s, 0.18, 0.5 * s), SNOW)
	m.blob(sub(xf, Vector3(0.5 * s, 0.2, 0)), 0.4 * s, SNOW, 0.2, seed)

# ================================================================= fire ===

## A pool of lava on the ground: glowing, with a dark crust around it.
static func lava_pool(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	var r := _rng(seed)
	var n := 9
	var pts: Array[Vector3] = []
	for i in n:
		var a := TAU * i / n
		var rad := r.randf_range(0.8, 1.3) * s
		pts.append(xf * Vector3(cos(a) * rad, 0.04, sin(a) * rad * 0.8))
	var c := xf * Vector3(0, 0.04, 0)
	for i in n:
		var j := (i + 1) % n
		m.decal(c, pts[i], pts[j], c, LAVA, true)
	for i in n:
		var p := pts[i]
		m.blob(at(p, Basis().scaled(Vector3(1.0, 0.45, 1.0))), r.randf_range(0.2, 0.32) * s, CHAR, 0.3, seed + i)

static func basalt(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	var r := _rng(seed)
	for i in r.randi_range(3, 6):
		var p := Vector3(r.randf_range(-0.6, 0.6) * s, 0, r.randf_range(-0.6, 0.6) * s)
		var h := r.randf_range(0.6, 2.4) * s
		m.prism(sub(xf, p), 0.3 * s, 0.3 * s, h, 6, BASALT, false, Color("#6A6060"))

static func fire_pit(m: Mesher, xf: Transform3D, seed: int) -> void:
	for i in 8:
		var a := TAU * i / 8.0
		m.blob(sub(xf, Vector3(cos(a) * 0.6, 0.1, sin(a) * 0.6)), 0.2, STONE_DARK, 0.3, seed + i)
	m.blob(sub(xf, Vector3(0, 0.05, 0), Basis().scaled(Vector3(1.0, 0.4, 1.0))), 0.45, EMBER, 0.3, seed, true)
	flame(m, sub(xf, Vector3(0, 0.1, 0)), 1.2, seed)

# ============================================================ road dangers ===

## A carved stela fallen across the road — run round it. Lies along local X.
static func fallen_stela(m: Mesher, xf: Transform3D, seed: int) -> void:
	m.box(sub(xf, Vector3(0, 0.3, 0)), Vector3(2.0, 0.6, 0.85), STONE)
	m.box(sub(xf, Vector3(0.94, 0.3, 0)), Vector3(0.14, 0.62, 0.87), CINNABAR)
	for i in 3:
		var x := -0.65 + i * 0.55
		carve(m, sub(xf, Vector3(x, 0.61, 0.28), Basis(Vector3.RIGHT, PI / 2.0)), 0.42, 0.6, seed + i)
	m.blob(sub(xf, Vector3(-1.05, 0.15, 0.3)), 0.25, STONE_DARK, 0.3, seed)

## Obsidian blades standing in the road.
static func blades(m: Mesher, xf: Transform3D, seed: int) -> void:
	obsidian(m, xf, 0.9, seed)

## A pylon that marks the way into a House: a tall painted pier with the
## House's glyph toward the road and a fire on top. [face] points at the road.
static func gate_pylon(m: Mesher, xf: Transform3D, accent: Color, seed: int) -> void:
	m.box(sub(xf, Vector3(0, 0.5, 0)), Vector3(1.5, 1.0, 1.5), STONE_DARK)
	m.box(sub(xf, Vector3(0, 2.6, 0)), Vector3(1.15, 3.2, 1.15), STONE)
	m.box(sub(xf, Vector3(0, 2.2, -0.59)), Vector3(1.0, 0.14, 0.02), accent, false, false)
	m.box(sub(xf, Vector3(0, 3.95, -0.59)), Vector3(1.0, 0.14, 0.02), accent, false, false)
	carve(m, sub(xf, Vector3(0, 3.75, -0.6)), 0.8, 1.3, seed)
	m.box(sub(xf, Vector3(0, 4.3, 0)), Vector3(1.45, 0.25, 1.45), accent)
	m.prism(sub(xf, Vector3(0, 4.42, 0)), 0.5, 0.6, 0.2, 8, STONE_DARK)
	flame(m, sub(xf, Vector3(0, 4.6, 0)), 1.5, seed)

## The temple the run leaves from: a painted pyramid behind the plaza, its dark
## doorway where the Sunstone was taken. Faces -Z.
static func start_temple(m: Mesher, xf: Transform3D) -> void:
	for i in 6:
		var w := 20.0 - i * 3.0
		var y := i * 1.5
		m.box(sub(xf, Vector3(0, y + 0.75, 7.0 + i * 0.5)), Vector3(w, 1.5, 12.0 - i * 1.6), STONE if i % 2 == 0 else STONE_LIGHT)
		m.box(sub(xf, Vector3(0, y + 1.2, 7.0 + i * 0.5 - (6.0 - i * 0.8) - 0.02)), Vector3(w - 0.4, 0.22, 0.03), MAYA_BLUE if i % 2 == 0 else CINNABAR, false, false)
	for k in 14:
		var y := k * 0.6
		m.box(sub(xf, Vector3(0, y + 0.3, 0.6 + k * 0.42)), Vector3(4.0, 0.6, 0.6), STUCCO_SHADE)
	m.box(sub(xf, Vector3(0, 10.4, 10.0)), Vector3(4.0, 3.2, 3.0), STUCCO)
	m.box(sub(xf, Vector3(0, 10.0, 8.48)), Vector3(1.4, 2.2, 0.04), PIT, false, false)
	m.box(sub(xf, Vector3(0, 12.2, 10.0)), Vector3(4.6, 0.4, 3.4), CINNABAR)
	for side in [-1.0, 1.0]:
		serpent_head(m, sub(xf, Vector3(side * 2.4, 0, -0.2)))
		brazier(m, sub(xf, Vector3(side * 5.5, 0, -1.0)), int(side * 7))

## The painted sky behind the temple, seen from the title: flat registers of
## colour from the glowing horizon up to the coming night, a huge setting k'in
## sun, and scrolled clouds. Built facing -Z at [xf]; drawn unshaded.
static func sky(m: Mesher, xf: Transform3D) -> void:
	var bands := Themes.sky()
	var h := 11.0
	for i in bands.size():
		m.box(sub(xf, Vector3(0, -8.0 + i * h + h / 2.0, 0)), Vector3(260.0, h + 0.05, 0.5), bands[i], false, false)
	# The sun, half sunk behind the horizon of the world.
	var sx := -21.0 # beside the temple, as the title camera sees it
	var sun := sub(xf, Vector3(sx, 12.0, -1.0), Basis(Vector3.RIGHT, PI / 2.0))
	m.prism(sun, 15.0, 15.0, 0.3, 32, Color("#FFE7A6"), false, Color(0, 0, 0, 0), false)
	m.prism(sub(sun, Vector3(0, 0.31, 0)), 12.5, 12.5, 0.3, 32, Color("#F7C65C"), false, Color(0, 0, 0, 0), false)
	for k in 4:
		var a := PI / 4.0 + k * PI / 2.0
		m.blob(sub(xf, Vector3(sx + cos(a) * 6.0, 12.0 + sin(a) * 6.0, -1.8), Basis(Vector3.FORWARD, a).scaled(Vector3(1.0, 0.6, 0.15))), 5.0, Color("#E39A2E"), 0.0, k, false, false)
	m.blob(sub(xf, Vector3(sx, 12.0, -2.2), Basis().scaled(Vector3(1.0, 1.0, 0.15))), 2.4, Color("#B8322A"), 0.0, 9, false, false)
	for k in 16:
		var a := TAU * k / 16.0
		var p := Vector3(sx + cos(a) * 19.0, 12.0 + sin(a) * 19.0, -0.8)
		m.box(sub(xf, p, Basis(Vector3.FORWARD, a)), Vector3(5.5, 1.2, 0.3), Color("#F7C65C"), false, false)
	# Cloud scrolls drifting across.
	var r := _rng(5)
	for i in 9:
		var cx := r.randf_range(-110.0, 110.0)
		var cy := r.randf_range(26.0, 62.0)
		var col := Color("#F6C9A0") if cy < 40.0 else Color("#C98A9A")
		for k in 3:
			m.blob(sub(xf, Vector3(cx + k * 6.0 - 6.0, cy + (2.0 if k == 1 else 0.0), -3.0), Basis().scaled(Vector3(1.6, 0.7, 0.2))), r.randf_range(4.0, 6.0), col, 0.1, i * 3 + k, false, false)

# ============================================================== seasons ===

## A pine dusted with snow, strung with little glowing lights.
static func pine(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	var r := _rng(seed)
	m.prism(xf, 0.16 * s, 0.12 * s, 0.7 * s, 6, BARK)
	var lights := [Color("#FF5A4A"), Color("#FFD35A"), Color("#5AD2FF"), Color("#8AFF7A")]
	for i in 4:
		var y := (0.55 + i * 0.62) * s
		var rad := (1.25 - i * 0.26) * s
		m.prism(sub(xf, Vector3(0, y, 0)), rad, 0.0, 1.0 * s, 8, Color("#2E6A46") if i % 2 == 0 else Color("#3A7A52"))
		m.prism(sub(xf, Vector3(0, y + 0.55 * s, 0)), rad * 0.5, 0.0, 0.42 * s, 8, SNOW, false, Color(0, 0, 0, 0), false)
		for k in 5:
			var a := r.randf() * TAU
			var p := Vector3(cos(a) * rad * 0.7, y + 0.3 * s, sin(a) * rad * 0.7)
			m.box(sub(xf, p), Vector3(0.09, 0.09, 0.09) * s, lights[(i + k) % 4], true, false)
	m.prism(sub(xf, Vector3(0, 3.0 * s, 0)), 0.14 * s, 0.0, 0.3 * s, 5, Color("#FFD35A"), true)

## A snowman with a scarf, coal eyes and a carrot nose, facing the road.
static func snowman(m: Mesher, xf: Transform3D, s: float, seed: int) -> void:
	m.blob(sub(xf, Vector3(0, 0.45 * s, 0)), 0.5 * s, SNOW, 0.05, seed)
	m.blob(sub(xf, Vector3(0, 1.1 * s, 0)), 0.36 * s, SNOW, 0.05, seed + 1)
	m.blob(sub(xf, Vector3(0, 1.6 * s, 0)), 0.26 * s, SNOW, 0.05, seed + 2)
	m.prism(sub(xf, Vector3(0, 1.36 * s, 0)), 0.3 * s, 0.28 * s, 0.1 * s, 10, CINNABAR)
	m.box(sub(xf, Vector3(0.18 * s, 1.2 * s, -0.12 * s), Basis(Vector3.RIGHT, -0.3)), Vector3(0.1, 0.35, 0.03) * s, CINNABAR)
	for x in [-0.09, 0.09]:
		m.box(sub(xf, Vector3(x * s, 1.68 * s, -0.24 * s)), Vector3(0.05, 0.05, 0.03) * s, INKY, false, false)
	m.prism(sub(xf, Vector3(0, 1.6 * s, -0.24 * s), Basis(Vector3.RIGHT, -PI / 2.0)), 0.045 * s, 0.0, 0.2 * s, 5, Color("#F07A2A"))
	for k in 3:
		m.box(sub(xf, Vector3(0, (1.0 + k * 0.13) * s, -0.35 * s)), Vector3(0.05, 0.05, 0.03) * s, INKY, false, false)
	m.prism(sub(xf, Vector3(0, 1.82 * s, 0)), 0.2 * s, 0.2 * s, 0.03 * s, 10, INKY)
	m.prism(sub(xf, Vector3(0, 1.84 * s, 0)), 0.13 * s, 0.13 * s, 0.25 * s, 10, INKY)

## A wrapped gift with a ribbon and a bow.
static func gift(m: Mesher, xf: Transform3D, seed: int) -> void:
	var r := _rng(seed)
	var wraps := [Color("#C8202A"), Color("#2E7A4A"), Color("#3A6AC8"), Color("#E3A82F")]
	var ribbon := [Color("#FFD35A"), Color("#FFFFFF"), Color("#C8202A")]
	var size := Vector3(r.randf_range(0.4, 0.7), r.randf_range(0.3, 0.6), r.randf_range(0.4, 0.7))
	var w: Color = wraps[r.randi() % wraps.size()]
	var rb: Color = ribbon[r.randi() % ribbon.size()]
	var at := sub(xf, Vector3(0, size.y / 2.0, 0))
	m.box(at, size, w)
	m.box(at, Vector3(size.x + 0.02, size.y + 0.02, 0.08), rb, false, false)
	m.box(at, Vector3(0.08, size.y + 0.02, size.z + 0.02), rb, false, false)
	for a in [-0.6, 0.6]:
		m.blob(sub(xf, Vector3(sin(a) * 0.08, size.y + 0.06, 0), Basis().scaled(Vector3(1.0, 0.6, 0.5))), 0.08, rb, 0.1, seed)

## The shared sun-drop mesh: a small gold sun disc with the four glowing
## petals of the k'in glyph on both faces.
static func coin_mesh() -> ArrayMesh:
	var m := Mesher.new()
	var upright := Basis(Vector3.RIGHT, PI / 2.0)
	m.prism(Transform3D(upright, Vector3(0, 0, -0.06)), 0.3, 0.3, 0.12, 10, GOLD)
	for face in [-1.0, 1.0]:
		for k in 4:
			var a := PI / 4.0 + k * PI / 2.0
			var petal := Basis(Vector3.FORWARD, a) * Basis().scaled(Vector3(1.0, 0.55, 1.0))
			m.box(Transform3D(petal, Vector3(cos(a) * 0.13, sin(a) * 0.13, face * 0.07)), Vector3(0.15, 0.15, 0.03), FLAME_CORE, true, false)
	return m.commit()
