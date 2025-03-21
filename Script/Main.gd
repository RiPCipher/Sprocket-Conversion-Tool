extends Control

# Config Manager
@onready var config_manager = $ConfigManager

# Converter
@onready var converter = $Convert

# UI Elements - OBJ to Blueprint
@onready var input_file_path = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/InputSection/HBoxContainer/PathInput
@onready var status_label = $MainPanel/VBoxContainer/StatusSection/StatusLabel
@onready var convert_obj_button = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/ConvertButton
@onready var browse_obj_button = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/InputSection/HBoxContainer/BrowseButton
@onready var blueprint_dir_path = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/BlueprintOutputSection/HBoxContainer/BlueprintPathInput
@onready var browse_blueprint_output = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/BlueprintOutputSection/HBoxContainer/BrowseBlueprintOutput

# Limit settings
@onready var limits_checkbox = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/LimitsSection/LimitsCheckbox
@onready var vertex_limit_input = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/LimitsSection/LimitsGrid/VertexLimitInput
@onready var face_limit_input = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/LimitsSection/LimitsGrid/FaceLimitInput
@onready var edge_limit_input = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/LimitsSection/LimitsGrid/EdgeLimitInput

# UI Elements - Blueprint to OBJ
@onready var blueprint_file_path = $MainPanel/VBoxContainer/TabContainer/"Blueprint to OBJ"/VBoxContainer/InputSection/HBoxContainer/PathInput
@onready var blueprint_output_path = $MainPanel/VBoxContainer/TabContainer/"Blueprint to OBJ"/VBoxContainer/OutputSection/HBoxContainer/OutputPathInput
@onready var browse_blueprint_button = $MainPanel/VBoxContainer/TabContainer/"Blueprint to OBJ"/VBoxContainer/InputSection/HBoxContainer/BrowseButton
@onready var browse_output_button = $MainPanel/VBoxContainer/TabContainer/"Blueprint to OBJ"/VBoxContainer/OutputSection/HBoxContainer/BrowseButton
@onready var convert_blueprint_button = $MainPanel/VBoxContainer/TabContainer/"Blueprint to OBJ"/VBoxContainer/ConvertButton

# Progress indicator
@onready var progress_bar = $MainPanel/VBoxContainer/StatusSection/ProgressBar
@onready var percent_label = $MainPanel/VBoxContainer/StatusSection/ProgressBar/PercentLabel

# UI Elements - Settings
@onready var settings_save_button = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/SaveSettingsButton
@onready var user_blueprint_path = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/FilepathSection/BlueprintFilepath/PathInput
@onready var user_obj_path = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/FilepathSection/ObjFilepath/PathInput
@onready var browse_blueprint_path = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/FilepathSection/BlueprintFilepath/BrowseButton
@onready var browse_obj_path = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/FilepathSection/ObjFilepath/BrowseButton

# Animation 
@onready var sprocket_animation_player = $Background/Gear/Icon/AnimationPlayer

# File dialogs
var file_dialog_obj: FileDialog
var file_dialog_blueprint: FileDialog
var file_dialog_output: FileDialog
var file_dialog_blueprint_output: FileDialog

