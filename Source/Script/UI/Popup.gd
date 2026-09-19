extends Window

signal popup_closed()
signal button_pressed()
signal confirmed()
signal cancelled()

const BUTTON_WIDTH := 80.0
const BUTTON_GAP := 8.0

@onready var title_label = $VBoxContainer/TitleBox
@onready var body_label = $VBoxContainer/BodyText
@onready var close_button = $Button
@onready var cancel_button = $CancelButton

var callback_function: Callable
var cancel_callback: Callable
var is_confirm: bool = false
var pending_popup_data: Dictionary = {}

func _ready():
	title = "Sprocket Conversion Tool"
	unresizable = false
	transient = true
	exclusive = true
	popup_window = false
	
	close_requested.connect(_on_close_requested)
	close_button.pressed.connect(_on_button_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	visible = false
	
	if not pending_popup_data.is_empty():
		_apply_popup_data(pending_popup_data)
		pending_popup_data = {}

func show_popup(title_text: String, body_text: String, button_text: String = "OK", callback: Callable = Callable()):
	var data = {
		"title": title_text,
		"body": body_text,
		"button": button_text,
		"callback": callback,
		"confirm": false
	}
	
	if is_node_ready():
		_apply_popup_data(data)
	else:
		pending_popup_data = data

func show_confirm(title_text: String, body_text: String, confirm_text: String = "Yes", cancel_text: String = "Cancel", on_confirm: Callable = Callable(), on_cancel: Callable = Callable()):
	var data = {
		"title": title_text,
		"body": body_text,
		"button": confirm_text,
		"callback": on_confirm,
		"confirm": true,
		"cancel_text": cancel_text,
		"cancel_callback": on_cancel
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
	is_confirm = data.get("confirm", false)
	cancel_callback = data.get("cancel_callback", Callable())
	
	cancel_button.visible = is_confirm
	if is_confirm:
		cancel_button.text = data.get("cancel_text", "Cancel")
		cancel_button.offset_left = -(BUTTON_WIDTH + BUTTON_GAP)
		cancel_button.offset_right = -BUTTON_GAP
		close_button.offset_left = BUTTON_GAP
		close_button.offset_right = BUTTON_GAP + BUTTON_WIDTH
	else:
		close_button.offset_left = -BUTTON_WIDTH / 2.0
		close_button.offset_right = BUTTON_WIDTH / 2.0
	
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
	if is_confirm:
		emit_signal("confirmed")
	hide()
	emit_signal("popup_closed")

func _on_cancel_pressed():
	_cancel()

func _on_close_requested():
	if is_confirm:
		_cancel()
		return
	hide()
	emit_signal("popup_closed")

func _cancel():
	if cancel_callback.is_valid():
		cancel_callback.call()
	emit_signal("cancelled")
	hide()
	emit_signal("popup_closed")
