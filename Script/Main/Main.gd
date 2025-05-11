extends Control

# Framework
const ThreadPool = preload("res://MeshFramework/Threading/ThreadPool.gd")
const ModelRenderer = preload("res://MeshFramework/Renderer/ModelRenderer.gd")

# Camera
const CameraController = preload("res://Script/Main/CameraController.gd")

# Mode enums
enum BrowserMode {
	OPEN_FILE,
	SAVE_FILE,
	SELECT_DIR
}

# Colors
var mesh_colors = {
	0: Color.WHITE,
	1: Color.GREEN,
	2: Color.BLACK,
	3: Color.RED,
	4: Color.CYAN,
	5: Color.PURPLE,
	6: Color.WEB_GRAY
}
var wireframe_colors = {
	0: Color(0.0, 0.8, 1.0, 1.0), # Blue
	1: Color.GREEN,
	2: Color.BLACK,
	3: Color.RED,
	4: Color.WHITE,
	5: Color.PURPLE,
	6: Color(1.0, 0.6, 0.0, 1.0) # Orange
}

# Node/Class References
@onready var config_manager = $ConfigManager
var ui_manager = null
var model_renderer = null
var camera_controller = null

# File browser
var browser_scene = null
var browser_instance = null
var current_browser_operation = ""

# Advanced Settings
var advanced_settings_scene = null
var advanced_settings_instance = null

# Format registry and thread pool
var format_registry = null
var thread_pool = null

# UI Elements - Main tabs
@onready var tab_container = $MainPanel/VBoxContainer/TabContainer

# Progress indicator
@onready var progress_bar = $MainPanel/VBoxContainer/StatusSection/ProgressBar
@onready var percent_label = $MainPanel/VBoxContainer/StatusSection/ProgressBar/PercentLabel

# Gear animation
@onready var sprocket_animation_player = $Background/Gear/Icon/AnimationPlayer

# Preview nodes
@onready var subviewport_container = $MainPanel/VBoxContainer/TabContainer/"Model Preview"/VBoxContainer/SubViewportContainer
@onready var subviewport = $MainPanel/VBoxContainer/TabContainer/"Model Preview"/VBoxContainer/SubViewportContainer/SubViewport
@onready var model_root = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/SubViewport/model_root"
@onready var camera = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/SubViewport/3DView"

# Preview UI elements
@onready var browse_preview_files_path = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/InputSection/HBoxContainer/PathInput"
@onready var browse_preview_files = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/InputSection/HBoxContainer/BrowseButton"
@onready var brightness_slider = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/HBoxContainer/VBoxContainer/HSlider"
@onready var lighting_slider = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/HBoxContainer/VBoxContainer/HSlider2"
@onready var wireframe_toggle = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/HBoxContainer/VBoxContainer/HBoxContainer2/Button"
@onready var wireframe_overlay_toggle = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/HBoxContainer/VBoxContainer/HBoxContainer2/Button2"
@onready var world_grid_toggle = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/HBoxContainer/VBoxContainer/CheckButton3"
@onready var recenter_button = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/HBoxContainer/VBoxContainer/Button"

@onready var cut_view_toggle = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/HBoxContainer/VBoxContainer/HBoxContainer2/Button3"

# UI Elements - Settings
@onready var wireframe_color_option = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer2/OptionButton
@onready var mesh_color_option = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer3/OptionButton
@onready var advanced_settings_button = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/FilepathSection/HBoxContainer/TextureButton
@onready var advanced_preview_settings_button = $"MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/InputSection/HBoxContainer2/TextureButton"
@onready var save_settings_button = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/SaveSettingsButton
@onready var input_dir_browse_button = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/FilepathSection/InputFilepath/BrowseButton
@onready var output_dir_browse_button = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/FilepathSection/OutputFilepath/BrowseButton
@onready var preview_dir_browse_button = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/FilepathSection/PreviewFilePath/BrowseButton
@onready var input_dir_path_field = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/FilepathSection/InputFilepath/PathInput
@onready var output_dir_path_field = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/FilepathSection/OutputFilepath/PathInput
@onready var preview_dir_path_field = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/FilepathSection/PreviewFilePath/PathInput
@onready var auto_preview_toggle = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer/CheckButton
@onready var theme_dropdown = $MainPanel/VBoxContainer/TabContainer/Settings/VBoxContainer/OtherSettings/GridContainer/OptionButton

