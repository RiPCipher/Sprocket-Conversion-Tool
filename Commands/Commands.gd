extends RefCounted
class_name DebugCommands

var available_commands = {}
var main_scene
var debugger
var models
var config_manager
var exe_dir

func _ready():
	main_scene = Engine.get_main_loop().current_scene
	debugger = main_scene.get_node_or_null("Mods/Debugger")
	models = debugger.get_node_or_null("TextBasedModels") if debugger else null

func _init():
	_register_commands()
	main_scene = Engine.get_main_loop().current_scene
	debugger = main_scene.get_node_or_null("Mods/Debugger")
	models = debugger.get_node_or_null("TextBasedModels") if debugger else null
	config_manager = main_scene.get_node_or_null("ConfigManager") if main_scene else null
	exe_dir = OS.get_executable_path().get_base_dir()
	
func _register_commands():
	available_commands["help"] = _cmd_help
	available_commands["test"] = _cmd_test
	available_commands["clear"] = _cmd_clear
	available_commands["time"] = _cmd_time
	available_commands["version"] = _cmd_version
	available_commands["popup"] = _cmd_popup
	available_commands["test_ngon"] = _cmd_test_ngon
	available_commands["test_blueprint"] = _cmd_test_blueprint
	available_commands["test_obj"] = _cmd_test_obj
	available_commands["test_roundtrip"] = _cmd_test_roundtrip
	available_commands["dump_models"] = _cmd_dump_models

func execute_command(command: String) -> String:
	var parts = command.split(" ", false)
	var cmd = parts[0].to_lower() if parts.size() > 0 else ""
	var args = parts.slice(1) if parts.size() > 1 else []
	
	if available_commands.has(cmd):
		return available_commands[cmd].call(args)
	else:
		return "Unknown command: '" + cmd + "'. Type 'help' for available commands."

# Commands ####################################################################
func _cmd_help(args: Array) -> String:
	var help_text = "Available commands:\n"
	help_text += "  help - Show this help message\n"
	help_text += "  test - Run a test command\n"
	help_text += "  clear - Clear the console\n"
	help_text += "  time - Show current time\n"
	help_text += "  popup - Test popups\n"
	help_text += "  test_ngon - Test N-gon file\n"
	help_text += "  test_blueprint - Test blueprint->OBJ conversion\n"
	help_text += "  test_obj - Test OBJ->blueprint conversion\n"
	help_text += "  test_roundtrip - Test round-trip conversion(s)\n"
	help_text += "  dump_models - Write test models to debug folder\n"
	help_text += "  version - Show debugger version\n"
	return help_text

func _cmd_test(args: Array) -> String:
	if args.size() > 0:
		return "Test command executed with args: " + str(args)
	else:
		return "Test command executed successfully!"

func _cmd_clear(args: Array) -> String:
	return "CLEAR_CONSOLE"

func _cmd_time(args: Array) -> String:
	return "Current time: " + Time.get_datetime_string_from_system()

func _cmd_version(args: Array) -> String:
	var version = ProjectSettings.get_setting("application/config/version", "Unknown")
	var app_name = ProjectSettings.get_setting("application/config/name", "Application")
	var debugger_version = debugger.debugger_version if debugger else "Unknown"
	return app_name + " v" + version + " | Debugger v" + debugger_version

func _cmd_popup(args: Array) -> String:
	if not main_scene:
		return "Error: Main scene not available"
	
	main_scene._show_error_popup("Test Popup", "This is a test popup from debugger")
	return "Test popup triggered"

func _cmd_test_ngon(args: Array) -> String:
	if not models:
		return "Error: Models data not available"
	
	return _test_conversion(models.NGON_OBJ_DATA, "obj", "blueprint", "N-gon OBJ->Blueprint")

func _cmd_test_blueprint(args: Array) -> String:
	if not models:
		return "Error: Models data not available"
	
	return _test_conversion(models.SIMPLE_BLUEPRINT_DATA, "blueprint", "obj", "Blueprint->OBJ")

func _cmd_test_obj(args: Array) -> String:
	if not models:
		return "Error: Models data not available"
	
	return _test_conversion(models.SIMPLE_OBJ_DATA, "obj", "blueprint", "OBJ->Blueprint")

func _cmd_test_roundtrip(args: Array) -> String:
	if not models:
		return "Error: Models data not available"
		
	var results = []
	
	# Test blueprint->obj->blueprint roundtrip
	var bp_result = _test_roundtrip(models.SIMPLE_BLUEPRINT_DATA, "blueprint", "obj")
	results.append("Blueprint roundtrip: " + bp_result)
	
	# Test obj->blueprint->obj roundtrip
	var obj_result = _test_roundtrip(models.SIMPLE_OBJ_DATA, "obj", "blueprint")
	results.append("OBJ roundtrip: " + obj_result)
	
	return "\n".join(results)

