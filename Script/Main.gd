extends Control

# Preview Constants
const DEFAULT_MATERIAL = preload("res://Textures/3D/Default.tres")

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
@onready var auto_preview_checkbox = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer/CheckButton
@onready var user_preview_path = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/FilepathSection/PreviewFilePath/PathInput
@onready var browse_preview_path = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/FilepathSection/PreviewFilePath/BrowseButton

# UI Elements - Preview
@onready var browse_preview_files_path = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/InputSection/HBoxContainer/PathInput"
@onready var browse_preview_files = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/InputSection/HBoxContainer/BrowseButton"
@onready var subviewport_container = $MainPanel/VBoxContainer/TabContainer/"Model Preview"/VBoxContainer/SubViewportContainer
@onready var subviewport = $MainPanel/VBoxContainer/TabContainer/"Model Preview"/VBoxContainer/SubViewportContainer/SubViewport
@onready var model_root = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/SubViewport/model_root"
@onready var camera = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/SubViewport/3DView"
@onready var world_environment = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/SubViewport/World/WorldEnvironment"
@onready var brightness_slider = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/HBoxContainer/VBoxContainer/HSlider"
@onready var world_node = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/SubViewport/World"
@onready var lighting_slider = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/HBoxContainer/VBoxContainer/HSlider2"

# Animation 
@onready var sprocket_animation_player = $Background/Gear/Icon/AnimationPlayer

# File dialogs
var file_dialog_obj: FileDialog
var file_dialog_blueprint: FileDialog
var file_dialog_output: FileDialog
var file_dialog_blueprint_output: FileDialog
var file_dialog_preview: FileDialog

# Camera Control Variables
var is_rotating = false
var last_mouse_pos = Vector2()
var rotation_sensitivity = 0.005 
var camera_zoom_speed = 0.5
var camera_min_distance = 0.5
var camera_max_distance = 20.0
var camera_bounds_radius = 15.0
var constraint_margin = 0.5
var orbit_pivot_point = Vector3.ZERO
var target_zoom_distance = 5.0
var current_zoom_distance = 5.0
var zoom_smoothing = 10.0

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
	if auto_preview_checkbox:
		auto_preview_checkbox.connect("toggled", Callable(self, "_on_auto_preview_toggled"))
	if browse_preview_path:
		browse_preview_path.connect("pressed", Callable(self, "_on_settings_preview_browse_pressed"))
		
	# Connect buttons - Preview
	browse_preview_files.connect("pressed", Callable(self, "_on_browse_preview_files_pressed"))
	brightness_slider.value = world_environment.environment.background_energy_multiplier
	brightness_slider.connect("value_changed", Callable(self, "_on_brightness_slider_changed"))
	lighting_slider.connect("value_changed", Callable(self, "_on_lighting_slider_changed"))
	
	
	# Initialize limits settings
	_setup_limits_settings()
	
	# Initialize progress bar
	progress_bar.value = 0
	progress_bar.visible = false
	percent_label.visible = false
	
	call_deferred("_connect_tab_changed_signal")
	
	# Ensure placeholders are updated after everything is initialized
	call_deferred("_update_all_placeholder_texts")
	
	# Setup model preview camera controls
	_setup_model_preview_controls()
	
	# Starts Spin Animation
	sprocket_animation_player.play("Spin")

func _process(delta):
	# Only handle controls when the preview tab is active
	if $MainPanel/VBoxContainer/TabContainer.current_tab == 2:
		# Existing code
		_handle_keyboard_navigation(delta)
		
		# Apply smooth zoom
		var pivot_point = model_root.global_position
		var current_distance = camera.global_position.distance_to(pivot_point)
		
		if abs(current_distance - target_zoom_distance) > 0.01:
			current_distance = lerp(current_distance, target_zoom_distance, delta * zoom_smoothing)
			
			# Get direction from pivot to camera
			var direction = (camera.global_position - pivot_point).normalized()
			
			# Update camera position
			camera.global_position = pivot_point + direction * current_distance
		
		_constrain_camera_to_bounds()

func _input(event):
	# Only handle inputs when on the preview tab
	if $MainPanel/VBoxContainer/TabContainer.current_tab != 2:
		return
		
	# Zoom with mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-camera_zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(camera_zoom_speed)