# UI Elements - Conversion tab
@onready var conversion_input_path = $MainPanel/VBoxContainer/TabContainer/Conversion/VBoxContainer/InputSection/HBoxContainer/PathInput
@onready var conversion_output_path = $MainPanel/VBoxContainer/TabContainer/Conversion/VBoxContainer/OutputSection/HBoxContainer/OutputPathInput
@onready var conversion_browse_input = $MainPanel/VBoxContainer/TabContainer/Conversion/VBoxContainer/InputSection/HBoxContainer/BrowseButton
@onready var conversion_browse_output = $MainPanel/VBoxContainer/TabContainer/Conversion/VBoxContainer/OutputSection/HBoxContainer/BrowseButton
@onready var conversion_button = $MainPanel/VBoxContainer/TabContainer/Conversion/VBoxContainer/ConvertButton
@onready var status_label = $MainPanel/VBoxContainer/StatusSection/StatusLabel
#========================
# INITIALIZATION
#========================

func _ready():
	FormatRegistry.initialize()
	format_registry = FormatRegistry
	
	thread_pool = ThreadPool.new(format_registry, 4)
	thread_pool.conversion_started.connect(_on_conversion_started)
	thread_pool.conversion_progress.connect(_on_conversion_progress)
	thread_pool.conversion_completed.connect(_on_conversion_completed)
	thread_pool.conversion_error.connect(_on_conversion_error)
	
	advanced_settings_scene = load("res://Scenes/AdvancedSettings.tscn")
	browser_scene = load("res://Scenes/Browser.tscn")

	var world_grid_scene = load("res://Scenes/WorldGrid.tscn")
	var world_grid = world_grid_scene.instantiate()
	model_root.add_child(world_grid)
	
	if config_manager:
		ui_manager = $UIManager
		ui_manager.initialize(config_manager)
		ui_manager.connect("theme_changed", _on_theme_changed)
		
		var grid_visible = config_manager.get_grid_visible()
		world_grid_toggle.button_pressed = grid_visible
		for child in model_root.get_children():
			if child.name == "WorldGrid":
				child.visible = grid_visible
				break
		
		_setup_theme_dropdown()
	
	DisplayServer.window_set_size(Vector2i(780, 700))
	
	var screen_size = DisplayServer.screen_get_size()
	var window_size = DisplayServer.window_get_size()
	DisplayServer.window_set_position((screen_size - window_size) / 2)
	
	DisplayServer.window_set_title("Sprocket Conversion Tool")
	
	model_renderer = ModelRenderer.new()
	model_renderer.set_target_viewport(subviewport)
	subviewport.add_child(model_renderer)
	
	camera_controller = CameraController.new(camera)
	camera_controller.initialize(config_manager)
	subviewport.add_child(camera_controller)
	
	_connect_signals()
	
	progress_bar.value = 0
	progress_bar.visible = false
	percent_label.visible = false
	
	sprocket_animation_player.play("Spin")
	
	config_manager.load_config()
	
	# Window size settings
	var saved_size = config_manager.get_window_size()
	DisplayServer.window_set_size(saved_size)
	
	if config_manager.get_fullscreen_state():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _connect_signals():
	config_manager.connect("config_loaded", _on_config_loaded)
	config_manager.connect("config_saved", _on_config_saved)
	
	# Conversion UI
	conversion_browse_input.connect("pressed", _on_browse_conversion_input_pressed)
	conversion_browse_output.connect("pressed", _on_browse_conversion_output_pressed)
	conversion_button.connect("pressed", _on_convert_file_pressed)
	
	# Connect preview UI
	brightness_slider.connect("value_changed", _on_brightness_slider_changed)
	lighting_slider.connect("value_changed", _on_lighting_slider_changed)
	wireframe_toggle.connect("toggled", _on_wireframe_toggled)
	wireframe_overlay_toggle.connect("toggled", _on_wireframe_overlay_toggled)
	world_grid_toggle.connect("toggled", _on_grid_toggle_toggled)
	recenter_button.connect("pressed", _on_recenter_pressed)
	browse_preview_files.connect("pressed", _on_browse_preview_files_pressed)
	cut_view_toggle.connect("toggled", _on_cut_view_toggled)
	
	# Viewport / Camera Stuff
	subviewport_container.gui_input.connect(camera_controller._on_viewport_gui_input)
	camera_controller.orbit_point = model_root.global_position
	camera_controller.initial_model_position = model_root.global_position
	
	# Connect Settings
	advanced_settings_button.connect("pressed", Callable(self, "_on_advanced_settings_pressed").bind(0))
	advanced_preview_settings_button.connect("pressed", Callable(self, "_on_advanced_settings_pressed").bind(0))
	input_dir_browse_button.connect("pressed", _on_browse_input_dir_pressed)
	output_dir_browse_button.connect("pressed", _on_browse_output_dir_pressed)
	preview_dir_browse_button.connect("pressed", _on_browse_preview_dir_pressed)
	save_settings_button.connect("pressed", _on_save_settings_pressed)
	auto_preview_toggle.connect("toggled", _on_auto_preview_toggled)
	
	# Setup tab change signal
	call_deferred("_connect_tab_changed_signal")
	
	# Setup drag/drop
	get_viewport().files_dropped.connect(_on_files_dropped)

