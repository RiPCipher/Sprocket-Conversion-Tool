extends Node
class_name FormatRegistryAutoload

var _import_handlers = {}
var _export_handlers = {}
var _extension_to_handler = {}

var _format_paths = ["res://MeshFramework/Formats/", "res://MeshFramework/Formats/AdditionalFormats/"]
var _user_format_path = ""

func register_format(format_class):
	var format_instance = format_class.new()
	
	if not format_instance is BaseFormat:
		push_error("FormatRegistry: Class is not a BaseFormat")
		return
		
	var extension = format_instance.get_format_extension().to_lower()
	
	if format_instance.can_import:
		_import_handlers[extension] = format_class
	
	if format_instance.can_export:
		_export_handlers[extension] = format_class
	
	_extension_to_handler[extension] = format_class
	print("Registered format handler for ." + extension + ": " + format_instance.get_format_name())

func initialize(user_format_path: String = "") -> int:
	_import_handlers.clear()
	_export_handlers.clear()
	_extension_to_handler.clear()
	if not user_format_path.is_empty():
		_user_format_path = user_format_path
		_format_paths.append(user_format_path)
	
	register_built_in_formats()
	
	var count = discover_and_register_formats()
	
	return count

func discover_and_register_formats() -> int:
	var registered_count = 0
	
	for path in _format_paths:
		registered_count += _scan_directory_for_formats(path)
	
	return registered_count

func _scan_directory_for_formats(directory_path: String) -> int:
	var registered_count = 0
	
	if not DirAccess.dir_exists_absolute(directory_path):
		return 0
	
	var dir = DirAccess.open(directory_path)
	if not dir:
		return 0
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with(".") and file_name != "AdditionalFormats":
			var subdir_count = _scan_directory_for_formats(directory_path.path_join(file_name))
			registered_count += subdir_count
		elif file_name.ends_with("Format.gd") and not file_name.begins_with("Base"):
			var format_path = directory_path.path_join(file_name)
			var format_script = load(format_path)
			if format_script and format_script is GDScript:
				var instance = format_script.new()
				if instance is BaseFormat:
					register_format(format_script)
					registered_count += 1
		
		file_name = dir.get_next()
	
	return registered_count

func set_user_format_directory(directory_path: String) -> bool:
	if directory_path.is_empty():
		return false
	
	if not DirAccess.dir_exists_absolute(directory_path):
		var dir = DirAccess.open("user://")
		if dir:
			dir.make_dir_recursive(directory_path)
	
	if not _user_format_path.is_empty() and _user_format_path in _format_paths:
		_format_paths.erase(_user_format_path)
	
	_user_format_path = directory_path
	_format_paths.append(_user_format_path)
	
	var count = _scan_directory_for_formats(_user_format_path)
	
	return count > 0

func get_format_handler_for_extension(extension: String) -> BaseFormat:
	extension = extension.to_lower()
	if _extension_to_handler.has(extension):
		return _extension_to_handler[extension].new()
	return null

func get_import_handler_for_extension(extension: String) -> BaseFormat:
	extension = extension.to_lower()
	if _import_handlers.has(extension):
		return _import_handlers[extension].new()
	return null

func get_export_handler_for_extension(extension: String) -> BaseFormat:
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

func register_built_in_formats():
	register_format(OBJFormat)
