class_name UiKit
## The Sunstone design system in code: palette, type, and the stepped-corner
## components every screen is built from. See DESIGN.md.
##
## Stepped corners (temple steps) are the signature shape — no plain rounded
## rectangles anywhere. Everything is drawn, nothing is a stock widget skin.

const MAYA_BLUE := Color("#3FA7B5")
const CINNABAR := Color("#B8322A")
const JADE := Color("#0E3B33")
const JADE_LIGHT := Color("#1C5A4E")
const GOLD := Color("#F4B732")
const GOLD_DEEP := Color("#B9801A")
const DUSK := Color("#2A1B3D")
const LIMESTONE := Color("#EDE6D6")
const INK := Color("#1A120C")

static var _display: FontFile
static var _text := {}

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

## "1240" → "1,240".
static func thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out

## The stepped outline of [rect]: two steps of [step] at every corner.
static func stepped(rect: Rect2, step: float) -> PackedVector2Array:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	var s := step
	return PackedVector2Array([
		Vector2(x, y + 2 * s), Vector2(x + s, y + 2 * s), Vector2(x + s, y + s), Vector2(x + 2 * s, y + s), Vector2(x + 2 * s, y),
		Vector2(x + w - 2 * s, y), Vector2(x + w - 2 * s, y + s), Vector2(x + w - s, y + s), Vector2(x + w - s, y + 2 * s), Vector2(x + w, y + 2 * s),
		Vector2(x + w, y + h - 2 * s), Vector2(x + w - s, y + h - 2 * s), Vector2(x + w - s, y + h - s), Vector2(x + w - 2 * s, y + h - s), Vector2(x + w - 2 * s, y + h),
		Vector2(x + 2 * s, y + h), Vector2(x + 2 * s, y + h - s), Vector2(x + s, y + h - s), Vector2(x + s, y + h - 2 * s), Vector2(x, y + h - 2 * s),
	])

static func draw_stepped(ci: CanvasItem, rect: Rect2, step: float, fill: Color, trim := Color(0, 0, 0, 0), trim_inset := 6.0, trim_width := 2.0) -> void:
	ci.draw_colored_polygon(stepped(rect, step), fill)
	if trim.a > 0.0:
		var inner := stepped(rect.grow(-trim_inset), maxf(step - trim_inset * 0.35, 2.0))
		inner.append(inner[0])
		ci.draw_polyline(inner, trim, trim_width, true)

# ================================================================ slab ===

## A carved panel: deep jade face with a Maya-blue inset trim line.
class Slab:
	extends Control
	var step := 14.0
	var fill := UiKit.JADE
	var trim := UiKit.MAYA_BLUE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP # panels swallow taps

	func _draw() -> void:
		# A soft drop "shadow" one step down grounds the slab on the scene.
		UiKit.draw_stepped(self, Rect2(Vector2(0, 8), size), step, Color(0, 0, 0, 0.28))
		UiKit.draw_stepped(self, Rect2(Vector2.ZERO, size), step, fill, trim, 9.0, 2.0)

# ============================================================== button ===

## A slab button that presses down into its lip. GOLD is the primary action.
class SlabButton:
	extends Control
	signal pressed

	enum Kind { GOLD, JADE }

	var text := ""
	var kind := Kind.GOLD
	var font_size := 34
	var _down := false
	var _label: Label
	const LIP := 7.0

	func _init(t := "", k := Kind.GOLD) -> void:
		text = t
		kind = k
		custom_minimum_size = Vector2(200, 92)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE

	func _ready() -> void:
		var color := UiKit.INK if kind == Kind.GOLD else UiKit.LIMESTONE
		_label = UiKit.label(text, UiKit.text_font(900), font_size, color)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
		resized.connect(_layout)
		_layout()

	func _layout() -> void:
		var drop := LIP if _down else 0.0
		_label.position = Vector2(0, drop)
		_label.size = Vector2(size.x, size.y - LIP)

	func _draw() -> void:
		var face := UiKit.GOLD if kind == Kind.GOLD else UiKit.JADE_LIGHT
		var lip := UiKit.GOLD_DEEP if kind == Kind.GOLD else UiKit.JADE
		var face_rect := Rect2(Vector2(0, LIP if _down else 0.0), Vector2(size.x, size.y - LIP))
		if not _down:
			UiKit.draw_stepped(self, Rect2(Vector2(0, LIP), Vector2(size.x, size.y - LIP)), 10.0, lip)
		UiKit.draw_stepped(self, face_rect, 10.0, face)
		if kind == Kind.JADE:
			var inner := UiKit.stepped(face_rect.grow(-5), 7.0)
			inner.append(inner[0])
			draw_polyline(inner, UiKit.MAYA_BLUE, 2.0, true)

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

