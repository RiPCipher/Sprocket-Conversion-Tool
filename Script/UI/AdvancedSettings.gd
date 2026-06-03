extends Window

signal settings_saved(keybinds)
signal settings_closed

# UI References
@onready var tab_container = %TabContainer

# Keybind UI Elements
@onready var recenter_button = %RecenterChange
@onready var recenter_label = %RecenterCurrent
@onready var pan_button = %PanCameraChange
@onready var pan_label = %PanCameraCurrent
@onready var zoom_in_button = %ZoomInChange
@onready var zoom_in_label = %ZoomInCurrent
@onready var zoom_out_button = %ZoomOutChange
@onready var zoom_out_label = %ZoomOutCurrent
@onready var reset_button = %"Reset Button"
@onready var exit_key_label = %ExitCurrent
@onready var _exit_button = %ExitChange
@onready var free_cam_label = %FreeCamCurrent
@onready var free_cam_button = %FreeCamChange
@onready var fov_increase_label = %FOVIncreaseCurrent
@onready var fov_increase_button = %FOVIncreaseChange
@onready var fov_decrease_label = %FOVDecreaseCurrent
@onready var fov_decrease_button = %FOVDecreaseChange


# Previewer Settings
@onready var camera_fov_slider = %CameraFOVSlider
@onready var camera_fov_line_edit = %FOVEdit


# Node Reference
var config_manager = null
var previewer = null
var ui_manager = null

# Active keybinding
var active_binding_button = null
var active_binding_label = null
var listening_for_key = false

var default_keybinds = {
	"recenter_key": KEY_R,
	"pan_key": KEY_SHIFT,
	"zoom_in_key": KEY_E,
	"zoom_out_key": KEY_Q,
	"exit_key": KEY_ESCAPE,
	"increase_fov_key": KEY_EQUAL,
	"decrease_fov_key": KEY_MINUS,
	"free_cam_key": KEY_F
}

var current_keybinds = {}

func _ready():
	title = "Advanced Settings"
	size = Vector2i(740, 440) #700, 600
	unresizable = false
	#always_on_top = true
	exclusive = true
	unfocusable = false
	popup_window = false
	transient = true
	
	content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	
	close_requested.connect(_on_exit_pressed)
	
	
	# Connect keybind buttons
	recenter_button.connect("pressed", Callable(self, "_on_keybind_button_pressed").bind(recenter_button, recenter_label, "recenter_key"))
	pan_button.connect("pressed", Callable(self, "_on_keybind_button_pressed").bind(pan_button, pan_label, "pan_key"))
	zoom_in_button.connect("pressed", Callable(self, "_on_keybind_button_pressed").bind(zoom_in_button, zoom_in_label, "zoom_in_key"))
	zoom_out_button.connect("pressed", Callable(self, "_on_keybind_button_pressed").bind(zoom_out_button, zoom_out_label, "zoom_out_key"))
	_exit_button.connect("pressed", Callable(self, "_on_keybind_button_pressed").bind(_exit_button, exit_key_label, "exit_key"))
	free_cam_button.connect("pressed", Callable(self, "_on_keybind_button_pressed").bind(free_cam_button, free_cam_label, "free_cam_key"))
	fov_increase_button.connect("pressed", Callable(self, "_on_keybind_button_pressed").bind(fov_increase_button, fov_increase_label, "increase_fov_key"))
	fov_decrease_button.connect("pressed", Callable(self, "_on_keybind_button_pressed").bind(fov_decrease_button, fov_decrease_label, "decrease_fov_key"))
	
	reset_button.connect("pressed", Callable(self, "_on_reset_defaults_pressed"))
	
	camera_fov_slider.connect("value_changed", Callable(self, "_on_fov_slider_changed"))
	camera_fov_line_edit.connect("text_submitted", Callable(self, "_on_fov_text_submitted"))
	
	# Hide by default
	visible = false

func initialize(p_config_manager, p_previewer = null, p_ui_manager = null):
	config_manager = p_config_manager
	previewer = p_previewer
	ui_manager = p_ui_manager
	
	load_keybinds()
	update_keybind_labels()
	
	if config_manager and config_manager.settings.has("preview") and config_manager.settings.preview.has("camera_fov"):
		camera_fov_slider.value = config_manager.settings.preview.camera_fov
		camera_fov_line_edit.text = str(int(camera_fov_slider.value))
	else:
		camera_fov_slider.value = 75
		camera_fov_line_edit.text = "75"

func load_keybinds():
	if config_manager:
		if config_manager.settings.has("keybinds"):
			current_keybinds = config_manager.settings.keybinds.duplicate()
			
			for key in default_keybinds:
				if not current_keybinds.has(key):
					current_keybinds[key] = default_keybinds[key]
					
			config_manager.settings["keybinds"] = current_keybinds.duplicate()
			config_manager.save_config()
		else:
			current_keybinds = default_keybinds.duplicate()
			config_manager.settings["keybinds"] = current_keybinds.duplicate()
			config_manager.save_config()
	else:
		current_keybinds = default_keybinds.duplicate()

