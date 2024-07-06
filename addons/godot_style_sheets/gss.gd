@tool
extends Node

## Used to indicate that a GSS property is not a Theme.DATA_TYPE_* property and is most likely a
## StyleBox property.
const DATA_TYPE_UNKNOWN: int = -1

## Used when parsing a Color value from a GSS file, because `Color.from_string()` requires a default
## value.
const DEFAULT_COLOR: Color = Color.WHITE

## Used when no theme type style (e.g. "disabled", "hover", "pressed") is specified.
const DEFAULT_STYLE: String = "normal"

## Used when no stylebox property is specified.
const DEFAULT_STYLEBOX: String = "StyleBoxFlat"

## RegEx pattern for identifying Color constant values. Matches values like "RED" from "Color.RED",
## or just "red".
const REGEX_COLOR_CONSTANT: String = r"(?:Color\.)?([\w]+)"

## RegEx pattern for identifying HTML hexadecimal color strings, with or without the "#" prefix.
const REGEX_COLOR_HEX: String = r"(?:#?([A-Fa-f0-9]{3}(?:[A-Fa-f0-9]{3})?(?:[A-Fa-f0-9]{2})?))"

## RegEx pattern for identifying Color RGBA values. Matches values like "Color(0.2, 1.0, 0.7, 0.8)".
const REGEX_COLOR_RGBA: String = r"Color\(([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)(?:\s*,\s*([\d.]+))?\)"

## RegEx pattern for identifying Godot-style comments, including inline commets (but not HTML hex
## colors).
const REGEX_COMMENT: String = r"(?m)(^[ \t]*#+(?!([a-fA-F0-9]{3}|[a-fA-F0-9]{4}|[a-fA-F0-9]{6}|[a-fA-F0-9]{8})\b).*$|[ \t]*#+(?!([a-fA-F0-9]{3}|[a-fA-F0-9]{4}|[a-fA-F0-9]{6}|[a-fA-F0-9]{8})\b).*$)"

## RegEx pattern for identifying the `type`, `path`, and `id` values of an external resource in a
## `.tres` file. Matches values like "FontFile", "res://font.ttf", and "1_touhl" from
## '[ext_resource type="FontFile" uid="uid://crfeeuddpgih3" path="res://font.ttf" id="1_touhl"]'.
const REGEX_EXT_RESOURCE: String = r'^\[ext_resource .*?type="([^"]+)".*?path="([^"]+)".*?id="([^"]+)"'

## RegEx pattern for capturing the type of a resource in a `.tres` file.
const REGEX_GD_RESOURCE: String = r'^[gd_resource [.]* type="(\w+)"'

## RegEx pattern for identifying GSS property key/value pairs in a GSS file. Matches values like
## "font" and "res://font.tres" from 'font: "res://font.tres"'; or "color" and "Color.RED" from
## "color: Color.RED;". Ignores trailing semicolons.
const REGEX_GSS_PROPERTY: String = r"(\w+)\s*:\s*(?:\"?([^\";\n]+)\"?;?|([^;\n]+))"

## RegEx pattern for identifying pixel size values. Matches values like "12" from "12px"; or "0.5"
## from "0.5px".
const REGEX_PIXEL_SIZE: String = r"^\d+(\.\d+)?px$"

## RegEX pattern that captures quoted text inside parentheses. Matches values like `1_touhl` from
## 'ExtResource("1_touhl")', and `StyleBoxFlat_4r6p2` from 'SubResource("StyleBoxFlat_4r6p2")'.
const REGEX_QUOTED_IN_PARENS: String = r'\("([A-Za-z0-9_]+)"\)'

## RegEx pattern for matching the theme type, property type, property name, and value in a resource
## file. Matches values like "Button/font_sizes/font_size = 20", with "Button" as the first capture
## string, "font_sizes" as the second, "font_size" as the third, and "20" as the fourth. This will
## Also match a single key/valye pair, like "bg_color" and "Color(0, 0, 0, 0.4)" from the text
## "bg_color = Color(0, 0, 0, 0.4)".
const REGEX_RESOURCE: String = r'(\w+)/?(\w+)?/?(\w+)? = (.*)'

