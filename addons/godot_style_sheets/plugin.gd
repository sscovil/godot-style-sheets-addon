@tool
extends EditorPlugin

var gss_editor: Control
var import_plugin: GSSEditorImportPlugin
var icon: Texture2D = preload("res://addons/godot_style_sheets/icon.svg")


func _enter_tree() -> void:
	# Register GSS as an auto-load singleton.
	add_autoload_singleton("GSS", "res://addons/godot_style_sheets/gss.gd")
	
	
	# Register import plugin, to add support for `.gss` files.
	import_plugin = GSSEditorImportPlugin.new()
	add_import_plugin(import_plugin)
	
	# Add GSS editor to bottom panel.
	gss_editor = preload("res://addons/godot_style_sheets/gss_editor.tscn").instantiate()
	add_control_to_bottom_panel(gss_editor, "GSS")


func _exit_tree():
	# Remove GSS editor from bottom panel.
	remove_control_from_bottom_panel(gss_editor)
	gss_editor.queue_free()
	
	# Deregister editor import plugin.
	remove_import_plugin(import_plugin)
	import_plugin = null
