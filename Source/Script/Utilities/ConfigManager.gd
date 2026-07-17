extends Node

signal config_loaded
signal config_saved

# Settings file path
var CONFIG_FILE_PATH = ""

# Default values
var default_obj_path = ""
var default_blueprint_path = ""
var default_conversion_path = ""

# Settings dictionary
var settings = {
	"paths": {
		"input_dir": "",
		"output_dir":"",
		"preview_dir": ""
	},
	"preview": {
		"auto_preview": false,
		"wireframe_color_index": 0,
		"mesh_color_index": 0,
		"grid_visible": true,
		"camera_fov": 75,
		
		"apply_smoothing": true
	},
	"keybinds": {
		"recenter_key": KEY_R,
		"pan_key": KEY_SHIFT,
		"zoom_in_key": KEY_E,
		"zoom_out_key": KEY_Q,
		"exit_key": KEY_ESCAPE,
		"increase_fov_key": KEY_PLUS,
		"decrease_fov_key": KEY_MINUS,
		"free_cam_key": KEY_F
	},
	"ui": {
		"window_width": 780,
		"window_height": 700,
		"is_fullscreen": false,
		"theme": "Default",
		"network_enabled": false,
		"force_native_windows": false,
	}
}

func _init():
	pass

func _ready():
	# Get executable directory for defaults
	var exe_path = OS.get_executable_path()
	var exe_dir = exe_path.get_base_dir()
	var data_dir = exe_dir.path_join("data")
	
	# Ensure data folder exists
	if not DirAccess.dir_exists_absolute(data_dir):
		DirAccess.make_dir_recursive_absolute(data_dir)
	
	CONFIG_FILE_PATH = data_dir.path_join("tool_settings.cfg")
	Debug.log("Config file location: " + CONFIG_FILE_PATH)
	
	load_config()
	
	var input_dir_from_config = get_saved_path("input_dir")
	var input_dir = get_saved_path("input_dir")
	var output_dir_from_config = get_saved_path("output_dir")
	var output_dir = exe_dir + "/Output"
	var default_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("My Games").path_join("Sprocket").path_join("Factions")
	
	if input_dir_from_config.is_empty():
		# Checks if default exists first,
		# if not found, defaults to exe dir
		if DirAccess.dir_exists_absolute(default_dir):
			set_saved_path("input_dir", default_dir)
		else:
			set_saved_path("input_dir", exe_dir)
	
	if output_dir_from_config.is_empty():
		# Check if dir exists, if not it creates the folder
		if !DirAccess.dir_exists_absolute(output_dir):
			DirAccess.make_dir_recursive_absolute(output_dir)
		set_saved_path("output_dir", output_dir)
	
	default_conversion_path = default_dir
	
	var preview_dir_from_config = get_saved_path("preview_dir")
	var preview_dir = default_dir #exe_dir + "/Preview"
	
	if preview_dir_from_config.is_empty():
		set_saved_path("preview_dir", default_dir)
	
	if not settings.ui.has("theme"):
		settings.ui["theme"] = "Default"
	
	save_config()

func save_config() -> bool:
	# Check if we can write to the config file before attempting
	var write_check = ErrorHandler.check_file_write(CONFIG_FILE_PATH)
	if not write_check.success:
		ErrorHandler.handle_file_error(write_check.error_key, write_check.error_code, "save config", CONFIG_FILE_PATH)
		return false
	
	var config = ConfigFile.new()
	
	for key in settings.paths:
		config.set_value("paths", key, settings.paths[key])
	
	for key in settings.ui:
		config.set_value("ui", key, settings.ui[key])
	
	for key in settings.preview:
		config.set_value("preview", key, settings.preview[key])
	
	for key in settings.keybinds:
		config.set_value("keybinds", key, settings.keybinds[key])
		
	# Save with error handling
	var error = config.save(CONFIG_FILE_PATH)
	if error != OK:
		# Map the error
		var error_key = ErrorHandler._get_error_key_from_code(error)
		ErrorHandler.handle_file_error(error_key, error, "save config", CONFIG_FILE_PATH)
		return false
	
	Debug.log("Config saved successfully to: " + CONFIG_FILE_PATH)
	emit_signal("config_saved")
	return true

