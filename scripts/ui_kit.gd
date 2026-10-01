class_name UiKit
## The Sunstone design system in code: the Codex. Every screen is a page from a
## Maya codex — lime-stucco bark paper, black ink linework, cinnabar-red rules
## between registers, glyph-block cartouches for buttons. See DESIGN.md.
##
## Lines waver like a scribe's hand, but steadily (seeded), never boiling.

const INK := Color("#1B1410")
const STUCCO := Color("#EFE3C8")
const STUCCO_SHADE := Color("#C9B48A")
const CINNABAR := Color("#B8322A")
const CINNABAR_DEEP := Color("#7A1D17")
const MAYA_BLUE := Color("#3FA7B5")
const OCHRE := Color("#E3A82F") ## the sun, sun-drops
const OCHRE_LIGHT := Color("#FFE3A0")
const NIGHT := Color("#0B0E24") ## the dim behind an open page

static var _display: FontFile
static var _text := {}
static var _paper: Texture2D

static func display_font() -> FontFile:
	if _display == null:
		_display = load("res://assets/fonts/DelaGothicOne-Regular.ttf")
	return _display

## Nunito at a given weight (700, 800, 900) from the variable font.
static func text_font(weight := 800) -> Font:
	if not _text.has(weight):
		var base: FontFile = load("res://assets/fonts/Nunito-Variable.ttf")
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_text[weight] = fv
	return _text[weight]

static func paper() -> Texture2D:
	if _paper == null:
		_paper = load("res://assets/ui/paper.png")
	return _paper

static func label(text: String, font: Font, size: int, color: Color, outline := 0, outline_color := INK) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = outline_color
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## A label that wraps within [width] at [pos]. Order matters: wrapping must be
## on before the label is sized or placed, or it locks to the unwrapped width.
static func wrapped(text: String, font: Font, size: int, color: Color, pos: Vector2, width: float, height := 0.0) -> Label:
	var l := label(text, font, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(width, 0)
	l.size = Vector2(width, height)
	l.position = pos
	return l

## "1240" → "1,240".
static func thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out

# ============================================================ geometry ===

## A steady hand-drawn waver along a perimeter: two slow sines, seeded.
static func _waver(t: float, seed: int, amount: float) -> float:
	return amount * (sin(t * 7.0 + seed * 1.7) * 0.6 + sin(t * 17.0 + seed * 0.9) * 0.4)

## The glyph block: the squared, puffy cartouche Maya scribes wrote each glyph
## into — rounded corners and gently bulging sides.
static func glyph_block(rect: Rect2, seed := 0, wobble := 1.0) -> PackedVector2Array:
	var m := minf(rect.size.x, rect.size.y)
	var r := m * 0.3
	var bulge := m * 0.05
	var corners := [
		Vector2(rect.end.x - r, rect.position.y + r), Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r), Vector2(rect.position.x + r, rect.position.y + r),
	]
	var pts := PackedVector2Array()
	for k in 4:
		var a0 := -PI / 2.0 + k * PI / 2.0
		var c: Vector2 = corners[k]
		for i in 7:
			var a := a0 + PI / 2.0 * i / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		var a1 := a0 + PI / 2.0
		var from := c + Vector2(cos(a1), sin(a1)) * r
		var nxt: Vector2 = corners[(k + 1) % 4]
		var to := nxt + Vector2(cos(a1), sin(a1)) * r
		var normal := Vector2(cos(a1), sin(a1))
		var steps := maxi(int(from.distance_to(to) / 14.0), 2)
		for i in range(1, steps):
			var t := float(i) / steps
			pts.append(from.lerp(to, t) + normal * bulge * sin(PI * t))
	if wobble > 0.0:
		var c0 := rect.get_center()
		for i in pts.size():
			var d := (pts[i] - c0).normalized()
			pts[i] += d * _waver(float(i) / pts.size() * TAU, seed, wobble)
	return pts

## A paper rectangle with a slightly torn, hand-cut edge.
static func torn(rect: Rect2, seed := 0, rough := 1.8) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pts := PackedVector2Array()
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var n := (b - a).normalized().orthogonal()
		var steps := maxi(int(a.distance_to(b) / 16.0), 2)
		for i in steps:
			var t := float(i) / steps
			pts.append(a.lerp(b, t) + n * rng.randf_range(-rough, rough))
	return pts

