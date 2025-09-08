extends Node
class_name Debugger

var logger = null
var console = null
var debugger_version = "0451"

func _init() -> void:
	pass
	
func _ready():
	print("Debugger: Initialized and ready")
	_setup_components()

func _setup_components():
	# Create logger
	logger = preload("res://Components/Logger.gd").new()
	logger.name = "Logger"
	add_child(logger)
	
	# Create console
	var console_scene = preload("res://UI/Console.tscn")
	console = console_scene.instantiate()
	get_tree().current_scene.add_child(console)
	
	# Connect them
	console.connect_to_logger(logger)

func set_debug_folder(folder_path: String):
	"""Called by Debug.gd to tell us where to put files"""
	if logger:
		logger.initialize(folder_path)

# interface
func debug_log(text):
	if logger:
		logger.debug_log(text)

func debug_error(text):
	if logger:
		logger.debug_error(text)

func debug_warn(text):
	if logger:
		logger.debug_warn(text)

func _exit_tree():
	if console:
		console.queue_free()
