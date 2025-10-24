class_name Error
extends Node

#= File Access Errors ===========================

# Example Usage
#var read_result = check_file_read(file_path)
#if not read_result.success:
	#handle_file_error(read_result.error_key, read_result.error_code, "read file", file_path)
	#return null
	
func check_file_read(file_path: String) -> Dictionary:
	var result = {"success": true, "error_code": OK, "error_key": "", "message": ""}
	
	# Basic path validation
	if file_path.is_empty():
		result.success = false
		result.error_code = ERR_FILE_BAD_PATH
		result.error_key = "empty_path"
		return result
	
	# Check if file exists
	if not FileAccess.file_exists(file_path):
		result.success = false
		result.error_code = ERR_FILE_NOT_FOUND
		result.error_key = "not_found"
		return result
	
	# Try to open for reading
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		result.success = false
		result.error_code = error
		result.error_key = _get_error_key_from_code(error)
		return result
	
	file.close()
	return result

func check_file_write(file_path: String) -> Dictionary:
	var result = {"success": true, "error_code": OK, "error_key": "", "message": ""}
	
	# Basic path validation
	if file_path.is_empty():
		result.success = false
		result.error_code = ERR_FILE_BAD_PATH
		result.error_key = "empty_path"
		return result
	
	# Check if directory exists
	var dir_path = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		result.success = false
		result.error_code = ERR_FILE_BAD_PATH
		result.error_key = "directory_not_found"
		return result
	
	# Check directory write permissions by testing with a temp file
	var temp_path = dir_path.path_join(".temp_write_test")
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var error = FileAccess.get_open_error()
		result.success = false
		result.error_code = error
		result.error_key = _get_error_key_from_code(error)
		return result
	
	file.close()
	DirAccess.remove_absolute(temp_path)  # Clean up temp file
	
	return result

func check_directory_access(dir_path: String) -> Dictionary:
	var result = {"success": true, "error_code": OK, "error_key": "", "message": ""}
	
	# Basic path validation
	if dir_path.is_empty():
		result.success = false
		result.error_code = ERR_FILE_BAD_PATH
		result.error_key = "empty_path"
		return result
	
	# Check if directory exists
	if not DirAccess.dir_exists_absolute(dir_path):
		result.success = false
		result.error_code = ERR_FILE_NOT_FOUND
		result.error_key = "directory_not_found"
		return result
	
	# Try to open directory
	var dir = DirAccess.open(dir_path)
	if dir == null:
		var error = DirAccess.get_open_error()
		result.success = false
		result.error_code = error
		result.error_key = _get_error_key_from_code(error)
		return result
	
	return result

func _get_error_key_from_code(error_code: int) -> String:
	match error_code:
		ERR_FILE_NOT_FOUND:
			return "not_found"
		ERR_FILE_BAD_DRIVE:
			return "bad_drive"
		ERR_FILE_BAD_PATH:
			return "bad_path"
		ERR_FILE_NO_PERMISSION:
			return "no_permission"
		ERR_FILE_ALREADY_IN_USE:
			return "already_in_use"
		ERR_FILE_CANT_OPEN:
			return "cant_open"
		ERR_FILE_CANT_WRITE:
			return "cant_write"
		ERR_FILE_CANT_READ:
			return "cant_read"
		ERR_FILE_UNRECOGNIZED:
			return "unrecognized"
		ERR_FILE_CORRUPT:
			return "corrupt"
		ERR_FILE_MISSING_DEPENDENCIES:
			return "missing_dependencies"
		ERR_FILE_EOF:
			return "unexpected_eof"
		ERR_OUT_OF_MEMORY:
			return "out_of_memory"
		_:
			return "unknown"

func handle_file_error(error_key: String, error_code: int, context: String, file_path: String) -> void:
	var file_name = file_path.get_file() if not file_path.is_empty() else "unknown file"
	
	var replacements = {
		"FILENAME": file_name,
		"FILEPATH": file_path,
		"ACTION": context,
		"ERROR_CODE": str(error_code)
	}
	
	# Log the error
	if Debug:
		Debug.error("File Error [" + context + "]: " + error_key + " for " + file_path)
	else:
		push_error("File Error [" + context + "]: " + error_key + " for " + file_path)
	
	# Show popup to user
	popup_error("file_access_errors." + error_key, replacements)

# Quick Checks
func can_read_file(file_path: String) -> bool:
	return check_file_read(file_path).success

func can_write_file(file_path: String) -> bool:
	return check_file_write(file_path).success

func can_access_directory(dir_path: String) -> bool:
	return check_directory_access(dir_path).success

#= Generic Errors ===========================
func popup_error(message_path: String, replacements: Dictionary = {}) -> void:
	# example usage: popup_error("file_errors.ngons", {"COUNT": 5}) or pop_error("file_errors.ngons")
	
	### Default Error Message
	var title = "Undefined Error"
	var body = "An unknown error occurred. \n\n This could be due to a number of issues, but the primary cause is using an unsupported blueprint type. \n\nExamples include: Vehicle Blueprints, Track Blueprints, Anything other than Plate Structure Blueprints"
	
	# Parse the message path
	var path_parts = message_path.split(".")
	
	if path_parts.size() >= 2:
		var category = path_parts[0]
		var error_key = path_parts[1]
		
		# Try to get the message from Messages class
		var message_data = null
		match category:
			"file_errors":
				if Messages.file_errors.has(error_key):
					message_data = Messages.file_errors[error_key]
			"file_access_errors":
				if Messages.file_access_errors.has(error_key):
					message_data = Messages.file_access_errors[error_key]
			"test":
				if Messages.test.has(error_key):
					message_data = Messages.test[error_key]
		
		# Extract title and body if found
		if message_data and message_data.has("title") and message_data.has("body"):
			title = message_data.title
			body = message_data.body
			
			# Replace placeholders in both title and body
			for key in replacements:
				var placeholder = "[" + key + "]"
				title = title.replace(placeholder, str(replacements[key]))
				body = body.replace(placeholder, str(replacements[key]))
	
	# Log the error
	if Debug:
		Debug.error("Error displayed: " + title + " - " + body)
	else:
		push_error("Error displayed: " + title + " - " + body)
	
	# Show the popup
	show_error_popup(title, body)
	
#= Logging ===========================
func show_error_popup(title: String, message: String) -> void:
	# Try to find the main scene to show popup
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("_show_error_popup"):
		main_scene._show_error_popup(title, message, "OK")
	else:
		# Fallback, print to console
		print("ERROR POPUP: " + title + " - " + message)