func _ready():
	# Set window size and position
	DisplayServer.window_set_size(Vector2i(780, 700))
	
	# Center window on screen
	var screen_size = DisplayServer.screen_get_size()
	var window_size = DisplayServer.window_get_size()
	DisplayServer.window_set_position((screen_size - window_size) / 2)
	
	# Set window title
	DisplayServer.window_set_title("Sprocket Conversion Tool")
	
	# Connect config manager signals
	config_manager.connect("config_loaded", Callable(self, "_on_config_loaded"))
	config_manager.connect("config_saved", Callable(self, "_on_config_saved"))
	
	# Initialize file dialogs
	_setup_file_dialogs()
	
	# Connect signals from converter classes
	converter.connect("conversion_complete", Callable(self, "_on_conversion_complete"))
	converter.connect("progress_updated", Callable(self, "_on_conversion_progress"))
	
	# Connect buttons - OBJ to Blueprint
	browse_obj_button.connect("pressed", Callable(self, "_on_browse_obj_pressed"))
	browse_blueprint_output.connect("pressed", Callable(self, "_on_browse_blueprint_output_pressed"))
	convert_obj_button.connect("pressed", Callable(self, "_on_convert_obj_pressed"))
	
	# Connect buttons - Blueprint to OBJ
	browse_blueprint_button.connect("pressed", Callable(self, "_on_browse_blueprint_pressed"))
	browse_output_button.connect("pressed", Callable(self, "_on_browse_output_pressed"))
	convert_blueprint_button.connect("pressed", Callable(self, "_on_convert_blueprint_pressed"))
	
	# Connect buttons - Settings
	browse_blueprint_path.connect("pressed", Callable(self, "_on_settings_blueprint_browse_pressed"))
	browse_obj_path.connect("pressed", Callable(self, "_on_settings_obj_browse_pressed"))
	if settings_save_button:
		settings_save_button.connect("pressed", Callable(self, "_on_save_settings_pressed"))
	
	# Initialize limits settings
	_setup_limits_settings()
	
	# Initialize progress bar
	progress_bar.value = 0
	progress_bar.visible = false
	percent_label.visible = false
	
	call_deferred("_connect_tab_changed_signal")
	
	# Ensure placeholders are updated after everything is initialized
	call_deferred("_update_all_placeholder_texts")
	
	# Starts Spin Animation
	sprocket_animation_player.play("Spin")
	
func _on_tab_changed(tab_index):
	# Save the last tab index to config
	config_manager.set_last_tab(tab_index)

func _on_config_loaded():
	# Load saved paths
	var blueprint_dir = config_manager.get_saved_path("blueprint_dir")
	if !blueprint_dir.is_empty():
		blueprint_dir_path.text = blueprint_dir
	else:
		blueprint_dir_path.text = ""
		
	input_file_path.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	blueprint_dir_path.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	# Update limits settings from config
	var limits = config_manager.get_limits()
	vertex_limit_input.text = str(limits.vertex_limit)
	face_limit_input.text = str(limits.face_limit)
	edge_limit_input.text = str(limits.edge_limit)
	limits_checkbox.button_pressed = limits.enforce_limits
	_update_limit_fields_editable(!limits.enforce_limits)
	
	# Restore last used tab
	var last_tab = config_manager.get_last_tab()
	$MainPanel/VBoxContainer/TabContainer.current_tab = last_tab
	
	# Load saved paths into Settings tab
	if user_obj_path:
		var obj_dir = config_manager.get_saved_path("obj_dir")
		user_obj_path.text = obj_dir
	
	if user_blueprint_path:
		blueprint_dir = config_manager.get_saved_path("blueprint_dir")
		user_blueprint_path.text = blueprint_dir
	
	# Update all placeholder texts
	_update_all_placeholder_texts()

func _on_config_saved():
	status_label.text = "Settings saved successfully at: " + config_manager.CONFIG_FILE_PATH
	
	# Only update path if there's a value in config
	var blueprint_dir = config_manager.get_saved_path("blueprint_dir")
	if !blueprint_dir.is_empty():
		blueprint_dir_path.text = blueprint_dir
	else:
		blueprint_dir_path.text = ""
	
	# Update all placeholder texts
	_update_all_placeholder_texts()

# Initialize limits settings
func _setup_limits_settings():
	# Get limit settings from config
	var limits = config_manager.get_limits()
	
	# Set default values
	vertex_limit_input.text = str(limits.vertex_limit)
	face_limit_input.text = str(limits.face_limit)
	edge_limit_input.text = str(limits.edge_limit)
	
	# Connect checkbox signal
	if !limits_checkbox.is_connected("toggled", Callable(self, "_on_limits_toggled")):
		limits_checkbox.connect("toggled", Callable(self, "_on_limits_toggled"))
	
	# Set checkbox state from confg
	limits_checkbox.button_pressed = limits.enforce_limits
	
	# Make input fields read-only by default
	_update_limit_fields_editable(!limits.enforce_limits)

