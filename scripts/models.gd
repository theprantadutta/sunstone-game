class_name Models
## Every 3D asset in the world, written into a [Mesher] at a transform: a
## painted Maya temple causeway at dusk. Ancient temples were brightly painted —
## Maya blue bands and cinnabar red, not plain brown stone — and that's the look.
## No imported models; tweak shapes and colours here.

const STONE := Color("#B4A386")
const STONE_DARK := Color("#857460")
const STONE_LIGHT := Color("#CDBD9F")
const MAYA_BLUE := Color("#3FA7B5")
const CINNABAR := Color("#B8322A")
const GOLD := Color("#F4B732")
const LEAF := Color("#2F6B3A")
const LEAF_DARK := Color("#1E4A2E")
const LEAF_LIGHT := Color("#4C8C3F")
const BARK := Color("#5A3B26")
const MOSS := Color("#5C7A35")
const FLAME := Color("#FF8A2A")
const FLAME_CORE := Color("#FFE08A")
const SHADOW_STONE := Color("#3D3329")

## Path geometry shared with the game.
const LANE_WIDTH := 1.6
const PATH_WIDTH := LANE_WIDTH * 3.0
const TILE_LENGTH := 2.0

## The jungle floor. The causeway is a raised road (a Maya sacbe) on a stepped
## stone embankment that stands on it — nothing floats.
const GROUND_Y := -7.3
const WALL_HALF := PATH_WIDTH / 2.0 + 0.45 ## outer face of the parapet wall
const TIER_TOP := -2.4 ## first stepped tier below the painted wall
const TIER_H := 1.7
const TIER_STEP := 0.6 ## each tier steps out this much per side
const JUNGLE := Color("#24412F")

static func at(origin: Vector3, basis := Basis()) -> Transform3D:
	return Transform3D(basis, origin)

## A transform at local position [p] inside the frame [xf].
static func sub(xf: Transform3D, p: Vector3, basis := Basis()) -> Transform3D:
	return xf * Transform3D(basis, p)

# ------------------------------------------------------------- causeway ---

## One floor tile, top surface at y = 0. Slight colour jitter per tile.
static func floor_tile(m: Mesher, xf: Transform3D, jitter: float) -> void:
	var c := STONE.lerp(STONE_LIGHT, jitter) if jitter > 0.5 else STONE.lerp(STONE_DARK, 0.5 - jitter)
	m.box(sub(xf, Vector3(0, -0.3, 0)), Vector3(LANE_WIDTH - 0.06, 0.6, TILE_LENGTH - 0.06), c)

## The low painted kerb along one edge, [length] long, centred on xf.
static func kerb(m: Mesher, xf: Transform3D, length: float, side: float) -> void:
	m.box(sub(xf, Vector3(0, 0.15, 0)), Vector3(0.45, 0.5, length), STONE_DARK)
	# A Maya-blue band on the face that looks onto the path.
	m.box(sub(xf, Vector3(-side * 0.23, 0.2, 0)), Vector3(0.02, 0.16, length), MAYA_BLUE)

## The body of the causeway under [length] metres of road (xf at the middle):
## a painted wall (tablero) with a frieze, a cornice, then three stepped tiers
## (talud) down into the jungle floor, greening with moss toward the bottom.
## [dy] nudges coplanar faces apart where two stretches meet at a corner.
static func embankment(m: Mesher, xf: Transform3D, length: float, dy := 0.0) -> void:
	var wall_h := -0.05 - (TIER_TOP + 0.1)
	m.box(sub(xf, Vector3(0, -0.05 - wall_h / 2.0 + dy, 0)), Vector3(WALL_HALF * 2.0, wall_h, length), STONE)
	for side in [-1.0, 1.0]:
		# Frieze: a cinnabar band over a thin Maya-blue line.
		m.box(sub(xf, Vector3(side * (WALL_HALF + 0.01), -0.85 + dy, 0)), Vector3(0.03, 0.42, length), CINNABAR)
		m.box(sub(xf, Vector3(side * (WALL_HALF + 0.01), -1.32 + dy, 0)), Vector3(0.03, 0.12, length), MAYA_BLUE)
	m.box(sub(xf, Vector3(0, TIER_TOP + 0.05 + dy, 0)), Vector3(WALL_HALF * 2.0 + 0.5, 0.22, length), STONE_LIGHT) # cornice
	for i in 3:
		var w := (WALL_HALF + TIER_STEP * (i + 1)) * 2.0
		var top := TIER_TOP - TIER_H * i
		var c := STONE_DARK.lerp(MOSS.darkened(0.25), 0.18 + 0.2 * i)
		m.box(sub(xf, Vector3(0, top - TIER_H / 2.0 + dy, 0)), Vector3(w, TIER_H + (0.4 if i == 2 else 0.0), length), c)