func _on_tab_changed(tab_index):
	config_manager.set_last_tab(tab_index)
	
	if tab_index == 2: 
		if model_root.get_child_count() == 0:
			camera.position = Vector3(0, 0, 5)
			camera.look_at(Vector3.ZERO, Vector3.UP)
			model_root.position = Vector3.ZERO

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
	
	# Set preview settings
	if auto_preview_checkbox:
		auto_preview_checkbox.button_pressed = config_manager.get_auto_preview()

	# Load preview path
	if user_preview_path:
		var preview_dir = config_manager.get_saved_path("preview_dir")
		user_preview_path.text = preview_dir
	
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
	
	# Preview File Dialogs
	file_dialog_preview = FileDialog.new()
	file_dialog_preview.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog_preview.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog_preview.filters = PackedStringArray(["*.obj ; OBJ Files", "*.blueprint ; Blueprint Files"])
	file_dialog_preview.title = "Select File to Preview"
	file_dialog_preview.connect("file_selected", Callable(self, "_on_preview_file_selected"))
	file_dialog_preview.min_size = Vector2(600, 500)
	
	# Set initial directory from config
	var preview_dir = config_manager.get_saved_path("preview_dir")
	if !preview_dir.is_empty() && DirAccess.dir_exists_absolute(preview_dir):
		file_dialog_preview.current_dir = preview_dir

	add_child(file_dialog_preview)
	
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
	
	# Auto-preview if enabled
	if config_manager.get_auto_preview():
		display_obj_model(path)
		
		# If on the preview tab, update the preview path field
		if $MainPanel/VBoxContainer/TabContainer.current_tab == 2:
			browse_preview_files_path.text = path
	
	# Auto-populate the blueprint output path
	var blueprint_dir = config_manager.get_saved_path("blueprint_dir")
	if blueprint_dir.is_empty():
		blueprint_dir = path.get_base_dir()
	
	var blueprint_path_input = $MainPanel/VBoxContainer/TabContainer/"OBJ to Blueprint"/VBoxContainer/BlueprintOutputSection/HBoxContainer/BlueprintPathInput
	blueprint_path_input.text = blueprint_dir + "/" + path.get_file().get_basename() + ".blueprint"
	
	# Auto-populate the output file path for Blueprint to OBJ
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
	
	# Auto-preview if enabled
	if config_manager.get_auto_preview():
		display_blueprint_model(path)
		
		# If on the preview tab, update the preview path field
		if $MainPanel/VBoxContainer/TabContainer.current_tab == 2:
			browse_preview_files_path.text = path
	
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
		
	# Save preview settings
	if auto_preview_checkbox:
		config_manager.set_auto_preview(auto_preview_checkbox.button_pressed)

	# Save preview path
	var preview_path = user_preview_path.text if user_preview_path else ""
	if !preview_path.is_empty():
		config_manager.set_saved_path("preview_dir", preview_path)
	
	
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
	
	# update the Blueprint Output field directly
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

## Previewer ##

func _on_auto_preview_toggled(button_pressed):
	# Update the auto-preview setting in the config
	config_manager.set_auto_preview(button_pressed)

func _on_settings_preview_browse_pressed():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = "Select Preview Directory"
	dialog.connect("dir_selected", Callable(self, "_on_settings_preview_dir_selected"))
	dialog.min_size = Vector2(600, 500)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)

func _on_settings_preview_dir_selected(path):
	user_preview_path.text = path
	# Update the config immediately
	config_manager.set_saved_path("preview_dir", path)

func _on_browse_preview_files_pressed():
	# Update from latest settings
	var preview_dir = config_manager.get_saved_path("preview_dir")
	if !preview_dir.is_empty() && DirAccess.dir_exists_absolute(preview_dir):
		file_dialog_preview.current_dir = preview_dir
	
	file_dialog_preview.popup_centered_ratio(0.7)

func _on_preview_file_selected(path):
	browse_preview_files_path.text = path
	status_label.text = "Preview file selected: " + path.get_file()
	
	# Save the directory path
	config_manager.save_last_directory("preview_dir", path)
	
	# Determine file type and display
	if path.ends_with(".obj"):
		display_obj_model(path)
	elif path.ends_with(".blueprint"):
		display_blueprint_model(path)
	else:
		status_label.text = "Unsupported file format for preview"

func _setup_model_preview_controls():
	if subviewport_container:
		subviewport_container.gui_input.connect(_on_viewport_gui_input)
	
	# Initialize orbit pivot point to model position
	orbit_pivot_point = model_root.global_position

