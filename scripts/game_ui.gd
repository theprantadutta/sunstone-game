class_name GameUI
extends CanvasLayer
## Every screen, composed from UiKit: title, HUD, pause, settings, results.
## The 3D world is always the background; these are slabs laid over it.
##
## Layout is anchor-based throughout, so it holds on any aspect ratio (tall
## 20:9 phones included) and re-flows if the window changes size.

signal run_pressed
signal pause_pressed
signal resume_pressed
signal home_pressed
signal again_pressed
signal settings_changed

var _save: SaveData
var _top := 28.0 ## below the status bar / camera cutout

var _title: Control
var _wordmark: UiKit.Wordmark
var _best_label: Label
var _hud: Control
var _distance: Label
var _coins: Label
var _hint: UiKit.HintToast
var _danger: UiKit.DangerFlash
var _pause: Control
var _settings: Control
var _results: Control

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_top = _safe_top() + 28.0

func setup(save: SaveData) -> void:
	_save = save
	_build_title()
	_build_hud()
	_danger = UiKit.DangerFlash.new()
	_root().add_child(_danger)
	_danger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
const BOTTOM_WIDE := Rect2(0, 1, 1, 0)
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
	_pin(_wordmark, TOP_CENTER, Rect2(-320, _top + 30, 640, 260))

	var run := UiKit.SlabButton.new("Run", UiKit.SlabButton.Kind.GOLD)
	run.font_size = 44
	_title.add_child(run)
	_pin(run, BOTTOM_CENTER, Rect2(-210, -310, 420, 122))
	run.pressed.connect(func(): run_pressed.emit())

	_best_label = UiKit.label("", UiKit.text_font(800), 30, UiKit.LIMESTONE, 8)
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_child(_best_label)
	_pin(_best_label, BOTTOM_WIDE, Rect2(0, -172, 0, 44))

	var gear := UiKit.IconButton.new(UiKit.IconButton.Icon.GEAR)
	_title.add_child(gear)
	_pin(gear, TOP_RIGHT, Rect2(-112, _top, 84, 84))
	gear.pressed.connect(_open_settings)

func show_title(best: int) -> void:
	_hide_all()
	_best_label.text = "Best %s m" % UiKit.thousands(best) if best > 0 else "Outrun the stone jaguars"
	_title.visible = true
	_wordmark.replay()

# ------------------------------------------------------------------ hud ---

func _build_hud() -> void:
	_hud = _layer()
	_distance = UiKit.label("0 m", UiKit.display_font(), 54, UiKit.LIMESTONE, 12)
	_hud.add_child(_distance)
	_pin(_distance, TOP_LEFT, Rect2(30, _top - 8, 420, 80))

	var glyph := UiKit.CoinGlyph.new(34)
	_hud.add_child(glyph)
	_pin(glyph, TOP_LEFT, Rect2(34, _top + 80, 34, 34))
	_coins = UiKit.label("0", UiKit.text_font(900), 36, UiKit.GOLD, 10)
	_hud.add_child(_coins)
	_pin(_coins, TOP_LEFT, Rect2(78, _top + 70, 200, 50))

	var pause := UiKit.IconButton.new(UiKit.IconButton.Icon.PAUSE)
	_hud.add_child(pause)
	_pin(pause, TOP_RIGHT, Rect2(-112, _top, 84, 84))
	pause.pressed.connect(func(): pause_pressed.emit())

	_hint = UiKit.HintToast.new()
	_hud.add_child(_hint)
	_pin(_hint, Rect2(0.5, 0.62, 0, 0), Rect2(-250, 0, 500, 120))

func show_hud() -> void:
	_hide_all()
	_hud.visible = true

func set_run_numbers(metres: int, coin_count: int) -> void:
	_distance.text = "%s m" % UiKit.thousands(metres)
	_coins.text = str(coin_count)

func show_hint(text: String, dir: Vector2) -> void:
	_hint.show_hint(text, dir)

func flash_danger() -> void:
	_danger.flash()

# ----------------------------------------------------------- modal slab ---

## A dimmed backdrop plus a centred slab; returns [layer, slab].
func _modal(height: float, dim := 0.62) -> Array:
	var root := _layer()
	var shade := ColorRect.new()
	shade.color = Color(UiKit.DUSK, dim)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var slab := UiKit.Slab.new()
	root.add_child(slab)
	_pin(slab, CENTER, Rect2(-290, -height / 2.0, 580, height))
	return [root, slab]

