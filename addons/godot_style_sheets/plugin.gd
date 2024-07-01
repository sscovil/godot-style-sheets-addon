@tool
extends EditorPlugin

var import_plugin: EditorImportPlugin


func _enter_tree():
	add_autoload_singleton("GSS", "res://addons/godot_style_sheets/gss.gd")
	import_plugin = preload("res://addons/godot_style_sheets/import_plugin.gd").new()
	add_import_plugin(import_plugin)


func _exit_tree():
	remove_import_plugin(import_plugin)
	import_plugin = null
	remove_autoload_singleton("GSS")