func update_keybind_labels():
	recenter_label.text = OS.get_keycode_string(current_keybinds["recenter_key"])
	pan_label.text = OS.get_keycode_string(current_keybinds["pan_key"])
	zoom_in_label.text = OS.get_keycode_string(current_keybinds["zoom_in_key"])
	zoom_out_label.text = OS.get_keycode_string(current_keybinds["zoom_out_key"])
	exit_key_label.text = OS.get_keycode_string(current_keybinds["exit_key"])
	free_cam_label.text = OS.get_keycode_string(current_keybinds["free_cam_key"])
	fov_increase_label.text = OS.get_keycode_string(current_keybinds["increase_fov_key"])
	fov_decrease_label.text = OS.get_keycode_string(current_keybinds["decrease_fov_key"])

func _on_keybind_button_pressed(button, label, keybind_name):
	if listening_for_key:
		if active_binding_button:
			active_binding_button.text = "Change"
		listening_for_key = false
	
	listening_for_key = true
	active_binding_button = button
	active_binding_label = label
	active_binding_button.text = "Press any key..."
	active_binding_button.add_theme_font_size_override("font_size", 12)
	
	active_binding_button.set_meta("keybind_name", keybind_name)

func _input(event):
	if listening_for_key and active_binding_button:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			active_binding_button.text = "Change"
			active_binding_button.add_theme_font_size_override("font_size", 15)
			listening_for_key = false
			active_binding_button = null
			active_binding_label = null
			get_viewport().set_input_as_handled()
			return
		
		if event is InputEventKey and event.pressed and not event.is_echo():
			var keybind_name = active_binding_button.get_meta("keybind_name")
			var keycode = event.keycode
			
			for k in current_keybinds:
				if current_keybinds[k] == keycode and k != keybind_name:
					var confirm = ConfirmationDialog.new()
					confirm.dialog_text = "This key is already bound to '" + k.replace("_key", "").capitalize() + "'. Assign?"
					confirm.title = "Key Already Bound"
					confirm.get_ok_button().text = "Assign"
					confirm.connect("confirmed", Callable(self, "_reassign_key").bind(keybind_name, keycode))
					add_child(confirm)
					confirm.popup_centered()
					
					active_binding_button.text = "Change"
					listening_for_key = false
					get_viewport().set_input_as_handled()
					return
			
			set_keybind(keybind_name, keycode)
			
			active_binding_button.text = "Change"
			listening_for_key = false
			get_viewport().set_input_as_handled()
			return
	
	elif visible and event is InputEventKey and event.pressed and not event.is_echo():
		if current_keybinds.has("exit_key") and event.keycode == current_keybinds["exit_key"]:
			_on_exit_pressed()
			get_viewport().set_input_as_handled()
			return

func _reassign_key(keybind_name, keycode):
	for k in current_keybinds:
		if current_keybinds[k] == keycode:
			current_keybinds[k] = default_keybinds[k]
	
	set_keybind(keybind_name, keycode)

func set_keybind(keybind_name, keycode):
	current_keybinds[keybind_name] = keycode
	
	var label = null
	match keybind_name:
		"recenter_key":
			label = recenter_label
		"pan_key":
			label = pan_label
		"zoom_in_key":
			label = zoom_in_label
		"zoom_out_key":
			label = zoom_out_label
		"exit_key":
			label = exit_key_label
		"free_cam_key":
			label = free_cam_label
		"increase_fov_key":
			label = fov_increase_label
		"decrease_fov_key":
			label = fov_decrease_label
		
		
	label.text = OS.get_keycode_string(keycode)
	
	config_manager.settings["keybinds"] = current_keybinds.duplicate()
	config_manager.save_config()
		
	emit_signal("settings_saved", current_keybinds)

func _on_fov_slider_changed(value):
	camera_fov_line_edit.text = str(int(value))
	
	if config_manager:
		if not config_manager.settings.preview.has("camera_fov"):
			config_manager.settings.preview["camera_fov"] = 75
		
		config_manager.settings.preview.camera_fov = value
	
	if previewer:
		previewer.set_camera_fov(value)

func _on_fov_text_submitted(text):
	var fov_value = float(text)
	
	fov_value = clamp(fov_value, camera_fov_slider.min_value, camera_fov_slider.max_value)
	
	camera_fov_slider.value = fov_value

func _on_exit_pressed():
	if listening_for_key:
		if active_binding_button:
			active_binding_button.text = "Change"
		listening_for_key = false
		active_binding_button = null
		active_binding_label = null
	
	hide()
	emit_signal("settings_closed")

func show_settings(tab_index: int = 0):
	var main_window_size = DisplayServer.window_get_size()
	var main_window_position = DisplayServer.window_get_position()
	
	var window_position = main_window_position + (main_window_size - size) / 2
	
	position = window_position
	
	show()
	grab_focus()
	
	load_keybinds()
	update_keybind_labels()
	
	$ScrollContainer/PanelContainer/VBoxContainer/TabContainer.current_tab = tab_index

func reset_to_defaults():
	current_keybinds = default_keybinds.duplicate()
	update_keybind_labels()
	
	config_manager.settings["keybinds"] = current_keybinds.duplicate()
	config_manager.save_config()
		
	emit_signal("settings_saved", current_keybinds)

func _on_reset_defaults_pressed():
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "This will reset all keybinds to their default values. Continue?"
	confirm.title = "Reset to Defaults"
	confirm.get_ok_button().text = "Reset"
	confirm.connect("confirmed", Callable(self, "reset_to_defaults"))
	add_child(confirm)
	confirm.popup_centered()
