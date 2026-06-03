extends Control

const Messages = preload("res://Text/Messages.gd")

@onready var config_manager = %ConfigManager
var ui_manager = null
var error_handler = null
var format_registry = null

# Advanced Settings
var advanced_settings_scene = null
var advanced_settings_instance = null
# Popup
var popup_scene = null
var popup_instance = null

# Controllers
@onready var browser_controller = %BrowserController
@onready var preview_controller = %PreviewController
@onready var conversion_controller = %ConversionController
@onready var update_controller = %UpdateController

# UI Elements
@onready var tab_container = %TabContainer_U
@onready var splash_text = %SplashText
@onready var status_label = %StatusLabel
@onready var progress_bar = %ProgressBar_U
@onready var percent_label = %PercentLabel
@onready var sprocket_animation_player = %AnimationPlayer_U
@onready var tools_tab = %Tools

# Settings tab
@onready var advanced_settings_button = %AdvancedSettingsButton
@onready var advanced_preview_settings_button = %PreviewAdvancedSettings
@onready var save_settings_button = %SaveSettingsButton
@onready var input_dir_browse_button = %FileInputBrowse
@onready var output_dir_browse_button = %FileOutputBrowse
@onready var preview_dir_browse_button = %FilePreviewBrowse
@onready var input_dir_path_field = %InputPath
@onready var output_dir_path_field = %OutputPath
@onready var preview_dir_path_field = %PreviewPath
@onready var auto_preview_toggle = %AutoPreviewCheck
@onready var native_windows_toggle = %NativeMenusButton
@onready var theme_dropdown = %ThemeOptions

# Update-related
@onready var update_manager = %UpdateManager
@onready var update_button = %Update

#========================
# Initialize
#========================
func _ready():
	FormatRegistry.initialize()
	format_registry = FormatRegistry
	error_handler = ErrorHandler

	advanced_settings_scene = load("res://Scenes/AdvancedSettings.tscn")

	# Controllers
	browser_controller.initialize(config_manager)
	preview_controller.initialize(config_manager, format_registry, browser_controller)
	conversion_controller.initialize(config_manager, format_registry, error_handler, browser_controller, preview_controller)
	update_controller.initialize(config_manager, update_manager, update_button)

	# UI Manager + theme
	if config_manager:
		ui_manager = %UIManager
		ui_manager.initialize(config_manager)
		ui_manager.connect("theme_changed", _on_theme_changed)
		_setup_theme_dropdown()

	# Window setup
	# Coming from the launcher the window is borderless + transparent + always-on-top.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, false, 0)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	get_tree().get_root().set_transparent_background(false)
	DisplayServer.window_set_title("Sprocket Conversion Tool")

	_connect_signals()


	progress_bar.value = 0
	progress_bar.visible = false
	percent_label.visible = false

	sprocket_animation_player.play("Spin")

	config_manager.load_config()

	# Window size settings
	var saved_size = config_manager.get_window_size()
	DisplayServer.window_set_size(saved_size)
	# Re-center now that the window is at its final size (single positioning, no jump).
	var screen_size = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position((screen_size - saved_size) / 2)

	if config_manager.get_fullscreen_state():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if splash_text:
		_select_random_splash_message()
		
	_hide_elements()

## Elements that need hidden due to being incomplete or outdated should go here
func _hide_elements():
	# Hide Tools Tabs
	if tools_tab:
		tab_container.set_tab_hidden(tab_container.get_tab_idx_from_control(tools_tab), true)
	
	# Hide Splash Text
	if splash_text:
		splash_text.visible = false
		
func _connect_signals():
	config_manager.connect("config_loaded", _on_config_loaded)
	config_manager.connect("config_saved", _on_config_saved)

	# Settings tab
	advanced_settings_button.connect("pressed", Callable(self, "_on_advanced_settings_pressed").bind(0))
	advanced_preview_settings_button.connect("pressed", Callable(self, "_on_advanced_settings_pressed").bind(0))
	input_dir_browse_button.pressed.connect(_on_browse_input_dir_pressed)
	output_dir_browse_button.pressed.connect(_on_browse_output_dir_pressed)
	preview_dir_browse_button.pressed.connect(_on_browse_preview_dir_pressed)
	save_settings_button.pressed.connect(_on_save_settings_pressed)
	auto_preview_toggle.toggled.connect(_on_auto_preview_toggled)
	native_windows_toggle.toggled.connect(_on_native_windows_toggled)

	# Drag/drop
	get_viewport().files_dropped.connect(_on_files_dropped)

#========================
# Input handling
#========================
func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo():
		var exit_key = config_manager.get_keybind("exit_key")
		if exit_key != 0 and event.keycode == exit_key:
			config_manager.save_config()
			get_tree().quit()

func _on_files_dropped(files):
	if files.size() == 0:
		return

	var file_path = files[0]
	var extension = file_path.get_extension().to_lower()
	if extension != "obj" and extension != "blueprint":
		return

	Debug.log("File dropped: ", file_path)

	var tab = tab_container.current_tab
	if tab == 1:
		preview_controller.set_preview_path_text(file_path)
		preview_controller.preview_file(file_path)
	elif tab == 0:
		conversion_controller.set_input_file(file_path)