## A square buttress standing out from the wall on [side], its top flush with
## the road — a footing for a pillar.
static func buttress(m: Mesher, xf: Transform3D, side: float) -> void:
	var x := side * (WALL_HALF + 0.9)
	var top_h := -0.05 - TIER_TOP
	m.box(sub(xf, Vector3(x, -0.05 - top_h / 2.0, 0)), Vector3(1.8, top_h, 1.9), STONE)
	m.box(sub(xf, Vector3(x + side * 0.91, -0.85, 0)), Vector3(0.03, 0.42, 1.7), CINNABAR)
	m.box(sub(xf, Vector3(x, TIER_TOP + 0.05, 0)), Vector3(2.3, 0.22, 2.4), STONE_LIGHT)
	var low_h := TIER_TOP - GROUND_Y + 0.2
	m.box(sub(xf, Vector3(x + side * 0.3, TIER_TOP - low_h / 2.0, 0)), Vector3(2.6, low_h, 2.6), STONE_DARK.lerp(MOSS.darkened(0.25), 0.3))

## Vines spilling over the wall on [side]: a few hanging strands of leaves.
static func vines(m: Mesher, xf: Transform3D, side: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var x := side * (WALL_HALF + 0.06)
	for i in rng.randi_range(3, 6):
		var z := rng.randf_range(-0.9, 0.9)
		var drop := rng.randf_range(0.7, 2.1)
		var col: Color = [LEAF, LEAF_LIGHT, LEAF_DARK][i % 3]
		m.box(sub(xf, Vector3(x, -drop / 2.0, z)), Vector3(0.06, drop, 0.13), col)
		m.blob(sub(xf, Vector3(x, -drop, z), Basis().scaled(Vector3(0.6, 1.0, 1.0))), 0.16, col, 0.3, seed + i)
	# A clump of leaves over the parapet where they hang from.
	m.blob(sub(xf, Vector3(x - side * 0.1, 0.05, 0), Basis().scaled(Vector3(0.7, 0.45, 1.6))), 0.5, LEAF, 0.3, seed)

## Low growth on a tier ledge or the jungle floor: a squat leafy bush.
static func bush(m: Mesher, xf: Transform3D, size: float, seed: int) -> void:
	var col: Color = [LEAF, LEAF_DARK, LEAF_LIGHT][seed % 3]
	m.blob(sub(xf, Vector3(0, 0.35 * size, 0), Basis().scaled(Vector3(1.3, 0.75, 1.1))), 0.7 * size, col, 0.3, seed)
	m.blob(sub(xf, Vector3(0.5 * size, 0.3 * size, 0.3 * size)), 0.45 * size, LEAF_DARK, 0.3, seed + 3)

## Tumbled blocks at the foot of a collapsed stretch.
static func rubble(m: Mesher, xf: Transform3D, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in 6:
		var p := Vector3(rng.randf_range(-3.0, 3.0), 0.2, rng.randf_range(-1.8, 1.8))
		var b := Basis.from_euler(Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6))
		var size := Vector3(rng.randf_range(0.6, 1.3), rng.randf_range(0.4, 0.8), rng.randf_range(0.6, 1.2))
		m.box(sub(xf, p, b), size, STONE_DARK if i % 2 == 0 else STONE)
	bush(m, sub(xf, Vector3(2.2, 0, 1.0)), 1.0, seed)

# ------------------------------------------------------------ dressing ---

## A painted pillar; [broken] snaps the top off. Stand it on a buttress.
static func pillar(m: Mesher, xf: Transform3D, height: float, broken := false) -> void:
	var h := height * (0.55 if broken else 1.0)
	m.box(sub(xf, Vector3(0, 0.2, 0)), Vector3(1.1, 0.4, 1.1), STONE_DARK)
	m.prism(sub(xf, Vector3(0, 0.4, 0)), 0.42, 0.36, h, 6, STONE)
	m.prism(sub(xf, Vector3(0, 0.5, 0)), 0.45, 0.45, 0.25, 6, CINNABAR)
	if broken:
		m.blob(sub(xf, Vector3(0.1, 0.4 + h, 0)), 0.38, STONE_LIGHT, 0.35, int(height * 10))
	else:
		m.prism(sub(xf, Vector3(0, 0.4 + h - 0.55, 0)), 0.4, 0.4, 0.3, 6, MAYA_BLUE)
		m.box(sub(xf, Vector3(0, 0.55 + h, 0)), Vector3(1.0, 0.3, 1.0), STONE_LIGHT)

## A standing torch with a glowing flame (emissive geometry, no real light).
static func torch(m: Mesher, xf: Transform3D) -> void:
	m.prism(xf, 0.2, 0.16, 0.12, 6, STONE_DARK) # foot
	m.prism(xf, 0.09, 0.07, 1.5, 5, BARK)
	m.prism(sub(xf, Vector3(0, 1.45, 0)), 0.14, 0.3, 0.25, 6, STONE_DARK)
	m.prism(sub(xf, Vector3(0, 1.62, 0)), 0.22, 0.0, 0.6, 5, FLAME, true)
	m.prism(sub(xf, Vector3(0, 1.62, 0)), 0.11, 0.0, 0.38, 5, FLAME_CORE, true)

## A jungle tree rooted at xf. [size] scales it; [seed] varies the canopy.
static func tree(m: Mesher, xf: Transform3D, size: float, seed: int) -> void:
	m.prism(xf, 0.45 * size, 0.22 * size, 6.0 * size, 5, BARK)
	# Buttress roots flaring into the floor.
	for i in 3:
		var a := TAU * i / 3.0 + seed
		m.box(sub(xf, Vector3(sin(a) * 0.45 * size, 0.3 * size, cos(a) * 0.45 * size), Basis(Vector3.UP, a)),
			Vector3(0.18 * size, 0.6 * size, 0.7 * size), BARK.darkened(0.15))
	var leaf: Color = [LEAF, LEAF_DARK, LEAF_LIGHT][seed % 3]
	m.blob(sub(xf, Vector3(0, 6.2 * size, 0)), 2.3 * size, leaf, 0.25, seed)
	m.blob(sub(xf, Vector3(1.1 * size, 7.0 * size, 0.6 * size)), 1.5 * size, LEAF_DARK, 0.3, seed + 1)
	m.blob(sub(xf, Vector3(-1.0 * size, 6.8 * size, -0.4 * size)), 1.3 * size, LEAF_LIGHT, 0.3, seed + 2)

## A fan of fern fronds.
static func fern(m: Mesher, xf: Transform3D, seed: int) -> void:
	for i in 6:
		var a := TAU * i / 6.0 + seed
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.7)
		m.box(xf * Transform3D(b, Vector3(sin(a) * 0.35, 0.3, cos(a) * 0.35)),
			Vector3(0.22, 0.04, 1.1), LEAF_LIGHT if i % 2 == 0 else LEAF)

