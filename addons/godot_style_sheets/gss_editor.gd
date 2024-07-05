@tool
class_name GSSEditor
extends VBoxContainer

## Seconds to wait before auto-saving the current file, if a change has been made.
const AUTO_SAVE_DELAY: float = 2.0

## Size of the file dialong window, when loading, saving, importing, or exporting a file.
const FILE_DIALOG_POPUP_SIZE := Vector2(800, 600)

## Seconds to wait before handling pending reimports.
const REIMPORT_POLL_INTERVAL: float = 1.0

var all_files: Dictionary = {}
var current_file: String = ""
var tres_file_dialog: FileDialog
var gss_file_dialog: FileDialog
var file_hashes: Dictionary = {}
var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
var is_reimporting: bool = false
var last_modified_times: Dictionary = {}
var pending_reimports: Array[String] = []
var reimport_timer: Timer
var save_timer: Timer

@onready var file_menu: PopupMenu = $SplitContainer/FileListContainer/FileListMenuBar/File
@onready var file_list: ItemList = $SplitContainer/FileListContainer/ScrollContainer/FileList
@onready var file_editor: GSSCodeEdit = $SplitContainer/FileEditorContainer/FileEditor
@onready var file_rename: LineEdit = $SplitContainer/FileListContainer/ScrollContainer/FileList/RenameFile


## Called when all child nodes are ready.
func _ready() -> void:
	# Add FileDialog window for GSS files.
	gss_file_dialog = _new_file_dialog_node("*.gss ; GSS Files")
	gss_file_dialog.file_selected.connect(_on_gss_file_selected)
	add_child(gss_file_dialog)
	
	# Add FileDialog window for Theme files.
	tres_file_dialog = _new_file_dialog_node("*.tres ; Theme Files")
	tres_file_dialog.file_selected.connect(_on_tres_file_selected)
	add_child(tres_file_dialog)
	
	# Add timer for auto-save.
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.timeout.connect(_save_current_file)
	add_child(save_timer)
	
	# Add timer for handling pending GSS file reimports.
	reimport_timer = Timer.new()
	reimport_timer.autostart = true
	reimport_timer.one_shot = false
	reimport_timer.timeout.connect(_process_pending_reimports)
	reimport_timer.wait_time = REIMPORT_POLL_INTERVAL
	add_child(reimport_timer)
	
	# Handle file editor text changes.
	file_editor.text_changed.connect(_on_file_editor_text_changed)
	
	# Handle clicks in the GSS file list sidebar.
	file_list.item_selected.connect(_on_file_list_item_selected)
	
	# Handle clicks in the `File` dropdown menu.
	file_menu.id_pressed.connect(_on_file_menu_id_pressed)
	
	# Set up inline file renaming in the GSS file list.
	file_list.set_allow_reselect(true)  # Needed to detect click on currently selected file.
	file_rename.set_visible(false)
	file_rename.text_change_rejected.connect(_on_file_rename_text_change_rejected)
	file_rename.text_submitted.connect(_on_file_rename_text_submitted)
	file_rename.focus_exited.connect(_on_file_rename_focus_exited)
	
	# Find all GSS files in the project and add them to the file list sidebar.
	_populate_file_list()


## Handles input events.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER:
			_on_enter_key_input()


## Clears the contents and current state of the GSS file editor.
func _clear_editor_state() -> void:
	current_file = ""
	file_editor.clear_state()
	file_editor.set_text("")


## Exports a GSS file as a Theme file.
func _export() -> void:
	tres_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	tres_file_dialog.popup_centered(FILE_DIALOG_POPUP_SIZE)
	tres_file_dialog.set_current_path("%s.tres" % current_file.trim_suffix(".gss"))


## Loads a GSS file in the editor.
func _load_file() -> void:
	gss_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	gss_file_dialog.popup_centered(FILE_DIALOG_POPUP_SIZE)


## Creates a new GSS file and open it in the editor.
func _new_file() -> void:
	var timestamp: int = floor(Time.get_unix_time_from_system())
	var file_name: String = "new_%d.gss" % timestamp
	current_file = ""
	file_editor.text = ""
	all_files[file_name] = ""
	_update_file_list()


## Instantiates a new FileDialog node with the given filter.
func _new_file_dialog_node(filter: String) -> FileDialog:
	var file_dialog := FileDialog.new()
	
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter(filter)
	
	return file_dialog


## Handles enter key inputs.
func _on_enter_key_input() -> void:
	# Open file rename field if the file list has focus and the field is not visible.
	if file_list.has_focus() and !file_rename.is_visible():
		_rename_file.call_deferred(current_file)
		get_viewport().set_input_as_handled()  # Prevent the scene tree dock from grabbing focus.


## Handles file editor text changes.
func _on_file_editor_text_changed() -> void:
	if !current_file:
		return
	
	all_files[current_file] = file_editor.text
	save_timer.start(AUTO_SAVE_DELAY)


## Handles clicks in the GSS file list sidebar.
func _on_file_list_item_selected(index: int) -> void:
	var path: String = file_list.get_item_metadata(index)
	
	if not path in all_files:
		_read_file(path)
	
	if current_file == path:
		_rename_file(path)
		return
	
	_save_current_file()  # Save current file before switching.
	current_file = path
	file_editor.set_text(all_files[path])
	file_editor.set_caret_line(0)  # Set cursor to start of file.


## Handles clicks in the `File` dropdown menu.
func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		0: _new_file()
		1: _load_file()
		2: _save_file()
		3: _save_file_as()
		4: _export()