func _cmd_dump_models(args: Array) -> String:
	if not models:
		return "Error: Models data not available"
	
	var debug_folder = debugger.logger.debug_folder_path if debugger and debugger.logger else "."
	var results = []
	
	# Write NGON OBJ file
	var ngon_path = debug_folder + "/test_ngon.obj"
	var ngon_file = FileAccess.open(ngon_path, FileAccess.WRITE)
	if ngon_file:
		ngon_file.store_string(models.NGON_OBJ_DATA)
		ngon_file.close()
		results.append("N-gon OBJ: " + ngon_path)
	else:
		results.append("Failed to write N-gon OBJ file")
	
	# Write Simple OBJ file
	var simple_obj_path = debug_folder + "/test_simple.obj"
	var simple_obj_file = FileAccess.open(simple_obj_path, FileAccess.WRITE)
	if simple_obj_file:
		simple_obj_file.store_string(models.SIMPLE_OBJ_DATA)
		simple_obj_file.close()
		results.append("Simple OBJ: " + simple_obj_path)
	else:
		results.append("Failed to write simple OBJ file")
	
	# Write Blueprint file
	var blueprint_path = debug_folder + "/test_simple.blueprint"
	var blueprint_file = FileAccess.open(blueprint_path, FileAccess.WRITE)
	if blueprint_file:
		blueprint_file.store_string(models.SIMPLE_BLUEPRINT_DATA)
		blueprint_file.close()
		results.append("Simple Blueprint: " + blueprint_path)
	else:
		results.append("Failed to write blueprint file")
	
	return "Files written to debug folder:\n" + "\n".join(results)

# Test Functions ###############################################

# conversion test with UI validation
func _test_conversion(data: String, source_ext: String, target_ext: String, description: String) -> String:
	var debug_folder = debugger.logger.debug_folder_path if debugger and debugger.logger else "."
	var source_temp_path = debug_folder + "/temp_validation_" + description.replace("->", "_to_").replace(" ", "_") + "." + source_ext
	
	# Write source data to temp file
	var source_file = FileAccess.open(source_temp_path, FileAccess.WRITE)
	if not source_file:
		return description + " failed: Could not create source temp file"
	source_file.store_string(data)
	source_file.close()
	
	# Load source file
	var model_data = FormatRegistry.load(source_temp_path)
	if not model_data:
		_cleanup_temp_file(source_temp_path)
		return description + " failed: Could not load source file"
	
	var validation_results = []
	
	# Basic model validation
	var vertex_count = model_data.get_vertex_count()
	if vertex_count == 0:
		_cleanup_temp_file(source_temp_path)
		return description + " basic validation failed: No vertices in model"
	
	# N-gon validation for OBJ->Blueprint
	if source_ext == "obj" and target_ext == "blueprint":
		if model_data.has_metadata("ngon_count"):
			var ngon_count = model_data.get_metadata("ngon_count", 0)
			if ngon_count > 0:
				_cleanup_temp_file(source_temp_path)
				
				# Show the actual popup like the UI does
				if main_scene:
					var message = "This OBJ file contains " + str(ngon_count) + " polygon(s) with more than 4 sides (n-gons).\n\nIf converted, Sprocket will not be able to load the blueprint file.\n\nPlease use a 3D modeling tool to triangulate the problematic face or remove it before attempting conversion."
					main_scene._show_error_popup("N-Gons Detected in File", message)
				
				return description + " Validation Blocked: " + str(ngon_count) + " N-gons detected (popup shown, conversion prevented)"
	
	# Format-specific export validation
	var target_handler = FormatRegistry.get_export_handler_for_extension(target_ext) if FormatRegistry else null
	if target_handler and target_handler.has_method("validate_for_export"):
		var export_validation = target_handler.validate_for_export(model_data)
		if not export_validation.valid:
			_cleanup_temp_file(source_temp_path)
			return description + " export validation failed: " + str(export_validation.errors)
		
		if export_validation.warnings.size() > 0:
			validation_results.append("Validation warnings: " + str(export_validation.warnings))
	
	# If all validation passed, proceed with conversion
	var target_temp_path = debug_folder + "/temp_target_validation_" + description.replace("->", "_to_").replace(" ", "_") + "." + target_ext
	var save_result = FormatRegistry.save(model_data, target_temp_path, target_ext)
	
	_cleanup_temp_file(source_temp_path)
	_cleanup_temp_file(target_temp_path)
	
	var result_text = ""
	if save_result.success:
		var stats = "(" + str(vertex_count) + " vertices"
		
		# Add additional stats if available
		var triangle_count = model_data.get_metadata("triangle_count", 0)
		var quad_count = model_data.get_metadata("quad_count", 0)
		if triangle_count > 0 or quad_count > 0:
			stats += ", " + str(triangle_count) + " triangles, " + str(quad_count) + " quads"
		stats += ")"
		
		result_text = description + " Validation Passed -> Conversion Success " + stats
	else:
		result_text = description + " conversion failed: " + save_result.error
	
	# Add any validation warnings
	if validation_results.size() > 0:
		result_text += "\n" + "\n".join(validation_results)
	
	return result_text