# ----------------------------------------------------------- obstacles ---

## A fallen log across [width] — jump it.
static func log_barrier(m: Mesher, xf: Transform3D, width: float) -> void:
	var lying := Basis(Vector3.FORWARD, PI / 2.0) # prism's +Y axis → world X
	m.prism(xf * Transform3D(lying, Vector3(width / 2.0, 0.42, 0)), 0.42, 0.42, width, 7, BARK)
	for x in [-width * 0.3, width * 0.15, width * 0.38]:
		m.blob(sub(xf, Vector3(x, 0.82, 0.05)), 0.22, MOSS, 0.3, int(x * 10))

## A low painted wall across one lane — jump it or change lanes.
static func low_wall(m: Mesher, xf: Transform3D, width: float) -> void:
	m.box(sub(xf, Vector3(0, 0.4, 0)), Vector3(width - 0.1, 0.8, 0.7), STONE_DARK)
	m.box(sub(xf, Vector3(0, 0.84, 0)), Vector3(width - 0.2, 0.1, 0.6), MOSS)
	# Two cinnabar glyph blocks on the face you run at.
	for x in [-width * 0.22, width * 0.22]:
		m.box(sub(xf, Vector3(x, 0.42, -0.36)), Vector3(0.36, 0.36, 0.04), CINNABAR)

