extends Node2D


func _ready() -> void:
	# You can simply import a `.gss` file as a Theme in the inspector. However, any changes you make
	# in the theme editor will not be reflected in the `.gss` file. For this reason, it is better to
	# export it to a `.tres` resource file and use that instead.
	# 
	# The following code will generate a new file (or overwrite an existing one) called
	# "res://examples/test_stylesheet.tres".
	GSS.file_to_tres("res://examples/test_stylesheet.gss")
	
	# The `GSS.file_to_tres()` method takes an optional second argument, where you can specify the
	# file path to save the `.tres` file to.
	# GSS.file_to_tres("res://examples/test_stylesheet.gss", "res://examples/my_theme.tres")
	
	# You can also read the contents of a `.gss` file into a Theme object for use in your code:
	var theme: Theme = GSS.file_to_theme("res://examples/test_stylesheet.gss")
	print(theme.get_theme_item_list(Theme.DATA_TYPE_STYLEBOX, "Button"))
	
