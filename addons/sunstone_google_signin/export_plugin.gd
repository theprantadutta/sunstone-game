@tool
extends EditorPlugin
## Hands the sign-in AAR and the Google libraries it needs to Godot's Android
## Gradle build. The AAR is built from android-plugins/google-signin
## (`gradlew copyAar`). At runtime: Engine.get_singleton("SunstoneGoogleSignIn").

var _export: AndroidExport

func _enter_tree() -> void:
	_export = AndroidExport.new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null

class AndroidExport:
	extends EditorExportPlugin

	func _get_name() -> String:
		return "SunstoneGoogleSignIn"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["sunstone_google_signin/bin/sunstone-google-signin-release.aar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"androidx.credentials:credentials:1.3.0",
			"androidx.credentials:credentials-play-services-auth:1.3.0",
			"com.google.android.libraries.identity.googleid:googleid:1.1.1",
			"org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0",
		])