# Handle limits checkbox toggle
func _on_limits_toggled(button_pressed):
	_update_limit_fields_editable(!button_pressed)
	
	# If limits are turned off / 50k editable limit
	if !button_pressed:
		vertex_limit_input.text = str(50000)
		face_limit_input.text = str(50000)
		edge_limit_input.text = str(50000)
	else:
		# Get defaults from config
		var limits = config_manager.get_limits()
		vertex_limit_input.text = str(limits.vertex_limit)
		face_limit_input.text = str(limits.face_limit)
		edge_limit_input.text = str(limits.edge_limit)
	
	# Save the setting // Annoying to save every toggle
	#config_manager.settings.limits.enforce_limits = button_pressed
	#config_manager.save_config()

# Update whether limit fields are editable
func _update_limit_fields_editable(editable: bool):
	vertex_limit_input.editable = editable
	face_limit_input.editable = editable
	edge_limit_input.editable = editable
	
	if editable:
		vertex_limit_input.add_theme_color_override("font_color", Color(1, 1, 1))
		face_limit_input.add_theme_color_override("font_color", Color(1, 1, 1))
		edge_limit_input.add_theme_color_override("font_color", Color(1, 1, 1))
	else:
		vertex_limit_input.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		face_limit_input.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		edge_limit_input.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

# Setup file dialogs
func _setup_file_dialogs():
	# OBJ file dialog
	file_dialog_obj = FileDialog.new()
	file_dialog_obj.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog_obj.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog_obj.filters = PackedStringArray(["*.obj ; OBJ Files"])
	file_dialog_obj.title = "Select OBJ File"
	file_dialog_obj.connect("file_selected", Callable(self, "_on_obj_file_selected"))
	file_dialog_obj.min_size = Vector2(600, 500)
	
	# Set initial directory from config
	var obj_dir = config_manager.get_saved_path("obj_dir")
	if !obj_dir.is_empty() && DirAccess.dir_exists_absolute(obj_dir):
		file_dialog_obj.current_dir = obj_dir
	
	add_child(file_dialog_obj)
	
	# Blueprint file dialog
	file_dialog_blueprint = FileDialog.new()
	file_dialog_blueprint.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog_blueprint.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog_blueprint.filters = PackedStringArray(["*.blueprint ; Blueprint Files"])
	file_dialog_blueprint.title = "Select Blueprint File"
	file_dialog_blueprint.connect("file_selected", Callable(self, "_on_blueprint_file_selected"))
	file_dialog_blueprint.min_size = Vector2(600, 500)
	
	# Set initial directory from config
	var blueprint_dir = config_manager.get_saved_path("blueprint_dir")
	if !blueprint_dir.is_empty() && DirAccess.dir_exists_absolute(blueprint_dir):
		file_dialog_blueprint.current_dir = blueprint_dir
	
	add_child(file_dialog_blueprint)
	
	# Output file dialog
	file_dialog_output = FileDialog.new()
	file_dialog_output.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog_output.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog_output.filters = PackedStringArray(["*.obj ; OBJ Files"])
	file_dialog_output.title = "Save OBJ File"
	file_dialog_output.connect("file_selected", Callable(self, "_on_output_file_selected"))
	file_dialog_output.min_size = Vector2(600, 500)
	
	# Set initial directory from config
	var obj_path = config_manager.get_saved_path("obj_dir")
	if !obj_path.is_empty() && DirAccess.dir_exists_absolute(obj_path):
		file_dialog_output.current_dir = obj_path
	
	add_child(file_dialog_output)
	
	# Blueprint output file dialog
	file_dialog_blueprint_output = FileDialog.new()
	file_dialog_blueprint_output.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog_blueprint_output.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog_blueprint_output.filters = PackedStringArray(["*.blueprint ; Blueprint Files"])
	file_dialog_blueprint_output.title = "Save Blueprint File"
	file_dialog_blueprint_output.connect("file_selected", Callable(self, "_on_blueprint_output_file_selected"))
	file_dialog_blueprint_output.min_size = Vector2(600, 500)
	
	# Set initial directory from blueprint config
	blueprint_dir = config_manager.get_saved_path("blueprint_dir")
	if !blueprint_dir.is_empty() && DirAccess.dir_exists_absolute(blueprint_dir):
		file_dialog_blueprint_output.current_dir = blueprint_dir
	
	add_child(file_dialog_blueprint_output)