func _on_viewport_gui_input(event):
	if event is InputEventMouseButton:
		# Left button rotates Camera around model
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_rotating = event.pressed
			last_mouse_pos = event.position
			# Update pivot point to current model position when starting orbit
			if event.pressed:
				orbit_pivot_point = model_root.global_position
	
	elif event is InputEventMouseMotion and is_rotating:
		var delta = event.position - last_mouse_pos
		last_mouse_pos = event.position
		
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			# Orbit the camera around the model
			_orbit_camera(delta)

# OBJ Models
func display_obj_model(obj_path):
	# Clear existing models
	for child in model_root.get_children():
		child.queue_free()
	
	# Read OBJ file
	var file = FileAccess.open(obj_path, FileAccess.READ)
	if file == null:
		status_label.text = "Failed to open OBJ file for preview"
		return
	
	# Parse OBJ data
	var vertices = []
	var faces = []
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		if line.begins_with("v "):
			var parts = line.split(" ", false)
			if parts.size() >= 4:
				vertices.append(Vector3(
					float(parts[1]),
					float(parts[2]),
					float(parts[3])
				))
		elif line.begins_with("f "):
			var parts = line.split(" ", false)
			if parts.size() >= 4: # Handle quads
				var face = []
				for i in range(1, parts.size()):
					var vert_parts = parts[i].split("/")
					face.append(int(vert_parts[0]) - 1)
				faces.append(face)
	
	file.close()
	
	# Validate the model data
	if vertices.size() < 3 or faces.size() < 1:
		status_label.text = "Invalid OBJ file: Not enough geometry"
		return
	
	# Create mesh data
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	
	# Convert vertices to PackedVector3Array
	var packed_vertices = PackedVector3Array()
	var packed_indices = PackedInt32Array()
	
	# Add each vertex to the array
	for v in vertices:
		packed_vertices.append(v)
	
	# Create triangle faces from potentially n-gons
	for f in faces:
		for i in range(1, f.size() - 1):
			packed_indices.append(f[0])
			packed_indices.append(f[i])
			packed_indices.append(f[i+1])
	
	# Create normals
	var packed_normals = PackedVector3Array()
	packed_normals.resize(packed_vertices.size())
	
	# Initialize all normals
	for i in range(packed_normals.size()):
		packed_normals[i] = Vector3(0, 0, 0)
	
	# Calculate face normals and assign to vertices
	for i in range(0, packed_indices.size(), 3):
		var a = packed_vertices[packed_indices[i]]
		var b = packed_vertices[packed_indices[i+1]] 
		var c = packed_vertices[packed_indices[i+2]]
		
		var normal = (b - a).cross(c - a)
		if normal.length() > 0.0001:
			normal = normal.normalized()
		else:
			normal = Vector3(0, 1, 0)
			
		# Add this normal to all vertices of this face
		packed_normals[packed_indices[i]] += normal
		packed_normals[packed_indices[i+1]] += normal
		packed_normals[packed_indices[i+2]] += normal
	
	# Normalize all vertex normals
	for i in range(packed_normals.size()):
		if packed_normals[i].length() > 0.0001:
			packed_normals[i] = packed_normals[i].normalized()
		else:
			packed_normals[i] = Vector3(0, 1, 0)
	
	# Create basic UVs based on normalized position
	var packed_uvs = PackedVector2Array()
	packed_uvs.resize(packed_vertices.size())
	
	# Find bounding box for UV normalization
	var min_pos = Vector3(INF, INF, INF)
	var max_pos = Vector3(-INF, -INF, -INF)
	
	for v in packed_vertices:
		min_pos.x = min(min_pos.x, v.x)
		min_pos.y = min(min_pos.y, v.y)
		min_pos.z = min(min_pos.z, v.z)
		max_pos.x = max(max_pos.x, v.x)
		max_pos.y = max(max_pos.y, v.y)
		max_pos.z = max(max_pos.z, v.z)
	
	# Generate UVs based on XZ coordinates
	for i in range(packed_vertices.size()):
		var v = packed_vertices[i]
		var size_x = max_pos.x - min_pos.x
		var size_z = max_pos.z - min_pos.z
		
		if size_x < 0.0001: size_x = 1.0
		if size_z < 0.0001: size_z = 1.0
		
		var u = (v.x - min_pos.x) / size_x
		var v_coord = (v.z - min_pos.z) / size_z
		
		packed_uvs[i] = Vector2(u, v_coord)
	
	# Assign arrays to surface
	surface_array[Mesh.ARRAY_VERTEX] = packed_vertices
	surface_array[Mesh.ARRAY_NORMAL] = packed_normals
	surface_array[Mesh.ARRAY_TEX_UV] = packed_uvs
	surface_array[Mesh.ARRAY_INDEX] = packed_indices
	
	# Create mesh
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	
	# Create mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	model_root.add_child(mesh_instance)
	
	# Create a material instance
	var material = DEFAULT_MATERIAL.duplicate()
	
	# Disable backface culling / for Debugging
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Apply material
	mesh_instance.set_surface_override_material(0, material)
	
	# Center the model
	var aabb = mesh_instance.get_aabb()
	model_root.position = -aabb.position - aabb.size/2
	
	# Set up camera
	var model_size = aabb.size.length()
	camera.global_position = Vector3(0, 0, model_size * 1.5)
	camera.look_at(model_root.global_position)
	
	status_label.text = "OBJ model loaded: " + obj_path.get_file()

