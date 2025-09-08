extends Node

# This exists to make the engine happy while working on and testing the pck without having to actually load 
# it into the main project
#
# Its Singleton shouldnt conflict with the Main applications iteration

func load(file_path: String, extension: String = "") -> ModelData:
	return null

func save(model_data: ModelData, file_path: String, extension: String, options: Dictionary = {}) -> Dictionary:
	return {"success": false}
