extends Node

var _debugger_loaded = false
var _debug_folder_path = ""
var _exe_dir = ""
var _debugger_instance = null

func _ready():
	_setup_debug_system()

func _setup_debug_system():
	var exe_path = OS.get_executable_path()
	_exe_dir = exe_path.get_base_dir()
	_debug_folder_path = _exe_dir + "/debug"
	
	print("Debug: Checking for debugger at: " + _debug_folder_path)
	
	# Only proceed if debug folder exists OR if debugger.pck exists
	if _should_load_debugger():
		_try_load_debugger_pck()

func _should_load_debugger() -> bool:
	# Check if debug folder exists
	if DirAccess.dir_exists_absolute(_debug_folder_path):
		return true
	
	# Or check if debugger.pck exists next to executable
	var pck_path = _exe_dir + "/debugger.pck"
	if FileAccess.file_exists(pck_path):
		return true
	
	return false

func _try_load_debugger_pck():
	# Try multiple locations for the PCK
	var pck_paths = [
		_debug_folder_path + "/debugger.pck",  # Inside debug folder
		_exe_dir + "/debugger.pck"             # Next to executable
	]
	
	for pck_path in pck_paths:
		if FileAccess.file_exists(pck_path):
			print("Debug: Found debugger PCK at: " + pck_path)
			
			if ProjectSettings.load_resource_pack(pck_path):
				print("Debug: Successfully loaded debugger PCK")
				_debugger_loaded = true
				
				# Create debug folder
				_ensure_debug_folder_exists()
				
				# Manually create the debugger instance
				await get_tree().process_frame
				_create_debugger_instance()
				
				return
			else:
				print("Debug: Failed to load debugger PCK at: " + pck_path)
	
	print("Debug: No valid debugger PCK found")

func _create_debugger_instance():
	# Try to load the debugger script from the PCK
	var debugger_script = load("res://Debugger.gd")
	if not debugger_script:
		print("Debug: Could not load Debugger.gd from PCK")
		return
	
	# Create the node structure in the main scene
	var main_scene = get_tree().current_scene
	
	# Find Mods Node
	var mods_node = main_scene.get_node_or_null("Mods")
	if not mods_node:
		mods_node = Node.new()
		mods_node.name = "Mods"
		main_scene.add_child(mods_node)
		print("Debug: Created Mods node")
	
	# Create Debugger instance
	_debugger_instance = debugger_script.new()
	_debugger_instance.name = "Debugger"
	mods_node.add_child(_debugger_instance)
	
	print("Debug: Created Debugger instance at Mods/Debugger")
	
	# Tell the debugger where to put files
	_debugger_instance.set_debug_folder(_debug_folder_path)

func _ensure_debug_folder_exists():
	# Only create debug folder if debugger is actually loaded
	if not DirAccess.dir_exists_absolute(_debug_folder_path):
		var success = DirAccess.make_dir_recursive_absolute(_debug_folder_path)
		if success:
			print("Debug: Created debug folder at: " + _debug_folder_path)
		else:
			push_error("Debug: Failed to create debug folder at: " + _debug_folder_path)

# Main logging functions
func log(text = "", arg2 = null, arg3 = null, arg4 = null, arg5 = null):
	var combined_text = str(text)
	
	if arg2 != null:
		combined_text += str(arg2)
	if arg3 != null:
		combined_text += str(arg3)
	if arg4 != null:
		combined_text += str(arg4)
	if arg5 != null:
		combined_text += str(arg5)
	
	if _debugger_instance:
		_debugger_instance.debug_log(combined_text)
	else:
		print(text, arg2, arg3, arg4, arg5)

func error(text = "", arg2 = null, arg3 = null, arg4 = null, arg5 = null):
	var combined_text = str(text)
	
	if arg2 != null:
		combined_text += str(arg2)
	if arg3 != null:
		combined_text += str(arg3)
	if arg4 != null:
		combined_text += str(arg4)
	if arg5 != null:
		combined_text += str(arg5)
		
	if _debugger_instance:
		_debugger_instance.debug_error(combined_text)
	else:
		push_error(combined_text)

func warn(text = "", arg2 = null, arg3 = null, arg4 = null, arg5 = null):
	var combined_text = str(text)
	
	if arg2 != null:
		combined_text += str(arg2)
	if arg3 != null:
		combined_text += str(arg3)
	if arg4 != null:
		combined_text += str(arg4)
	if arg5 != null:
		combined_text += str(arg5)
		
	if _debugger_instance:
		_debugger_instance.debug_warn(combined_text)
	else:
		push_warning(combined_text)

func is_debug_enabled() -> bool:
	return _debugger_instance != null

func get_debug_folder() -> String:
	return _debug_folder_path
