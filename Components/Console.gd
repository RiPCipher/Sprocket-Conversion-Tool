extends Window

@onready var output_area = $MarginContainer/VBoxContainer/OutputArea
@onready var rich_text = $MarginContainer/VBoxContainer/OutputArea/RichTextLabel
@onready var line_edit = $MarginContainer/VBoxContainer/InputArea/LineEdit
@onready var send_button = $MarginContainer/VBoxContainer/InputArea/Button

var logger = null
var commands = null

func _ready():
	# Window setup
	title = "Debugger Console"
	size = Vector2i(750, 400)
	
	var screen_size = DisplayServer.screen_get_size()
	position = (screen_size - size) / 2
	
	# Initialize commands and models
	commands = DebugCommands.new()
	commands.models = $TextBasedModels
	
	# Connect input signals
	send_button.pressed.connect(_on_send_pressed)
	line_edit.text_submitted.connect(_on_text_submitted)
	
	# Set up RichTextLabel
	rich_text.bbcode_enabled = true
	rich_text.scroll_following = true
	
	# Focus the input
	line_edit.grab_focus()
	
	# Defer the initial message to ensure everything is ready
	call_deferred("_show_initial_message")

func _show_initial_message():
	_add_message("Console ready. Type 'help' for available commands.", "system")

func connect_to_logger(p_logger):
	logger = p_logger
	if logger:
		logger.log_message.connect(_on_log_message)
		_add_message("Connected to logger.", "system")

func _on_log_message(message: String, log_type: String):
	_add_message(message, log_type)

func _on_send_pressed():
	_process_input()

func _on_text_submitted(text: String):
	_process_input()

func _process_input():
	var input = line_edit.text.strip_edges()
	if input.is_empty():
		return
	
	# Display user input
	_add_message("> " + input, "user")
	
	# Process command
	var response = commands.execute_command(input)
	
	# Handle special responses
	if response == "CLEAR_CONSOLE":
		rich_text.clear()
		_add_message("Console cleared.", "system")
	else:
		_add_message("< " + response, "response")
	
	# Clear input and refocus
	line_edit.clear()
	line_edit.grab_focus()

func _add_message(message: String, message_type: String):
	# Safety check to ensure rich_text is available
	if not rich_text:
		print("Console: rich_text not ready, deferring message: " + message)
		call_deferred("_add_message", message, message_type)
		return
	
	var colored_message = ""
	
	match message_type:
		"error":
			colored_message = "[color=red]" + message + "[/color]"
		"warning":
			colored_message = "[color=yellow]" + message + "[/color]"
		"user":
			colored_message = "[color=cyan]" + message + "[/color]"
		"response":
			colored_message = "[color=lime]" + message + "[/color]"
		"system":
			colored_message = "[color=gray]" + message + "[/color]"
		_:
			colored_message = message
	
	rich_text.append_text(colored_message + "\n")
	
	# Auto-scroll to bottom
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom():
	if not output_area:
		return
	output_area.ensure_control_visible(rich_text)
	var v_scroll = output_area.get_v_scroll_bar()
	v_scroll.value = v_scroll.max_value
	
