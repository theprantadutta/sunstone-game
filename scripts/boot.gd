extends Control
## The first scene: the launch splash's plum and sun glyph, drawn on the very
## first frame exactly where the system splash had them, so the screen holds
## still while the game itself loads. Then the game, whose own splash
## (GameUI.Splash, same geometry) starts from the same picture and flies it
## into the title. Godot's boot image is off on Android, where the system
## splash shows the glyph instead; without this scene, the seconds it takes the
## game to build itself were bare plum.
##
## Deliberately tiny and self-contained (no GameUI, no UiKit): anything it
## references is loaded before its first frame can show.

const BG := Color(0.1647, 0.1059, 0.2392)
const GLYPH_R := 150.0 / 1024.0 ## the glyph's radius in the image (tools/make_splash.py)
const OUTER := 1.0 + 26.0 / 58.0 ## the marks' outer edge, in glyph radii
var _tex: Texture2D = load("res://assets/icon/splash.png")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Let the glyph reach the screen, then let the system splash go (it waits
	# for this, see addons/sunstone_google_signin _patch_activity) and fade out
	# over the same picture before the load blocks the main thread.
	for i in 2:
		await get_tree().process_frame
	if OS.get_name() == "Android" and Engine.has_singleton("JavaClassWrapper"):
		var system = JavaClassWrapper.wrap("java.lang.System")
		if system:
			system.setProperty("sunstone.splash", "1")
	for i in 2:
		await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/main.tscn")

## Same as GameUI.Splash._start_side: the image's side at launch.
func _side() -> float:
	if OS.get_name() != "Android":
		return minf(size.x, size.y)
	var screen := Vector2(DisplayServer.screen_get_size())
	var density := DisplayServer.screen_get_dpi() / 160.0
	if screen.x <= 0.0 or density <= 0.0:
		return minf(size.x, size.y)
	var sw := minf(screen.x, screen.y) / density
	var outer_dp := 80.0 if sw < 400.0 else (91.0 if sw < 600.0 else 94.0)
	return outer_dp / OUTER * density / (screen.x / size.x) / GLYPH_R

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var side := _side()
	draw_texture_rect(_tex, Rect2(size / 2.0 - Vector2(side, side) / 2.0, Vector2(side, side)), false)