func _connect_tab_changed_signal():
	tab_container.connect("tab_changed", Callable(self, "_on_tab_changed"))

#========================
# INPUT HANDLING
#========================
func _process(delta):
	if tab_container.current_tab == 1 and camera_controller:
		camera_controller.process_camera(delta)
		camera_controller.handle_keyboard_navigation(delta)

func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo():
		var exit_key = config_manager.get_keybind("exit_key")
		if exit_key != 0 and event.keycode == exit_key:
			config_manager.save_config()
			get_tree().quit()

func _on_files_dropped(files):
	if files.size() > 0:
		var file_path = files[0]
		var extension = file_path.get_extension().to_lower()
		var tab = tab_container.current_tab
		
		print("File dropped: ", file_path)
		
		if tab == 1:  # Preview tab
			if extension == "obj" or extension == "blueprint":
				browse_preview_files_path.text = file_path
				_preview_file(file_path)
		elif tab == 0:
			if extension == "obj" or extension == "blueprint":
				_on_conversion_input_file_selected(file_path)
				if config_manager.get_auto_preview() and tab != 1:
					tab_container.current_tab = 1
					_preview_file(file_path)

#========================
# UI EVENT HANDLERS
#========================
func _on_tab_changed(tab_index):
	config_manager.set_last_tab(tab_index)
	
	if tab_index == 2:
		if camera_controller:
			camera_controller.reset_camera()

func _on_recenter_pressed():
	if camera_controller:
		camera_controller.reset_camera()

func _on_wireframe_toggled(enabled):
	if model_renderer:
		if enabled:
			wireframe_overlay_toggle.button_pressed = false
			cut_view_toggle.button_pressed = false
		_update_render_mode()

func _on_wireframe_overlay_toggled(enabled):
	if model_renderer:
		if enabled:
			wireframe_toggle.button_pressed = false
			cut_view_toggle.button_pressed = false
		_update_render_mode()

func _on_cut_view_toggled(enabled):
	if model_renderer:
		if enabled:
			wireframe_toggle.button_pressed = false
			wireframe_overlay_toggle.button_pressed = false
		_update_render_mode()

func _on_grid_toggle_toggled(enabled):
	for child in model_root.get_children():
		if child.name == "WorldGrid":
			child.visible = enabled
			if config_manager:
				config_manager.set_grid_visible(enabled)
			break

func _on_brightness_slider_changed(value):
	if subviewport.get_node_or_null("World/WorldEnvironment"):
		subviewport.get_node("World/WorldEnvironment").environment.background_energy_multiplier = value

func _on_lighting_slider_changed(value):
	var lights = get_tree().get_nodes_in_group("Lighting")
	for light in lights:
		light.light_energy = value

func _on_wireframe_color_selected(index):
	if model_renderer:
		model_renderer.set_wireframe_color(wireframe_colors[index])
		config_manager.set_wireframe_color_index(index)

