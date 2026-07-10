class_name BlueprintFormat
extends BaseFormat

var _standard_handler = StandardBlueprintHandler.new()
#var _vehicle_handler = VehicleBlueprintHandler.new()

func _init():
	can_import = true
	can_export = true
	supports_materials = true
	supports_animations = false
	supports_skeletons = false
	supports_morph_targets = false

#====================#
# FORMAT INFORMATION #
#====================#
static func get_format_name() -> String:
	return "Blueprint Format"

static func get_format_extension() -> String:
	return "blueprint"

static func get_format_description() -> String:
	return "Blueprint"

#=================#
# Import File     #
#=================#
func import_model(file_path: String, options: Dictionary = {}) -> ModelData:
	var model_data = ModelData.new()
	model_data.source_format = "blueprint"
	model_data.set_metadata("source_path", file_path)
	
	var blueprint_type = "standard"
	Debug.call_deferred("log", "BlueprintFormat: Using standard blueprint handler")
	
	var import_options = get_default_import_options()
	for key in options:
		import_options[key] = options[key]
	
	var result = _standard_handler.import_model(file_path, import_options, model_data)
	if result:
		model_data.set_metadata("blueprint_type", "standard")
		return model_data
	
	Debug.call_deferred("log", "BlueprintFormat: Import failed, returning model_data with error info")
	
	if not model_data.has_metadata("import_error_type"):
		model_data.set_metadata("import_error_type", "blueprint_invalid_format")
		model_data.set_metadata("import_error_file", file_path.get_file())
	
	return model_data 

#================#
# Export File    #
#================#
func export_model(model_data: ModelData, file_path: String, options: Dictionary = {}) -> Dictionary:
	return _standard_handler.export_model(model_data, file_path, options)
	
func create_wireframe_mesh(model_data: ModelData) -> MeshInstance3D:
	return _standard_handler.create_wireframe_mesh(model_data)

func _detect_blueprint_type(file_path: String) -> String:
	# Add error checking before file access
	var read_check = ErrorHandler.check_file_read(file_path)
	if not read_check.success:
		ErrorHandler.handle_file_error(read_check.error_key, read_check.error_code, "detect blueprint type", file_path)
		return "standard"
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("BlueprintFormat: Failed to open file: " + file_path)
		return "standard"
	
	var file_content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(file_content)
	if error != OK:
		push_warning("BlueprintFormat: File is not valid JSON: " + file_path)
		return "standard"
	
	var data = json.get_data()
	
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("header") and data.has("blueprints") and data.has("objects") and data.has("meshes"):
			Debug.log("BlueprintFormat: Detected vehicle blueprint structure")
			
			if data.has("header"):
				if data.header.has("class") or data.header.has("era") or data.header.has("gameVersion"):
					Debug.log("BlueprintFormat: Confirmed as vehicle blueprint")
					return "vehicle"
	
	return "standard"

# Default options
static func get_default_import_options() -> Dictionary:
	return {
		"calculate_normals": true,
		"generate_uvs": true,
		"preserve_quads": true
	}

static func get_default_export_options() -> Dictionary:
	return {
		"precision": 6,
		"include_materials": true
	}

func validate_for_export(model_data: ModelData, options: Dictionary = {}) -> Dictionary:
	return _standard_handler.validate_for_export(model_data, options)

