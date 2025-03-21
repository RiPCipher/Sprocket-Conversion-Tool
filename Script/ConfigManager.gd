extends Node

signal config_loaded
signal config_saved

# Settings file path
var CONFIG_FILE_PATH = ""

# Default values
var default_obj_path = ""
var default_blueprint_path = ""

# Node Refernces
@onready var status_label = $"../MainPanel/VBoxContainer/StatusSection/StatusLabel"

# Settings dictionary
var settings = {
	"paths": {
		"obj_dir": "",
		"blueprint_dir": ""
	},
	"limits": {
		"enforce_limits": true,
		"vertex_limit": 8000,
		"face_limit": 4000,
		"edge_limit": 12000
	},
	"ui": {
		"last_tab": 0
	}
}

func _init():
	# Set config path to be next to the executable
	var exe_path = OS.get_executable_path()
	var exe_dir = exe_path.get_base_dir()
	CONFIG_FILE_PATH = exe_dir + "/sct_settings.cfg"
	print("Config file location: " + CONFIG_FILE_PATH)

func _ready():
	# Get executable directory for defaults
	var exe_path = OS.get_executable_path()
	var exe_dir = exe_path.get_base_dir()
	
	#load the existing config to check if paths already exist
	load_config()
	
	# Only create default Blueprints folder if no blueprint_dir is set in config
	var blueprint_dir_from_config = get_saved_path("blueprint_dir")
	var blueprints_dir = exe_dir + "/Blueprints"
	
	if blueprint_dir_from_config.is_empty():
		# Only create the default folder if it doesn't exist and no path is configured
		if !DirAccess.dir_exists_absolute(blueprints_dir):
			# Try to create it
			DirAccess.make_dir_recursive_absolute(blueprints_dir)
	
	# Store default path but don't use for automatic population
	default_blueprint_path = blueprints_dir
	
	# Only create default Objects folder if no obj_dir is set in config
	var obj_dir_from_config = get_saved_path("obj_dir")
	var objects_dir = exe_dir + "/Objects"
	
	if obj_dir_from_config.is_empty():
		# Only create the default folder if it doesn't exist and no path is configured
		if !DirAccess.dir_exists_absolute(objects_dir):
			# Try to create it
			DirAccess.make_dir_recursive_absolute(objects_dir)
	
	default_obj_path = objects_dir

# Save config
func save_config() -> bool:
	var config = ConfigFile.new()
	
	# Save paths
	for key in settings.paths:
		config.set_value("paths", key, settings.paths[key])
	
	# Save limits
	for key in settings.limits:
		config.set_value("limits", key, settings.limits[key])
	
	# Save UI settings
	for key in settings.ui:
		config.set_value("ui", key, settings.ui[key])
	
	# Save
	var error = config.save(CONFIG_FILE_PATH)
	if error == OK:
		print("Config saved successfully to: " + CONFIG_FILE_PATH)
		emit_signal("config_saved")
		return true
	
	push_error("Failed to save config file. Error code: " + str(error))
	return false

# Load configuration
func load_config() -> bool:
	var config = ConfigFile.new()
	
	# Check if the config file exists
	if not FileAccess.file_exists(CONFIG_FILE_PATH):
		print("No config file found at: " + CONFIG_FILE_PATH + ", using empty settings")
		# No existing config - use empty settings
		emit_signal("config_loaded")
		return false
	
	# Load the config file
	var error = config.load(CONFIG_FILE_PATH)
	if error != OK:
		push_error("Failed to load config file. Error code: " + str(error))
		emit_signal("config_loaded")
		return false
	
	print("Config loaded from: " + CONFIG_FILE_PATH)
	
	# Load paths (with empty defaults if not found)
	for key in settings.paths:
		if config.has_section_key("paths", key):
			settings.paths[key] = config.get_value("paths", key, "")
		else:
			settings.paths[key] = ""
	
	# Load limits (with defaults if not found)
	for key in settings.limits:
		if config.has_section_key("limits", key):
			settings.limits[key] = config.get_value("limits", key, settings.limits[key])
	
	# Load UI settings (with defaults if not found)
	for key in settings.ui:
		if config.has_section_key("ui", key):
			settings.ui[key] = config.get_value("ui", key, settings.ui[key])
	
	emit_signal("config_loaded")
	return true

# Get a path setting
func get_saved_path(path_name: String) -> String:
	if settings.paths.has(path_name):
		return settings.paths[path_name]
	return ""

# Set a path setting
func set_saved_path(path_name: String, value: String) -> void:
	if settings.paths.has(path_name):
		settings.paths[path_name] = value

# Save the last directory used to memory
func save_last_directory(operation: String, path: String) -> void:
	var dir = path.get_base_dir()
	set_saved_path(operation, dir)

# Get limit settings
func get_limits() -> Dictionary:
	return settings.limits.duplicate()

# Set limit settings
func set_limits(new_limits: Dictionary) -> void:
	for key in new_limits:
		if settings.limits.has(key):
			settings.limits[key] = new_limits[key]

# Get the last tab index
func get_last_tab() -> int:
	return settings.ui.last_tab if settings.ui.has("last_tab") else 0

# Set the last tab index
func set_last_tab(tab_index: int) -> void:
	settings.ui.last_tab = tab_index