func display_blueprint_model(blueprint_path):
	# Clear existing model
	for child in model_root.get_children():
		child.queue_free()
	
	# Read blueprint file
	var file = FileAccess.open(blueprint_path, FileAccess.READ)
	if file == null:
		status_label.text = "Failed to open blueprint file for preview"
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	# Parse JSON
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		status_label.text = "Failed to parse blueprint JSON"
		return
	
	var blueprint_data = json.get_data()
	
	# Validate blueprint format
	if !blueprint_data.has("mesh") or !blueprint_data.mesh.has("vertices") or !blueprint_data.mesh.has("faces"):
		status_label.text = "Invalid blueprint format"
		return
	
	# Extract mesh data
	var flat_vertices = blueprint_data.mesh.vertices
	var faces = blueprint_data.mesh.faces
	
	# Create vertex array
	var packed_vertices = PackedVector3Array()
	for i in range(0, flat_vertices.size(), 3):
		if i + 2 < flat_vertices.size():
			packed_vertices.append(Vector3(
				flat_vertices[i],
				flat_vertices[i+1],
				flat_vertices[i+2]
			))
	
	# Create index array from faces
	var packed_indices = PackedInt32Array()
	
	for face in faces:
		if face.has("v"):
			if face.v.size() == 3: # Triangle
				packed_indices.append(face.v[0])
				packed_indices.append(face.v[1])
				packed_indices.append(face.v[2])
			elif face.v.size() == 4: # Quad
				# First triangle
				packed_indices.append(face.v[0])
				packed_indices.append(face.v[1])
				packed_indices.append(face.v[2])
				# Second triangle
				packed_indices.append(face.v[0])
				packed_indices.append(face.v[2])
				packed_indices.append(face.v[3])
	
	# If no valid faces, exit
	if packed_indices.size() < 3:
		status_label.text = "Blueprint contains no valid geometry"
		return
	
	# Create normals
	var packed_normals = PackedVector3Array()
	packed_normals.resize(packed_vertices.size())
	
	# Initialize all normals
	for i in range(packed_normals.size()):
		packed_normals[i] = Vector3(0, 0, 0)
	
	# Calculate face normals and assign to vertices
	for i in range(0, packed_indices.size(), 3):
		var a = packed_vertices[packed_indices[i]]
		var b = packed_vertices[packed_indices[i+1]] 
		var c = packed_vertices[packed_indices[i+2]]
		
		var normal = (b - a).cross(c - a)
		if normal.length() > 0.0001:
			normal = normal.normalized()
		else:
			normal = Vector3(0, 1, 0)
			
		# Add this normal to all vertices of this face
		packed_normals[packed_indices[i]] += normal
		packed_normals[packed_indices[i+1]] += normal
		packed_normals[packed_indices[i+2]] += normal
	
	# Normalize all vertex normals
	for i in range(packed_normals.size()):
		if packed_normals[i].length() > 0.0001:
			packed_normals[i] = packed_normals[i].normalized()
		else:
			packed_normals[i] = Vector3(0, 1, 0)
	
	# Create UVs
	var packed_uvs = PackedVector2Array()
	packed_uvs.resize(packed_vertices.size())
	
	# Find bounding box for UV normalization
	var min_pos = Vector3(INF, INF, INF)
	var max_pos = Vector3(-INF, -INF, -INF)
	
	for v in packed_vertices:
		min_pos.x = min(min_pos.x, v.x)
		min_pos.y = min(min_pos.y, v.y)
		min_pos.z = min(min_pos.z, v.z)
		max_pos.x = max(max_pos.x, v.x)
		max_pos.y = max(max_pos.y, v.y)
		max_pos.z = max(max_pos.z, v.z)
	
	# Generate UVs based on XZ coordinates
	for i in range(packed_vertices.size()):
		var v = packed_vertices[i]
		var size_x = max_pos.x - min_pos.x
		var size_z = max_pos.z - min_pos.z
		
		if size_x < 0.0001: size_x = 1.0
		if size_z < 0.0001: size_z = 1.0
		
		var u = (v.x - min_pos.x) / size_x
		var v_coord = (v.z - min_pos.z) / size_z
		
		packed_uvs[i] = Vector2(u, v_coord)
	
	# Create mesh arrays
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = packed_vertices
	surface_array[Mesh.ARRAY_NORMAL] = packed_normals
	surface_array[Mesh.ARRAY_TEX_UV] = packed_uvs
	surface_array[Mesh.ARRAY_INDEX] = packed_indices
	
	# Create mesh
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	
	# Create mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	model_root.add_child(mesh_instance)
	
	# Create material instance
	var material = DEFAULT_MATERIAL.duplicate()
	
	# Disable backface culling for debugging
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Apply material
	mesh_instance.set_surface_override_material(0, material)
	
	# Center the model
	var aabb = mesh_instance.get_aabb()
	model_root.position = -aabb.position - aabb.size/2
	
	# Set up camera
	var model_size = aabb.size.length()
	camera.global_position = Vector3(0, 0, model_size * 1.5)
	camera.look_at(model_root.global_position)
	
	status_label.text = "Blueprint model loaded: " + blueprint_path.get_file()