func _settings_rows(parent: Control, y: float) -> float:
	for row in [["Music", "music"], ["Sound", "sound"], ["Vibration", "vibration"]]:
		var key: String = row[1]
		var t := UiKit.Toggle.new(row[0], _save.get(key))
		t.position = Vector2(54, y)
		t.size = Vector2(472, 76)
		t.toggled.connect(func(on: bool):
			_save.set(key, on)
			settings_changed.emit())
		parent.add_child(t)
		y += 84
	return y

func _headline(parent: Control, text: String, y: float, font_size := 52) -> void:
	var l := UiKit.label(text, UiKit.display_font(), font_size, UiKit.LIMESTONE)
	l.position = Vector2(54, y)
	parent.add_child(l)

# ---------------------------------------------------------------- pause ---

func show_pause() -> void:
	_hide_all()
	if _pause:
		_pause.queue_free()
	var m := _modal(700)
	_pause = m[0]
	var slab: Control = m[1]
	_headline(slab, "Paused", 44)
	var y := _settings_rows(slab, 150)
	var resume := UiKit.SlabButton.new("Resume", UiKit.SlabButton.Kind.GOLD)
	resume.position = Vector2(54, y + 26)
	resume.size = Vector2(472, 104)
	resume.pressed.connect(func(): resume_pressed.emit())
	slab.add_child(resume)
	var home := UiKit.SlabButton.new("Home", UiKit.SlabButton.Kind.JADE)
	home.position = Vector2(54, y + 144)
	home.size = Vector2(472, 92)
	home.pressed.connect(func(): home_pressed.emit())
	slab.add_child(home)

# ------------------------------------------------------------- settings ---

func _open_settings() -> void:
	if _settings:
		_settings.queue_free()
	var m := _modal(560)
	_settings = m[0]
	var slab: Control = m[1]
	_headline(slab, "Settings", 44)
	var y := _settings_rows(slab, 150)
	var done := UiKit.SlabButton.new("Done", UiKit.SlabButton.Kind.GOLD)
	done.position = Vector2(54, y + 26)
	done.size = Vector2(472, 104)
	done.pressed.connect(func(): _settings.visible = false)
	slab.add_child(done)

# -------------------------------------------------------------- results ---

func show_results(cause: String, metres: int, coin_count: int, best: int, is_best: bool) -> void:
	_hide_all()
	if _results:
		_results.queue_free()
	_results = _layer()
	var shade := ColorRect.new()
	shade.color = Color(UiKit.DUSK, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_results.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The slab is pinned to the bottom; it rises by animating a holder's offset.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results.add_child(holder)
	_pin(holder, BOTTOM_CENTER, Rect2(-330, -730, 660, 660))
	var slab := UiKit.Slab.new()
	slab.size = Vector2(660, 660)
	slab.position = Vector2(0, 760)
	holder.add_child(slab)

	var head := UiKit.label(cause, UiKit.display_font(), 40, UiKit.LIMESTONE)
	head.position = Vector2(54, 50)
	head.size = Vector2(560, 110)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD
	slab.add_child(head)

	var dist := UiKit.label("0 m", UiKit.display_font(), 100, UiKit.GOLD)
	dist.position = Vector2(50, 150)
	slab.add_child(dist)

	var glyph := UiKit.CoinGlyph.new(36)
	glyph.position = Vector2(56, 316)
	slab.add_child(glyph)
	var coin_l := UiKit.label("+%d coins" % coin_count, UiKit.text_font(900), 34, UiKit.GOLD)
	coin_l.position = Vector2(104, 304)
	slab.add_child(coin_l)

	var best_l := UiKit.label("New best" if is_best else "Best %s m" % UiKit.thousands(best),
		UiKit.text_font(900 if is_best else 800), 32, UiKit.MAYA_BLUE if is_best else UiKit.LIMESTONE)
	best_l.position = Vector2(56, 362)
	slab.add_child(best_l)

	var again := UiKit.SlabButton.new("Run again", UiKit.SlabButton.Kind.GOLD)
	again.position = Vector2(54, 440)
	again.size = Vector2(552, 106)
	again.pressed.connect(func(): again_pressed.emit())
	slab.add_child(again)
	var home := UiKit.SlabButton.new("Home", UiKit.SlabButton.Kind.JADE)
	home.position = Vector2(54, 556)
	home.size = Vector2(552, 80)
	home.pressed.connect(func(): home_pressed.emit())
	slab.add_child(home)

	# The one orchestrated moment: the slab rises, then the distance counts up.
	var tw := create_tween()
	tw.tween_property(slab, "position", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): dist.text = "%s m" % UiKit.thousands(int(v)), 0.0, float(metres), 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
