@tool
extends EditorPlugin
## Hands the sign-in AAR and the Google libraries it needs to Godot's Android
## Gradle build. The AAR is built from android-plugins/google-signin
## (`gradlew copyAar`). At runtime: Engine.get_singleton("SunstoneGoogleSignIn").
##
## Firebase without Google's Gradle plugin: each export writes the values that
## plugin would generate (google_app_id, api key, sender id, ...) from the
## gitignored google-services.json into the Gradle build's resources, plus a
## fresh Crashlytics build id. Firebase then starts by itself at launch, which
## Analytics and Crashlytics need (Crashlytics refuses to start without a
## build id).

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
			"com.google.android.play:app-update:2.1.0",
			# One Firebase release train (BoM 33.7.0): keep these in step.
			"com.google.firebase:firebase-messaging:24.1.0",
			"com.google.firebase:firebase-analytics:22.1.2",
			"com.google.firebase:firebase-crashlytics:19.3.0",
			"com.google.firebase:firebase-crashlytics-ndk:19.3.0",
		])

	## Debug exports start with Analytics and Crashlytics off (the game also
	## switches them off), so testing never reaches Firebase.
	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, debug: bool) -> String:
		if not debug:
			return ""
		return "<meta-data android:name=\"firebase_analytics_collection_deactivated\" android:value=\"true\" />
" 			+ "<meta-data android:name=\"firebase_crashlytics_collection_enabled\" android:value=\"false\" />
"

	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		if not get_export_platform() is EditorExportPlatformAndroid:
			return
		var out := "res://android/build/res/values/sunstone_firebase.xml"
		if not DirAccess.dir_exists_absolute("res://android/build/res/values"):
			return # no Gradle build template installed
		var cfg := _firebase_values()
		if cfg.is_empty():
			DirAccess.remove_absolute(out) # no Firebase in this build
			push_warning("google-services.json missing or unreadable: Analytics and Crashlytics are off in this export")
			return
		var xml := "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<!-- Written by addons/sunstone_google_signin at export; do not edit. -->
<resources>
"
		for k in cfg:
			xml += "    <string name=\"%s\" translatable=\"false\">%s</string>
" % [k, str(cfg[k]).xml_escape()]
		xml += "</resources>
"
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f:
			f.store_string(xml)

	## What Google's Gradle plugin would generate from google-services.json.
	func _firebase_values() -> Dictionary:
		if not FileAccess.file_exists("res://google-services.json"):
			return {}
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://google-services.json"))
		if not d is Dictionary:
			return {}
		var project: Dictionary = d.get("project_info", {})
		var client: Dictionary = {}
		for c in d.get("client", []):
			if str(c.get("client_info", {}).get("android_client_info", {}).get("package_name", "")) == "com.pranta.sunstone":
				client = c
		if client.is_empty():
			return {}
		var keys: Array = client.get("api_key", [])
		var api_key := str(keys[0].get("current_key", "")) if not keys.is_empty() else ""
		var crypto := Crypto.new()
		var id := crypto.generate_random_bytes(16).hex_encode()
		return {
			"google_app_id": str(client.client_info.get("mobilesdk_app_id", "")),
			"gcm_defaultSenderId": str(project.get("project_number", "")),
			"project_id": str(project.get("project_id", "")),
			"google_storage_bucket": str(project.get("storage_bucket", "")),
			"google_api_key": api_key,
			"google_crash_reporting_api_key": api_key,
			"com.google.firebase.crashlytics.mapping_file_id": id,
		}
