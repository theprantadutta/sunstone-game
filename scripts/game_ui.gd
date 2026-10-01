class_name GameUI
extends CanvasLayer
## Every screen, composed from UiKit's codex pieces: title, HUD, pause,
## settings, results. The 3D world is always the background; menus are codex
## pages that unfold over it.
##
## Layout is anchor-based throughout, so it holds on any aspect ratio (tall
## 20:9 phones included) and re-flows if the window changes size.

signal run_pressed
signal pause_pressed
signal resume_pressed
signal home_pressed
signal again_pressed
signal settings_changed
signal back_requested

var _save: SaveData
var _top := 28.0 ## below the status bar / camera cutout

var _title: Control
var _wordmark: UiKit.Wordmark
var _best: UiKit.PaperSlip
var _hud: Control
var _distance: Label
var _drops: Label
var _meter: UiKit.SunMeter
var _hint: UiKit.HintStrip
var _danger: UiKit.DangerFlash
var _pause: Control
var _settings: Control
var _results: Control
var _records: Control
var _dark: TextureRect
var _flare_rect: ColorRect

## A freehand cinnabar rule between two registers of a page.
class Rule:
	extends Control
	var seed := 0
	func _init(s := 0) -> void:
		seed = s
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		UiKit.draw_rule(self, Vector2(0, size.y / 2.0), Vector2(size.x, size.y / 2.0), UiKit.CINNABAR, 3.0, seed)

## A number written in Maya bar-and-dot numerals.
class MayaNumber:
	extends Control
	var value := 0
	var unit := 9.0
	var color := UiKit.CINNABAR
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_value(v: int) -> void:
		value = v
		queue_redraw()
	func _draw() -> void:
		UiKit.draw_maya_number(self, Vector2.ZERO, value, unit, color)

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_top = _safe_top() + 28.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BACK:
		_back()
		get_viewport().set_input_as_handled()

## Android delivers one press of back both as a key and as a request, and a
## heavy frame (rebuilding the world) can push the second a frame or more
## later. Count it once: ignore anything within a few frames or 300 ms.
var _last_back := -1000
var _last_back_frame := -1000
func _back() -> void:
	var now := Time.get_ticks_msec()
	var frame := Engine.get_process_frames()
	if now - _last_back < 300 or frame - _last_back_frame <= 4:
		return
	_last_back = now
	_last_back_frame = frame
	back_requested.emit()

## Closes whichever title page is open (settings, records...); true when one was.
func close_modal() -> bool:
	for page in [_settings, _records]:
		if page and is_instance_valid(page) and page.visible:
			page.visible = false
			return true
	return false

func setup(save: SaveData) -> void:
	_save = save
	_build_title()
	_build_hud()
	_danger = UiKit.DangerFlash.new()
	_root().add_child(_danger)
	_danger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Darkness at the edges: a radial vignette, faded in as the light fails.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.02, 0.06, 0.0))
	grad.set_color(1, Color(0.02, 0.02, 0.06, 0.95))
	grad.add_point(0.55, Color(0.02, 0.02, 0.06, 0.15))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.55)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	_dark = TextureRect.new()
	_dark.texture = tex
	_dark.stretch_mode = TextureRect.STRETCH_SCALE
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark.modulate.a = 0.0
	_root().add_child(_dark)
	_root().move_child(_dark, 0)
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flare_rect = ColorRect.new()
	_flare_rect.color = Color("#FFE6A8")
	_flare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flare_rect.modulate.a = 0.0
	_root().add_child(_flare_rect)
	_flare_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The camera-cutout inset, in UI units.
func _safe_top() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var vp := get_viewport().get_visible_rect().size
	if screen.y <= 0 or OS.get_name() != "Android":
		return 0.0
	return safe.position.y * vp.y / float(screen.y)

var _root_control: Control
func _root() -> Control:
	if _root_control == null:
		_root_control = Control.new()
		_root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_root_control)
		_root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return _root_control

## A full-screen screen layer.
func _layer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root().add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

## Pins [c] by anchors (0..1 of the parent) plus pixel offsets.
static func _pin(c: Control, anchors: Rect2, offsets: Rect2) -> void:
	c.anchor_left = anchors.position.x
	c.anchor_top = anchors.position.y
	c.anchor_right = anchors.position.x + anchors.size.x
	c.anchor_bottom = anchors.position.y + anchors.size.y
	c.offset_left = offsets.position.x
	c.offset_top = offsets.position.y
	c.offset_right = offsets.position.x + offsets.size.x
	c.offset_bottom = offsets.position.y + offsets.size.y

