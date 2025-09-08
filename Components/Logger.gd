extends Node

signal log_message(message: String, log_type: String)

var log_file_path: String
var debug_folder_path: String
var session_start_time: String
var session_initialized: bool = false

func initialize(folder_path: String):
	debug_folder_path = folder_path
	session_start_time = Time.get_datetime_string_from_system().replace(":", "-")
	_setup_logging()

func get_debugger():
	# Access the debugger instance from the scene tree
	var main_scene = Engine.get_main_loop().current_scene
	return main_scene.get_node_or_null("Mods/Debugger")
	
func _setup_logging():
	if debug_folder_path.is_empty():
		push_error("Logger: No debug folder path provided")
		return
	
	log_file_path = debug_folder_path + "/debug_log_" + session_start_time + ".txt"
	
	# Create initial file with session header
	var file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if file:
		_write_session_header_to_file(file)
		file.close()
		session_initialized = true
		print("Logger: Logging to: " + log_file_path)
	else:
		push_error("Logger: Failed to create log file at: " + log_file_path)

func _write_session_header_to_file(file: FileAccess):
	if not file:
		return
		
	var separator = "=".repeat(50)
	var version = ProjectSettings.get_setting("application/config/version", "Unknown")
	var app_name = ProjectSettings.get_setting("application/config/name", "Application")
	
	var debugger = get_debugger()
	var debugger_version = debugger.debugger_version if debugger else "Unknown"
	
	file.store_line(separator)
	file.store_line("DEBUG SESSION STARTED")
	file.store_line(separator)
	file.store_line(app_name)
	file.store_line("debugger version " + "v" + debugger.debugger_version) #file.store_line("debugger version " + "v0444")
	file.store_line("tool version " + "v" + version)
	file.store_line("Timestamp: " + Time.get_datetime_string_from_system())
	file.store_line(separator)

func _write_to_log_file(text: String):
	if not session_initialized or log_file_path.is_empty():
		return
	
	var file = FileAccess.open(log_file_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_line(text)
		file.close()
	else:
		push_warning("Logger: Failed to write to log file")

func debug_log(text):
	var timestamp = Time.get_datetime_string_from_system()
	var log_line = "[%s] %s" % [timestamp, str(text)]
	
	# Print to console (Godot's console)
	print(log_line)
	
	# Write to file
	_write_to_log_file(log_line)
	
	# Emit signal for console display
	emit_signal("log_message", log_line, "log")

func debug_error(text):
	var timestamp = Time.get_datetime_string_from_system()
	var log_line = "[%s] ERROR: %s" % [timestamp, str(text)]
	
	print(log_line)
	_write_to_log_file(log_line)
	emit_signal("log_message", log_line, "error")

func debug_warn(text):
	var timestamp = Time.get_datetime_string_from_system()
	var log_line = "[%s] WARNING: %s" % [timestamp, str(text)]
	
	print(log_line)
	_write_to_log_file(log_line)
	emit_signal("log_message", log_line, "warning")

func _exit_tree():
	if session_initialized and not log_file_path.is_empty():
		var separator = "=".repeat(50)
		_write_to_log_file(separator)
		_write_to_log_file("DEBUG SESSION ENDED")
		_write_to_log_file("Timestamp: " + Time.get_datetime_string_from_system())
		_write_to_log_file(separator)