## Handles when the user hits the escape key while renaming a file (does not rename the file).
func _on_file_rename_text_change_rejected(rejected_substring: String) -> void:
	_on_file_renamed(current_file.get_file())


## Handles when the user hits the enter or tab key while renaming a file (renames the file).
func _on_file_rename_text_submitted(new_text: String) -> void:
	_on_file_renamed(new_text)


## Handles when the user clicks elsewhere while renaming a file (renames the file).
func _on_file_rename_focus_exited() -> void:
	# The `focus_exited` signal is emitted after `text_submitted` when the user hits the tab key,
	# so check first if the rename field is still visible. If not, it's already been handled.
	if file_rename.is_visible():
		_on_file_renamed(file_rename.get_text())


func _on_file_renamed(new_name: String) -> void:
	file_rename.set_text("")
	file_rename.set_visible(false)
	
	var old_name: String = current_file.get_file()
	var current_file_list_index: int = file_list.get_selected_items()[0]
	
	if new_name == old_name:
		file_list.select(current_file_list_index)
		return
	
	var base_dir: String = current_file.get_base_dir()
	var new_path: String = base_dir.path_join(new_name)
	var old_path: String = current_file
	
	if FileAccess.file_exists(new_path):
		push_warning("[GSS] Unable to rename file because file already exists: %s" % new_path)
		file_list.select(current_file_list_index)
		return
	
	var dir: DirAccess = DirAccess.open(base_dir)
	
	# Remove the old import file if it exists.
	var old_import: String = "%s.import" % old_name
	if dir.file_exists(old_import):
		dir.remove(old_import)
	
	# Rename the file.
	dir.rename(old_path, new_path)
	
	# Update current state.
	all_files[new_path] = all_files[old_path]
	all_files.erase(old_path)
	file_hashes[new_path] = file_hashes[old_path]
	file_hashes.erase(old_path)
	current_file = new_path
	
	# Tell Godot's internal file system object about the changes (required for reimport).
	file_system.update_file(old_path)
	file_system.update_file(new_path)
	
	# Queue file for reimport with new name.
	if not new_path in pending_reimports:
		pending_reimports.append(new_path)
	
	_update_file_list(current_file_list_index)


## Handles GSS file dialog when file is selected.
func _on_gss_file_selected(path: String) -> void:
	if gss_file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		_read_file(path)
	elif gss_file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		_write_file(path)


## Handles Theme file dialog when file is selected.
func _on_tres_file_selected(path: String) -> void:
	if gss_file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		push_warning("Importing theme files as GSS is not yet possible.")
	elif gss_file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		GSS.file_to_tres(current_file, path)


## Finds all GSS files in the project and adds them to the file list sidebar.
func _populate_file_list() -> void:
	_scan_directory("res://", "gss")


## Reimports an GSS files that were queued to be reimported.
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


## Reads the file at the given path and stores its contents as `current_file`. Also adds it to the
## `all_files` dictionary, and adds the file hash to the `file_hashes` dictionary.
func _read_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	
	if file:
		current_file = path
		file_editor.text = file.get_as_text()
		file.close()
		all_files[path] = file_editor.text
		file_hashes[path] = all_files[path].hash()
		_update_file_list()
	else:
		# File was not readable, so remove it from the list.
		push_warning("[GSS] Unable to open file: %s" % path)
		all_files.erase(path)
		file_hashes.erase(path)
	
	_update_file_list()


## Enables the user to rename a given file in place, in the file list.
func _rename_file(path: String) -> void:
	if !path or !FileAccess.file_exists(path):
		return
	
	var index: int = file_list.get_selected_items()[0]
	var file_name: String = file_list.get_item_text(index)
	var file_list_global_pos: Vector2 = file_list.get_global_position()
	var file_list_item_pos: Vector2 = file_list.get_item_rect(index, true).position
	
	file_rename.set_text(file_name)
	file_rename.set_visible(true)
	file_rename.set_global_position(file_list_global_pos + file_list_item_pos)
	file_rename.set_size(file_list.get_item_rect(index).size)
	
	#await get_tree().process_frame
	file_rename.grab_focus()
	file_rename.select(0, file_name.length() - ".gss".length())


## Saves the current file, if it has been changed (based on file hash).
func _save_current_file() -> void:
	if !current_file:
		return
	
	var current_hash = all_files[current_file].hash()
	if current_hash != file_hashes.get(current_file, 0):
		_write_file(current_file)


## Saves the current file if set; otherwise, opens the 'Save File As...' dialog.
func _save_file() -> void:
	if current_file.is_empty():
		_save_file_as()
	else:
		_write_file(current_file)


## Opens the 'Save File As...' dialog for the code that is currently in the GSS editor.
func _save_file_as() -> void:
	gss_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	gss_file_dialog.popup_centered(FILE_DIALOG_POPUP_SIZE)


## Scans the given path recursively, calling `_read_file()` for each file with the given extension.
func _scan_directory(path: String, file_extension: String) -> void:
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
				_scan_directory(full_path, file_extension)  # Recursive call for subdirectories.
			elif file_name.get_extension() == file_extension:
				_read_file(full_path)
				
			file_name = dir.get_next()
		
		dir.list_dir_end()


## Updates the list of GSS file names in the sidebar, with the full file path as tooltip text.
func _update_file_list(select_index: int = 0) -> void:
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
	if file_list.get_item_count() > select_index:
		file_list.select(select_index)
		_on_file_list_item_selected(select_index)
	
	# Ensure the FileList is visible in the editor.
	file_list.ensure_current_is_visible()


## Saves the contents of the GSS file editor to a file at the given path.
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