# OBJ to Blueprint UI handlers
func _on_browse_obj_pressed():
	# Update from latest settings
	var obj_dir = config_manager.get_saved_path("obj_dir")
	if !obj_dir.is_empty() && DirAccess.dir_exists_absolute(obj_dir):
		file_dialog_obj.current_dir = obj_dir
	
	file_dialog_obj.popup_centered_ratio(0.7)

func _on_obj_file_selected(path):
	input_file_path.text = path
	input_file_path.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	status_label.text = "OBJ file selected: " + path.get_file()
	
	# Save the directory path
	config_manager.save_last_directory("obj_dir", path)
	
	# Auto-populate the blueprint output path
	var blueprint_dir = config_manager.get_saved_path("blueprint_dir")
	if blueprint_dir.is_empty():
		blueprint_dir = path.get_base_dir()
	
	var blueprint_path_input = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/BlueprintOutputSection/HBoxContainer/BlueprintPathInput
	blueprint_path_input.text = blueprint_dir + "/" + path.get_file().get_basename() + ".blueprint"
	
	# Auto-populate the output file path for Blueprint to OBJ (if empty)
	if blueprint_output_path.text.is_empty():
		blueprint_output_path.text = path.get_base_dir() + "/" + path.get_file().get_basename() + ".obj"

func _on_blueprint_dir_selected(path):
	blueprint_dir_path.text = path
	blueprint_dir_path.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	# Save as blueprint directory path
	config_manager.set_saved_path("blueprint_dir", path)
	
	# Update status label
	status_label.text = "Blueprint output directory set to: " + path

# Blueprint to OBJ UI handlers
func _on_browse_blueprint_pressed():
	# Update from latest settings
	var blueprint_dir = config_manager.get_saved_path("blueprint_dir")
	if !blueprint_dir.is_empty() && DirAccess.dir_exists_absolute(blueprint_dir):
		file_dialog_blueprint.current_dir = blueprint_dir
	
	file_dialog_blueprint.popup_centered_ratio(0.7)

func _on_browse_blueprint_output_pressed():
	# Update from latest settings
	var blueprint_dir = config_manager.get_saved_path("blueprint_dir")
	if !blueprint_dir.is_empty() && DirAccess.dir_exists_absolute(blueprint_dir):
		file_dialog_blueprint_output.current_dir = blueprint_dir
	
	file_dialog_blueprint_output.popup_centered_ratio(0.7)

func _on_blueprint_output_file_selected(path):
	var blueprint_path_input = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/BlueprintOutputSection/HBoxContainer/BlueprintPathInput
	blueprint_path_input.text = path
	status_label.text = "Blueprint will be saved to: " + path
	
	# Save the directory path
	config_manager.save_last_directory("blueprint_dir", path)

func _on_browse_output_pressed():
	file_dialog_output.popup_centered_ratio(0.7)

func _on_blueprint_file_selected(path):
	blueprint_file_path.text = path
	status_label.text = "Blueprint file selected: " + path.get_file()
	
	# Save the directory path
	config_manager.save_last_directory("blueprint_dir", path)
	
	# Auto-populate the output path
	var obj_dir = config_manager.get_saved_path("obj_dir")
	if obj_dir.is_empty():
		obj_dir = path.get_base_dir()
	
	blueprint_output_path.text = obj_dir + "/" + path.get_file().get_basename() + ".obj"

