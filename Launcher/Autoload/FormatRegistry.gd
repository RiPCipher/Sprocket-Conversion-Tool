extends Node
class_name FormatRegistryAutoload

# Don't preload - will be loaded at runtime from PCK
var OBJ_FORMAT_CLASS = null
var BLUEPRINT_FORMAT_CLASS = null

var _import_handlers = {}
var _export_handlers = {}
var _extension_to_handler = {}
var _initialized = false

func initialize() -> int:
	if _initialized:
		print("FormatRegistry: Already initialized")
		return _extension_to_handler.size()
	
	print("FormatRegistry: Initializing from PCK...")
	
	_import_handlers.clear()
	_export_handlers.clear()
	_extension_to_handler.clear()
	
	# Load format classes from PCK at runtime
	OBJ_FORMAT_CLASS = load("res://MeshFramework/Formats/OBJFormat.gd")
	BLUEPRINT_FORMAT_CLASS = load("res://MeshFramework/Formats/BlueprintFormat.gd")
	
	if not OBJ_FORMAT_CLASS:
		push_error("FormatRegistry: Failed to load OBJFormat.gd from PCK")
		return 0
	
	if not BLUEPRINT_FORMAT_CLASS:
		push_error("FormatRegistry: Failed to load BlueprintFormat.gd from PCK")
		return 0
	
	print("FormatRegistry: Format classes loaded successfully")
	
	# Register the formats
	register_format(OBJ_FORMAT_CLASS)
	register_format(BLUEPRINT_FORMAT_CLASS)
	
	_initialized = true
	print("FormatRegistry: Initialization complete - ", _extension_to_handler.size(), " formats registered")
	
	return _extension_to_handler.size()

func register_formats(format_classes: Array) -> void:
	for format_class in format_classes:
		register_format(format_class)

func register_format(format_class):
	if not format_class:
		push_error("FormatRegistry: Cannot register null format class")
		return
		
	var format_instance = format_class.new()
	
	# Check if it's a BaseFormat (use duck typing since we can't preload BaseFormat)
	if not format_instance.has_method("get_format_extension"):
		push_error("FormatRegistry: Class is not a valid format handler")
		return
		
	var extension = format_instance.get_format_extension().to_lower()
	
	if format_instance.can_import:
		_import_handlers[extension] = format_class
	
	if format_instance.can_export:
		_export_handlers[extension] = format_class
	
	_extension_to_handler[extension] = format_class
	print("FormatRegistry: Registered format handler for ." + extension + ": " + format_instance.get_format_name())

func get_format_handler_for_extension(extension: String):
	extension = extension.to_lower()
	if _extension_to_handler.has(extension):
		return _extension_to_handler[extension].new()
	return null

func get_import_handler_for_extension(extension: String):
	extension = extension.to_lower()
	if _import_handlers.has(extension):
		return _import_handlers[extension].new()
	return null

func get_export_handler_for_extension(extension: String):
	extension = extension.to_lower()
	if _export_handlers.has(extension):
		return _export_handlers[extension].new()
	return null

func get_supported_import_extensions() -> PackedStringArray:
	var extensions = PackedStringArray()
	for ext in _import_handlers:
		extensions.append(ext)
	return extensions

func get_supported_export_extensions() -> PackedStringArray:
	var extensions = PackedStringArray()
	for ext in _export_handlers:
		extensions.append(ext)
	return extensions

func get_import_file_dialog_filters() -> PackedStringArray:
	var filters = PackedStringArray()
	for ext in _import_handlers:
		var format_class = _import_handlers[ext]
		filters.append(format_class.get_format_name() + " (*." + ext + ")")
	return filters

func get_export_file_dialog_filters() -> PackedStringArray:
	var filters = PackedStringArray()
	for ext in _export_handlers:
		var format_class = _export_handlers[ext]
		filters.append(format_class.get_format_name() + " (*." + ext + ")")
	return filters

func detect_format(file_path: String) -> String:
	var extension = file_path.get_extension().to_lower()
	if _extension_to_handler.has(extension):
		return extension
	return ""

func load(file_path: String, format_extension: String = "", options: Dictionary = {}):
	if format_extension.is_empty():
		format_extension = file_path.get_extension().to_lower()
	
	var handler = get_import_handler_for_extension(format_extension)
	if not handler:
		push_error("FormatRegistry: No import handler found for format: " + format_extension)
		print("Available import formats: ", get_supported_import_extensions())
		return null
	
	print("Using import handler for format: " + format_extension)
	return handler.import_model(file_path, options)

func save(model_data, file_path: String, format_extension: String, options: Dictionary = {}) -> Dictionary:
	format_extension = format_extension.to_lower()
	var handler = get_export_handler_for_extension(format_extension)
	
	if not handler:
		push_error("FormatRegistry: No export handler found for format: " + format_extension)
		print("Available export formats: ", get_supported_export_extensions())
		return {"success": false, "error": "No export handler found for format: " + format_extension}
	
	print("Using export handler for format: " + format_extension)
	return handler.export_model(model_data, file_path, options)