static func ellipse(c: Vector2, rx: float, ry: float, angle := 0.0, seg := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rot := Vector2(cos(angle), sin(angle))
	for i in seg:
		var t := TAU * i / seg
		var p := Vector2(cos(t) * rx, sin(t) * ry)
		pts.append(c + Vector2(p.x * rot.x - p.y * rot.y, p.x * rot.y + p.y * rot.x))
	return pts

static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out

# ============================================================== drawing ===

## Fills [pts] with codex paper, tinted by [tint] (white = plain stucco).
static func draw_paper(ci: CanvasItem, pts: PackedVector2Array, tint := Color.WHITE) -> void:
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(p / 512.0)
	ci.draw_colored_polygon(pts, tint, uvs, paper())

## An ink outline along a closed shape.
static func draw_ink(ci: CanvasItem, pts: PackedVector2Array, color := INK, width := 4.0) -> void:
	ci.draw_polyline(closed(pts), color, width, true)

## A red rule dividing two registers, drawn freehand.
static func draw_rule(ci: CanvasItem, a: Vector2, b: Vector2, color := CINNABAR, width := 3.0, seed := 0) -> void:
	var pts := PackedVector2Array()
	var steps := maxi(int(a.distance_to(b) / 20.0), 2)
	var n := (b - a).normalized().orthogonal()
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(a.lerp(b, t) + n * _waver(t * 3.0, seed, 0.8))
	ci.draw_polyline(pts, color, width, true)

## The k'in glyph — the Maya sign for sun and day: a four-petalled flower in a
## round cartouche. [lit] 0..1 dims the petals.
static func draw_kin(ci: CanvasItem, c: Vector2, r: float, lit := 1.0, ink_w := 3.0, paper_fill := true) -> void:
	var disc := ellipse(c, r, r, 0.0, 40)
	if paper_fill:
		draw_paper(ci, disc)
	else:
		ci.draw_colored_polygon(disc, STUCCO)
	var petal := OCHRE.lerp(Color("#5A4632"), 1.0 - lit)
	for k in 4:
		var a := PI / 4.0 + k * PI / 2.0
		var pc := c + Vector2(cos(a), sin(a)) * r * 0.38
		var e := ellipse(pc, r * 0.36, r * 0.22, a, 18)
		ci.draw_colored_polygon(e, petal)
		ci.draw_polyline(closed(e), INK, maxf(ink_w - 1.0, 1.5), true)
	var hub := ellipse(c, r * 0.17, r * 0.17, 0.0, 16)
	ci.draw_colored_polygon(hub, OCHRE_LIGHT.lerp(petal, 0.4))
	ci.draw_polyline(closed(hub), INK, maxf(ink_w - 1.0, 1.5), true)
	ci.draw_polyline(closed(disc), INK, ink_w, true)

## A Maya bar-and-dot numeral (base 20, highest place on top), its top-left at
## [origin], each place [u]*4 wide. Returns the drawn height.
static func draw_maya_number(ci: CanvasItem, origin: Vector2, n: int, u := 8.0, color := INK) -> float:
	var places: Array[int] = []
	var v := absi(n)
	if v == 0:
		places.append(0)
	while v > 0:
		places.push_front(v % 20)
		v /= 20
	var y := origin.y
	for i in places.size():
		y += _maya_digit(ci, Vector2(origin.x, y), places[i], u, color)
		if i < places.size() - 1:
			y += u * 1.1 # gap between places
	return y - origin.y

## Height of [n] written as a Maya numeral at unit [u].
static func maya_height(n: int, u := 8.0) -> float:
	var h := 0.0
	var v := absi(n)
	var first := true
	if v == 0:
		return u * 2.0
	while v > 0:
		var d := v % 20
		var dh := u * 2.0 if d == 0 else (u * 1.1 if d % 5 > 0 else 0.0) + (d / 5) * u * 1.05
		h += dh + (0.0 if first else u * 1.1)
		first = false
		v /= 20
	return h

static func _maya_digit(ci: CanvasItem, at: Vector2, d: int, u: float, color: Color) -> float:
	var w := u * 4.0
	if d == 0:
		# The shell, the Maya zero.
		var sh := ellipse(at + Vector2(w / 2.0, u), w / 2.0, u * 0.9, 0.0, 22)
		ci.draw_polyline(closed(sh), color, maxf(u * 0.28, 1.5), true)
		ci.draw_line(at + Vector2(w * 0.25, u * 0.7), at + Vector2(w * 0.75, u * 0.7), color, maxf(u * 0.22, 1.2), true)
		ci.draw_line(at + Vector2(w * 0.3, u * 1.3), at + Vector2(w * 0.7, u * 1.3), color, maxf(u * 0.22, 1.2), true)
		return u * 2.0
	var y := 0.0
	var dots := d % 5
	if dots > 0:
		var gap := w / 4.0
		var x0 := at.x + w / 2.0 - gap * (dots - 1) / 2.0
		for i in dots:
			ci.draw_circle(Vector2(x0 + gap * i, at.y + y + u * 0.45), u * 0.42, color, true, -1.0, true)
		y += u * 1.1
	for b in d / 5:
		var top := at.y + y + u * 0.1
		var h := u * 0.7
		ci.draw_rect(Rect2(at.x + h / 2.0, top, w - h, h), color)
		ci.draw_circle(Vector2(at.x + h / 2.0, top + h / 2.0), h / 2.0, color, true, -1.0, true)
		ci.draw_circle(Vector2(at.x + w - h / 2.0, top + h / 2.0), h / 2.0, color, true, -1.0, true)
		y += u * 1.05
	return y

# ================================================================ page ===

## A codex page: stucco paper with a hand-cut edge and a double cinnabar frame.
## It opens like the codex's screenfold — three leaves unfolding from the middle.
class Page:
	extends Control
	var seed := 7
	var unfold := 1.0

	func _init() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP # pages swallow taps

	## Unfolds the page, then lets its contents ink in.
	func open() -> void:
		unfold = 0.0
		queue_redraw()
		for c in get_children():
			if c is CanvasItem:
				c.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_method(_set_unfold, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var fade := tw.chain().set_parallel()
		for c in get_children():
			if c is CanvasItem:
				fade.tween_property(c, "modulate:a", 1.0, 0.18)

	func _set_unfold(v: float) -> void:
		unfold = v
		queue_redraw()

	func _draw() -> void:
		var e := maxf(unfold, 0.001)
		draw_set_transform(Vector2(size.x * (1.0 - e) / 2.0, 0.0), 0.0, Vector2(e, 1.0))
		var r := Rect2(Vector2.ZERO, size)
		var edge := UiKit.torn(r, seed)
		var shadow := PackedVector2Array()
		for p in edge:
			shadow.append(p + Vector2(0, 10))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
		UiKit.draw_paper(self, edge)
		# Screenfold leaves: the creases show, and fade as the page lies flat.
		var crease := 1.0 - e
		for k in [1, 2]:
			var x: float = size.x * k / 3.0
			draw_line(Vector2(x, 4), Vector2(x, size.y - 4), Color(UiKit.STUCCO_SHADE, 0.35 + 0.5 * crease), 2.0)
		draw_rect(Rect2(size.x / 3.0, 0, size.x / 3.0, size.y), Color(0, 0, 0, 0.22 * crease))
		UiKit.draw_ink(self, UiKit.torn(r.grow(-16), seed + 1, 0.8), UiKit.CINNABAR, 4.0)
		UiKit.draw_ink(self, UiKit.torn(r.grow(-25), seed + 2, 0.6), UiKit.CINNABAR, 1.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ============================================================== button ===

## A glyph-block button. It stands on its own ink edge and stamps down into it
## when pressed. PRIMARY is cinnabar with stucco lettering; SECONDARY is paper.
class GlyphButton:
	extends Control
	signal pressed

	enum Kind { PRIMARY, SECONDARY }

	var text := ""
	var kind := Kind.PRIMARY
	var font_size := 34
	var _down := false
	var _label: Label
	const DEPTH := 8.0

	func _init(t := "", k := Kind.PRIMARY) -> void:
		text = t
		kind = k
		custom_minimum_size = Vector2(200, 92)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _ready() -> void:
		var color := UiKit.STUCCO if kind == Kind.PRIMARY else UiKit.INK
		_label = UiKit.label(text, UiKit.display_font(), font_size, color)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
		resized.connect(_layout)
		_layout()

	func _layout() -> void:
		_label.position = Vector2(0, (DEPTH - 2.0 if _down else 0.0) - 2.0)
		_label.size = Vector2(size.x, size.y - DEPTH)

	func _draw() -> void:
		var h := size.y - DEPTH
		var seed := int(size.x) + kind * 13
		var base := UiKit.glyph_block(Rect2(Vector2(0, DEPTH), Vector2(size.x, h)), seed)
		draw_colored_polygon(base, UiKit.INK)
		var face_rect := Rect2(Vector2(0, DEPTH - 2.0 if _down else 0.0), Vector2(size.x, h))
		var face := UiKit.glyph_block(face_rect, seed)
		UiKit.draw_paper(self, face, UiKit.CINNABAR.lightened(0.12) if kind == Kind.PRIMARY else Color.WHITE)
		UiKit.draw_ink(self, face, UiKit.INK, 5.0)
		var inner := UiKit.glyph_block(face_rect.grow(-10), seed + 5, 0.6)
		UiKit.draw_ink(self, inner, Color(UiKit.STUCCO, 0.55) if kind == Kind.PRIMARY else UiKit.CINNABAR, 2.0)
		# Affixes: the small dotted marks scribes set beside a main sign.
		var dot := Color(UiKit.STUCCO, 0.85) if kind == Kind.PRIMARY else UiKit.CINNABAR
		for side in [-1.0, 1.0]:
			var x: float = face_rect.get_center().x + side * (face_rect.size.x / 2.0 - 26.0)
			for dy in [-9.0, 0.0, 9.0]:
				draw_circle(Vector2(x, face_rect.get_center().y + dy), 3.2, dot, true, -1.0, true)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			if event.pressed:
				_set_down(true)
			else:
				var was := _down
				_set_down(false)
				if was and Rect2(Vector2.ZERO, size).has_point(event.position):
					pressed.emit()
			accept_event()

	func _set_down(v: bool) -> void:
		if _down == v:
			return
		_down = v
		_layout()
		queue_redraw()

# ========================================================= icon button ===

## A small square glyph block with an inked sign: pause, settings, close, and
## the title menu's pages.
class GlyphIcon:
	extends Control
	signal pressed

	enum Icon { PAUSE, SETTINGS, CLOSE, RECORDS, DAILY, MARKET, GLYPHS, OFFERINGS }

	var icon := Icon.PAUSE
	var badge := false: ## a cinnabar dot: something waits on that page
		set(v):
			badge = v
			queue_redraw()
	var _down := false
	const DEPTH := 6.0

	func _init(i := Icon.PAUSE) -> void:
		icon = i
		custom_minimum_size = Vector2(84, 84)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _draw() -> void:
		var h := size.y - DEPTH
		draw_colored_polygon(UiKit.glyph_block(Rect2(Vector2(0, DEPTH), Vector2(size.x, h)), 31), UiKit.INK)
		var r := Rect2(Vector2(0, DEPTH - 1.0 if _down else 0.0), Vector2(size.x, h))
		var face := UiKit.glyph_block(r, 31)
		UiKit.draw_paper(self, face)
		UiKit.draw_ink(self, face, UiKit.INK, 4.0)
		UiKit.draw_ink(self, UiKit.glyph_block(r.grow(-8), 33, 0.5), UiKit.CINNABAR, 1.6)
		var c := r.get_center()
		match icon:
			Icon.PAUSE:
				for dx in [-9.0, 9.0]:
					draw_rect(Rect2(c + Vector2(dx - 5, -13), Vector2(10, 26)), UiKit.INK)
			Icon.SETTINGS:
				# Three sliders, drawn as bars and dots — like Maya numerals.
				var knobs := [-8.0, 9.0, -2.0]
				for i in 3:
					var y := c.y - 12.0 + i * 12.0
					var kx: float = c.x + knobs[i]
					draw_line(Vector2(c.x - 18, y), Vector2(c.x + 18, y), UiKit.INK, 4.0, true)
					draw_circle(Vector2(kx, y), 5.5, UiKit.CINNABAR, true, -1.0, true)
					draw_arc(Vector2(kx, y), 5.5, 0.0, TAU, 16, UiKit.INK, 2.0, true)
			Icon.CLOSE:
				draw_line(c + Vector2(-12, -12), c + Vector2(12, 12), UiKit.INK, 6.0, true)
				draw_line(c + Vector2(12, -12), c + Vector2(-12, 12), UiKit.INK, 6.0, true)
			Icon.RECORDS:
				# A record of counts: a Maya numeral, dots over bars.
				UiKit.draw_maya_number(self, c + Vector2(-16, -14), 12, 8.0, UiKit.INK)
			Icon.DAILY:
				# Today's sun, half sunk below the horizon.
				var sc := c + Vector2(0, 6)
				var half := PackedVector2Array()
				for i in 11:
					var a := PI + PI * i / 10.0
					half.append(sc + Vector2(cos(a), sin(a)) * 11.0)
				draw_colored_polygon(half, UiKit.OCHRE)
				draw_arc(sc, 12.0, PI, TAU, 20, UiKit.INK, 3.5, true)
				for k in 5:
					var a := PI + PI * (k + 0.5) / 5.0
					var d := Vector2(cos(a), sin(a))
					draw_line(sc + d * 17.0, sc + d * 23.0, UiKit.INK, 3.0, true)
				draw_line(c + Vector2(-22, 7), c + Vector2(22, 7), UiKit.CINNABAR, 4.0, true)
			Icon.MARKET:
				# A cacao jar: the Maya market's currency, in a painted pot.
				var jar := PackedVector2Array([c + Vector2(-8, -16), c + Vector2(8, -16), c + Vector2(6, -11),
					c + Vector2(15, -2), c + Vector2(12, 12), c + Vector2(7, 16), c + Vector2(-7, 16),
					c + Vector2(-12, 12), c + Vector2(-15, -2), c + Vector2(-6, -11)])
				draw_colored_polygon(jar, UiKit.CINNABAR)
				draw_polyline(UiKit.closed(jar), UiKit.INK, 3.0, true)
				draw_line(c + Vector2(-14, 2), c + Vector2(14, 2), UiKit.STUCCO, 3.0, true)
			Icon.OFFERINGS:
				# An offering bowl with three curls of copal smoke rising.
				var bowl := PackedVector2Array()
				for i in 13:
					var a := PI * i / 12.0
					bowl.append(c + Vector2(cos(a) * 18.0, 4.0 + sin(a) * 12.0))
				draw_colored_polygon(bowl, UiKit.CINNABAR)
				draw_polyline(UiKit.closed(bowl), UiKit.INK, 3.0, true)
				for k in 3:
					var x := (k - 1) * 9.0
					var smoke := PackedVector2Array()
					for j in 7:
						var t := j / 6.0
						smoke.append(c + Vector2(x + sin(t * TAU + k) * 3.0, 0.0 - t * 18.0))
					draw_polyline(smoke, UiKit.INK, 2.5, true)
			Icon.GLYPHS:
				# Four small glyph blocks: the collection.
				for gx in [-1.0, 1.0]:
					for gy in [-1.0, 1.0]:
						var b := UiKit.glyph_block(Rect2(c + Vector2(gx * 10.0 - 8.0, gy * 10.0 - 8.0), Vector2(16, 16)), 3, 0.0)
						draw_colored_polygon(b, UiKit.OCHRE if gx * gy > 0.0 else UiKit.STUCCO)
						draw_polyline(UiKit.closed(b), UiKit.INK, 2.5, true)

		if badge:
			var bc := Vector2(r.end.x - 10, r.position.y + 10)
			draw_circle(bc, 11.0, UiKit.INK, true, -1.0, true)
			draw_circle(bc, 8.0, UiKit.CINNABAR, true, -1.0, true)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			_down = event.pressed
			queue_redraw()
			if not event.pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
			accept_event()

# =============================================================== signs ===

## A glyph's sign, composed from its seed the way scribes built glyphs: one
## main sign, with dot-and-bar affixes and a crest. Every glyph gets its own.
static func draw_sign(ci: CanvasItem, rect: Rect2, seed: int, ink: Color, fill: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 13
	var c := rect.get_center() + Vector2(4, 4)
	var r := minf(rect.size.x, rect.size.y) * 0.3
	var w := maxf(r * 0.12, 2.0)
	match seed % 7:
		0: # k'in flower
			for k in 4:
				var a := PI / 4.0 + k * PI / 2.0
				var e := ellipse(c + Vector2(cos(a), sin(a)) * r * 0.42, r * 0.38, r * 0.22, a, 14)
				ci.draw_colored_polygon(e, fill)
				ci.draw_polyline(closed(e), ink, w, true)
			ci.draw_circle(c, r * 0.18, ink, true, -1.0, true)
		1: # an eye
			var eye := ellipse(c, r, r * 0.5, 0.0, 22)
			ci.draw_colored_polygon(eye, fill)
			ci.draw_polyline(closed(eye), ink, w, true)
			ci.draw_circle(c, r * 0.28, ink, true, -1.0, true)
		2: # a spiral
			var sp := PackedVector2Array()
			for i in 40:
				var t := i / 39.0
				var a := t * TAU * 2.2
				sp.append(c + Vector2(cos(a), sin(a)) * r * (0.12 + 0.88 * t))
			ci.draw_polyline(sp, ink, w * 1.3, true)
			ci.draw_circle(c, r * 0.16, fill, true, -1.0, true)
		3: # a step-fret
			var steps := PackedVector2Array([
				c + Vector2(-r, r * 0.6), c + Vector2(-r * 0.4, r * 0.6), c + Vector2(-r * 0.4, 0), c + Vector2(r * 0.2, 0),
				c + Vector2(r * 0.2, -r * 0.6), c + Vector2(r, -r * 0.6), c + Vector2(r, r * 0.6), c + Vector2(r * 0.55, r * 0.6),
				c + Vector2(r * 0.55, r * 0.15)])
			ci.draw_polyline(steps, ink, w * 1.3, true)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, r * 0.15), Vector2(r * 0.4, r * 0.4)), fill)
		4: # jaguar rosettes
			for k in rng.randi_range(3, 5):
				var p := c + Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7)) * r
				ci.draw_circle(p, r * 0.3, fill, true, -1.0, true)
				ci.draw_arc(p, r * 0.3, 0.0, TAU, 16, ink, w, true)
				ci.draw_circle(p, r * 0.09, ink, true, -1.0, true)
		5: # water
			for k in 3:
				var wave := PackedVector2Array()
				for i in 13:
					var t := i / 12.0
					wave.append(c + Vector2((t - 0.5) * 2.0 * r, (k - 1) * r * 0.55 + sin(t * TAU * 1.5 + k) * r * 0.18))
				ci.draw_polyline(wave, ink if k != 1 else fill.darkened(0.2), w * 1.2, true)
		_: # maize
			for k in 3:
				var a := -PI / 2.0 + (k - 1) * 0.55
				var leaf := ellipse(c + Vector2(cos(a), sin(a)) * r * 0.5, r * 0.55, r * 0.2, a, 14)
				ci.draw_colored_polygon(leaf, fill)
				ci.draw_polyline(closed(leaf), ink, w, true)
			ci.draw_circle(c + Vector2(0, r * 0.45), r * 0.22, ink, true, -1.0, true)
	# Affixes: a column of dots or a bar to the left, a crest on top.
	var left := rect.position + Vector2(rect.size.x * 0.17, rect.size.y * 0.3)
	if rng.randf() < 0.5:
		for i in rng.randi_range(1, 3):
			ci.draw_circle(left + Vector2(0, i * r * 0.42), r * 0.1, ink, true, -1.0, true)
	else:
		ci.draw_rect(Rect2(left + Vector2(-r * 0.08, 0), Vector2(r * 0.16, r * 0.9)), ink)
	for i in rng.randi_range(2, 4):
		var x := c.x - r * 0.45 + i * r * 0.3
		ci.draw_line(Vector2(x, rect.position.y + rect.size.y * 0.16), Vector2(x, rect.position.y + rect.size.y * 0.24), ink, w, true)