func _on_output_file_selected(path):
	blueprint_output_path.text = path
	status_label.text = "Output will be saved to: " + path
	
	# Save the directory path
	config_manager.save_last_directory("obj_dir", path)

# Settings save
func _on_save_settings_pressed():
	# Get values from Settings tab
	var obj_path = user_obj_path.text if user_obj_path else ""
	var blueprint_path = user_blueprint_path.text if user_blueprint_path else ""
	
	# Update config values
	if !obj_path.is_empty():
		config_manager.set_saved_path("obj_dir", obj_path)
	if !blueprint_path.is_empty():
		config_manager.set_saved_path("blueprint_dir", blueprint_path)
	
	# Get and save limit values
	var limits = {
		"enforce_limits": limits_checkbox.button_pressed,
		"vertex_limit": int(vertex_limit_input.text),
		"face_limit": int(face_limit_input.text),
		"edge_limit": int(edge_limit_input.text)
	}
	config_manager.set_limits(limits)
	
	# Save config
	config_manager.save_config()
	
	# Update all placeholders to reflect the new settings
	_update_all_placeholder_texts()

func _update_all_placeholder_texts():
	# Get the current saved paths
	var obj_dir = config_manager.get_saved_path("obj_dir")
	var blueprint_dir = config_manager.get_saved_path("blueprint_dir")
	
	# Update OBJ to Blueprint tab
	if input_file_path:
		input_file_path.placeholder_text = "Select OBJ file to convert"
		input_file_path.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	
	var blueprint_path_input = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/BlueprintOutputSection/HBoxContainer/BlueprintPathInput
	if blueprint_path_input:
		blueprint_path_input.placeholder_text = "Save Blueprint file to..."
		blueprint_path_input.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	
	# Update Blueprint to OBJ tab
	if blueprint_file_path:
		blueprint_file_path.placeholder_text = "Select Blueprint file to convert"
	
	if blueprint_output_path:
		blueprint_output_path.placeholder_text = "Save OBJ file to..."
	
	# Update Settings tab
	if user_obj_path:
		if user_obj_path.text.is_empty():
			user_obj_path.placeholder_text = obj_dir
	
	if user_blueprint_path:
		if user_blueprint_path.text.is_empty():
			user_blueprint_path.placeholder_text = blueprint_dir

# Conversion
func _on_convert_obj_pressed():
	# Start conversion
	status_label.text = "Converting OBJ file..."
	progress_bar.visible = true
	percent_label.visible = true
	progress_bar.value = 0
	
	# Disable buttons during conversion
	_set_buttons_enabled(false)
	
	var input_path = input_file_path.text.strip_edges()
	var blueprint_path = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/BlueprintOutputSection/HBoxContainer/BlueprintPathInput.text.strip_edges()
	
	if input_path.is_empty():
		status_label.text = "Error: Please select an input OBJ file"
		progress_bar.visible = false
		percent_label.visible = false
		_set_buttons_enabled(true)
		return
	
	if blueprint_path.is_empty():
		status_label.text = "Error: Please select a blueprint output file"
		progress_bar.visible = false
		percent_label.visible = false
		_set_buttons_enabled(true)
		return
	
	# Get limit settings
	var vertex_limit = int(vertex_limit_input.text)
	var face_limit = int(face_limit_input.text)
	var edge_limit = int(edge_limit_input.text)
	
	# Save these settings to config
	config_manager.settings.limits.vertex_limit = vertex_limit
	config_manager.settings.limits.face_limit = face_limit
	config_manager.settings.limits.edge_limit = edge_limit
	config_manager.save_config()
	
	# Extract blueprint name and directory from the full path
	var blueprint_name = blueprint_path.get_file().get_basename()
	var blueprint_dir = blueprint_path.get_base_dir()
	
	# Call the converter with limit settings
	var result = converter.convert_OBJToBlueprint(
		input_path, 
		blueprint_name, 
		blueprint_dir,
		vertex_limit,
		face_limit,
		edge_limit
	)
	
	# Handle immediate errors
	if result.has("error"):
		status_label.text = "Error: " + result.error
		progress_bar.visible = false
		percent_label.visible = false
		_set_buttons_enabled(true)

