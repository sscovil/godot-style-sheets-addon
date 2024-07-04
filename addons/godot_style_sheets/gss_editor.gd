@tool
class_name GSSEditor
extends VBoxContainer

const AUTO_SAVE_DELAY := 2.0  # Seconds to wait before saving, after a change is made.
const FILE_DIALOG_POPUP_SIZE := Vector2(800, 600)

var all_files: Dictionary = {}
var current_file: String = ""
var file_dialog: FileDialog
var file_hashes: Dictionary = {}
var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
var is_reimporting: bool = false
var last_modified_times: Dictionary = {}
var pending_reimports: Array[String] = []
var reimport_timer: Timer
var save_timer: Timer

@onready var file_menu: PopupMenu = $SplitContainer/FileListContainer/FileListMenuBar/File
@onready var file_list: ItemList = $SplitContainer/FileListContainer/ScrollContainer/FileList
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
	
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.timeout.connect(_save_current_file)
	add_child(save_timer)
	
	reimport_timer = Timer.new()
	reimport_timer.wait_time = 1.0  # Check every second
	reimport_timer.one_shot = false
	reimport_timer.timeout.connect(_process_pending_reimports)
	add_child(reimport_timer)
	reimport_timer.start()
	
	_populate_file_list()


func _load_file() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered(FILE_DIALOG_POPUP_SIZE)


func _new_file() -> void:
	current_file = ""
	file_editor.text = ""
	all_files["Untitled"] = ""
	_update_file_list()


func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		0: _new_file()
		1: _load_file()
		2: _save_file()
		3: _save_file_as()


func _on_file_editor_text_changed() -> void:
	if !current_file:
		return
	
	all_files[current_file] = file_editor.text
	save_timer.start(AUTO_SAVE_DELAY)


func _on_file_list_item_selected(index: int) -> void:
	var path: String = file_list.get_item_metadata(index)
	
	if path in all_files:
		_save_current_file()  # Save current file before switching.
		current_file = path
		file_editor.set_text(all_files[path])
		file_editor.set_caret_line(0)  # Set cursor to start of file.


func _on_file_selected(path: String) -> void:
	if file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		_read_file(path)
	elif file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		_write_file(path)


func _populate_file_list() -> void:
	_scan_directory("res://")


func _process_pending_reimports() -> void:
	if is_reimporting or pending_reimports.is_empty():
		return
	
	is_reimporting = true
	
	# Create an array filtered to only include files that still exist.
	var to_reimport = pending_reimports.filter(func(path): return FileAccess.file_exists(path))
	pending_reimports.clear()
	
	
	# Notify file editor when resources are reloaded.
	if !file_system.resources_reimported.is_connected(file_editor._on_resources_reimported):
		file_system.resources_reimported.connect(file_editor._on_resources_reimported)
	
	print("[GSS] Reimporting files: ", to_reimport)
	file_system.reimport_files(to_reimport)
	
	is_reimporting = false


func _read_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	
	if file:
		current_file = path
		file_editor.text = file.get_as_text()
		file.close()
		all_files[path] = file_editor.text
		file_hashes[path] = all_files[path].hash()
		_update_file_list()


func _save_current_file() -> void:
	if !current_file:
		return
	
	var current_hash = all_files[current_file].hash()
	if current_hash != file_hashes.get(current_file, 0):
		_write_file(current_file)


func _save_file() -> void:
	if current_file.is_empty():
		_save_file_as()
	else:
		_write_file(current_file)


func _save_file_as() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.popup_centered(FILE_DIALOG_POPUP_SIZE)


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


func _update_file_list() -> void:
	file_list.clear()
	
	var sorted_paths: Array = all_files.keys()
	sorted_paths.sort_custom(func(a, b): return a.get_file() < b.get_file())
	
	for path in sorted_paths:
		var file_name: String = path.get_file()
		file_list.add_item(file_name, null, true)
		
		var index: int = file_list.get_item_count() - 1
		file_list.set_item_metadata(index, path)
		file_list.set_item_tooltip(index, path)  # Set full path as tooltip text.
	
	# Set focus to the first item if the list is not empty.
	if file_list.get_item_count() > 0:
		file_list.select(0)
		_on_file_list_item_selected(0)
	
	# Ensure the FileList is visible in the editor.
	file_list.ensure_current_is_visible()


func _write_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	
	if !file:
		return
	
	file.store_string(file_editor.text)
	file.close()
	
	# Update file contents in memory.
	all_files[path] = file_editor.text
	
	# Update file hash so new changes can be detected.
	file_hashes[path] = all_files[path].hash()
	
	# Validate the GSS content
	var validation_result: Dictionary = GSS.validate_gss(file_editor.text)
	
	if validation_result.valid:
		# Update the file system, so other modules can know that the file has changed.
		file_system.update_file(path)
		
		# Queue the file up for re-importing.
		if not path in pending_reimports:
			pending_reimports.append(path)
	else:
		# Display validation errors
		push_warning("[GSS] Validation error in file: %s" % current_file)
		for warning in validation_result.errors:
			push_warning(warning)
