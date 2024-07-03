@tool
class_name GSSEditor
extends VBoxContainer

const FILE_DIALOG_POPUP_SIZE := Vector2(800, 600)

var all_files: Dictionary = {}
var current_file: String = ""
var file_dialog: FileDialog

@onready var file_menu: PopupMenu = $SplitContainer/FileListContainer/FileListMenuBar/File
@onready var file_list: ItemList = $SplitContainer/FileListContainer/FileList
@onready var file_editor: CodeEdit = $SplitContainer/FileEditorContainer/FileEditor


func _ready() -> void:
	file_menu.id_pressed.connect(_on_file_menu_id_pressed)

	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.gss ; GSS Files")
	add_child(file_dialog)

	file_dialog.file_selected.connect(_on_file_selected)
	file_editor.text_changed.connect(_on_file_editor_text_changed)
	
	file_list.item_selected.connect(_on_file_list_item_selected)
	_populate_file_list()


func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		0: _new_file()
		1: _load_file()
		2: _save_file()
		3: _save_file_as()
		4: _close_file()


func _new_file() -> void:
	current_file = ""
	file_editor.text = ""
	all_files["Untitled"] = ""
	_update_file_list()


func _load_file() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered(FILE_DIALOG_POPUP_SIZE)


func _save_file() -> void:
	if current_file.is_empty():
		_save_file_as()
	else:
		_write_file(current_file)


func _save_file_as() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.popup_centered(FILE_DIALOG_POPUP_SIZE)


func _close_file() -> void:
	if current_file in all_files:
		all_files.erase(current_file)
	
	current_file = ""
	file_editor.text = ""
	_update_file_list()


func _on_file_selected(path: String) -> void:
	if file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		_read_file(path)
	elif file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		_write_file(path)


func _read_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	
	if file:
		current_file = path
		file_editor.text = file.get_as_text()
		file.close()
		all_files[path] = file_editor.text
		_update_file_list()


func _write_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	
	if file:
		current_file = path
		file.store_string(file_editor.text)
		file.close()
		all_files[path] = file_editor.text
		_update_file_list()


func _update_file_list() -> void:
	file_list.clear()
	
	for path in all_files.keys():
		file_list.add_item(path.get_file(), null, true)
		file_list.set_item_metadata(file_list.get_item_count() - 1, path)


func _on_file_list_item_selected(index: int) -> void:
	var path: String = file_list.get_item_metadata(index)
	
	if path in all_files:
		current_file = path
		file_editor.text = all_files[path]


func _on_file_editor_text_changed() -> void:
	if current_file != "":
		all_files[current_file] = file_editor.text
		_write_file(current_file)


func _populate_file_list() -> void:
	_scan_directory("res://")


func _scan_directory(path: String) -> void:
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# Skip hidden files and directories (those starting with a dot).
			if file_name.begins_with("."):
				continue
			
			var full_path = path.path_join(file_name)
			
			if dir.current_is_dir():
				_scan_directory(full_path)  # Recursive call for subdirectories.
			elif file_name.get_extension() == "gss":
				_read_file(full_path)
				
			file_name = dir.get_next()
		
		dir.list_dir_end()
