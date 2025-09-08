extends Resource
class_name ModelData

# This exists to make the engine happy while working on and testing the pck without having to actually load 
# it into the main project

func get_vertex_count() -> int:
	return 0
	
func get_metadata(key: String, default_value = null):
	return default_value
