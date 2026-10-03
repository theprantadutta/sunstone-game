@tool
extends EditorPlugin
## The editor ignores override.cfg (only the running game reads it), so the
## AdMob exporter never saw the live app ids in it and shipped Google's test id.
## This hands override.cfg's values to ProjectSettings for the length of a
## release export and puts the old values back afterwards — nothing is ever
## saved into project.godot. Debug exports keep the test ids.

var _export: OverrideExport

func _enter_tree() -> void:
	_export = OverrideExport.new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null

class OverrideExport:
	extends EditorExportPlugin

	const OVERRIDE := "res://override.cfg"
	var _saved := {}

	func _get_name() -> String:
		return "SunstoneOverrides"

	func _export_begin(_features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
		_saved.clear()
		if is_debug or not FileAccess.file_exists(OVERRIDE):
			return
		var cfg := ConfigFile.new()
		if cfg.load(OVERRIDE) != OK:
			push_warning("Sunstone: could not read override.cfg")
			return
		for section in cfg.get_sections():
			for key in cfg.get_section_keys(section):
				var setting := "%s/%s" % [section, key]
				_saved[setting] = ProjectSettings.get_setting(setting) if ProjectSettings.has_setting(setting) else null
				ProjectSettings.set_setting(setting, cfg.get_value(section, key))
		print("Sunstone: override.cfg applied to this export (%d settings)" % _saved.size())

	func _export_end() -> void:
		for setting in _saved:
			ProjectSettings.set_setting(setting, _saved[setting])
		_saved.clear()