#==============================#
# Standard Blueprint Handler   #
#==============================#
class StandardBlueprintHandler:
	func import_model(file_path: String, options: Dictionary, model_data: ModelData) -> bool:
		var read_check = ErrorHandler.check_file_read(file_path)
		if not read_check.success:
			ErrorHandler.handle_file_error(read_check.error_key, read_check.error_code, "import blueprint model", file_path)
			return false
		
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			push_error("StandardBlueprintHandler: Failed to open blueprint file")
			return false
		
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		if error != OK:
			push_error("StandardBlueprintHandler: Failed to parse blueprint JSON")
			model_data.set_metadata("import_error_type", "blueprint_invalid_format")
			model_data.set_metadata("import_error_file", file_path.get_file())
			return false
		
		var blueprint_data = json.get_data()

		# store error
		if !blueprint_data.has("v"):
			model_data.set_metadata("import_error_type", "blueprint_no_version")
			model_data.set_metadata("import_error_file", file_path.get_file())
			return false

		if blueprint_data.v != "0.2":
			model_data.set_metadata("import_error_type", "blueprint_unsupported_version")
			model_data.set_metadata("import_error_file", file_path.get_file())
			model_data.set_metadata("import_error_version", str(blueprint_data.v))
			return false

		# mesh validation
		if !blueprint_data.has("mesh") or !blueprint_data.mesh.has("vertices") or !blueprint_data.mesh.has("faces"):
			model_data.set_metadata("import_error_type", "blueprint_invalid_format")
			model_data.set_metadata("import_error_file", file_path.get_file())
			return false

		var mesh = blueprint_data.mesh
		var flat_vertices = mesh.vertices
		var faces = mesh.faces
		
		var surface_arrays = []
		surface_arrays.resize(Mesh.ARRAY_MAX)
		
		var packed_vertices = PackedVector3Array()
		for i in range(0, flat_vertices.size(), 3):
			if i + 2 < flat_vertices.size():
				packed_vertices.append(Vector3(
					-flat_vertices[i],    # X
					flat_vertices[i + 1], # Y
					flat_vertices[i + 2]  # Z
				))
		
		surface_arrays[Mesh.ARRAY_VERTEX] = packed_vertices
		var packed_indices = PackedInt32Array()
		
		var part_idx = model_data.get_active_part_index()
		
		var topology = {
			"is_quad_mesh": false,
			"quads": []
		}
		model_data.part_topology[part_idx] = topology
		
		# Process faces
		var quad_count = 0
		var triangle_count = 0
		
		for face in faces:
			if face.has("v"):
				var face_vertices = face.v
				
				if face_vertices.size() == 3:
					triangle_count += 1
					packed_indices.append(int(face_vertices[0]))
					packed_indices.append(int(face_vertices[1]))
					packed_indices.append(int(face_vertices[2]))
				elif face_vertices.size() == 4 and options.get("preserve_quads", true):
					quad_count += 1
					model_data.part_topology[part_idx]["is_quad_mesh"] = true
					
					var quad_indices = [
						int(face_vertices[0]),
						int(face_vertices[1]),
						int(face_vertices[2]), 
						int(face_vertices[3])
					]
					model_data.part_topology[part_idx]["quads"].append(quad_indices)
					
					# Triangulate for renderer / Still retaining
					# original topology for conversion
					packed_indices.append(int(face_vertices[0]))
					packed_indices.append(int(face_vertices[1]))
					packed_indices.append(int(face_vertices[2]))
					
					packed_indices.append(int(face_vertices[0]))
					packed_indices.append(int(face_vertices[2]))
					packed_indices.append(int(face_vertices[3]))
		
		surface_arrays[Mesh.ARRAY_INDEX] = packed_indices
		
		model_data.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
		
		if options.get("calculate_normals", true):
			MeshUtility.calculate_normals(model_data)
		
		if options.get("generate_uvs", true):
			MeshUtility.generate_planar_uvs(model_data)
		
		if blueprint_data.has("name"):
			model_data.set_metadata("name", blueprint_data.name)
		
		if blueprint_data.has("format"):
			model_data.set_metadata("blueprint_format", blueprint_data.format)
		
		# Smothing
		if blueprint_data.has("smoothAngle"):
			model_data.set_metadata("smooth_angle", float(blueprint_data.smoothAngle))
		
		model_data.format_version = blueprint_data.get("v", "0.2")
		
		print("StandardBlueprintHandler: Loaded model with " + str(triangle_count) + " triangles and " + 
			  str(quad_count) + " quads")
		
		var original_faces = []
		for face in faces:
			if face.has("v"):
				original_faces.append(face.v.duplicate())
		model_data.set_part_metadata(part_idx, "original_faces", original_faces)
		
		# Store topology statistics in metadata for display in previewer
		model_data.set_part_metadata(part_idx, "triangle_count", triangle_count)
		model_data.set_part_metadata(part_idx, "quad_count", quad_count)
		model_data.set_part_metadata(part_idx, "total_faces", triangle_count + quad_count)
		
		return true
	
	func export_model(model_data: ModelData, file_path: String, options: Dictionary) -> Dictionary:
		var result = {
			"success": false,
			"error": "",
			"warnings": []
		}
		
		var part_idx = model_data.get_active_part_index()
		
		if model_data.meshes[part_idx].get_surface_count() == 0:
			result.error = "No surfaces to export"
			return result
		
		var blueprint_name = file_path.get_file().get_basename()
		if model_data.has_metadata("name"):
			blueprint_name = model_data.get_metadata("name")
		
		# Use original OBJ vertices if available
		var vertices = PackedVector3Array()
		var faces = []
		
		# Check if we have original OBJ data
		var has_original_obj_data = false
		if part_idx < model_data.part_original_vertices.size() and \
		   model_data.part_original_vertices[part_idx].size() > 0 and \
		   model_data.has_part_metadata(part_idx, "original_obj_faces"):
			vertices = model_data.part_original_vertices[part_idx]
			var original_obj_faces = model_data.get_part_metadata(part_idx, "original_obj_faces")
			has_original_obj_data = true
			
			print("BlueprintFormat: Using original OBJ topology - ", vertices.size(), " vertices, ", original_obj_faces.size(), " faces")
			
			# Build face data using original OBJ indices
			for face in original_obj_faces:
				if face.size() >= 3:
					var face_data = {
						"v": face.duplicate(),  # Use original OBJ vertex indices
						"t": [],
						"tm": 65793 if face.size() == 3 else 16843009,
						"te": 0
					}
					
					for i in range(face.size()):
						face_data.t.append(5)
					
					faces.append(face_data)
		else:
			# Fallback to surface arrays if no original OBJ data
			var surface_arrays = model_data.meshes[part_idx].surface_get_arrays(0)
			vertices = surface_arrays[Mesh.ARRAY_VERTEX]
			
			if model_data.has_part_metadata(part_idx, "original_faces"):
				var original_faces = model_data.get_part_metadata(part_idx, "original_faces")
				
				for face in original_faces:
					if face.size() >= 3:
						var face_data = {
							"v": face.duplicate(),
							"t": [],
							"tm": 65793 if face.size() == 3 else 16843009,
							"te": 0
						}
						
						for i in range(face.size()):
							face_data.t.append(5)
						
						faces.append(face_data)
			else:
				result.warnings.append("No original face data found in model - export may be incomplete")
		
		# Convert vertices to flat array
		var vertex_array = []
		for v in vertices:
			vertex_array.append(v.x)
			vertex_array.append(v.y)
			vertex_array.append(v.z)
		
		# Build edges
		var edges = []
		var edge_flags = []
		var edge_map = {}
		
		for face in faces:
			var face_vertices = face.v
			var face_size = face_vertices.size()
			
			for i in range(face_size):
				var v1 = int(face_vertices[i])
				var v2 = int(face_vertices[(i + 1) % face_size])
				
				if v1 > v2:
					var temp = v1
					v1 = v2
					v2 = temp
				
				var edge_key = str(v1) + "_" + str(v2)
				
				if !edge_map.has(edge_key):
					edges.append(v1)
					edges.append(v2)
					edge_flags.append(0)
					edge_map[edge_key] = true
		
		# Write Blueprint file
		var output_file = FileAccess.open(file_path, FileAccess.WRITE)
		if output_file == null:
			result.error = "Failed to create output file - " + str(FileAccess.get_open_error())
			return result
		
		# Write the JSON structure
		output_file.store_line("{")
		output_file.store_line('  "v": "0.2",') 
		output_file.store_line('  "name": "' + blueprint_name + '",')
		output_file.store_line('  "smoothAngle": 0,')
		output_file.store_line('  "gridSize": 1,')
		output_file.store_line('  "format": "freeform",')
		output_file.store_line('  "mesh": {')
		output_file.store_line('    "majorVersion": 0,')
		output_file.store_line('    "minorVersion": 3,')
		
		# Write vertices
		output_file.store_string('    "vertices": [')
		var write_chunk_size = 1000
		
		for i in range(0, vertex_array.size(), write_chunk_size):
			var end = min(i + write_chunk_size, vertex_array.size())
			var vertex_chunk = ""
			
			for j in range(i, end):
				var value = vertex_array[j]
				var formatted_value = "%.6f" % value
				
				if j > 0:
					vertex_chunk += ", "
					
				vertex_chunk += formatted_value
			
			output_file.store_string(vertex_chunk)
		
		output_file.store_line("\n    ],")
		
		# Write edges
		output_file.store_string('    "edges": [')
		
		for i in range(0, edges.size(), write_chunk_size):
			var end = min(i + write_chunk_size, edges.size())
			var edge_chunk = ""
			
			for j in range(i, end):
				if j > 0:
					edge_chunk += ", "
					
				edge_chunk += str(int(edges[j]))
			
			output_file.store_string(edge_chunk)
		
		output_file.store_line("\n    ],")
		
		# Write edge flags
		output_file.store_string('    "edgeFlags": [')
		
		for i in range(0, edge_flags.size(), write_chunk_size):
			var end = min(i + write_chunk_size, edge_flags.size())
			var flag_chunk = ""
			
			for j in range(i, end):
				if j > 0:
					flag_chunk += ", "
					
				flag_chunk += str(edge_flags[j])
			
			output_file.store_string(flag_chunk)
		
		output_file.store_line("\n    ],")
		
		# Write faces
		output_file.store_line('    "faces": [')
		
		for i in range(faces.size()):
			var face = faces[i]
			
			if i > 0:
				output_file.store_line(",")
			
			output_file.store_string('      {')
			
			# Write vertex indices
			output_file.store_string('"v": [')
			for j in range(face.v.size()):
				if j > 0:
					output_file.store_string(", ")
				output_file.store_string(str(int(face.v[j])))
			output_file.store_string('], ')
			
			# Write texture coordinates (placeholder0
			output_file.store_string('"t": [')
			for j in range(face.t.size()):
				if j > 0:
					output_file.store_string(", ")
				output_file.store_string(str(face.t[j]))
			output_file.store_string('], ')
			
			# Write texture metadata
			output_file.store_string('"tm": ' + str(face.tm) + ', ')
			output_file.store_string('"te": ' + str(face.te))
			
			output_file.store_string('}')
		
		output_file.store_line("\n    ]")
		output_file.store_line('  },')
		output_file.store_line('  "rivets": {')
		output_file.store_line('    "profiles": [')
		output_file.store_line('      {')
		output_file.store_line('        "model": 0,')
		output_file.store_line('        "spacing": 0.19,')
		output_file.store_line('        "diameter": 0.03,')
		output_file.store_line('        "height": 0.02,')
		output_file.store_line('        "padding": 0.04')
		output_file.store_line('      }')
		output_file.store_line('    ],')
		output_file.store_line('    "nodes": []')
		output_file.store_line('  }')
		output_file.store_line('}')
		
		output_file.close()
		
		result.success = true
		
		if has_original_obj_data:
			print("BlueprintFormat: Successfully exported with preserved OBJ topology")
		else:
			print("BlueprintFormat: Exported using standard surface arrays")
		
		return result
	
	func create_wireframe_mesh(model_data: ModelData) -> MeshInstance3D:
		print("StandardBlueprintHandler: Creating wireframe mesh")
		
		var part_idx = model_data.get_active_part_index()
		
		var wireframe_mesh = MeshInstance3D.new()
		var imm = ImmediateMesh.new()
		wireframe_mesh.mesh = imm
		
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0, 0.8, 1.0)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		wireframe_mesh.material_override = material
		
		var vertices = []
		if model_data.meshes[part_idx].get_surface_count() > 0:
			var surface_arrays = model_data.meshes[part_idx].surface_get_arrays(0)
			vertices = surface_arrays[Mesh.ARRAY_VERTEX]
		else:
			return wireframe_mesh
		
		imm.clear_surfaces()
		imm.surface_begin(Mesh.PRIMITIVE_LINES)
		
		var added_edges = {}
		var vertices_added = false
		
		# Check if we have original faces in metadata
		if model_data.has_part_metadata(part_idx, "original_faces"):
			var original_faces = model_data.get_part_metadata(part_idx, "original_faces")
			
			for face in original_faces:
				if face.size() >= 3:
					for i in range(face.size()):
						var v1_idx = face[i]
						var v2_idx = face[(i + 1) % face.size()]
						
						var edge_key = min(v1_idx, v2_idx) * 1000000 + max(v1_idx, v2_idx)
						
						if not edge_key in added_edges:
							added_edges[edge_key] = true
							
							if v1_idx >= 0 and v2_idx >= 0 and v1_idx < vertices.size() and v2_idx < vertices.size():
								imm.surface_add_vertex(vertices[v1_idx])
								imm.surface_add_vertex(vertices[v2_idx])
								vertices_added = true
								
		if vertices_added:
			imm.surface_end()
			print("StandardBlueprintHandler: Wireframe created with ", added_edges.size(), " edges")
		else:
			print("StandardBlueprintHandler: No valid edges found, creating placeholder")
			imm.surface_add_vertex(Vector3.ZERO)
			imm.surface_add_vertex(Vector3(0, 0, 0.001))
			imm.surface_end()
		
		return wireframe_mesh
	
	# Validation for export
	func validate_for_export(model_data: ModelData, options: Dictionary = {}) -> Dictionary:
		var result = {
			"valid": true,
			"errors": [],
			"warnings": []
		}
		
		# Check for limits
		var part_idx = model_data.get_active_part_index()
		var vertex_count = model_data.get_part_vertex_count(part_idx)
		
		if vertex_count == 0:
			result.errors.append("No vertices in model")
			result.valid = false
		
		if vertex_count > 50000: # Should remove entirely
			result.warnings.append("Model has a high vertex count (" + str(vertex_count) + 
								 "). This may cause performance issues.")
		
		# Check face count // Should remove entirely?
		if model_data.meshes[part_idx].get_surface_count() > 0:
			var surface_arrays = model_data.meshes[part_idx].surface_get_arrays(0)
			if surface_arrays[Mesh.ARRAY_INDEX].size() > 0:
				var face_count = surface_arrays[Mesh.ARRAY_INDEX].size() / 3
				
				if face_count > 30000:
					result.warnings.append("Model has a high face count (" + str(face_count) + 
									 "). This may cause performance issues.")
		
		return result