## A glyph in the collection: a paper glyph block with its sign — inked in
## gold once earned, faint until then, with a cinnabar dot while it waits to
## be claimed.
class GlyphTile:
	extends Control
	signal chosen
	var index := 0
	var state := "" ## "", "earned", "claimed"
	var selected := false:
		set(v):
			selected = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(100, 100)
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var b := UiKit.glyph_block(r.grow(-4), index + 101)
		var known := state != ""
		UiKit.draw_paper(self, b, Color(1.0, 0.94, 0.8) if known else Color(0.86, 0.82, 0.76))
		UiKit.draw_ink(self, b, UiKit.CINNABAR if selected else (UiKit.INK if known else Color(UiKit.INK, 0.45)), 5.0 if selected else 3.5)
		var ink := UiKit.INK if known else Color(UiKit.INK, 0.28)
		var fill := UiKit.OCHRE if known else Color(UiKit.STUCCO_SHADE, 0.6)
		UiKit.draw_sign(self, r.grow(-10), index, ink, fill)
		if state == "earned":
			var bc := Vector2(size.x - 12, 12)
			draw_circle(bc, 11.0, UiKit.INK, true, -1.0, true)
			draw_circle(bc, 8.0, UiKit.CINNABAR, true, -1.0, true)

	func _gui_input(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and not event.pressed:
			chosen.emit()
			accept_event()

## One day of the offering cycle: the day in Maya numerals and its gift.
class OfferingDay:
	extends Control
	var day := 1
	var reward := 25
	var state := "later" ## "taken", "today", "later"
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(110, 150)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _process(delta: float) -> void:
		if state == "today":
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(0, 0), Vector2(size.x, size.x))
		var b := UiKit.glyph_block(r.grow(-4), day * 17)
		var tint := Color(1.0, 0.92, 0.72) if state == "taken" else (Color.WHITE if state == "today" else Color(0.88, 0.84, 0.78))
		UiKit.draw_paper(self, b, tint)
		var edge := UiKit.INK
		if state == "today":
			edge = UiKit.CINNABAR.lerp(UiKit.INK, 0.5 + 0.5 * sin(_t * 4.0))
		UiKit.draw_ink(self, b, edge, 5.0 if state == "today" else 3.5)
		if state == "taken":
			UiKit.draw_kin(self, r.get_center(), r.size.x * 0.28, 1.0, 2.5, false)
		else:
			var u := 7.0
			var h := UiKit.maya_height(day, u)
			UiKit.draw_maya_number(self, Vector2(r.get_center().x - u * 2.0, r.get_center().y - h / 2.0), day, u,
				UiKit.INK if state == "today" else Color(UiKit.INK, 0.5))
		var font := UiKit.text_font(900)
		var txt := "+%d" % reward
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(font, Vector2((size.x - tw) / 2.0, size.y - 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
			UiKit.CINNABAR if state == "today" else UiKit.INK)

# ============================================================== swatch ===

## A Market item on paper: a garb shown as a tiny explorer in its colours, or
## a hue as the glowing stone. Marked when it's the one you wear.
class Swatch:
	extends Control
	signal chosen
	var kind := "garb" ## "garb" | "hue"
	var item := {}
	var owned := false
	var worn := false
	var selected := false:
		set(v):
			selected = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, Vector2(size.x, size.x))
		var b := UiKit.glyph_block(r.grow(-4), int(size.x) + item.get("cost", 0))
		UiKit.draw_paper(self, b, Color.WHITE if owned else Color(0.9, 0.86, 0.8))
		UiKit.draw_ink(self, b, UiKit.CINNABAR if selected else UiKit.INK, 5.0 if selected else 3.5)
		var c := r.get_center()
		var u := r.size.x / 10.0
		if kind == "garb":
			var p: Dictionary = item.palette
			var shirt: Color = p.get("shirt", Color("#2F6B5A"))
			var scarf: Color = p.get("scarf", Color("#B8322A"))
			var trousers: Color = p.get("trousers", Color("#C9B68E"))
			var hat: Color = p.get("hat", Color("#8A5A34"))
			var band: Color = p.get("band", Color("#3FA7B5"))
			# legs, body, scarf, head, hat — a little standing figure
			for lx in [-0.7, 0.3]:
				draw_rect(Rect2(c + Vector2(lx * u, 0.9 * u), Vector2(0.8 * u, 2.3 * u)), trousers)
			draw_rect(Rect2(c + Vector2(-1.5 * u, -1.6 * u), Vector2(3.0 * u, 2.7 * u)), shirt)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-1.2 * u, -1.6 * u), c + Vector2(1.2 * u, -1.6 * u), c + Vector2(0.2 * u, -0.2 * u)]), scarf)
			draw_circle(c + Vector2(0, -2.3 * u), 0.75 * u, Color("#C98B62"), true, -1.0, true)
			draw_rect(Rect2(c + Vector2(-1.6 * u, -3.0 * u), Vector2(3.2 * u, 0.35 * u)), hat)
			draw_rect(Rect2(c + Vector2(-0.8 * u, -3.7 * u), Vector2(1.6 * u, 0.75 * u)), hat)
			draw_rect(Rect2(c + Vector2(-0.8 * u, -3.15 * u), Vector2(1.6 * u, 0.2 * u)), band)
		else:
			var light: Color = item.light
			for k in 4:
				draw_circle(c, (3.6 - k * 0.6) * u, Color(light, 0.12 + k * 0.08), true, -1.0, true)
			var gem := UiKit.ellipse(c, 1.5 * u, 1.9 * u, 0.0, 6)
			draw_colored_polygon(gem, item.gem)
			draw_polyline(UiKit.closed(gem), UiKit.INK, 3.0, true)
			draw_line(c + Vector2(-0.6 * u, -0.9 * u), c + Vector2(0.2 * u, -1.4 * u), Color(1, 1, 1, 0.8), 2.5, true)
		if worn:
			UiKit.draw_kin(self, Vector2(r.end.x - 20, 20), 14.0, 1.0, 2.0, false)
		var font := UiKit.text_font(900)
		var t: String = item.title
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(font, Vector2((size.x - tw) / 2.0, r.end.y + 26), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiKit.INK)

	func _gui_input(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and not event.pressed:
			chosen.emit()
			accept_event()

## A charm's tier marks: three small glyph blocks, gold when bought.
class TierMarks:
	extends Control
	var tier := 0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	func _draw() -> void:
		for i in 3:
			var r := Rect2(Vector2(i * 40.0, 0), Vector2(32, 32))
			var b := UiKit.glyph_block(r, 90 + i, 0.4)
			if i < tier:
				draw_colored_polygon(b, UiKit.OCHRE)
				UiKit.draw_kin(self, r.get_center(), 9.0, 1.0, 1.5, false)
			else:
				UiKit.draw_paper(self, b, Color(0.88, 0.84, 0.78))
			UiKit.draw_ink(self, b, UiKit.INK, 2.5)

## The ring that counts down an offer: a cinnabar arc that empties.
class Countdown:
	extends Control
	var seconds := 5.0
	var left := 5.0
	signal expired
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		if left <= 0.0:
			return
		left = maxf(left - delta, 0.0)
		queue_redraw()
		if left <= 0.0:
			expired.emit()
	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 6.0
		draw_arc(c, r, 0.0, TAU, 48, Color(UiKit.INK, 0.2), 8.0, true)
		draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * left / seconds, 48, UiKit.CINNABAR, 8.0, true)
		var font := UiKit.display_font()
		var t := str(ceili(left))
		var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
		draw_string(font, c + Vector2(-ts.x / 2.0, 14), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UiKit.INK)