## An archway with a low lintel — slide under it.
static func arch(m: Mesher, xf: Transform3D, width: float) -> void:
	var half := width / 2.0 + 0.35
	for x in [-half, half]:
		m.box(sub(xf, Vector3(x, 1.4, 0)), Vector3(0.7, 2.8, 0.8), STONE)
		m.box(sub(xf, Vector3(x, 0.3, 0)), Vector3(0.8, 0.25, 0.9), CINNABAR)
	m.box(sub(xf, Vector3(0, 1.75, 0)), Vector3(width + 1.5, 0.95, 0.9), STONE_LIGHT)
	m.box(sub(xf, Vector3(0, 1.75, -0.46)), Vector3(width + 1.4, 0.22, 0.03), MAYA_BLUE)
	# Vines hanging off the lintel make "duck" readable at a glance.
	for i in 7:
		var vx := -width / 2.0 + width * (i + 0.5) / 7.0
		m.box(sub(xf, Vector3(vx, 1.08, -0.3)), Vector3(0.07, 0.45 + (i % 3) * 0.12, 0.07), LEAF_LIGHT)

## A jaguar-head totem filling one lane — change lanes.
static func statue(m: Mesher, xf: Transform3D) -> void:
	m.box(sub(xf, Vector3(0, 1.15, 0)), Vector3(1.3, 2.3, 1.1), STONE)
	m.box(sub(xf, Vector3(0, 2.4, 0)), Vector3(1.45, 0.3, 1.2), MAYA_BLUE) # headdress band
	m.box(sub(xf, Vector3(0, 2.7, 0)), Vector3(1.1, 0.35, 0.9), CINNABAR)
	for x in [-0.32, 0.32]: # glowing eyes
		m.box(sub(xf, Vector3(x, 1.75, -0.56)), Vector3(0.24, 0.14, 0.04), GOLD, true)
	m.box(sub(xf, Vector3(0, 1.2, -0.56)), Vector3(0.7, 0.16, 0.04), SHADOW_STONE) # snarl
	for x in [-0.22, 0.0, 0.22]: # fangs
		m.box(sub(xf, Vector3(x, 1.04, -0.57)), Vector3(0.08, 0.16, 0.04), STONE_LIGHT)

# ------------------------------------------------------------ set pieces ---

## The altar on the outside of a corner: tells you to turn.
static func corner_altar(m: Mesher, xf: Transform3D) -> void:
	m.box(sub(xf, Vector3(0, 0.5, 0)), Vector3(PATH_WIDTH, 1.0, 0.8), STONE_DARK)
	m.box(sub(xf, Vector3(0, 1.2, 0.1)), Vector3(PATH_WIDTH * 0.7, 0.5, 0.6), STONE)
	m.box(sub(xf, Vector3(0, 1.05, -0.41)), Vector3(PATH_WIDTH - 0.2, 0.12, 0.03), MAYA_BLUE)
	torch(m, sub(xf, Vector3(-PATH_WIDTH / 2.0 - 0.2, 0, 0)))
	torch(m, sub(xf, Vector3(PATH_WIDTH / 2.0 + 0.2, 0, 0)))

