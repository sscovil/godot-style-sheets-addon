@tool
class_name GSSCodeEdit
extends CodeEdit

var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()


func _ready() -> void:
	set_comment_delimiters(["#"])
	set_code_completion_enabled(true)
	set_code_completion_prefixes(_get_code_completion_prefixes())
	set_draw_line_numbers(true)
	
	text_changed.connect(_on_text_changed)


func _get_code_completion_prefixes() -> Array[String]:
	var prefixes: Array[String] = []
	
	prefixes.append_array(GSS.get_classes_with_theme_properties())
	
	return prefixes


func _on_resources_reimported(resources: PackedStringArray) -> void:
	var is_any_resource_gss: bool = false
	
	for resource in resources:
		if resource.ends_with(".gss"):
			is_any_resource_gss = true
			break
	
	if !is_any_resource_gss:
		return
	
	# Ensure the GSS file editor retains focus after GSS files are reimported.
	grab_focus.call_deferred()
	
	# Disconnect this handler; it will be connected again when GSS files get reimported.
	if file_system.resources_reimported.is_connected(_on_resources_reimported):
		file_system.resources_reimported.disconnect(_on_resources_reimported)


func _on_text_changed() -> void:
	for prefix in GSS.get_classes_with_theme_properties():
		add_code_completion_option(
			CodeEdit.KIND_CLASS,
			prefix,
			"%s:" % prefix,
			Color.PALE_GREEN,
		)
	update_code_completion_options(true)
