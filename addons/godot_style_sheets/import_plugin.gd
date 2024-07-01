@tool
extends EditorImportPlugin

var GSS: Node = preload("res://addons/godot_style_sheets/gss.gd").new()

enum Presets { DEFAULT }


func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	match preset_index:
		Presets.DEFAULT: return []
		_: return []


func _get_import_order() -> int:
	return 0


func _get_importer_name() -> String:
	return "godot_style_sheets"


func _get_option_visibility(path, option_name, options):
	return true


func _get_preset_count() -> int:
	return Presets.size()


func _get_preset_name(preset_index: int) -> String:
	match preset_index:
		Presets.DEFAULT: return "Default"
		_: return "Unknown"


func _get_priority() -> float:
	return 1.0


func _get_recognized_extensions() -> PackedStringArray:
	return ["gss"]


func _get_resource_type() -> String:
	return "Theme"


func _get_save_extension() -> String:
	return "tres"


func _get_visible_name() -> String:
	return "Godot Style Sheets"


func _import(
	source_file: String,
	save_path: String,
	options: Dictionary,
	platform_variants: Array[String],
	gen_files: Array[String],
) -> int:
	var result: int = GSS.file_to_tres(source_file, save_path, _get_save_extension())
	
	gen_files.append_array(GSS.fonts)
	gen_files.append_array(GSS.icons)
	
	return result