## The temple the run starts from: a painted stepped pyramid with a dark
## doorway the jaguars burst out of. Faces -Z (the path leads away from it).
static func start_temple(m: Mesher, xf: Transform3D) -> void:
	for i in 6:
		var w := 22.0 - i * 3.2
		var y := i * 1.6
		m.box(sub(xf, Vector3(0, y + 0.8, 8.0 + i * 0.4)), Vector3(w, 1.6, 12.0 - i * 1.4), STONE if i % 2 == 0 else STONE_DARK)
		m.box(sub(xf, Vector3(0, y + 1.35, 8.0 + i * 0.4 - (6.0 - i * 0.7) - 0.02)), Vector3(w - 0.3, 0.25, 0.04), MAYA_BLUE if i % 2 == 0 else CINNABAR)
	# Doorway and lintel.
	# The temple stands on its own stepped platform, down to the jungle floor.
	for i in 3:
		var w := 24.0 + TIER_STEP * 2.0 * (i + 1)
		var top := -0.05 - (TIER_H + 0.6) * i
		var h := (TIER_H + 0.6) + (1.0 if i == 2 else 0.0)
		m.box(sub(xf, Vector3(0, top - h / 2.0, 7.8)), Vector3(w, h, 15.6 + TIER_STEP * 2.0 * i), STONE_DARK.lerp(MOSS.darkened(0.25), 0.15 + 0.2 * i))
	m.box(sub(xf, Vector3(0, 1.7, 1.95)), Vector3(4.2, 3.4, 0.1), Color("#120d0a"))
	m.box(sub(xf, Vector3(0, 3.7, 1.9)), Vector3(5.4, 0.7, 0.6), GOLD)
	torch(m, sub(xf, Vector3(-3.2, 0, 1.4)))
	torch(m, sub(xf, Vector3(3.2, 0, 1.4)))

## A distant forested hill for the skyline.
static func far_hill(m: Mesher, xf: Transform3D, radius: float, seed: int) -> void:
	m.blob(sub(xf, Vector3.ZERO, Basis().scaled(Vector3(1.4, 0.55, 1.0))), radius, LEAF_DARK.lerp(JUNGLE, 0.5), 0.12, seed)
	m.blob(sub(xf, Vector3(radius * 0.7, -radius * 0.1, radius * 0.2), Basis().scaled(Vector3(1.1, 0.5, 1.0))), radius * 0.7, JUNGLE, 0.15, seed + 1)

## A distant stepped pyramid for the skyline.
static func far_pyramid(m: Mesher, xf: Transform3D, scale: float) -> void:
	for i in 5:
		var w := (40.0 - i * 7.0) * scale
		m.box(sub(xf, Vector3(0, (i * 6.0 + 3.0) * scale, 0)), Vector3(w, 6.0 * scale, w), STONE_DARK.lerp(Color("#5B4A63"), 0.5))
	m.box(sub(xf, Vector3(0, 33.0 * scale, 0)), Vector3(7.0 * scale, 6.0 * scale, 7.0 * scale), CINNABAR.darkened(0.3))

## The shared coin mesh: a faceted gold disc with a glowing heart.
static func coin_mesh() -> ArrayMesh:
	var m := Mesher.new()
	var upright := Basis(Vector3.RIGHT, PI / 2.0)
	m.prism(Transform3D(upright, Vector3(0, 0, -0.06)), 0.34, 0.34, 0.12, 8, GOLD)
	m.prism(Transform3D(upright, Vector3(0, 0, -0.08)), 0.14, 0.14, 0.16, 4, FLAME_CORE, true)
	return m.commit()