func _orbit_camera(delta):
	# Create rotation transforms
	var rotation_y = Quaternion(Vector3.UP, -delta.x * rotation_sensitivity)
	var camera_right = camera.global_transform.basis.x
	var rotation_x = Quaternion(camera_right, -delta.y * rotation_sensitivity)
	
	# Get relative position to pivot point
	var relative_pos = camera.global_position - orbit_pivot_point
	
	# Apply rotations
	relative_pos = rotation_y * relative_pos
	relative_pos = rotation_x * relative_pos
	
	# Set new camera position
	camera.global_position = orbit_pivot_point + relative_pos
	
	# Make camera look at pivot point
	camera.look_at(orbit_pivot_point)

func _handle_keyboard_navigation(delta):
	orbit_pivot_point = model_root.global_position
	
	# Handl;e Vertical orbit with W/S
	if Input.is_key_pressed(KEY_W):
		var orbit_delta = Vector2(0.0, 7.0)
		_orbit_camera(orbit_delta)
	if Input.is_key_pressed(KEY_S):
		var orbit_delta = Vector2(0.0, -7.0)
		_orbit_camera(orbit_delta)
	# Handle horizontal orbit with A/D
	if Input.is_key_pressed(KEY_A):
		var orbit_delta = Vector2(7.0, 0.0)
		_orbit_camera(orbit_delta)
	if Input.is_key_pressed(KEY_D):
		var orbit_delta = Vector2(-7.0, 0.0)
		_orbit_camera(orbit_delta)

func _zoom_camera(zoom_amount):
	target_zoom_distance = clamp(target_zoom_distance + zoom_amount, camera_min_distance, camera_max_distance)

func _constrain_camera_to_bounds():
	var camera_pos = camera.global_position
	var model_pos = model_root.global_position
	
	# Calculate direction and distance
	var to_camera = camera_pos - model_pos
	var distance = to_camera.length()
	
	# If outside bounds, move back to boundary
	if distance > camera_bounds_radius - constraint_margin:
		camera.global_position = model_pos + to_camera.normalized() * (camera_bounds_radius - constraint_margin)

func _on_brightness_slider_changed(value):
	if world_environment and world_environment.environment:
		world_environment.environment.background_energy_multiplier = value

func _on_lighting_slider_changed(value):
	var lights = get_tree().get_nodes_in_group("Lighting")
	for light in lights:
		light.light_energy = value
