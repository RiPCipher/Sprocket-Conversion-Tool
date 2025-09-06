extends Node

var log_file_path: String
var debug_folder_path: String
var session_start_time: String
var session_initialized: bool = false

var debugger_version = "0444" # Compatible with 0.4.4rc3

func _ready():
	session_start_time = Time.get_datetime_string_from_system().replace(":", "-")
	print("Debugger: Initialized and ready")

func set_debug_folder(folder_path: String):
	"""Called by Debug.gd to tell us where to put files"""
	debug_folder_path = folder_path
	_setup_logging()

func _setup_logging():
	if debug_folder_path.is_empty():
		push_error("Debugger: No debug folder path provided")
		return
	
	log_file_path = debug_folder_path + "/debug_log_" + session_start_time + ".txt"
	
	# Create initial file with session header
	var file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if file:
		_write_session_header_to_file(file)
		file.close()
		session_initialized = true
		print("Debugger: Logging to: " + log_file_path)
	else:
		push_error("Debugger: Failed to create log file at: " + log_file_path)

func _write_session_header_to_file(file: FileAccess):
	if not file:
		return
		
	var separator = "=".repeat(50)
	var version = ProjectSettings.get_setting("application/config/version", "Unknown")
	var app_name = ProjectSettings.get_setting("application/config/name", "Application")
	
	file.store_line(separator)
	file.store_line("DEBUG SESSION STARTED")
	file.store_line(separator)
	file.store_line(app_name)
	file.store_line("debugger version " + "v" + debugger_version)
	file.store_line("tool version " + "v" + version)
	file.store_line("Timestamp: " + Time.get_datetime_string_from_system())
	file.store_line(separator)

func _write_to_log_file(text: String):
	if not session_initialized or log_file_path.is_empty():
		return
	
	# Open in read-write mode to append to existing file
	var file = FileAccess.open(log_file_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()  # Move to end of file for appending
		file.store_line(text)
		file.close()  # Immediate close ensures data is written
	else:
		# Fallback: print error but don't spam console
		push_warning("Debugger: Failed to write to log file")

func debug_log(text):
	var timestamp = Time.get_datetime_string_from_system()
	var log_line = "[%s] %s" % [timestamp, str(text)]
	
	# Still print to console
	print(log_line)
	
	# Write to file using write-and-close pattern
	_write_to_log_file(log_line)

func debug_error(text):
	debug_log("ERROR: " + str(text))

func debug_warn(text):
	debug_log("WARNING: " + str(text))

func _exit_tree():
	if session_initialized and not log_file_path.is_empty():
		var separator = "=".repeat(50)
		_write_to_log_file(separator)
		_write_to_log_file("DEBUG SESSION ENDED")
		_write_to_log_file("Timestamp: " + Time.get_datetime_string_from_system())
		_write_to_log_file(separator)
