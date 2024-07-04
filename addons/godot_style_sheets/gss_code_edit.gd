@tool
class_name GSSCodeEdit
extends CodeEdit

var current_indent: int = 0
var current_line: String = ""
var current_theme_type: String = ""
var current_style: String = ""
var current_stylebox: String = ""

var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()


func _ready() -> void:
	set_comment_delimiters(["# ", "##"])
	set_code_completion_enabled(true)
	set_draw_line_numbers(true)
	set_syntax_highlighter(GSSSyntaxHighlighter.new())
	
	text_changed.connect(_on_text_changed)


func _add_code_completion_options(options: Array, kind: int, color: Color, location: int) -> void:
	set_code_completion_prefixes(options)
	for option in options:
		add_code_completion_option(
			kind,
			option,
			"%s:" % option,
			color,
			null,
			null,
			location
		)


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
	_update_current_state()
	
	var is_before_colon: bool = current_line.find(":") == -1
	
	if is_before_colon:
		# Find the proper code completion options for the current indentation level.
		match current_indent:
			0: _update_theme_type_code_completion_options()
			1: _update_theme_style_code_completion_options()
			2: _update_stylebox_code_completion_options()
		
		update_code_completion_options(true)


func _update_current_state() -> void:
	var cursor_line: int = get_caret_line()
	var clean_text: String = GSS.strip_comments(text)
	var lines: PackedStringArray = clean_text.split("\n")
	
	current_line = lines[cursor_line]
	current_indent = GSS.get_indentation_level(current_line)
	current_theme_type = ""
	current_style = ""
	current_stylebox = ""
	
	# Step backwards from current line to determine current theme type & style being edited.
	for i in range(cursor_line, -1, -1):
		var line = lines[i].strip_edges()
		
		if line.ends_with(":"):
			match current_indent:
				0: current_theme_type = line.trim_suffix(":")
				1: current_style = line.trim_suffix(":")
		elif line.begins_with("stylebox:"):
			current_stylebox = line.get_slice(":", 1).strip_edges()
		
		# When we find the current theme type, ensure current style is set and exit the `for` loop.
		if current_theme_type:
			if !current_style:
				current_style = GSS.DEFAULT_STYLE
			break
	
	# Step forward from the current line to determine the current flavor of StyleBox, if defined.
	if 2 == current_indent and !current_stylebox:
		for i in range(cursor_line, 1, 1):
			var line = lines[i].strip_edges()
			
			if line and GSS.get_indentation_level(line) < 2:
				break  # Stop when a property is defined at a lower indentation level.
			
			if line.begins_with("stylebox:"):
				current_stylebox = line.get_slice(":", 1).strip_edges()
	
	if !current_stylebox:
		current_stylebox = GSS.DEFAULT_STYLEBOX


func _update_stylebox_code_completion_options() -> void:
	var options = GSS.get_stylebox_properties(GSS.DEFAULT_STYLEBOX)
	_add_code_completion_options(
		options,
		CodeEdit.KIND_MEMBER,
		GSSSyntaxHighlighter.STYLEBOX_PROPERTY_COLOR,
		CodeEdit.CodeCompletionLocation.LOCATION_OTHER
	)

func _update_theme_type_code_completion_options() -> void:
	var options = GSS.get_classes_with_theme_properties()
	_add_code_completion_options(
		options,
		CodeEdit.KIND_CLASS,
		GSSSyntaxHighlighter.THEME_TYPE_PROPERTY_COLOR,
		CodeEdit.CodeCompletionLocation.LOCATION_OTHER
	)

func _update_theme_style_code_completion_options() -> void:
	var style_options = GSS.get_theme_properties(current_style)
	var stylebox_options = GSS.get_stylebox_properties(GSS.DEFAULT_STYLEBOX)
	
	set_code_completion_prefixes(style_options + stylebox_options)
	
	_add_code_completion_options(
		style_options,
		CodeEdit.KIND_MEMBER,
		GSSSyntaxHighlighter.STYLE_PROPERTY_COLOR,
		CodeEdit.CodeCompletionLocation.LOCATION_LOCAL
	)
	
	_add_code_completion_options(
		stylebox_options,
		CodeEdit.KIND_MEMBER,
		GSSSyntaxHighlighter.STYLEBOX_PROPERTY_COLOR,
		CodeEdit.CodeCompletionLocation.LOCATION_OTHER
	)