## A square stepped button with a drawn pictogram.
class IconButton:
	extends Control
	signal pressed

	enum Icon { PAUSE, GEAR, CLOSE }

	var icon := Icon.PAUSE
	var _down := false

	func _init(i := Icon.PAUSE) -> void:
		icon = i
		custom_minimum_size = Vector2(84, 84)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var off := 4.0 if _down else 0.0
		UiKit.draw_stepped(self, Rect2(Vector2(0, 5), size - Vector2(0, 5)), 9.0, Color(0, 0, 0, 0.3))
		var r := Rect2(Vector2(0, off), size - Vector2(0, 5))
		UiKit.draw_stepped(self, r, 9.0, UiKit.JADE, UiKit.MAYA_BLUE, 5.0, 2.0)
		var c := r.get_center()
		match icon:
			Icon.PAUSE:
				for dx in [-10.0, 10.0]:
					draw_rect(Rect2(c + Vector2(dx - 5, -15), Vector2(10, 30)), UiKit.LIMESTONE)
			Icon.GEAR:
				# A sun-wheel: stepped rays around a hub (doubles as the brand sun).
				for k in 8:
					var a := TAU * k / 8.0
					var d := Vector2(cos(a), sin(a))
					var p := Vector2(-d.y, d.x)
					draw_colored_polygon(PackedVector2Array([
						c + d * 12 + p * 5, c + d * 22 + p * 4, c + d * 22 - p * 4, c + d * 12 - p * 5]), UiKit.LIMESTONE)
				draw_circle(c, 13.0, UiKit.LIMESTONE)
				draw_circle(c, 6.0, UiKit.JADE)
			Icon.CLOSE:
				draw_line(c + Vector2(-13, -13), c + Vector2(13, 13), UiKit.LIMESTONE, 6.0)
				draw_line(c + Vector2(13, -13), c + Vector2(-13, 13), UiKit.LIMESTONE, 6.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			_down = event.pressed
			queue_redraw()
			if not event.pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
			accept_event()

# ============================================================ wordmark ===

## SUNSTONE, carved: a stepped extrusion in deep gold under an idol-gold face,
## with the sun glyph rising behind it. Settles into place once.
class Wordmark:
	extends Control
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(640, 260)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Plays the settle again (each time the title screen appears).
	func replay() -> void:
		_t = 0.0

	func _process(delta: float) -> void:
		if _t < 1.0:
			_t = minf(_t + delta / 0.9, 1.0)
			queue_redraw()

	func _draw() -> void:
		var e := 1.0 - pow(1.0 - _t, 3.0) # ease out
		var center := Vector2(size.x / 2.0, 92)
		# The sun glyph: a disc with eight stepped rays, behind the letters.
		var sun_r := 70.0 * (0.85 + 0.15 * e)
		var a := e
		for k in 8:
			var ang := TAU * k / 8.0 + PI / 8.0
			var d := Vector2(cos(ang), sin(ang))
			var p := Vector2(-d.y, d.x)
			var base := center + d * (sun_r - 4)
			draw_colored_polygon(PackedVector2Array([
				base + p * 16, base + d * 26 + p * 16, base + d * 26 + p * 8, base + d * 44 + p * 8,
				base + d * 44 - p * 8, base + d * 26 - p * 8, base + d * 26 - p * 16, base - p * 16]),
				Color(UiKit.CINNABAR, 0.9 * a))
		draw_circle(center, sun_r, Color(UiKit.GOLD_DEEP, a))
		draw_circle(center, sun_r - 12, Color(UiKit.GOLD, a))

		var font := UiKit.display_font()
		var fs := 84
		var text := "SUNSTONE"
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2((size.x - w) / 2.0, 150 + (1.0 - e) * 24.0)
		# Carved depth: stacked offsets in jade, then a gold face with an ink rim.
		for i in range(10, 0, -1):
			draw_string(font, pos + Vector2(i * 0.6, i), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UiKit.JADE, a))
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(UiKit.INK, a))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UiKit.LIMESTONE, a))
		# Maya-blue band under the name, like a painted lintel.
		var band := Rect2(Vector2((size.x - w) / 2.0, pos.y + 26), Vector2(w * e, 10))
		draw_rect(band, Color(UiKit.MAYA_BLUE, a))

