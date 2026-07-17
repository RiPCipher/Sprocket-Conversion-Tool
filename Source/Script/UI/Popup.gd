extends Window

signal popup_closed()
signal button_pressed()

@onready var title_label = $VBoxContainer/TitleBox
@onready var body_label = $VBoxContainer/BodyText
@onready var close_button = $Button

var callback_function: Callable
var pending_popup_data: Dictionary = {}

func _ready():
	title = "Sprocket Conversion Tool"
	unresizable = false
	transient = true
	exclusive = true
	popup_window = false
	
	close_requested.connect(_on_close_requested)
	close_button.pressed.connect(_on_button_pressed)
	
	visible = false
	
	if not pending_popup_data.is_empty():
		_apply_popup_data(pending_popup_data)
		pending_popup_data = {}

func show_popup(title_text: String, body_text: String, button_text: String = "OK", callback: Callable = Callable()):
	var data = {
		"title": title_text,
		"body": body_text,
		"button": button_text,
		"callback": callback
	}
	
	if is_node_ready():
		_apply_popup_data(data)
	else:
		pending_popup_data = data

func _apply_popup_data(data: Dictionary):
	title_label.text = data.title
	body_label.text = data.body
	close_button.text = data.button
	callback_function = data.callback
	
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	_center_on_main_window()
	
	show()
	grab_focus()

func _center_on_main_window():
	var main_window_size = DisplayServer.window_get_size()
	var main_window_position = DisplayServer.window_get_position()
	
	var popup_size = size
	var popup_position = main_window_position + (main_window_size - popup_size) / 2
	
	position = popup_position

func _on_button_pressed():
	if callback_function.is_valid():
		callback_function.call()
	
	emit_signal("button_pressed")
	hide()
	emit_signal("popup_closed")

func _on_close_requested():
	hide()
	emit_signal("popup_closed")