func _on_mesh_color_selected(index):
	if model_renderer:
		model_renderer.set_default_material_color(mesh_colors[index])
		config_manager.set_mesh_color_index(index)

func _on_theme_changed(theme_name):
	ui_manager.apply_themed_textures_to_button(advanced_settings_button, "settings")
	ui_manager.apply_themed_textures_to_button(advanced_preview_settings_button, "settings")
	
	$Background/Gear/Icon.texture = ui_manager.get_themed_texture("gear")

func _on_window_resized():
	var current_size = DisplayServer.window_get_size()
	config_manager.set_window_size(current_size)
	config_manager.set_fullscreen_state(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)


#========================
# FILE BROWSER FUNCTIONALITY
#========================
func _show_browser(mode: int, path: String = "", filters: PackedStringArray = [], initial_name: String = ""):
	if !browser_scene:
		push_error("Browser scene not loaded")
		return
	
	if !browser_instance:
		browser_instance = browser_scene.instantiate()
		add_child(browser_instance)
		
		browser_instance.initialize(config_manager)
		
		browser_instance.file_selected.connect(_on_browser_file_selected)
		browser_instance.dir_selected.connect(_on_browser_dir_selected)
		browser_instance.canceled.connect(_on_browser_canceled)
	
	var main_window_size = DisplayServer.window_get_size()
	var main_window_position = DisplayServer.window_get_position()
	
	var window_size = browser_instance.size
	var window_position = main_window_position + (main_window_size - window_size) / 2
	
	browser_instance.position = window_position
	browser_instance.open(mode, path, filters, initial_name)

func _on_browser_file_selected(path):
	match current_browser_operation:
		"conversion_input":
			_on_conversion_input_file_selected(path)
		"conversion_output":
			_on_conversion_output_file_selected(path)
		"preview_select":
			browse_preview_files_path.text = path
			_preview_file(path)

func _on_browser_dir_selected(path):
	match current_browser_operation: 
		"preview_dir_select":
			_on_settings_preview_dir_selected(path)
		"input_dir_select":
			_on_settings_input_dir_selected(path)
		"output_dir_select":
			_on_settings_output_dir_selected(path)

func _on_browser_canceled():
	pass

func _on_browse_input_dir_pressed():
	current_browser_operation = "input_dir_select"
	var input_dir = config_manager.get_input_dir()
	if !input_dir.is_empty() && DirAccess.dir_exists_absolute(input_dir):
		_show_browser(BrowserMode.SELECT_DIR, input_dir)
	else:
		_show_browser(BrowserMode.SELECT_DIR)

func _on_browse_output_dir_pressed():
	current_browser_operation = "output_dir_select"
	var output_dir = config_manager.get_output_dir()
	if !output_dir.is_empty() && DirAccess.dir_exists_absolute(output_dir):
		_show_browser(BrowserMode.SELECT_DIR, output_dir)
	else:
		_show_browser(BrowserMode.SELECT_DIR)

func _on_conversion_input_file_selected(path):
	conversion_input_path.text = path
	status_label.text = "File selected: " + path.get_file()
	
	var extension = path.get_extension().to_lower()
	
	var output_dir = config_manager.get_output_dir()
	
	if output_dir.is_empty():
		output_dir = path.get_base_dir()
	
	if extension == "obj":
		conversion_output_path.text = output_dir + "/" + path.get_file().get_basename() + ".blueprint"
	elif extension == "blueprint":
		conversion_output_path.text = output_dir + "/" + path.get_file().get_basename() + ".obj"
	
	if config_manager.get_auto_preview():
		browse_preview_files_path.text = path
		_preview_file(path)
		
func _on_browse_conversion_input_pressed():
	current_browser_operation = "conversion_input"
	var input_dir = config_manager.get_input_dir() 
	
	if !input_dir.is_empty() && DirAccess.dir_exists_absolute(input_dir):
		_show_browser(BrowserMode.OPEN_FILE, input_dir, PackedStringArray(["*.obj", "*.blueprint"]))
	else:
		_show_browser(BrowserMode.OPEN_FILE, "", PackedStringArray(["*.obj", "*.blueprint"]))
		