const TOP_LEFT := Rect2(0, 0, 0, 0)
const TOP_RIGHT := Rect2(1, 0, 0, 0)
const TOP_CENTER := Rect2(0.5, 0, 0, 0)
const BOTTOM_CENTER := Rect2(0.5, 1, 0, 0)
const CENTER := Rect2(0.5, 0.5, 0, 0)

func _hide_all() -> void:
	for c in [_title, _hud, _pause, _settings, _results]:
		if c:
			c.visible = false

# ---------------------------------------------------------------- title ---

func _build_title() -> void:
	_title = _layer()
	_wordmark = UiKit.Wordmark.new()
	_title.add_child(_wordmark)
	_pin(_wordmark, TOP_CENTER, Rect2(-320, _top + 6, 640, 300))

	var run := UiKit.GlyphButton.new("Run", UiKit.GlyphButton.Kind.PRIMARY)
	run.font_size = 48
	_title.add_child(run)
	_pin(run, BOTTOM_CENTER, Rect2(-200, -400, 400, 128))
	run.pressed.connect(func(): run_pressed.emit())

	_best = UiKit.PaperSlip.new()
	_title.add_child(_best)
	_pin(_best, BOTTOM_CENTER, Rect2(-200, -254, 400, 70))

	# The menu: one glyph per page of the codex, labelled underneath.
	var menu := [[UiKit.GlyphIcon.Icon.RECORDS, "Records", _open_records]]
	var gap := 128.0
	var x0 := -gap * (menu.size() - 1) / 2.0
	for i in menu.size():
		var item: Array = menu[i]
		var b := UiKit.GlyphIcon.new(item[0])
		_title.add_child(b)
		_pin(b, BOTTOM_CENTER, Rect2(x0 + gap * i - 42, -158, 84, 84))
		b.pressed.connect(item[2])
		var l := UiKit.label(item[1], UiKit.text_font(900), 24, UiKit.STUCCO, 8)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title.add_child(l)
		_pin(l, BOTTOM_CENTER, Rect2(x0 + gap * i - 70, -70, 140, 34))

	var gear := UiKit.GlyphIcon.new(UiKit.GlyphIcon.Icon.SETTINGS)
	_title.add_child(gear)
	_pin(gear, TOP_RIGHT, Rect2(-108, _top, 84, 84))
	gear.pressed.connect(_open_settings)

func show_title(save: SaveData) -> void:
	_hide_all()
	if save.best > 0:
		_best.set_text("Best %s m" % UiKit.thousands(save.best), save.best)
	else:
		_best.set_text("Outrun the stone jaguars")
	_title.visible = true
	_wordmark.replay()

# ------------------------------------------------------------------ hud ---

func _build_hud() -> void:
	_hud = _layer()
	_distance = UiKit.label("0 m", UiKit.display_font(), 52, UiKit.STUCCO, 12)
	_hud.add_child(_distance)
	_pin(_distance, TOP_LEFT, Rect2(28, _top - 6, 320, 80))

	var glyph := UiKit.DropGlyph.new(34)
	_hud.add_child(glyph)
	_pin(glyph, TOP_LEFT, Rect2(32, _top + 80, 34, 34))
	_drops = UiKit.label("0", UiKit.text_font(900), 34, UiKit.OCHRE_LIGHT, 10)
	_hud.add_child(_drops)
	_pin(_drops, TOP_LEFT, Rect2(76, _top + 70, 200, 50))

	_meter = UiKit.SunMeter.new()
	_hud.add_child(_meter)
	_pin(_meter, TOP_CENTER, Rect2(-75, _top - 10, 150, 190))

	var pause := UiKit.GlyphIcon.new(UiKit.GlyphIcon.Icon.PAUSE)
	_hud.add_child(pause)
	_pin(pause, TOP_RIGHT, Rect2(-108, _top, 84, 84))
	pause.pressed.connect(func(): pause_pressed.emit())

	_hint = UiKit.HintStrip.new()
	_hud.add_child(_hint)
	_pin(_hint, Rect2(0.5, 0.62, 0, 0), Rect2(-270, 0, 540, 112))

func show_hud() -> void:
	_hide_all()
	_hud.visible = true

func set_run_numbers(metres: int, drop_count: int) -> void:
	_distance.text = "%s m" % UiKit.thousands(metres)
	_drops.text = str(drop_count)