# ============================================================ wordmark ===

## The title, as a codex heading: a strip of bark paper ruled in cinnabar, the
## name inked in two colours (red printed a hair off the black), and the k'in
## sun glyph rising above it. The strip unrolls once when the title appears.
class Wordmark:
	extends Control
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(640, 300)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func replay() -> void:
		_t = 0.0

	func _process(delta: float) -> void:
		if _t < 1.0:
			_t = minf(_t + delta / 0.9, 1.0)
			queue_redraw()

	func _draw() -> void:
		var e := 1.0 - pow(1.0 - _t, 3.0)
		var strip := Rect2(Vector2(20, 130), Vector2(600, 150))
		var w := strip.size.x * e
		var unrolled := Rect2(Vector2(strip.get_center().x - w / 2.0, strip.position.y), Vector2(maxf(w, 40.0), strip.size.y))
		var edge := UiKit.torn(unrolled, 41)
		var shadow := PackedVector2Array()
		for p in edge:
			shadow.append(p + Vector2(0, 8))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
		UiKit.draw_paper(self, edge)
		UiKit.draw_rule(self, unrolled.position + Vector2(14, 16), Vector2(unrolled.end.x - 14, unrolled.position.y + 16), UiKit.CINNABAR, 4.0, 3)
		UiKit.draw_rule(self, Vector2(unrolled.position.x + 14, unrolled.end.y - 16), unrolled.end - Vector2(14, 16), UiKit.CINNABAR, 4.0, 5)
		if _t > 0.35:
			var a := clampf((_t - 0.35) / 0.4, 0.0, 1.0)
			var font := UiKit.display_font()
			var fs := 88
			var text := "Sunstone"
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := Vector2(strip.get_center().x - tw / 2.0, strip.position.y + 112)
			draw_string(font, pos + Vector2(4, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UiKit.CINNABAR, a))
			draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UiKit.INK, a))
		# The sun glyph above the strip, with twenty count marks around it.
		var s := clampf((_t - 0.15) / 0.6, 0.0, 1.0)
		if s > 0.0:
			var c := Vector2(strip.get_center().x, 96)
			var r := 58.0 * (0.7 + 0.3 * s)
			for k in 20:
				var ang := TAU * k / 20.0 - PI / 2.0
				var d := Vector2(cos(ang), sin(ang))
				draw_line(c + d * (r + 8), c + d * (r + 22), UiKit.INK, 8.0, true)
				draw_line(c + d * (r + 9), c + d * (r + 21), UiKit.OCHRE, 4.0, true)
			UiKit.draw_kin(self, c, r, 1.0, 4.0)