func _on_browse_conversion_output_pressed():
	current_browser_operation = "conversion_output"
	
	var input_path = conversion_input_path.text.strip_edges()
	var current_output_path = conversion_output_path.text.strip_edges()
	var initial_filename = ""
	
	if !current_output_path.is_empty():
		initial_filename = current_output_path.get_file()
	elif !input_path.is_empty():
		var basename = input_path.get_file().get_basename()
		var extension = input_path.get_extension().to_lower()
		if extension == "obj":
			initial_filename = basename + ".blueprint"
		elif extension == "blueprint":
			initial_filename = basename + ".obj"
	
	var output_dir = config_manager.get_output_dir()
	if !output_dir.is_empty() && DirAccess.dir_exists_absolute(output_dir):
		_show_browser(BrowserMode.SAVE_FILE, output_dir, PackedStringArray(["*.blueprint"]), initial_filename)
	else:
		_show_browser(BrowserMode.SAVE_FILE, input_path.get_base_dir(), PackedStringArray(["*.blueprint"]), initial_filename)

func _on_conversion_output_file_selected(path):
	conversion_output_path.text = path
	status_label.text = "Output will be saved to: " + path
	
	var extension = path.get_extension().to_lower()

func _on_browse_output_pressed():
	current_browser_operation = "obj_save"
	var obj_dir = config_manager.get_saved_path("obj_dir")
	if !obj_dir.is_empty() && DirAccess.dir_exists_absolute(obj_dir):
		_show_browser(BrowserMode.SAVE_FILE, obj_dir, PackedStringArray(["*.obj ; OBJ Files"]))
	else:
		_show_browser(BrowserMode.SAVE_FILE, "", PackedStringArray(["*.obj ; OBJ Files"]))

func _on_browse_preview_files_pressed():
	current_browser_operation = "preview_select"
	var preview_dir = config_manager.get_saved_path("preview_dir")
	if !preview_dir.is_empty() && DirAccess.dir_exists_absolute(preview_dir):
		_show_browser(BrowserMode.OPEN_FILE, preview_dir)
	else:
		_show_browser(BrowserMode.OPEN_FILE, "")

func _on_browse_blueprint_dir_pressed():
	current_browser_operation = "blueprint_dir_select"
	var blueprint_dir = config_manager.get_saved_path("blueprint_dir")
	if !blueprint_dir.is_empty() && DirAccess.dir_exists_absolute(blueprint_dir):
		_show_browser(BrowserMode.SELECT_DIR, blueprint_dir)
	else:
		_show_browser(BrowserMode.SELECT_DIR)

func _on_browse_obj_dir_pressed():
	current_browser_operation = "obj_dir_select"
	var obj_dir = config_manager.get_saved_path("obj_dir")
	if !obj_dir.is_empty() && DirAccess.dir_exists_absolute(obj_dir):
		_show_browser(BrowserMode.SELECT_DIR, obj_dir)
	else:
		_show_browser(BrowserMode.SELECT_DIR)

func _on_browse_preview_dir_pressed():
	current_browser_operation = "preview_dir_select"
	var preview_dir = config_manager.get_saved_path("preview_dir")
	if !preview_dir.is_empty() && DirAccess.dir_exists_absolute(preview_dir):
		_show_browser(BrowserMode.SELECT_DIR, preview_dir)
	else:
		_show_browser(BrowserMode.SELECT_DIR)

#========================
# FILE SELECTION HANDLERS
#========================
func _on_convert_file_pressed():
	status_label.text = "Converting file..."
	progress_bar.visible = true
	percent_label.visible = true
	progress_bar.value = 0
	
	_set_buttons_enabled(false)
	
	var input_path = conversion_input_path.text.strip_edges()
	var output_path = conversion_output_path.text.strip_edges()
	
	if input_path.is_empty():
		status_label.text = "Error: Please select an input file"
		progress_bar.visible = false
		percent_label.visible = false
		_set_buttons_enabled(true)
		return
	
	if output_path.is_empty():
		status_label.text = "Error: Please select an output file"
		progress_bar.visible = false
		percent_label.visible = false
		_set_buttons_enabled(true)
		return
	
	var options = {
		"include_materials": false,
		"include_normals": false,
		"calculate_normals": true, 
		"smooth_shading": false
	}
	
	var input_extension = input_path.get_extension().to_lower()
	var output_extension = output_path.get_extension().to_lower()
	
	thread_pool.queue_conversion(input_path, output_path, options)