## The Sunstone's charge, how far night has fallen, and how close the jaguars are.
func set_light(value: float, night: float, chaser_gap: float) -> void:
	_meter.light = value
	_meter.night = night
	_meter.gap = chaser_gap
	# The world closes in from the edges as the light fails at night.
	_dark.modulate.a = clampf((0.45 - value) / 0.45, 0.0, 1.0) * lerpf(0.5, 0.9, night)

func show_hint(text: String, dir: Vector2) -> void:
	_hint.show_hint(text, dir)

func dismiss_hint() -> void:
	_hint.dismiss()

func flash_danger() -> void:
	_danger.flash()

## A warm white burst for the flare.
func flash_flare() -> void:
	_flare_rect.modulate.a = 0.55
	var tw := create_tween()
	tw.tween_property(_flare_rect, "modulate:a", 0.0, 0.45)

# ---------------------------------------------------------------- pages ---

## A dimmed backdrop plus a centred codex page; returns [layer, page].
func _modal(height: float, dim := 0.55) -> Array:
	var root := _layer()
	var shade := ColorRect.new()
	shade.color = Color(UiKit.NIGHT, dim)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := UiKit.Page.new()
	root.add_child(page)
	_pin(page, CENTER, Rect2(-300, -height / 2.0, 600, height))
	return [root, page]

func _headline(page: Control, text: String) -> void:
	var l := UiKit.label(text, UiKit.display_font(), 46, UiKit.INK)
	l.position = Vector2(56, 44)
	page.add_child(l)
	_rule(page, 122, 1)

func _rule(page: Control, y: float, seed: int) -> void:
	var r := Rule.new(seed)
	r.position = Vector2(48, y - 6)
	r.size = Vector2(504, 12)
	page.add_child(r)

func _settings_rows(page: Control, y: float) -> float:
	var i := 0
	for row in [["Music", "music"], ["Sound", "sound"], ["Vibration", "vibration"]]:
		var key: String = row[1]
		var t := UiKit.Toggle.new(row[0], _save.get(key))
		t.position = Vector2(56, y)
		t.size = Vector2(488, 76)
		t.toggled.connect(func(on: bool):
			_save.set(key, on)
			settings_changed.emit())
		page.add_child(t)
		y += 84
		i += 1
	_rule(page, y + 8, 7)
	return y + 16

func show_pause() -> void:
	_hide_all()
	if _pause:
		_pause.queue_free()
	var m := _modal(720)
	_pause = m[0]
	var page: UiKit.Page = m[1]
	_headline(page, "Paused")
	var y := _settings_rows(page, 140)
	var resume := UiKit.GlyphButton.new("Resume", UiKit.GlyphButton.Kind.PRIMARY)
	resume.position = Vector2(56, y + 18)
	resume.size = Vector2(488, 112)
	resume.pressed.connect(func(): resume_pressed.emit())
	page.add_child(resume)
	var home := UiKit.GlyphButton.new("Home", UiKit.GlyphButton.Kind.SECONDARY)
	home.font_size = 30
	home.position = Vector2(56, y + 140)
	home.size = Vector2(488, 96)
	home.pressed.connect(func(): home_pressed.emit())
	page.add_child(home)
	page.open()

func _open_settings() -> void:
	if _settings:
		_settings.queue_free()
	var m := _modal(580)
	_settings = m[0]
	var page: UiKit.Page = m[1]
	_headline(page, "Settings")
	var y := _settings_rows(page, 140)
	var done := UiKit.GlyphButton.new("Done", UiKit.GlyphButton.Kind.PRIMARY)
	done.position = Vector2(56, y + 18)
	done.size = Vector2(488, 112)
	done.pressed.connect(func(): _settings.visible = false)
	page.add_child(done)
	page.open()

# -------------------------------------------------------------- records ---

## How deep into the night a run reached, in words.
static func night_name(d: float) -> String:
	if d < 0.3:
		return "Sunset"
	if d < 0.6:
		return "Twilight"
	if d < 0.9:
		return "Moonrise"
	return "Deep night"

static func duration_text(seconds: float) -> String:
	var m := int(seconds / 60.0)
	if m < 60:
		return "%d min" % m
	return "%d h %d min" % [m / 60, m % 60]

