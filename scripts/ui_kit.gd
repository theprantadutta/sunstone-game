class_name UiKit
## The Sunstone design system in code: palette, type, and the components every
## screen is built from. See DESIGN.md.
##
## Shape: polished stone — generous, smooth curves, chunky depth. Buttons are
## pills standing on a darker lip they press into, with a soft sheen on top;
## panels are deep rounded slabs. All curves are anti-aliased styleboxes.

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

## A rounded box: [fill] with corner [radius], optional [border], optional
## soft [shadow] (alpha) dropped [shadow_y] below. Anti-aliased.
static func round_box(fill: Color, radius: float, border := Color(0, 0, 0, 0), border_w := 0, shadow := 0.0, shadow_y := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 12
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.2
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	if shadow > 0.0:
		sb.shadow_color = Color(0, 0, 0, shadow)
		sb.shadow_size = 18
		sb.shadow_offset = Vector2(0, shadow_y)
	return sb

## A rim line just inside [rect] — the polished edge of a slab.
static func draw_rim(ci: CanvasItem, rect: Rect2, radius: float, color: Color, inset := 7.0, width := 2) -> void:
	var sb := round_box(Color(0, 0, 0, 0), maxf(radius - inset, 4.0), color, width)
	sb.draw_center = false
	ci.draw_style_box(sb, rect.grow(-inset))

## The sheen across the upper part of a face: light catching polished stone.
static func draw_sheen(ci: CanvasItem, rect: Rect2, radius: float, alpha := 0.2) -> void:
	var r := Rect2(rect.position + Vector2(6, 5), Vector2(rect.size.x - 12, rect.size.y * 0.42))
	var sb := round_box(Color(1, 1, 1, alpha), minf(radius - 4.0, r.size.y / 2.0))
	ci.draw_style_box(sb, r)

# ================================================================ slab ===

## A polished panel: deep jade, big soft corners, a Maya-blue rim, and a soft
## shadow that lifts it off the scene.
class Slab:
	extends Control
	var radius := 40.0
	var fill := UiKit.JADE
	var trim := UiKit.MAYA_BLUE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP # panels swallow taps

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(UiKit.round_box(fill, radius, Color(0, 0, 0, 0), 0, 0.4, 12.0), r)
		UiKit.draw_rim(self, r, radius, Color(trim, 0.75), 9.0, 2)

# ============================================================== button ===

## A pill button standing on a darker lip; pressing sinks it into the lip.
## GOLD is the primary action.
class SlabButton:
	extends Control
	signal pressed

	enum Kind { GOLD, JADE }

	var text := ""
	var kind := Kind.GOLD
	var font_size := 34
	var _down := false
	var _label: Label
	const LIP := 9.0

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
		var drop := LIP - 2.0 if _down else 0.0
		_label.position = Vector2(0, drop)
		_label.size = Vector2(size.x, size.y - LIP)

	func _draw() -> void:
		var face := UiKit.GOLD if kind == Kind.GOLD else UiKit.JADE_LIGHT
		var lip := UiKit.GOLD_DEEP if kind == Kind.GOLD else UiKit.JADE
		var h := size.y - LIP
		var radius := h / 2.0
		# Lip (with the drop shadow under it), then the face sitting on top.
		draw_style_box(UiKit.round_box(lip, radius, Color(0, 0, 0, 0), 0, 0.3, 6.0), Rect2(Vector2(0, LIP), Vector2(size.x, h)))
		var face_rect := Rect2(Vector2(0, LIP - 2.0 if _down else 0.0), Vector2(size.x, h))
		draw_style_box(UiKit.round_box(face, radius), face_rect)
		UiKit.draw_sheen(self, face_rect, radius, 0.28 if kind == Kind.GOLD else 0.1)
		if kind == Kind.JADE:
			UiKit.draw_rim(self, face_rect, radius, Color(UiKit.MAYA_BLUE, 0.8), 5.0, 2)

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

## A round button with a drawn pictogram, on the same lip as the pills.
class IconButton:
	extends Control
	signal pressed

	enum Icon { PAUSE, GEAR, CLOSE }

	var icon := Icon.PAUSE
	var _down := false
	const LIP := 6.0

	func _init(i := Icon.PAUSE) -> void:
		icon = i
		custom_minimum_size = Vector2(84, 84)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var d := size.y - LIP
		var radius := d / 2.0
		draw_style_box(UiKit.round_box(UiKit.JADE.darkened(0.35), radius, Color(0, 0, 0, 0), 0, 0.3, 5.0), Rect2(Vector2(0, LIP), Vector2(size.x, d)))
		var r := Rect2(Vector2(0, LIP - 1.0 if _down else 0.0), Vector2(size.x, d))
		draw_style_box(UiKit.round_box(UiKit.JADE, radius), r)
		UiKit.draw_sheen(self, r, radius, 0.08)
		UiKit.draw_rim(self, r, radius, Color(UiKit.MAYA_BLUE, 0.85), 5.0, 2)
		var c := r.get_center()
		match icon:
			Icon.PAUSE:
				for dx in [-9.0, 9.0]:
					draw_style_box(UiKit.round_box(UiKit.LIMESTONE, 4.0), Rect2(c + Vector2(dx - 5, -14), Vector2(10, 28)))
			Icon.GEAR:
				# A sun-wheel: tapered rays around a hub (doubles as the brand sun).
				for k in 8:
					var a := TAU * k / 8.0
					var dir := Vector2(cos(a), sin(a))
					var p := Vector2(-dir.y, dir.x)
					draw_colored_polygon(PackedVector2Array([c + dir * 11 + p * 5.5, c + dir * 23, c + dir * 11 - p * 5.5]), UiKit.LIMESTONE)
				draw_circle(c, 13.0, UiKit.LIMESTONE, true, -1.0, true)
				draw_circle(c, 6.0, UiKit.JADE, true, -1.0, true)
			Icon.CLOSE:
				draw_line(c + Vector2(-12, -12), c + Vector2(12, 12), UiKit.LIMESTONE, 6.0, true)
				draw_line(c + Vector2(12, -12), c + Vector2(-12, 12), UiKit.LIMESTONE, 6.0, true)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			_down = event.pressed
			queue_redraw()
			if not event.pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
			accept_event()

# ============================================================ wordmark ===

## SUNSTONE, carved: a deep jade extrusion under a limestone face,
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
		# The sun glyph: a disc with twelve tapered rays, behind the letters.
		var sun_r := 70.0 * (0.85 + 0.15 * e)
		var a := e
		for k in 12:
			var ang := TAU * k / 12.0 + PI / 12.0
			var d := Vector2(cos(ang), sin(ang))
			var p := Vector2(-d.y, d.x)
			var base := center + d * (sun_r - 6)
			var reach := 40.0 if k % 2 == 0 else 26.0
			draw_colored_polygon(PackedVector2Array([base + p * 13, base + d * reach, base - p * 13]), Color(UiKit.CINNABAR, 0.9 * a))
		draw_circle(center, sun_r, Color(UiKit.GOLD_DEEP, a), true, -1.0, true)
		draw_circle(center, sun_r - 12, Color(UiKit.GOLD, a), true, -1.0, true)
		draw_circle(center + Vector2(-sun_r * 0.25, -sun_r * 0.3), sun_r * 0.35, Color(1, 1, 1, 0.16 * a), true, -1.0, true)

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
		var band := Rect2(Vector2((size.x - w) / 2.0, pos.y + 26), Vector2(maxf(w * e, 10.0), 10))
		draw_style_box(UiKit.round_box(Color(UiKit.MAYA_BLUE, a), 5.0), band)

# ============================================================ coin glyph ===

## The coin as a flat glyph: a round gold coin with a rim and a bright heart.
class CoinGlyph:
	extends Control
	func _init(px := 34.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var r := size.x / 2.0
		draw_circle(c, r, UiKit.GOLD_DEEP, true, -1.0, true)
		draw_circle(c - Vector2(0, r * 0.06), r * 0.8, UiKit.GOLD, true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.34), c + Vector2(r * 0.3, 0), c + Vector2(0, r * 0.34), c + Vector2(-r * 0.3, 0)]), Color("#FFF2C4"))

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
		var track := Rect2(Vector2(size.x - 112, 16), Vector2(108, 48))
		draw_style_box(UiKit.round_box(UiKit.MAYA_BLUE if on else UiKit.JADE.darkened(0.3), 24.0, Color(0, 0, 0, 0.25), 2), track)
		var knob := Rect2(Vector2(track.position.x + (track.size.x - 44 if on else 4.0), track.position.y + 4), Vector2(40, 40))
		draw_style_box(UiKit.round_box(UiKit.LIMESTONE, 20.0, Color(0, 0, 0, 0), 0, 0.35, 3.0), knob)

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

## "Swipe up to jump", with an animated chevron showing the swipe.
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
		var r := Rect2(Vector2.ZERO, size - Vector2(0, 8))
		draw_style_box(UiKit.round_box(Color(UiKit.JADE, 0.92), r.size.y / 2.0, Color(0, 0, 0, 0), 0, 0.3, 6.0), r)
		UiKit.draw_rim(self, r, r.size.y / 2.0, Color(UiKit.MAYA_BLUE, 0.8), 6.0, 2)
		# A chevron travelling in the swipe direction, repeating.
		var c := Vector2(56, (size.y - 8) / 2.0)
		var travel := fmod(_t * 1.6, 1.0)
		var d := _dir.normalized()
		var p := Vector2(-d.y, d.x)
		var tip := c + d * (-12.0 + 24.0 * travel)
		var col := Color(UiKit.GOLD, 1.0 - travel * 0.6)
		draw_polyline(PackedVector2Array([tip - d * 8 + p * 16, tip + d * 8, tip - d * 8 - p * 16]), col, 9.0, true)
		draw_circle(tip + d * 8, 4.5, col, true, -1.0, true)