func _on_settings_preview_dir_selected(path):
	if config_manager:
		config_manager.set_saved_path("preview_dir", path)
		preview_dir_path_field.text = path
		config_manager.save_config()
		
func _on_settings_input_dir_selected(path):
	if config_manager:
		config_manager.set_input_dir(path)
		input_dir_path_field.text = path
		config_manager.save_config()
		
func _on_settings_output_dir_selected(path):
	if config_manager:
		config_manager.set_output_dir(path)
		output_dir_path_field.text = path
		config_manager.save_config()
		
#========================
# CONVERSION HANDLING
#========================
func _on_conversion_started(task_id, source_path, target_path):
	status_label.text = "Converting " + source_path.get_file() + " to " + target_path.get_file() + "..."

func _on_conversion_progress(task_id, progress):
	progress_bar.value = progress * 100
	percent_label.text = str(int(progress * 100)) + "%"
	await get_tree().process_frame

func _on_conversion_completed(task_id, result):
	_set_buttons_enabled(true)
	
	if result.success:
		var triangle_count = result.statistics.get("triangle_count", 0)
		var quad_count = result.statistics.get("quad_count", 0)
		var vertex_count = result.statistics.get("vertex_count", 0)
		
		var stats_text = "Vertices: " + str(vertex_count)
		if triangle_count > 0 or quad_count > 0:
			stats_text += ", Triangles: " + str(triangle_count) + ", Quads: " + str(quad_count)
		else:
			stats_text += ", Faces: " + str(result.statistics.get("face_count", 0))
		
		status_label.text = "Success: Conversion completed. " + stats_text
		
		if config_manager.get_auto_preview() and result.has("target_path"):
			_preview_file(result.target_path)
	else:
		status_label.text = "Error: " + result.error
	
	progress_bar.visible = false
	percent_label.visible = false
	progress_bar.value = 0

func _on_conversion_error(task_id, error_message):
	_set_buttons_enabled(true)
	status_label.text = "Error: " + error_message
	progress_bar.visible = false
	percent_label.visible = false

func _set_buttons_enabled(enabled: bool):
	conversion_button.disabled = !enabled
	conversion_browse_input.disabled = !enabled
	conversion_browse_output.disabled = !enabled

