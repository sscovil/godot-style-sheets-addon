class_name GSSSyntaxHighlighter
extends SyntaxHighlighter

const COMMENT_COLOR := Color.DIM_GRAY
const INVALID_COLOR := Color.LIGHT_CORAL
const PROPERTY_VALUE_COLOR := Color.WHITE_SMOKE
const STYLE_PROPERTY_COLOR := Color.LIGHT_GOLDENROD
const STYLEBOX_PROPERTY_COLOR := Color.POWDER_BLUE
const THEME_TYPE_PROPERTY_COLOR := Color.PALE_GREEN


## Returns a dictionary with column numbers as keys and syntax highlighting data dictionaries as
## values. The column number keys denote the start of a region, and the region will end if another
## region is found (or at the end of the line). The nested syntax highlighting data dictionaries
## contain the data for that region, currently only the key "color" is supported.
func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var color_map: Dictionary = {}
	var editor: TextEdit = get_text_edit()
	var text: String = editor.get_line(line)
	
	# Determine indentation level.
	var indent: int = GSS.get_indentation_level(text)
	
	# Find the position of the first colon.
	var colon_pos: int = text.find(":")
	
	# Find comment position
	var _comment: RegExMatch = GSS.regex.comment.search(text)
	var comment_pos: int = _comment.get_start() if _comment else -1
	
	# Apply color based on indentation level.
	var property_color: Color
	match indent:
		0: property_color = THEME_TYPE_PROPERTY_COLOR
		1: property_color = STYLE_PROPERTY_COLOR
		2: property_color = STYLEBOX_PROPERTY_COLOR
		_: property_color = INVALID_COLOR
	
	# Color property name (up to colon or comment)
	color_map[indent] = {"color": property_color}
	
	# Color property value (after colon, up to comment or end of line)
	if colon_pos != -1:
		var value_start: int = colon_pos + 1
		var value_end: int = comment_pos if comment_pos != -1 else text.length()
		if value_start < value_end:
			color_map[value_start] = {"color": PROPERTY_VALUE_COLOR}
	
	# Color comment
	if comment_pos != -1:
		color_map[comment_pos] = {"color": COMMENT_COLOR}
	
	return color_map