## The record book: every count the codex keeps, one register per line.
func _open_records() -> void:
	if _records:
		_records.queue_free()
	var rows := [
		["Best distance", "%s m" % UiKit.thousands(_save.best)],
		["Runs", UiKit.thousands(_save.runs)],
		["Distance run", "%.1f km" % (_save.total_distance / 1000.0)],
		["Sun-drops gathered", UiKit.thousands(_save.total_drops)],
		["Most in one run", UiKit.thousands(_save.best_drops)],
		["Flares", UiKit.thousands(_save.flares)],
		["Deepest night", night_name(_save.deepest_dusk) if _save.runs > 0 else "-"],
		["Time in the temple", duration_text(_save.play_seconds)],
	]
	var top := _save.most_common_death()
	var height := 210.0 + rows.size() * 64.0 + (96.0 if top != "" else 0.0) + 150.0
	var m := _modal(height)
	_records = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 29
	_headline(page, "Records")
	var y := 146.0
	for row in rows:
		var name_l := UiKit.label(row[0], UiKit.text_font(900), 28, UiKit.INK)
		name_l.position = Vector2(58, y)
		page.add_child(name_l)
		var val := UiKit.label(row[1], UiKit.display_font(), 28, UiKit.CINNABAR if row[0] == "Best distance" else UiKit.INK)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.position = Vector2(300, y - 2)
		val.size = Vector2(244, 40)
		page.add_child(val)
		y += 64.0
	if top != "":
		_rule(page, y + 4, 31)
		var t := UiKit.label("Most runs end: %s" % top.to_lower(), UiKit.text_font(900), 26, UiKit.INK)
		t.position = Vector2(58, y + 24)
		t.size = Vector2(486, 60)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD
		page.add_child(t)
		y += 96.0
	var done := UiKit.GlyphButton.new("Done", UiKit.GlyphButton.Kind.PRIMARY)
	done.position = Vector2(56, y + 24)
	done.size = Vector2(488, 104)
	done.pressed.connect(func(): _records.visible = false)
	page.add_child(done)
	page.open()

# -------------------------------------------------------------- results ---

## The run, recorded as a codex entry: what ended it, the distance in our
## numerals and in Maya ones, the sun-drops gathered, and the way back in.
func show_results(cause: String, metres: int, drop_count: int, best: int, is_best: bool) -> void:
	_hide_all()
	if _results:
		_results.queue_free()
	_results = _layer()
	var shade := ColorRect.new()
	shade.color = Color(UiKit.NIGHT, 0.4)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_results.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var page := UiKit.Page.new()
	page.seed = 19
	_results.add_child(page)
	_pin(page, BOTTOM_CENTER, Rect2(-310, -760, 620, 700))

	var head := UiKit.label(cause, UiKit.display_font(), 38, UiKit.INK)
	head.position = Vector2(56, 44)
	head.size = Vector2(508, 100)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD
	page.add_child(head)
	_rule(page, 150, 21)

	var dist := UiKit.label("0 m", UiKit.display_font(), 92, UiKit.INK)
	dist.position = Vector2(52, 160)
	page.add_child(dist)
	var maya := MayaNumber.new()
	maya.position = Vector2(510, 176)
	maya.size = Vector2(40, 120)
	page.add_child(maya)

	var glyph := UiKit.DropGlyph.new(36)
	glyph.position = Vector2(58, 306)
	page.add_child(glyph)
	var drops := UiKit.label("+%d sun-drops" % drop_count, UiKit.text_font(900), 32, UiKit.INK)
	drops.position = Vector2(106, 298)
	page.add_child(drops)

	var best_l := UiKit.label("New best" if is_best else "Best %s m" % UiKit.thousands(best),
		UiKit.display_font() if is_best else UiKit.text_font(900), 30, UiKit.CINNABAR if is_best else UiKit.INK)
	best_l.position = Vector2(58, 352)
	page.add_child(best_l)
	_rule(page, 420, 23)

	var again := UiKit.GlyphButton.new("Run again", UiKit.GlyphButton.Kind.PRIMARY)
	again.position = Vector2(56, 444)
	again.size = Vector2(508, 116)
	again.pressed.connect(func(): again_pressed.emit())
	page.add_child(again)
	var home := UiKit.GlyphButton.new("Home", UiKit.GlyphButton.Kind.SECONDARY)
	home.font_size = 30
	home.position = Vector2(56, 574)
	home.size = Vector2(508, 96)
	home.pressed.connect(func(): home_pressed.emit())
	page.add_child(home)

	# The one orchestrated moment: the page unfolds, then the distance is
	# counted out — in both kinds of numerals.
	page.open()
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_method(func(v: float):
		dist.text = "%s m" % UiKit.thousands(int(v))
		maya.set_value(int(v)), 0.0, float(metres), 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