# ============================================================ coin glyph ===

## The coin as a flat glyph: a faceted gold octagon with a bright heart.
class CoinGlyph:
	extends Control
	func _init(px := 34.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var r := size.x / 2.0
		var pts := PackedVector2Array()
		for k in 8:
			var a := TAU * k / 8.0 + PI / 8.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, UiKit.GOLD_DEEP)
		var inner := PackedVector2Array()
		for k in 8:
			var a := TAU * k / 8.0 + PI / 8.0
			inner.append(c + Vector2(cos(a), sin(a)) * r * 0.78)
		draw_colored_polygon(inner, UiKit.GOLD)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.32), c + Vector2(r * 0.32, 0), c + Vector2(0, r * 0.32), c + Vector2(-r * 0.32, 0)]), Color("#FFF2C4"))

# =============================================================== toggle ===

## A labelled on/off row: tap anywhere on it.
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

	func _ready() -> void:
		var l := UiKit.label(_text, UiKit.text_font(800), 30, UiKit.LIMESTONE)
		l.position = Vector2(4, 18)
		add_child(l)

	func _draw() -> void:
		var track := Rect2(Vector2(size.x - 112, 16), Vector2(108, 46))
		UiKit.draw_stepped(self, track, 7.0, UiKit.MAYA_BLUE if on else Color(UiKit.JADE_LIGHT, 1.0))
		var knob_x := track.position.x + (track.size.x - 46 if on else 0.0)
		UiKit.draw_stepped(self, Rect2(Vector2(knob_x, track.position.y), Vector2(46, 46)), 7.0, UiKit.LIMESTONE)

	func _gui_input(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and not event.pressed:
			on = not on
			queue_redraw()
			toggled.emit(on)
			accept_event()

# ========================================================= danger flash ===

## Cinnabar glow from the screen edges — a stumble or a crash.
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

# =========================================================== hint toast ===

## "Swipe up to jump", with an animated stepped chevron showing the swipe.
class HintToast:
	extends Control
	var _dir := Vector2.UP
	var _t := 0.0
	var _life := 0.0
	var _label: Label

	func _init() -> void:
		custom_minimum_size = Vector2(500, 120)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.0

	func _ready() -> void:
		_label = UiKit.label("", UiKit.text_font(900), 32, UiKit.LIMESTONE)
		_label.position = Vector2(110, 0)
		_label.size = Vector2(size.x - 130, size.y - 8)
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)

	func show_hint(text: String, dir: Vector2) -> void:
		_label.text = text
		_dir = dir
		_life = 2.2
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
		UiKit.draw_stepped(self, Rect2(Vector2.ZERO, size - Vector2(0, 8)), 10.0, Color(UiKit.JADE, 0.92), UiKit.MAYA_BLUE, 6.0, 2.0)
		# A chevron travelling in the swipe direction, repeating.
		var c := Vector2(56, (size.y - 8) / 2.0)
		var travel := fmod(_t * 1.6, 1.0)
		var d := _dir.normalized()
		var p := Vector2(-d.y, d.x)
		var tip := c + d * (-12.0 + 24.0 * travel)
		var col := Color(UiKit.GOLD, 1.0 - travel * 0.6)
		draw_colored_polygon(PackedVector2Array([tip + d * 14, tip - d * 2 + p * 18, tip - d * 10 + p * 18, tip + d * 4, tip - d * 10 - p * 18, tip - d * 2 - p * 18]), col)
