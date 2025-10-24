extends Node

# Launcher executable version - UPDATE THIS WHEN RELEASING NEW LAUNCHER!!!
const LAUNCHER_VERSION = "v1.0"

func _ready():
	# Get the directory where the launcher executable is located
	var exe_dir = OS.get_executable_path().get_base_dir()
	var data_dir = exe_dir.path_join("data")
	var pck_name = "Sprocket_Conversion_Tool.pck"
	var update_pck_name = "Sprocket_Conversion_Tool_UPDATE.pck"
	
	# Create data folder if it doesn't exist
	if not DirAccess.dir_exists_absolute(data_dir):
		print("Creating data folder at: ", data_dir)
		var err = DirAccess.make_dir_recursive_absolute(data_dir)
		if err != OK:
			printerr("ERROR: Failed to create data folder: " + error_string(err))
			await get_tree().create_timer(5.0).timeout
			get_tree().quit()
			return
	
	var pck_path = data_dir.path_join(pck_name)
	var update_pck_path = data_dir.path_join(update_pck_name)
	
	print("Launcher starting...")
	print("Launcher version: ", LAUNCHER_VERSION)
	print("Executable directory: ", exe_dir)
	print("Data directory: ", data_dir)
	
	# Check if there's a pending update
	if FileAccess.file_exists(update_pck_path):
		print("Update found! Applying update...")
		apply_update(pck_path, update_pck_path)
	
	# Load the .pck file
	if not FileAccess.file_exists(pck_path):
		printerr("ERROR: Could not find " + pck_name)
		printerr("Make sure the .pck file is in the data folder!")
		printerr("Looking in: " + data_dir)
		await get_tree().create_timer(5.0).timeout 
		get_tree().quit()
		return
	
	print("Loading resource pack: ", pck_path)
	var success = ProjectSettings.load_resource_pack(pck_path)
	
	if not success:
		printerr("ERROR: Failed to load resource pack: " + pck_path)
		await get_tree().create_timer(5.0).timeout
		get_tree().quit()
		return
	
	print("Successfully loaded: " + pck_name)
	
	# Change to the main entry scene
	get_tree().change_scene_to_file.call_deferred("res://Scenes/Converter.tscn")

func apply_update(old_pck_path: String, new_pck_path: String):
	print("Applying update...")
	print("Old .pck: ", old_pck_path)
	print("New .pck: ", new_pck_path)
	
	# Delete the old .pck file
	if FileAccess.file_exists(old_pck_path):
		var err = DirAccess.remove_absolute(old_pck_path)
		if err != OK:
			printerr("ERROR: Failed to remove old .pck file: " + error_string(err))
			return
		print("Old .pck removed successfully")
	
	# Rename the update file to the main .pck name
	var err = DirAccess.rename_absolute(new_pck_path, old_pck_path)
	if err != OK:
		printerr("ERROR: Failed to rename update file: " + error_string(err))
		return
	
	print("Update applied successfully!")