func load_config() -> bool:
	var config = ConfigFile.new()
	
	# Check if config file exists first
	if not FileAccess.file_exists(CONFIG_FILE_PATH):
		Debug.log("No config file found at: " + CONFIG_FILE_PATH + ", using default settings")
		emit_signal("config_loaded")
		return false
	
	# Check if we can read the file
	var read_check = ErrorHandler.check_file_read(CONFIG_FILE_PATH)
	if not read_check.success:
		ErrorHandler.handle_file_error(read_check.error_key, read_check.error_code, "load config", CONFIG_FILE_PATH)
		emit_signal("config_loaded")
		return false
	
	# Attempt to load the config file
	var error = config.load(CONFIG_FILE_PATH)
	if error != OK:
		var error_key = ErrorHandler._get_error_key_from_code(error)
		ErrorHandler.handle_file_error(error_key, error, "load config", CONFIG_FILE_PATH)
		emit_signal("config_loaded")
		return false
	
	Debug.log("Config loaded from: " + CONFIG_FILE_PATH)
	
	# Load paths section
	for key in settings.paths:
		if config.has_section_key("paths", key):
			settings.paths[key] = config.get_value("paths", key, "")
		else:
			settings.paths[key] = ""
	
	# Load UI section
	for key in settings.ui:
		if config.has_section_key("ui", key):
			settings.ui[key] = config.get_value("ui", key, settings.ui[key])
	
	# Load preview section
	for key in settings.preview:
		if config.has_section_key("preview", key):
			settings.preview[key] = config.get_value("preview", key, settings.preview[key])
	
	# Load keybinds section
	for key in settings.keybinds:
		if config.has_section_key("keybinds", key):
			settings.keybinds[key] = config.get_value("keybinds", key, settings.keybinds[key])
			
	emit_signal("config_loaded")
	return true

func get_saved_path(path_name: String) -> String:
	if settings.paths.has(path_name):
		return settings.paths[path_name]
	return ""

func set_saved_path(path_name: String, value: String) -> void:
	if settings.paths.has(path_name):
		settings.paths[path_name] = value

# Save the last directory used to memory
func save_last_directory(operation: String, path: String) -> void:
	var dir = path.get_base_dir()
	set_saved_path(operation, dir)

func get_input_dir() -> String:
	return settings.paths.input_dir if settings.paths.has("input_dir") else ""

func set_input_dir(path: String) -> void:
	settings.paths.input_dir = path

func get_output_dir() -> String:
	return settings.paths.output_dir if settings.paths.has("output_dir") else ""

func set_output_dir(path: String) -> void:
	settings.paths.output_dir = path

func get_auto_preview() -> bool:
	return settings.preview.auto_preview if settings.preview.has("auto_preview") else false

func set_auto_preview(value: bool) -> void:
	settings.preview.auto_preview = value

func get_wireframe_color_index() -> int:
	return settings.preview.wireframe_color_index if settings.preview.has("wireframe_color_index") else 0

func set_wireframe_color_index(value: int) -> void:
	settings.preview.wireframe_color_index = value

func get_mesh_color_index() -> int:
	return settings.preview.mesh_color_index if settings.preview.has("mesh_color_index") else 0

func set_mesh_color_index(value: int) -> void:
	settings.preview.mesh_color_index = value

func get_window_size() -> Vector2i:
	var width = settings.ui.window_width if settings.ui.has("window_width") else 780
	var height = settings.ui.window_height if settings.ui.has("window_height") else 700
	return Vector2i(width, height)

func set_window_size(size: Vector2i) -> void:
	settings.ui.window_width = size.x
	settings.ui.window_height = size.y

func get_keybind(keybind_name: String) -> int:
	if settings.has("keybinds") and settings.keybinds.has(keybind_name):
		return settings.keybinds[keybind_name]
	
	# Return default values if not found
	match keybind_name:
		"recenter_key":
			return KEY_R
		"pan_key":
			return KEY_SHIFT
		"zoom_in_key":
			return KEY_E
		"zoom_out_key":
			return KEY_Q
		"exit_key":
			return KEY_ESCAPE
		"increase_fov_key":
			return KEY_PLUS
		"decrease_fov_key":
			return KEY_MINUS
		"free_cam_key":
			return KEY_F
		_:
			return 0

func set_keybind(keybind_name: String, value: int) -> void:
	if settings.keybinds.has(keybind_name):
		settings.keybinds[keybind_name] = value

func get_grid_visible() -> bool:
	return settings.preview.grid_visible if settings.preview.has("grid_visible") else true

func set_grid_visible(value: bool) -> void:
	settings.preview.grid_visible = value

func get_camera_fov() -> float:
	return settings.preview.camera_fov if settings.preview.has("camera_fov") else 75.0

func set_camera_fov(value: float) -> void:
	settings.preview.camera_fov = value

func get_fullscreen_state() -> bool:
	return settings.ui.is_fullscreen if settings.ui.has("is_fullscreen") else false

func set_fullscreen_state(value: bool) -> void:
	settings.ui.is_fullscreen = value

func get_theme() -> String:
	return settings.ui.theme if settings.ui.has("theme") else "Default"

func set_theme(value: String) -> void:
	settings.ui.theme = value
	
func set_native(value: bool) -> void:
	settings.ui.force_native_windows = value

func get_native() -> bool:
	return settings.ui.force_native_windows if settings.ui.has("force_native_windows") else false

func get_apply_smoothing() -> bool:
	return settings.preview.apply_smoothing if settings.preview.has("apply_smoothing") else true

func set_apply_smoothing(value: bool) -> void:
	settings.preview.apply_smoothing = value
