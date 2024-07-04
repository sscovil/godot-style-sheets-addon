@tool
class_name GSSCodeEdit
extends CodeEdit

var current_indent: int = 0
var current_theme_type: String = ""
var current_style: String = ""
var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
var is_code_completion_active: bool = false


func _ready() -> void:
	set_comment_delimiters(["#"])
	set_code_completion_enabled(true)
	set_draw_line_numbers(true)
	
	code_completion_requested.connect(_on_code_completion_requested)
	text_changed.connect(_on_text_changed)


func _confirm_code_completion(replace: bool) -> void:
	is_code_completion_active = false
	super.confirm_code_completion(replace)


func _on_code_completion_requested() -> void:
	is_code_completion_active = true


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
	_update_current_data()
	
	match current_indent:
		0: _update_theme_type_code_completion_options()
		1: _update_theme_style_code_completion_options()
		2: _update_stylebox_code_completion_options()


func _update_current_data() -> void:
	var cursor_line: int = get_caret_line()
	var lines: PackedStringArray = text.split("\n")
	var current_line: String = lines[cursor_line]
	
	current_indent = GSS.get_indentation_level(current_line)
	current_theme_type = ""
	current_style = ""
	
	# Step backwards from current line to determine current theme type & style being edited.
	for i in range(cursor_line, -1, -1):
		var line = lines[i].strip_edges()
		
		if line.ends_with(":"): # TODO: and if not preceded by a `#` comment delimeter.
			match current_indent:
				0: current_theme_type = line.trim_suffix(":")
				1: current_style = line.trim_suffix(":")
		
		# When we find the current theme type, ensure current style is set and exit the `for` loop.
		if current_theme_type:
			if !current_style:
				current_style = GSS.DEFAULT_STYLE
			break


func _update_code_completion_options(
	options: Array,
	type: CodeCompletionKind,
	text_color: Color = Color(1, 1, 1, 1),
	icon: Resource = null,
	value: Variant = null,
	location: int = CodeEdit.CodeCompletionLocation.LOCATION_OTHER,
	insert_text_template: String = "%s:",
) -> void:
	set_code_completion_prefixes(options)
	
	for option in options:
		var insert_text: String = insert_text_template % option
		
		add_code_completion_option(
			type,
			option,
			insert_text,
			text_color,
			icon,
			value,
			location,
		)
	
	update_code_completion_options(true)
	request_code_completion()


func _update_stylebox_code_completion_options() -> void:
	# TODO: Get key and value options for StyleBox properties, based on the type of StyleBox.
	pass


func _update_theme_type_code_completion_options() -> void:
	var options: Array = GSS.get_classes_with_theme_properties()
	
	_update_code_completion_options(
		options,
		CodeEdit.KIND_CLASS,
		Color.PALE_GREEN,
		null,
		null,
		CodeEdit.CodeCompletionLocation.LOCATION_OTHER,
	)


func _update_theme_style_code_completion_options() -> void:
	# TODO: Handle code completion options when preceded by a `:` character (i.e. property values).
	
	var options: Array = GSS.get_theme_properties(current_style)
	
	_update_code_completion_options(
		options,
		CodeEdit.KIND_MEMBER,
		Color.WHITE_SMOKE,
		null,
		null,
		CodeEdit.CodeCompletionLocation.LOCATION_LOCAL,
	)