#========================
# Settings tab directory browsing
#========================
func _on_browse_input_dir_pressed():
	var input_dir = config_manager.get_input_dir()
	if !input_dir.is_empty() && DirAccess.dir_exists_absolute(input_dir):
		browser_controller.browse_select_dir(input_dir, _on_settings_input_dir_selected)
	else:
		browser_controller.browse_select_dir("", _on_settings_input_dir_selected)

func _on_browse_output_dir_pressed():
	var output_dir = config_manager.get_output_dir()
	if !output_dir.is_empty() && DirAccess.dir_exists_absolute(output_dir):
		browser_controller.browse_select_dir(output_dir, _on_settings_output_dir_selected)
	else:
		browser_controller.browse_select_dir("", _on_settings_output_dir_selected)

func _on_browse_preview_dir_pressed():
	var preview_dir = config_manager.get_saved_path("preview_dir")
	if !preview_dir.is_empty() && DirAccess.dir_exists_absolute(preview_dir):
		browser_controller.browse_select_dir(preview_dir, _on_settings_preview_dir_selected)
	else:
		browser_controller.browse_select_dir("", _on_settings_preview_dir_selected)

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

func _on_settings_preview_dir_selected(path):
	if config_manager:
		config_manager.set_saved_path("preview_dir", path)
		preview_dir_path_field.text = path
		config_manager.save_config()

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

func _on_native_windows_toggled(enabled):
	if config_manager:
		config_manager.set_native(enabled)
		config_manager.save_config()

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

		advanced_settings_instance.initialize(config_manager, preview_controller.model_renderer, ui_manager)

		advanced_settings_instance.connect("settings_closed", Callable(self, "_on_advanced_settings_closed"))
		advanced_settings_instance.connect("settings_saved", Callable(self, "_on_keybinds_saved"))

	advanced_settings_instance.show_settings(tab_index)

func _on_advanced_settings_closed():
	pass

func _on_keybinds_saved(keybinds):
	if config_manager and config_manager.settings.has("preview") and config_manager.settings.preview.has("camera_fov"):
		preview_controller.set_camera_fov(config_manager.settings.preview.camera_fov)

#========================
# POPUP
#========================
func _show_error_popup(title_text: String, body_text: String, button_text: String = "OK", callback: Callable = Callable()):
	_load_popup_scene()

	if not popup_instance:
		popup_instance = popup_scene.instantiate()
		get_tree().current_scene.add_child(popup_instance)
		popup_instance.popup_closed.connect(_on_popup_closed)

	popup_instance.show_popup(title_text, body_text, button_text, callback)

func _load_popup_scene():
	if not popup_scene:
		popup_scene = load("res://Scenes/Popup.tscn")

func _on_popup_closed():
	if popup_instance:
		popup_instance.queue_free()
		popup_instance = null

#========================
# CONFIGURATION
#========================
func _on_config_loaded():
	var input_dir = config_manager.get_input_dir()
	if !input_dir.is_empty():
		input_dir_path_field.text = input_dir

	var output_dir = config_manager.get_output_dir()
	if !output_dir.is_empty():
		output_dir_path_field.text = output_dir

	var preview_dir = config_manager.get_saved_path("preview_dir")
	if !preview_dir.is_empty():
		preview_dir_path_field.text = preview_dir
		preview_controller.set_preview_path_text(preview_dir)

	native_windows_toggle.set_pressed_no_signal(config_manager.get_native())

	tab_container.current_tab = 0

func _on_config_saved():
	status_label.text = "Settings saved successfully"

#========================
# THEME
#========================
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

func _on_theme_changed(theme_name):
	ui_manager.apply_themed_textures_to_button(advanced_settings_button, "settings")
	ui_manager.apply_themed_textures_to_button(advanced_preview_settings_button, "settings")
	%Icon.texture = ui_manager.get_themed_texture("gear")

#========================
# SPLASH
#========================
func _select_random_splash_message() -> void:
	var total_weight = 0
	for key in Messages.splash_messages:
		total_weight += Messages.splash_messages[key].weight

	var random_value = randf() * total_weight

	var cumulative_weight = 0
	for key in Messages.splash_messages:
		cumulative_weight += Messages.splash_messages[key].weight
		if random_value <= cumulative_weight:
			splash_text.text = Messages.splash_messages[key].text
			break

	var tween = create_tween().set_loops()
	tween.tween_property(splash_text, "scale", Vector2(1.05, 1.05), 1.5)
	tween.tween_property(splash_text, "scale", Vector2(1.0, 1.0), 1.5)

	var color_tween = create_tween().set_loops()
	color_tween.tween_property(splash_text, "modulate", Color.RED, 2.5)
	color_tween.tween_property(splash_text, "modulate", Color.DARK_ORANGE, 2.5)
	color_tween.tween_property(splash_text, "modulate", Color.DEEP_PINK, 2.5)