# ============================================================ sun meter ===

## The HUD's centrepiece: the k'in sun glyph is the Sunstone's charge. Twenty
## count marks ring it and go dark as the light drains; at night, with the
## light failing, a jaguar's eyes open beneath it as the pack closes in.
class SunMeter:
	extends Control
	var light := 1.0
	var night := 0.0
	var gap := 24.0
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(150, 190)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, 66)
		var r := 36.0
		var lit := ceili(light * 20.0 - 0.001)
		for k in 20:
			var ang := TAU * k / 20.0 - PI / 2.0
			var d := Vector2(cos(ang), sin(ang))
			if k < lit:
				draw_line(c + d * (r + 6), c + d * (r + 22), UiKit.INK, 9.0, true)
				draw_line(c + d * (r + 7), c + d * (r + 21), UiKit.OCHRE, 4.5, true)
			else:
				draw_line(c + d * (r + 9), c + d * (r + 18), Color(UiKit.INK, 0.55), 4.0, true)
		UiKit.draw_kin(self, c, r, clampf(light * 1.4, 0.15, 1.0), 3.5)
		if light < 0.35:
			# Failing: a cinnabar ring beats around the glyph.
			var beat := 0.5 + 0.5 * sin(_t * 9.0)
			draw_arc(c, r + 28, 0.0, TAU, 48, Color(UiKit.CINNABAR, 0.45 + 0.4 * beat), 4.0, true)
		var near := clampf((14.0 - gap) / 10.0, 0.0, 1.0)
		if near > 0.0:
			# Jaguar eyes: almond shapes, gold, with slit pupils.
			var ey := c.y + r + 54
			var open := near * (0.75 + 0.25 * sin(_t * 3.0))
			for side in [-1.0, 1.0]:
				var ec := Vector2(c.x + side * 22.0, ey)
				var eye := UiKit.ellipse(ec, 15.0, maxf(7.5 * open, 0.5), side * 0.25, 18)
				draw_colored_polygon(eye, Color(UiKit.OCHRE_LIGHT, near))
				draw_polyline(UiKit.closed(eye), Color(UiKit.INK, near), 3.0, true)
				draw_line(ec + Vector2(0, -6 * open), ec + Vector2(0, 6 * open), Color(UiKit.INK, near), 3.5, true)