## RegEx pattern for matching snake case strings. Matches "foo_bar", but not "Foo", "Bar", "FooBar",
## or "Foo Bar".
const REGEX_SNAKE_CASE: String = r"^([a-z0-9_]+)$"

## RegEx pattern for matching the StyleBox type and ID in a resource file. Matches values like
## '[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_4r6p2"]', with "StyleBoxFlat" as the first
## capture string and "StyleBoxFlat_4r6p2" as the second.
const REGEX_SUB_RESOURCE: String = r'^\[sub_resource .*?type="([^"]+)".*?id="([^"]+)"'

## RegEx pattern for identifying theme override properties. Matches values like "colors" and
## "font_color" from "theme_override_colors/font_color"; or "fonts" and "font" from
## "theme_override_fonts/font".
const REGEX_THEME_OVERRIDE: String = r"theme_override_([a-z0-9_]+)/([a-z0-9_]+)"

## RegEx pattern for identifying Vector2 values. Matches values like "5" and "20" from
## "Vector2(5, 20)"; or "-20" and "100" from "Vector2(-20, 100)".
const REGEX_VECTOR2: String = r"Vector2?i?\s*\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)"

## Icon file paths that have been loaded. 
var icons: Array[String] = []

## Font file paths that have been loaded.
var fonts: Array[String] = []

## Dictionary of RegEx objects used to match patterns.
var regex: Dictionary = {
	"color_constant": RegEx.create_from_string(REGEX_COLOR_CONSTANT),
	"color_hex": RegEx.create_from_string(REGEX_COLOR_HEX),
	"color_rgba": RegEx.create_from_string(REGEX_COLOR_RGBA),
	"comment": RegEx.create_from_string(REGEX_COMMENT),
	"gd_resource": RegEx.create_from_string(REGEX_GD_RESOURCE),
	"ext_resource": RegEx.create_from_string(REGEX_EXT_RESOURCE),
	"gss_property": RegEx.create_from_string(REGEX_GSS_PROPERTY),
	"pixel_size": RegEx.create_from_string(REGEX_PIXEL_SIZE),
	"quoted_in_parens": RegEx.create_from_string(REGEX_QUOTED_IN_PARENS),
	"resource": RegEx.create_from_string(REGEX_RESOURCE),
	"snake_case": RegEx.create_from_string(REGEX_SNAKE_CASE),
	"sub_resource": RegEx.create_from_string(REGEX_SUB_RESOURCE),
	"theme_override": RegEx.create_from_string(REGEX_THEME_OVERRIDE),
	"vector2": RegEx.create_from_string(REGEX_VECTOR2),
}

## Dictionary of `theme_override_*` keys and their corresponding Theme.DATA_TYPE_* integer values.
var theme_property_types: Dictionary = {
	"colors": Theme.DATA_TYPE_COLOR,
	"constants": Theme.DATA_TYPE_CONSTANT,
	"fonts": Theme.DATA_TYPE_FONT,
	"font_sizes": Theme.DATA_TYPE_FONT_SIZE,
	"icons": Theme.DATA_TYPE_ICON,
	"styles": Theme.DATA_TYPE_STYLEBOX,
}


## Converts a GSS Dictionary into a Theme object.
func dict_to_theme(dict: Dictionary) -> Theme:
	var theme := Theme.new()
	
	# Loop through each key in the GSS dictionary.
	for theme_type in dict.keys():
		for style in dict[theme_type].keys():
			var props: Dictionary = dict[theme_type][style]
			var theme_props: Dictionary = _get_theme_property_types(theme_type)
			
			# Different theme types (e.g. Button, TextEdit) allow different styles (e.g. disabled,
			# hover, pressed); properties for invalid types will raise a warning and be ignored.
			if !_is_valid_style(style, theme_props):
				push_warning("[GSS] Invalid theme type style: %s")
				continue
			
			# Instantiate a new StyleBox that can have properties applied to it.
			var stylebox_type: String = props.get("stylebox", DEFAULT_STYLEBOX)
			var stylebox = ClassDB.instantiate(stylebox_type)
			var stylebox_props: Dictionary = _get_stylebox_property_types(stylebox_type)
			
			# Loop through each property in the GSS dictionary.
			for prop: String in props.keys():
				var value: String = props[prop]
				var data_type: int = theme_props.get(prop, DATA_TYPE_UNKNOWN)
				
				if DATA_TYPE_UNKNOWN == data_type:
					_set_stylebox_property(stylebox, stylebox_props, prop, theme_type, value)
				else:
					_set_theme_property(theme, data_type, prop, theme_type, value)
						
			# Apply the StyleBox to the Theme.
			theme.set_stylebox(style, theme_type, stylebox)
	
	return theme