func _on_convert_blueprint_pressed():
	# Start conversion
	status_label.text = "Converting Blueprint file to OBJ..."
	progress_bar.visible = true
	progress_bar.value = 0
	percent_label.visible = true
	
	# Disable buttons during conversion
	_set_buttons_enabled(false)
	
	var input_path = blueprint_file_path.text.strip_edges()
	var output_path = blueprint_output_path.text.strip_edges()
	
	# Call the converter
	var result = converter.convert_BlueprintToOBJ(input_path, output_path)
	
	# Handle immediate errors
	if result.has("error"):
		status_label.text = "Error: " + result.error
		progress_bar.visible = false
		percent_label.visible = false
		_set_buttons_enabled(true)

# Conversion complete callback
func _on_conversion_complete(result):
	# Re-enable buttons
	_set_buttons_enabled(true)
	
	if result.has("error"):
		status_label.text = "Error: " + result.error
		progress_bar.visible = false
		percent_label.visible = false
		return
		
	if result.has("obj_path"):
		# Blueprint to OBJ conversion complete
		status_label.text = "Success: Blueprint converted and saved to " + result.obj_path + "\nVertices: " + str(result.vertex_count) + ", Faces: " + str(result.face_count)
	elif result.has("output_path"):
		# OBJ to Blueprint conversion complete
		var message = "Success: OBJ converted and saved to " + result.output_path + "\n"
		
		# Add mesh statistics if available // Annoying UI Scaling + Unneeded Data
		#if result.has("vertex_count"):
			#message += "\nVertex count: " + str(result.vertex_count)
			#message += "\nFace count: " + str(result.face_count)
			#message += "\nEdge count: " + str(result.edge_count)
			
		status_label.text = message
	else:
		status_label.text = "Conversion completed successfully."
	
	# Hide progress bar when done
	progress_bar.visible = false
	percent_label.visible = false
	progress_bar.value = 0

# Update progress bar based on conversion progress
func _on_conversion_progress(value):
	# Update the progress bar
	progress_bar.value = value * 100
	percent_label.text = str(int(value * 100)) + "%"
	# Process events to keep UI responsive
	await get_tree().process_frame

# Enable or disable all buttons
func _set_buttons_enabled(enabled: bool):
	convert_obj_button.disabled = !enabled
	convert_blueprint_button.disabled = !enabled
	browse_obj_button.disabled = !enabled
	browse_blueprint_output.disabled = !enabled
	browse_blueprint_button.disabled = !enabled
	browse_output_button.disabled = !enabled
	limits_checkbox.disabled = !enabled

func _on_settings_blueprint_browse_pressed():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = "Select Blueprint Directory"
	dialog.connect("dir_selected", Callable(self, "_on_settings_blueprint_dir_selected"))
	dialog.min_size = Vector2(600, 500)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)

func _on_settings_obj_browse_pressed():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = "Select OBJ Directory"
	dialog.connect("dir_selected", Callable(self, "_on_settings_obj_dir_selected"))
	dialog.min_size = Vector2(600, 500)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)

func _on_settings_blueprint_dir_selected(path):
	user_blueprint_path.text = path
	
	# Update the config immediately
	config_manager.set_saved_path("blueprint_dir", path)
	
	# Also update the Blueprint Output field directly
	blueprint_dir_path.text = path

func _on_settings_obj_dir_selected(path):
	user_obj_path.text = path
	# Update the config immediately
	config_manager.set_saved_path("obj_dir", path)
	
# Connect to the tab_changed signal after nodes are ready
func _connect_tab_changed_signal():
	var tab_container = $MainPanel/VBoxContainer/TabContainer
	if tab_container:
		tab_container.connect("tab_changed", Callable(self, "_on_tab_changed"))
	else:
		push_error("TabContainer node not found")