# Comprehensive roundtrip test with validation at each step
func _test_roundtrip(data: String, source_ext: String, intermediate_ext: String) -> String:
	var debug_folder = debugger.logger.debug_folder_path if debugger and debugger.logger else "."
	var test_id = Time.get_ticks_msec()
	
	# Load original file
	var original_temp_path = debug_folder + "/temp_roundtrip_" + str(test_id) + "_original." + source_ext
	var original_file = FileAccess.open(original_temp_path, FileAccess.WRITE)
	if not original_file:
		return "Roundtrip Failed: Could not create original temp file"
	original_file.store_string(data)
	original_file.close()
	
	var original_data = FormatRegistry.load(original_temp_path)
	if not original_data:
		_cleanup_temp_file(original_temp_path)
		return "Roundtrip Failed: Could not load original " + source_ext + " file"
	
	var original_vertices = original_data.get_vertex_count()
	var original_triangles = original_data.get_metadata("triangle_count", 0)
	var original_quads = original_data.get_metadata("quad_count", 0)
	
	# Convert to intermediate format
	var validation_errors = []
	
	# Check for issues that would block conversion in UI
	if source_ext == "obj" and intermediate_ext == "blueprint":
		if original_data.has_metadata("ngon_count"):
			var ngon_count = original_data.get_metadata("ngon_count", 0)
			if ngon_count > 0:
				_cleanup_temp_file(original_temp_path)
				return "Roundtrip Blocked: " + str(ngon_count) + " N-gons detected in original " + source_ext
	
	var temp1_path = debug_folder + "/temp_roundtrip_" + str(test_id) + "_step1." + intermediate_ext
	var save1_result = FormatRegistry.save(original_data, temp1_path, intermediate_ext)
	if not save1_result.success:
		_cleanup_temp_file(original_temp_path)
		return "Roundtrip Failed: First conversion (" + source_ext + "→" + intermediate_ext + "): " + save1_result.error
	
	# Load intermediate file
	var intermediate_data = FormatRegistry.load(temp1_path)
	if not intermediate_data:
		_cleanup_temp_file(original_temp_path)
		_cleanup_temp_file(temp1_path)
		return "Roundtrip Failed: Could not load intermediate " + intermediate_ext + " file"
	
	var intermediate_vertices = intermediate_data.get_vertex_count()
	
	# Convert back to original format
	if intermediate_ext == "obj" and source_ext == "blueprint":
		if intermediate_data.has_metadata("ngon_count"):
			var ngon_count = intermediate_data.get_metadata("ngon_count", 0)
			if ngon_count > 0:
				_cleanup_temp_file(original_temp_path)
				_cleanup_temp_file(temp1_path)
				return "Roundtrip Blocked: " + str(ngon_count) + " N-gons detected in intermediate " + intermediate_ext
	
	var temp2_path = debug_folder + "/temp_roundtrip_" + str(test_id) + "_step2." + source_ext
	var save2_result = FormatRegistry.save(intermediate_data, temp2_path, source_ext)
	
	# Clean up all temp files
	_cleanup_temp_file(original_temp_path)
	_cleanup_temp_file(temp1_path)
	_cleanup_temp_file(temp2_path)
	
	if save2_result.success:
		var final_vertices = intermediate_data.get_vertex_count()
		var stats = "(" + str(original_vertices) + "->" + str(intermediate_vertices) + "->" + str(final_vertices) + " vertices)"
		
		# Check for data integrity
		var integrity_notes = []
		if original_vertices != final_vertices:
			integrity_notes.append("vertex count changed")
		
		var result = "Roundtrip Success " + stats
		if integrity_notes.size() > 0:
			result += " [WARNING: " + ", ".join(integrity_notes) + "]"
		
		return result
	else:
		return "Roundtrip Failed: Second conversion (" + intermediate_ext + "->" + source_ext + "): " + save2_result.error

# Cleanup
func _cleanup_temp_file(path: String):
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		