## Converts the contents of a GSS file to a GSS Dictionary that can be parsed into a Theme.
func file_to_dict(source_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	
	if !file:
		push_error("[GSS] Unable to open file: %s" % source_path)
		return {}
	
	var text: String = file.get_as_text()
	file.close()
	
	return text_to_dict(text)


## Converts the contents of a GSS file to a Theme object.
func file_to_theme(source_path: String) -> Theme:
	return dict_to_theme(file_to_dict(source_path))


## Converts the contents of a GSS file to a Theme object and saves it to a resource file.
func file_to_tres(source_path: String, save_path: String = "") -> int:
	var source_file_content: String = _read_file(source_path)
	if source_file_content == null:
		return FileAccess.get_open_error()
	
	var dict: Dictionary = text_to_dict(source_file_content)
	var theme: Theme = dict_to_theme(dict)
	
	if !save_path:
		save_path = source_path
	save_path = _replace_file_extension(save_path, "tres")
	
	return ResourceSaver.save(theme, save_path)


## Returns an array of all class names that have theme properties.
func get_classes_with_theme_properties() -> Array[String]:
	var classes_with_theme: Array[String] = []
	var all_classes: PackedStringArray = ClassDB.get_class_list()
	
	for cls: String in all_classes:
		if has_theme_properties(cls):
			classes_with_theme.append(cls)
	
	return classes_with_theme


## Returns the number of tab characters at the beginning of a string.
func get_indentation_level(text: String) -> int:
	var level: float = 0.0
	
	for char in text:
		if char == "\t":
			# Tabs are one full level of indentation. 
			level += 1.0
		elif char == " ":
			# Four spaces equal one tab. That's just math.
			level += 0.25
		else:
			# Any other character ends the indentation.
			break
	
	return round(level)


## Returns an array of all theme properties for the given class.
func get_stylebox_properties(cls: String) -> Array:
	var result: Array = ["stylebox"]
	
	result.append_array(_get_stylebox_property_types(cls).keys())
	
	return result


## Returns an array of all theme properties for the given class.
func get_theme_properties(cls: String) -> Array:
	return _get_theme_property_types(cls).keys()


## Returns `true` if the given class has a `theme` property.
func has_theme_properties(cls: String) -> bool:
	var properties: Array[Dictionary] = ClassDB.class_get_property_list(cls)
	
	for property: Dictionary in properties:
		if property.name == "theme":
			return true
	
	return false


## Imports a Theme from a `.tres` resource file, parses it to GSS, and saves it as a `.gss` file.
func import_from_tres(import_path: String, save_path: String = "") -> int:
	var import_file_content: String = _read_file(import_path)
	if import_file_content == null:
		return FileAccess.get_open_error()
	
	var gss: String = tres_to_gss(import_file_content)
	
	if !save_path:
		save_path = import_path
	save_path = _replace_file_extension(save_path, "gss")
	
	return _save_file(save_path, gss)


## Strips comments from the given text.
func strip_comments(text: String) -> String:
	return regex.comment.sub(text, '', true)


## Converts GSS text into a GSS Dictionary that can be parsed into a Theme.
func text_to_dict(raw_text: String) -> Dictionary:
	var text: String = strip_comments(raw_text)
	var lines: PackedStringArray = text.split("\n")
	var result: Dictionary = {}
	var theme_type: String = ""
	var style: String = DEFAULT_STYLE
	
	# Loop through each line in the GSS text.
	for i: int in range(lines.size()):
		var line: String = lines[i].strip_edges()
		
		if !line:
			continue  # Ignore blank lines.
		
		match get_indentation_level(lines[i]):
			0: theme_type = line.trim_suffix(":")
			1: style = _parse_gss_property(line, result, theme_type, style)
			2: _parse_gss_property(line, result, theme_type, style)
	
	return result


## Saves a Theme object to a resource file, returning OK or ERR_FILE_CANT_WRITE.
func theme_to_tres(theme: Theme, save_path: String) -> int:
	return ResourceSaver.save(theme, save_path)


## Parses the contents of a theme's `.tres` resource file and returns the equivalent GSS as text.
## Returns null if `tres_file_content` is not the file contents of a Theme resource.
func tres_to_gss(tres_file_content: String) -> String:
	var lines: PackedStringArray = tres_file_content.split("\n")
	var first_line: String = lines[0].strip_edges()
	var gss_output: String
	
	if !regex.get("gd_resource").search(first_line):
		push_warning("[GSS] Invalid Theme resource file content: %s" % first_line)
		return gss_output
	
	var ext_resources: Dictionary = {}
	var sub_resources: Dictionary = {}
	
	var current_class: String = ""
	var current_property_type: String = ""
	var current_stylebox: String = ""
	var current_stylebox_id: String = ""
	
	gss_output = ""
	
	for line in lines:
		var text: String = line.strip_edges()
		var _match: RegExMatch
		
		if line.is_empty() or line == first_line:
			current_class = ""
			current_property_type = ""
			current_stylebox = ""
			current_stylebox_id = ""
			continue
		
		# Parse external resource definition (e.g. fonts, icons).
		_match = regex.get("ext_resource").search(text)
		if _match:
			var path: String = _match.get_string(2)
			var id: String = _match.get_string(3)
			ext_resources[id] = path
			continue
		
		# Parse StyleBox sub-resource definition (e.g. StyleBoxFlat, StyleBoxTexture).
		_match = regex.get("sub_resource").search(text)
		if _match:
			current_stylebox = _match.get_string(1)
			current_stylebox_id = _match.get_string(2)
			sub_resources[current_stylebox_id] = {"stylebox": current_stylebox}
			continue
		
		# Parse properties of a sub-resource.
		_match = regex.get("resource").search(text)
		if _match and !current_stylebox_id.is_empty():
			var key: String = _match.get_string(1)
			var value: String = _match.get_string(4)
			if value.begins_with("ExtResource"):
				value = _get_ext_resource_reference(ext_resources, value)
			sub_resources[current_stylebox_id][key] = value
			continue
		
		# Parse properties of a resource.
		elif _match:
			var cls: String = _match.get_string(1)
			var type: String = _match.get_string(2)
			var key: String = _match.get_string(3)
			var value: String = _match.get_string(4)
			
			if current_class.is_empty():
				# Add a blank line before each new theme type, after the first.
				if !gss_output.is_empty():
					gss_output += "\n"
				# Set the current theme type and add it to the GSS output.
				current_class = cls
				gss_output += "%s:\n" % current_class
			
			if current_property_type.is_empty():
				# Set the current property type and add a comment indicating the type.
				current_property_type = type
				gss_output += "\t# %s\n" % type
			elif current_property_type != type:
				# Set the current property type and add a comment indicating the type, with a
				# line break before it.
				current_property_type = type
				gss_output += "\t\n\t# %s\n" % type
			
			# If value is SubResource reference, parse the GSS for the appropriate StyleBox.
			if value.begins_with("SubResource"):
				var stylebox: Dictionary = _get_sub_resource_reference(sub_resources, value)
				# Add the style (e.g. normal, hover, focus) to the GSS output.
				gss_output += "\t\n\t%s:\n" % key
				# Loop through the StyleBox properties, adding each to the GSS output.
				for stylebox_key: String in stylebox.keys():
					var stylebox_value: String = stylebox[stylebox_key]
					gss_output += "\t\t%s: %s\n" % [stylebox_key, stylebox_value]
				continue
				
			# If value is ExtResource reference, set value to the external resource path.
			if value.begins_with("ExtResource"):
				value = _get_ext_resource_reference(ext_resources, value)
			
			# Add the current key/value pair to the GSS output.
			gss_output += "\t%s: %s\n" % [key, value]
	
	return gss_output


func _get_ext_resource_reference(resources: Dictionary, value: String) -> String:
	var _match: RegExMatch = regex.get("quoted_in_parens").search(value)
	return resources.get(_match.get_string(1), value) if _match else value


func _get_sub_resource_reference(resources: Dictionary, value: String) -> Dictionary:
	var _match: RegExMatch = regex.get("quoted_in_parens").search(value)
	return resources.get(_match.get_string(1), {}) if _match else {}


## Validates GSS syntax, returning a dictionary with a boolean `valid` property and an `errors`
## array that contains a list of errors found (if any).
func validate_gss(content: String) -> Dictionary:
	var result = {"valid": true, "errors": []}
	var lines = content.split("\n")
	var current_indent = 0
	var current_theme_type = ""
	var current_style = ""
	var expect_nested = false
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
	
		var indent = get_indentation_level(lines[i])
	
		if indent > current_indent + 1:
			result.errors.append("Line %d: Invalid indentation" % (i + 1))
		elif indent == 0:
			if not line.ends_with(":"):
				result.errors.append("Line %d: Theme type should end with ':'" % (i + 1))
			current_theme_type = line.trim_suffix(":")
			expect_nested = false
		elif indent == 1:
			if ":" not in line:
				result.errors.append("Line %d: Style should contain ':'" % (i + 1))
			else:
				var parts = line.split(":", true, 1)
				if parts.size() == 2:
					current_style = parts[0].strip_edges()
					if parts[1].strip_edges().is_empty():
						expect_nested = true
					else:
						expect_nested = false
				else:
					result.errors.append("Line %d: Invalid style format" % (i + 1))
		elif indent == 2:
			if expect_nested:
				if ":" not in line:
					result.errors.append("Line %d: Nested property should contain ':'" % (i + 1))
			else:
				if ":" not in line:
					result.errors.append("Line %d: Property should contain ':'" % (i + 1))
		
		current_indent = indent
	
	result.valid = result.errors.is_empty()
	return result


## Returns a dictionary of property names and their corresponding data types for the given class.
func _get_class_property_types(cls: Variant, no_inheritance: bool = false) -> Dictionary:
	var result: Dictionary = {}
	
	if !ClassDB.class_exists(cls):
		push_warning("[GSS] Class does not exist: %s" % cls)
		return result
	
	var props: Array[Dictionary] = ClassDB.class_get_property_list(cls, no_inheritance)
	
	for prop in props:
		var key: String = prop.name
		var value: int = prop.type
		
		# Ignore any property names that are not snake_case.
		if regex.snake_case.search(key):
			result[key] = value
	
	return result


## Returns an array of keys from `props` that are prefixed with the given key. For example, if
## the given `props` dictionary contained the Button theme properties, and "border_width" was
## the given `key` parameter, this function would return:
## ["border_width_bottom", "border_width_left", "border_width_right", "border_width_top"]
func _get_property_group(props: Dictionary, key: String) -> Array:
	return props.keys().filter(func(k): return k != key and k.begins_with(key))


## Returns a dictionary of property names and their corresponding data types for the given class.
func _get_stylebox_property_types(cls: String) -> Dictionary:
	var no_inheritance: bool = true
	var result: Dictionary = _get_class_property_types(cls, no_inheritance)
	
	if "StyleBox" != cls:
		result.merge(_get_class_property_types("StyleBox", no_inheritance))
	
	return result


## Returns a dictionary of `theme_override_*` property names and their corresponding data types.
func _get_theme_property_types(theme_type: String) -> Dictionary:
	var result: Dictionary = {}
	
	if !ClassDB.class_exists(theme_type):
		push_warning("[GSS] Class does not exist: %s" % theme_type)
		return result
	
	# The array returned by `ClassDB.class_get_property_list()` does not include `theme_override_*`
	# properties, so we need to instantiate the class to get them.
	var temp_instance: Variant = ClassDB.instantiate(theme_type)
	var props: Array[Dictionary] = temp_instance.get_property_list()
	
	# Release the temporary instance from memory, if it is an Object.
	if temp_instance is Object:
		temp_instance.free()
	
	for prop: Dictionary in props:
		var _match: RegExMatch = regex.theme_override.search(prop.name)
		
		if !_match:
			continue
		
		var key: String = _match.get_string(2)
		var value: int = theme_property_types.get(_match.get_string(1), DATA_TYPE_UNKNOWN)
		
		result[key] = value
	
	return result


## Returns `true` if the given style is a valid StyleBox property.
func _is_valid_style(style: String, theme_props: Dictionary) -> bool:
	return style in theme_props.keys() and Theme.DATA_TYPE_STYLEBOX == theme_props[style]


## Parses a boolean value from a string.
func _parse_bool(text: String) -> bool:
	if !text:
		return false
	
	text = text.to_lower().strip_edges()
	
	if text in ["false", "0"]:
		return false
	
	return true


## Parses a Color value from a string.
func _parse_color(text: String) -> Color:
	var _match: RegExMatch
	
	# Handle RGB/RGBA values like "Color(0.2, 1.0, 0.7)" and "Color(0.2, 1.0, 0.7, 0.8)".
	_match = regex.color_rgba.search(text)
	if _match:
		var r := clampf(float(_match.get_string(1)), 0.0, 1.0) 
		var g := clampf(float(_match.get_string(2)), 0.0, 1.0)
		var b := clampf(float(_match.get_string(3)), 0.0, 1.0)
		var a := clampf(float(_match.get_string(4)), 0.0, 1.0)
		return Color(r, g, b, a)

	# Handle HTML hex values like "#55aaFF", "#55AAFF20", "55AAFF", and "#F2C".
	_match = regex.color_hex.search(text)
	if _match:
		var hex_string: String = _match.get_string(1)
		if !Color.html_is_valid(hex_string):
			push_warning("[GSS] Invalid HTML hexadecimal color string: %s" % hex_string)
			return DEFAULT_COLOR
		return Color.html(hex_string)

	# Handle color constant values like "Color.RED" and "red".
	_match = regex.color_constant.search(text)
	if _match:
		var color_name: String = _match.get_string(1).to_upper()
		var color = Color.from_string(color_name, DEFAULT_COLOR)
		if DEFAULT_COLOR == color and color_name != "WHITE":
			push_warning("[GSS] Invalid color constant: %s" % color_name)
		return color

	push_warning("[GSS] Invalid Color value: %s" % text)
	return DEFAULT_COLOR


## Parses a theme constant value (i.e. an integer) from a string.
func _parse_constant(value: String) -> int:
	return value as int


## Parses a Font value from a string by loading the font resource from the given path.
func _parse_font(value: String) -> Font:
	var font: Font = load(value)
	
	if !font:
		push_error("[GSS] Font file not found: %s" % value)
		return font
	
	if not value in fonts:
		fonts.append(value)
	
	return font


## Parses a font size value (i.e. an integer) from a string.
func _parse_font_size(value: String) -> int:
	return value as int


## Parses a GSS property and adds it to the given GSS Dictionary.
func _parse_gss_property(
	text: String,
	dict: Dictionary,
	theme_type: String,
	style: String,
) -> String:
	var _match: RegExMatch = regex.gss_property.search(text)
	
	if !_match:
		# If the line does not match the GSS property pattern, return it as a new style.
		return text.trim_suffix(":")
	
	var key: String = _match.get_string(1)
	var value: String = _match.get_string(2)

	# If the property value is a pixel size, remove the "px" suffix.
	if regex.pixel_size.search(value):
		value = value.trim_suffix("px")
	
	# Initialize the theme type in the GSS Dictionary, if it does not already exist.
	if !dict.has(theme_type):
		dict[theme_type] = {}
	
	# Initialize the style for the given theme type, if it does not already exist.
	if !dict[theme_type].has(style):
		dict[theme_type][style] = {}

	# Add the property to the GSS Dictionary.
	dict[theme_type][style][key] = value

	# Return the current style.
	return style


## Parses an icon value from a string by loading the icon resource from the given path.
func _parse_icon(value: String) -> Texture2D:
	var icon: Texture2D = load(value)
	
	if !icon:
		push_error("[GSS] Icon file not found: %s" % value)
		return icon
	
	if not value in icons:
		icons.append(value)
	
	return icon


## Parses a StyleBox property value from a string, based on the property type.
func _parse_stylebox_property(prop: String, text: String, stylebox_props: Dictionary) -> Variant:
	if !stylebox_props.has(prop):
		push_warning("[GSS] Invalid StyleBox property: %s" % prop)
		return text
	
	match stylebox_props[prop]:
		TYPE_BOOL: return _parse_bool(text)
		TYPE_COLOR: return _parse_color(text)
		TYPE_FLOAT: return float(text)
		TYPE_INT: return int(text)
		TYPE_STRING: return text
		TYPE_VECTOR2: return _parse_vector2(text)
		_: push_warning("[GSS] No parser found for StyleBox property: %s" % prop)
	
	return text


## Parses a Vector2 value from a string.
func _parse_vector2(text: String) -> Vector2:
	var _match: RegExMatch = regex.vector2.search(text)
	
	if !_match:
		push_warning("[GSS] Unable to parse Vector2 value from String: %s" % text)
		return Vector2.ZERO
	
	var x: int = _match.get_string(1) as int
	var y: int = _match.get_string(2) as int
	
	return Vector2(x, y)


## Returns the content of a given file path, or null there is an error reading the file. Use
## `FileAccess.get_open_error()` immediately after calling this function if it returns null, to
## get the error code. 
func _read_file(path: String) -> String:
	var content: String
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	
	if !file:
		push_error("[GSS] Unable to open file: %s" % path)
		return content
	
	content = file.get_as_text()
	file.close()
	
	return content


## String utility to replace an existing file extension with a new one, for a given file path.
func _replace_file_extension(path: String, new_extension) -> String:
	return path.trim_suffix(path.get_extension()) + new_extension


## Saves the given content to the given file path, returning `OK` or an error status code.
func _save_file(path: String, content: String) -> int:
	if FileAccess.file_exists(path):
		push_warning("[GSS] Unable to save file because file already exists: %s" % path)
		return ERR_FILE_ALREADY_IN_USE
	
	var file = FileAccess.open("user://save_game.dat", FileAccess.WRITE)
	
	file.store_string(content)
	file.close()
	
	return OK


## Sets a property on the given StyleBox. If the property is not found in the `stylebox_props` dictionary,
## it may be a group property (e.g. "border_width", "corner_radius") that has multiple properties (e.g.
## "border_width_top", "border_width_bottom"). If so, this function will call itself recursively for each
## of the properties prefixed with the group property name.
func _set_stylebox_property(
	stylebox: StyleBox,
	stylebox_props: Dictionary,
	prop: String,
	theme_type: String,
	value: String,
) -> void:
	if DATA_TYPE_UNKNOWN == stylebox_props.get(prop, DATA_TYPE_UNKNOWN):
		for group_prop in _get_property_group(stylebox_props, prop):
			_set_stylebox_property(stylebox, stylebox_props, group_prop, theme_type, value)
	else:
		stylebox.set(prop, _parse_stylebox_property(prop, value, stylebox_props))


## Sets a property on the given Theme, based on the property type.
func _set_theme_property(
	theme: Theme,
	data_type: int,
	prop: String,
	theme_type: String,
	value: String,
) -> void:
	match data_type:
		Theme.DATA_TYPE_COLOR: theme.set_color(prop, theme_type, _parse_color(value))
		Theme.DATA_TYPE_CONSTANT: theme.set_constant(prop, theme_type, _parse_constant(value))
		Theme.DATA_TYPE_FONT: theme.set_font(prop, theme_type, _parse_font(value))
		Theme.DATA_TYPE_FONT_SIZE: theme.set_font_size(prop, theme_type, _parse_font_size(value))
		Theme.DATA_TYPE_ICON: theme.set_icon(prop, theme_type, _parse_icon(value))
