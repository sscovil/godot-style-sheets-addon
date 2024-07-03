@tool
class_name GSSScript
extends Resource

@export var source_code: String = ""


func load_from_file(file_path: String) -> Error:
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if !file:
		return ERR_FILE_CANT_OPEN
	
	source_code = file.get_as_text()
	file.close()
	
	set_script(file_path)
	
	return OK


func save_to_file(file_path: String) -> Error:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if !file:
		return ERR_FILE_CANT_WRITE
	
	file.store_string(source_code)
	file.close()
	
	return OK