#========================
# PREVIEW FUNCTIONALITY
#========================
func _preview_file(file_path):
	if not model_renderer:
		return
		
	if file_path.ends_with(".obj") or file_path.ends_with(".blueprint"):
		var format_handler = null
		
		if file_path.ends_with(".obj"):
			format_handler = format_registry.get_import_handler_for_extension("obj")
		else:
			format_handler = format_registry.get_import_handler_for_extension("blueprint")
			
		if format_handler:
			var model_data = format_handler.import_model(file_path)
			if model_data:
				model_renderer.render_model(model_data)
				model_renderer.center_model()
				
				### Lighting Stuff ###
				await get_tree().process_frame
		
				var combined_aabb = AABB()
				var has_valid_mesh = false
				
				for mesh_instance in model_renderer._mesh_instances:
					if mesh_instance and mesh_instance.mesh:
						var mesh_aabb = mesh_instance.get_aabb()
						
						if !has_valid_mesh:
							combined_aabb = mesh_aabb
							has_valid_mesh = true
						else:
							combined_aabb = combined_aabb.merge(mesh_aabb)
				
				if !has_valid_mesh:
					return
				
				var model_center = combined_aabb.position + combined_aabb.size/2
				var half_extents = combined_aabb.size/2
				
				var padding = 3.0 #Distance from model
				var x_extent = half_extents.x + padding
				var y_extent = half_extents.y + padding
				var z_extent = half_extents.z + padding
				
				var omni_lights_parent = get_node("MainPanel/VBoxContainer/TabContainer/Model Preview/VBoxContainer/SubViewportContainer/SubViewport/World/Omni-Lights")
				var omni_lights = omni_lights_parent.get_children()
				
				# Check to ensure all lights are loaded, then positions lights
				if omni_lights.size() >= 6:
					var positions = [
						Vector3(x_extent, 0, 0),
						Vector3(-x_extent, 0, 0),
						Vector3(0, y_extent, 0),
						Vector3(0, -y_extent, 0),
						Vector3(0, 0, z_extent),
						Vector3(0, 0, -z_extent)
					]
					
					# Position lights
					for i in range(min(omni_lights.size(), 6)):
						omni_lights[i].global_position = model_center + positions[i]
						
						var max_extent = max(max(x_extent, y_extent), z_extent)
						omni_lights[i].omni_range = max_extent * 2
				#######################################
				
				browse_preview_files_path.text = file_path
				
				var triangle_count = 0
				var quad_count = 0
				var vertex_count = model_data.get_vertex_count()
				var part_idx = model_data.get_active_part_index()
				
				if model_data.has_metadata("triangle_count"):
					triangle_count = model_data.get_metadata("triangle_count")
					quad_count = model_data.get_metadata("quad_count", 0)
					
				elif model_data.has_part_metadata(part_idx, "triangle_count"):
					triangle_count = model_data.get_part_metadata(part_idx, "triangle_count", 0)
					quad_count = model_data.get_part_metadata(part_idx, "quad_count", 0)
				
				var stats_text = ""
				if file_path.ends_with(".blueprint"):
					# For blueprints
					stats_text = "Loaded blueprint: " + file_path.get_file() + " (" + str(vertex_count) + " vertices, " + str(triangle_count) + " triangles, " + str(quad_count) + " quads)"
				else:
					# For OBJ files
					stats_text = "Loaded model: " + file_path.get_file() + " (" + str(vertex_count) + " vertices, " + str(triangle_count) + " triangles, " + str(quad_count) + " quads)"
								
				status_label.text = stats_text
				
				_update_render_mode()
				camera_controller.focus_on_point(model_root.global_position)
				
				if tab_container.current_tab != 1:
					tab_container.current_tab = 1

#========================
# ADVANCED SETTINGS
#========================
func _on_advanced_settings_pressed(tab_index: int = 0):
	if !advanced_settings_scene:
		push_error("Advanced settings scene not loaded")
		return
	
	if !advanced_settings_instance:
		advanced_settings_instance = advanced_settings_scene.instantiate()
		add_child(advanced_settings_instance)
		
		advanced_settings_instance.initialize(config_manager, model_renderer, ui_manager)
		
		advanced_settings_instance.connect("settings_closed", Callable(self, "_on_advanced_settings_closed"))
		advanced_settings_instance.connect("settings_saved", Callable(self, "_on_keybinds_saved"))
	
	advanced_settings_instance.show_settings(tab_index)

func _on_advanced_settings_closed():
	pass

func _on_keybinds_saved(keybinds):
	if camera_controller and config_manager and config_manager.settings.has("preview") and config_manager.settings.preview.has("camera_fov"):
		camera_controller.set_camera_fov(config_manager.settings.preview.camera_fov)

func _on_camera_fov_changed(value):
	if advanced_settings_instance and is_instance_valid(advanced_settings_instance):
		if advanced_settings_instance.camera_fov_slider:
			advanced_settings_instance.camera_fov_slider.value = value
		if advanced_settings_instance.camera_fov_line_edit:
			advanced_settings_instance.camera_fov_line_edit.text = str(int(value))

func _on_save_settings_pressed():
	if config_manager:
		if config_manager.save_config():
			status_label.text = "Settings saved successfully"
		else:
			status_label.text = "Error: Failed to save settings"

func _on_auto_preview_toggled(enabled):
	if config_manager:
		config_manager.set_auto_preview(enabled)
		config_manager.save_config()