# ============================================================== glyphs ===

## A sun-drop as a small glyph: a gold k'in sun with no paper behind it.
class DropGlyph:
	extends Control
	func _init(px := 36.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var r := size.x / 2.0 - 1.5
		draw_circle(c, r, UiKit.OCHRE, true, -1.0, true)
		for k in 4:
			var a := PI / 4.0 + k * PI / 2.0
			draw_colored_polygon(UiKit.ellipse(c + Vector2(cos(a), sin(a)) * r * 0.4, r * 0.33, r * 0.2, a, 12), UiKit.OCHRE_LIGHT)
		draw_arc(c, r, 0.0, TAU, 28, UiKit.INK, 3.0, true)

## A slip of paper with an inked line of text — for small notes over the world.
## With [maya] >= 0 the number is also written in Maya numerals at the right.
class PaperSlip:
	extends Control
	var text := ""
	var maya := -1
	var _label: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _ready() -> void:
		_label = UiKit.label("", UiKit.text_font(900), 28, UiKit.INK)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
		resized.connect(func(): set_text(text, maya))
		set_text(text, maya)

	func set_text(t: String, m := -1) -> void:
		text = t
		maya = m
		if _label:
			_label.text = t
			_label.position = Vector2(14, 0)
			_label.size = Vector2(size.x - 28.0 - (44.0 if m >= 0 else 0.0), size.y)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var edge := UiKit.torn(r, 57, 1.4)
		var shadow := PackedVector2Array()
		for p in edge:
			shadow.append(p + Vector2(0, 6))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
		UiKit.draw_paper(self, edge)
		UiKit.draw_rule(self, Vector2(10, 7), Vector2(size.x - 10, 7), UiKit.CINNABAR, 2.5, 9)
		UiKit.draw_rule(self, Vector2(10, size.y - 7), Vector2(size.x - 10, size.y - 7), UiKit.CINNABAR, 2.5, 11)
		if maya >= 0:
			var u := 4.5
			var h := UiKit.maya_height(maya, u)
			UiKit.draw_maya_number(self, Vector2(size.x - 46.0, (size.y - h) / 2.0), maya, u, UiKit.CINNABAR)

# =============================================================== toggle ===

## A labelled setting: a small glyph block that shows the sun when it's on and
## a red stroke through it when it's off. Tap anywhere on the row.
class Toggle:
	extends Control
	signal toggled(on: bool)
	var on := true
	var _text := ""

	func _init(t: String, value: bool) -> void:
		_text = t
		on = value
		custom_minimum_size = Vector2(440, 76)
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _ready() -> void:
		var l := UiKit.label(_text, UiKit.text_font(900), 32, UiKit.INK)
		l.position = Vector2(4, 16)
		add_child(l)

	func _draw() -> void:
		var box := Rect2(Vector2(size.x - 66, 8), Vector2(60, 60))
		var face := UiKit.glyph_block(box, 77)
		UiKit.draw_paper(self, face, Color(1, 1, 1) if on else Color(0.88, 0.84, 0.78))
		UiKit.draw_ink(self, face, UiKit.INK, 3.5)
		if on:
			UiKit.draw_kin(self, box.get_center(), 19.0, 1.0, 2.5, false)
		else:
			draw_line(box.position + Vector2(14, box.size.y - 14), box.position + Vector2(box.size.x - 14, 14), UiKit.CINNABAR, 6.0, true)

	func _gui_input(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and not event.pressed:
			on = not on
			queue_redraw()
			toggled.emit(on)
			accept_event()

# ========================================================= danger flash ===

## A cinnabar wash from the screen edges — a stumble or a crash.
class DangerFlash:
	extends Control
	var strength := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func flash() -> void:
		strength = 1.0
		queue_redraw()

	func _process(delta: float) -> void:
		if strength > 0.0:
			strength = maxf(strength - delta * 1.8, 0.0)
			queue_redraw()

	func _draw() -> void:
		if strength <= 0.0:
			return
		var c := Color(UiKit.CINNABAR, 0.6 * strength)
		var clear := Color(UiKit.CINNABAR, 0.0)
		var w := size.x
		var h := size.y
		var e := 150.0
		for quad in [
			[Vector2(0, 0), Vector2(w, 0), Vector2(w - e, e), Vector2(e, e)],
			[Vector2(0, h), Vector2(e, h - e), Vector2(w - e, h - e), Vector2(w, h)],
			[Vector2(0, 0), Vector2(e, e), Vector2(e, h - e), Vector2(0, h)],
			[Vector2(w, 0), Vector2(w - e, e), Vector2(w - e, h - e), Vector2(w, h)],
		]:
			draw_polygon(PackedVector2Array(quad), PackedColorArray([c, c, clear, clear]) if quad[0].y == 0 and quad[1].y == 0 else PackedColorArray([c, clear, clear, c]))

# ========================================================== hint strip ===

## A codex strip naming the move: "Swipe up to jump", with an inked gesture —
## a brush chevron for swipes, ripples for a tap.
class HintStrip:
	extends Control
	var _dir := Vector2.UP
	var _t := 0.0
	var _life := 0.0
	var _label: Label

	func _init() -> void:
		custom_minimum_size = Vector2(540, 112)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.0
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _ready() -> void:
		_label = UiKit.wrapped("", UiKit.text_font(900), 30, UiKit.INK, Vector2(116, 0), size.x - 134, size.y)
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)

	func show_hint(text: String, dir: Vector2) -> void:
		_label.text = text
		_dir = dir
		_life = 2.4
		_t = 0.0

	## Fades out now — the player already did what it asked.
	func dismiss() -> void:
		_life = minf(_life, 0.3)

	func _process(delta: float) -> void:
		if _life > 0.0:
			_life -= delta
			_t += delta
			modulate.a = clampf(minf(_t / 0.15, _life / 0.3), 0.0, 1.0)
			queue_redraw()
		elif modulate.a > 0.0:
			modulate.a = 0.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var edge := UiKit.torn(r, 63, 1.6)
		var shadow := PackedVector2Array()
		for p in edge:
			shadow.append(p + Vector2(0, 7))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.32))
		UiKit.draw_paper(self, edge)
		UiKit.draw_rule(self, Vector2(12, 9), Vector2(size.x - 12, 9), UiKit.CINNABAR, 3.0, 13)
		UiKit.draw_rule(self, Vector2(12, size.y - 9), Vector2(size.x - 12, size.y - 9), UiKit.CINNABAR, 3.0, 17)
		UiKit.draw_rule(self, Vector2(102, 18), Vector2(102, size.y - 18), UiKit.CINNABAR, 2.0, 19)
		var c := Vector2(54, size.y / 2.0)
		var travel := fmod(_t * 1.5, 1.0)
		if _dir == Vector2.ZERO:
			# A tap: ink ripples spreading from a fingertip dot.
			draw_circle(c, 9.0, UiKit.INK, true, -1.0, true)
			for k in 2:
				var p := fmod(travel + k * 0.5, 1.0)
				draw_arc(c, 12.0 + p * 26.0, 0.0, TAU, 32, Color(UiKit.INK, 1.0 - p), 4.0, true)
			return
		var d := _dir.normalized()
		var n := d.orthogonal()
		for k in 2:
			var p := fmod(travel + k * 0.5, 1.0)
			var tip := c + d * (-16.0 + 32.0 * p)
			var col := Color(UiKit.INK if k == 0 else UiKit.CINNABAR, 1.0 - p * 0.7)
			draw_polyline(PackedVector2Array([tip - d * 11 + n * 16, tip + d * 6, tip - d * 11 - n * 16]), col, 8.0, true)