#-----------------------------------------------------------------
# CONFIGURATION MANAGEMENT
#-----------------------------------------------------------------
func _on_config_loaded():
	var blueprint_dir = config_manager.get_saved_path("blueprint_dir")
	var auto_preview_toggle = config_manager.get_auto_preview()
	var obj_dir = config_manager.get_saved_path("obj_dir")

	var input_dir = config_manager.get_input_dir()
	if !input_dir.is_empty():
		input_dir_path_field.text = input_dir
	
	var output_dir = config_manager.get_output_dir()
	if !output_dir.is_empty():
		output_dir_path_field.text = output_dir
	
	var preview_dir = config_manager.get_saved_path("preview_dir")
	if !preview_dir.is_empty():
		preview_dir_path_field.text = preview_dir
		browse_preview_files_path.text = preview_dir
	
	var last_tab = config_manager.get_last_tab()
	tab_container.current_tab = last_tab
	
	_on_grid_toggle_toggled(config_manager.get_grid_visible())
	_setup_wireframe_color_options()
	
	if model_renderer:
		var wireframe_index = config_manager.get_wireframe_color_index()
		var mesh_index = config_manager.get_mesh_color_index()
		
		if wireframe_colors.has(wireframe_index):
			model_renderer.set_wireframe_color(wireframe_colors[wireframe_index])
			
		if mesh_colors.has(mesh_index):
			model_renderer.set_default_material_color(mesh_colors[mesh_index])
			
	if not wireframe_color_option.is_connected("item_selected", Callable(self, "_on_wireframe_color_selected")):
		wireframe_color_option.connect("item_selected", Callable(self, "_on_wireframe_color_selected"))
		
	if not mesh_color_option.is_connected("item_selected", Callable(self, "_on_mesh_color_selected")):
		mesh_color_option.connect("item_selected", Callable(self, "_on_mesh_color_selected"))
	
func _on_config_saved():
	status_label.text = "Settings saved successfully"

func _setup_wireframe_color_options():
	wireframe_color_option.clear()
	
	wireframe_color_option.add_item("Blue (Default)", 0)
	wireframe_color_option.add_item("Green", 1)
	wireframe_color_option.add_item("Black", 2)
	wireframe_color_option.add_item("Red", 3)
	wireframe_color_option.add_item("White", 4)
	wireframe_color_option.add_item("Purple", 5)
	wireframe_color_option.add_item("Orange", 6)
	
	var wireframe_index = config_manager.get_wireframe_color_index()
	var mesh_index = config_manager.get_mesh_color_index()
	
	if wireframe_color_option.get_item_count() > wireframe_index:
		wireframe_color_option.select(wireframe_index)
	
	mesh_color_option.clear()
	mesh_color_option.add_item("White (Default)", 0)
	mesh_color_option.add_item("Green", 1)
	mesh_color_option.add_item("Black", 2)
	mesh_color_option.add_item("Red", 3)
	mesh_color_option.add_item("Blue", 4)
	mesh_color_option.add_item("Purple", 5)
	mesh_color_option.add_item("Gray", 6)
	
	if mesh_color_option.get_item_count() > mesh_index:
		mesh_color_option.select(mesh_index)

func _setup_theme_dropdown():
	theme_dropdown.clear()
	
	var index = 0
	for theme_name in ui_manager.themes.keys():
		theme_dropdown.add_item(theme_name, index)
		if theme_name == ui_manager.current_theme_name:
			theme_dropdown.select(index)
		index += 1

	if not theme_dropdown.is_connected("item_selected", Callable(self, "_on_theme_selected")):
		theme_dropdown.connect("item_selected", Callable(self, "_on_theme_selected"))

func _on_theme_selected(index):
	if ui_manager:
		var theme_name = theme_dropdown.get_item_text(index)
		ui_manager.switch_theme(theme_name)

func _update_render_mode():
	if model_renderer:
		if wireframe_toggle.button_pressed and wireframe_overlay_toggle.button_pressed:
			model_renderer.set_render_mode(ModelRenderer.RenderMode.WIREFRAME_OVERLAY)
		elif wireframe_toggle.button_pressed:
			model_renderer.set_render_mode(ModelRenderer.RenderMode.WIREFRAME)
		elif wireframe_overlay_toggle.button_pressed:
			model_renderer.set_render_mode(ModelRenderer.RenderMode.WIREFRAME_OVERLAY)
		elif cut_view_toggle.button_pressed:
			model_renderer.set_render_mode(ModelRenderer.RenderMode.TEXTURED)
		else:
			model_renderer.set_render_mode(ModelRenderer.RenderMode.SOLID)
