class_name OBJFormat
extends BaseFormat

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
	return "Wavefront OBJ"

static func get_format_extension() -> String:
	return "obj"

static func get_format_description() -> String:
	return "Wavefront OBJ"

#=================#
# Import File     #
#=================#
func import_model(file_path: String, options: Dictionary = {}) -> ModelData:
	var model_data = ModelData.new()
	model_data.source_format = "obj"
	model_data.set_metadata("source_path", file_path)
	
	var import_options = get_default_import_options()
	for key in options:
		import_options[key] = options[key]
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("OBJFormat: Failed to open file: " + file_path)
		return null
	
	var vertices = []
	var normals = []
	var uvs = []
	var faces = []
	
	var debug_info = {
		"raw_vertices": [],
		"raw_faces": [],
		"invalid_faces": [],
		"processed_triangles": 0,
		"processed_quads": 0,
		"processed_ngons": 0,
		"line_numbers": {}
	}
	
	var vertex_count = 0
	var face_count = 0
	var normal_count = 0
	var uv_count = 0
	var line_number = 0
	
	var file_content = file.get_as_text()
	file.close()
	
	var lines = file_content.split("\n")
	
	for line in lines:
		line_number += 1
		
		if line.is_empty() or line[0] == '#':
			continue
		
		var space_idx = line.find(" ")
		if space_idx < 0:
			continue
		
		var command = line.substr(0, space_idx)
		var rest = line.substr(space_idx + 1)
		
		match command:
			"v":
				var parts = rest.split(" ", false)
				debug_info.raw_vertices.append({"line": line_number, "content": line, "parts": parts})
				
				if parts.size() >= 3:
					vertices.append(Vector3(
						float(parts[0]),
						float(parts[1]),
						float(parts[2])
					))
					vertex_count += 1
				else:
					print("Invalid vertex at line ", line_number, ": ", line)
			
			"vn":
				var parts = rest.split(" ", false)
				if parts.size() >= 3:
					normals.append(Vector3(
						float(parts[0]),
						float(parts[1]),
						float(parts[2])
					))
					normal_count += 1
			
			"vt":
				var parts = rest.split(" ", false)
				if parts.size() >= 2:
					uvs.append(Vector2(
						float(parts[0]),
						1.0 - float(parts[1]) 
					))
					uv_count += 1
			
			"f":
				var parts = rest.split(" ", false)
				debug_info.raw_faces.append({"line": line_number, "content": line, "parts": parts})
				debug_info.line_numbers[line_number] = face_count
				
				var face = {
					"vertices": [],
					"normals": [],
					"uvs": [],
					"line_number": line_number
				}
				
				for i in range(parts.size()):
					var indices = parts[i].split("/")
					if indices.size() > 0 and not indices[0].is_empty():
						var vertex_idx = indices[0].to_int() - 1
						face.vertices.append(vertex_idx)
						
						if vertex_idx < 0 or vertex_idx >= vertices.size():
							debug_info.invalid_faces.append({
								"line": line_number,
								"reason": "Invalid vertex index: " + str(vertex_idx),
								"content": line
							})
					
					var uv_idx = -1
					if indices.size() > 1 and not indices[1].is_empty():
						uv_idx = indices[1].to_int() - 1
					face.uvs.append(uv_idx)
					
					var normal_idx = -1
					if indices.size() > 2 and not indices[2].is_empty():
						normal_idx = indices[2].to_int() - 1
					face.normals.append(normal_idx)
				
				if face.vertices.size() == 3:
					debug_info.processed_triangles += 1
				elif face.vertices.size() == 4:
					debug_info.processed_quads += 1
				else:
					debug_info.processed_ngons += 1
				
				faces.append(face)
				face_count += 1
	
	var triangle_count = 0
	var quad_count = 0
	var other_count = 0
	
	for face in faces:
		if face.vertices.size() == 3:
			triangle_count += 1
		elif face.vertices.size() == 4:
			quad_count += 1
		else:
			other_count += 1
	
	print("\n=== OBJ DEBUG INFO ===")
	print("File: ", file_path)
	print("Total lines parsed: ", line_number)
	print("Raw vertex lines found: ", debug_info.raw_vertices.size())
	print("Raw face lines found: ", debug_info.raw_faces.size())
	print("Vertices parsed: ", vertex_count)
	print("Normals parsed: ", normal_count)
	print("UVs parsed: ", uv_count)
	print("Faces parsed: ", face_count)
	print("Triangle count: ", triangle_count)
	print("Quad count: ", quad_count)
	print("Other polygon count: ", other_count)
	print("Invalid faces: ", debug_info.invalid_faces.size())
	
	var active_part_idx = model_data.get_active_part_index()
	
	var orig_verts = PackedVector3Array()
	orig_verts.resize(vertices.size())
	for i in range(vertices.size()):
		orig_verts[i] = vertices[i]
	model_data.part_original_vertices[active_part_idx] = orig_verts
	
	var topology = {
		"is_quad_mesh": (quad_count > 0),
		"quads": []
	}
	
	for face in faces:
		if face.vertices.size() == 4:
			topology["quads"].append(face.vertices.duplicate())
	
	model_data.part_topology[active_part_idx] = topology
	
	var vertex_map = {} 
	var surface_vertices = PackedVector3Array()
	var surface_normals = PackedVector3Array()
	var surface_uvs = PackedVector2Array()
	var surface_indices = PackedInt32Array()
	var vertex_counter = 0
	
	for face in faces:
		for i in range(face.vertices.size()):
			var v_idx = face.vertices[i]
			var n_idx = face.normals[i] if face.normals.size() > i else -1
			var uv_idx = face.uvs[i] if face.uvs.size() > i else -1
			
			var key = "%d:%d:%d" % [v_idx, n_idx, uv_idx]
			
			if not vertex_map.has(key):
				vertex_map[key] = vertex_counter
				
				surface_vertices.append(vertices[v_idx])
				
				if n_idx >= 0 and n_idx < normals.size():
					while surface_normals.size() <= vertex_counter:
						surface_normals.append(Vector3.UP)
					surface_normals[vertex_counter] = normals[n_idx]
				
				if uv_idx >= 0 and uv_idx < uvs.size():
					while surface_uvs.size() <= vertex_counter:
						surface_uvs.append(Vector2.ZERO)
					surface_uvs[vertex_counter] = uvs[uv_idx]
				
				vertex_counter += 1
	
	for face in faces:
		if face.vertices.size() == 3:
			for i in range(3):
				var v_idx = face.vertices[i]
				var n_idx = face.normals[i] if face.normals.size() > i else -1
				var uv_idx = face.uvs[i] if face.uvs.size() > i else -1
				var key = "%d:%d:%d" % [v_idx, n_idx, uv_idx]
				surface_indices.append(vertex_map[key])
		
		elif face.vertices.size() == 4:
			var indices = []
			for i in range(4):
				var v_idx = face.vertices[i]
				var n_idx = face.normals[i] if face.normals.size() > i else -1
				var uv_idx = face.uvs[i] if face.uvs.size() > i else -1
				var key = "%d:%d:%d" % [v_idx, n_idx, uv_idx]
				indices.append(vertex_map[key])
			
			surface_indices.append(indices[0])
			surface_indices.append(indices[1])
			surface_indices.append(indices[2])
			
			surface_indices.append(indices[0])
			surface_indices.append(indices[2])
			surface_indices.append(indices[3])
		
		elif face.vertices.size() > 4:
			#triangulate using fan if n-gon
			var base_idx = face.vertices[0]
			var base_n_idx = face.normals[0] if face.normals.size() > 0 else -1
			var base_uv_idx = face.uvs[0] if face.uvs.size() > 0 else -1
			var base_key = "%d:%d:%d" % [base_idx, base_n_idx, base_uv_idx]
			var base_surface_idx = vertex_map[base_key]
			
			for i in range(1, face.vertices.size() - 1):
				surface_indices.append(base_surface_idx)
				
				var v1_idx = face.vertices[i]
				var n1_idx = face.normals[i] if face.normals.size() > i else -1
				var uv1_idx = face.uvs[i] if face.uvs.size() > i else -1
				var key1 = "%d:%d:%d" % [v1_idx, n1_idx, uv1_idx]
				surface_indices.append(vertex_map[key1])
				
				var v2_idx = face.vertices[i + 1]
				var n2_idx = face.normals[i + 1] if face.normals.size() > i + 1 else -1
				var uv2_idx = face.uvs[i + 1] if face.uvs.size() > i + 1 else -1
				var key2 = "%d:%d:%d" % [v2_idx, n2_idx, uv2_idx]
				surface_indices.append(vertex_map[key2])
	
	var surface_arrays = []
	surface_arrays.resize(Mesh.ARRAY_MAX)
	surface_arrays[Mesh.ARRAY_VERTEX] = surface_vertices
	surface_arrays[Mesh.ARRAY_INDEX] = surface_indices
	
	if surface_normals.size() > 0:
		while surface_normals.size() < surface_vertices.size():
			surface_normals.append(Vector3.UP)
		surface_arrays[Mesh.ARRAY_NORMAL] = surface_normals
	
	if surface_uvs.size() > 0:
		while surface_uvs.size() < surface_vertices.size():
			surface_uvs.append(Vector2.ZERO)
		surface_arrays[Mesh.ARRAY_TEX_UV] = surface_uvs
	
	model_data.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
	
	var remapped_faces = []
	for face in faces:
		var remapped_face = []
		for i in range(face.vertices.size()):
			var v_idx = face.vertices[i]
			var n_idx = face.normals[i] if face.normals.size() > i else -1
			var uv_idx = face.uvs[i] if face.uvs.size() > i else -1
			var key = "%d:%d:%d" % [v_idx, n_idx, uv_idx]
			
			if vertex_map.has(key):
				remapped_face.append(vertex_map[key])
			else:
				push_error("OBJFormat: Vertex key not found in map during remapping")
		
		if remapped_face.size() >= 3:
			remapped_faces.append(remapped_face)

	model_data.set_part_metadata(active_part_idx, "original_faces", remapped_faces)
	model_data.set_metadata("triangle_count", triangle_count)
	model_data.set_metadata("quad_count", quad_count)
	model_data.set_metadata("total_faces", triangle_count + quad_count)
	
	model_data.set_metadata("debug_info", debug_info)
	
	if import_options.get("calculate_normals", true) and surface_normals.size() == 0:
		MeshUtility.calculate_normals(model_data)
	
	if import_options.get("generate_uvs", true) and surface_uvs.size() == 0:
		MeshUtility.generate_planar_uvs(model_data)
	
	return model_data

#================#
# Export File    #
#================#
func export_model(model_data: ModelData, file_path: String, options: Dictionary = {}) -> Dictionary:
	var result = {
		"success": false,
		"error": "",
		"warnings": []
	}
	
	var export_options = get_default_export_options()
	for key in options:
		export_options[key] = options[key]
	
	var part_idx = model_data.get_active_part_index()
	
	if model_data.meshes[part_idx].get_surface_count() == 0:
		result.error = "No surfaces to export"
		return result
	
	var surface_arrays = model_data.meshes[part_idx].surface_get_arrays(0)
	var vertices = surface_arrays[Mesh.ARRAY_VERTEX]
	var indices = surface_arrays[Mesh.ARRAY_INDEX]
	var normals = surface_arrays[Mesh.ARRAY_NORMAL] if surface_arrays.size() > Mesh.ARRAY_NORMAL else PackedVector3Array()
	var uvs = surface_arrays[Mesh.ARRAY_TEX_UV] if surface_arrays.size() > Mesh.ARRAY_TEX_UV else PackedVector2Array()
	
	var output_lines = []
	output_lines.append("# OBJ file exported from Mesh Framework")
	output_lines.append("# " + Time.get_datetime_string_from_system())
	
	var vertex_lines = []
	for v in vertices:
		vertex_lines.append("v " + str(v.x) + " " + str(v.y) + " " + str(v.z))
	output_lines.append("\n".join(vertex_lines))
	
	if export_options.get("include_uvs", true) and uvs.size() > 0:
		var uv_lines = []
		for uv in uvs:
			uv_lines.append("vt " + str(uv.x) + " " + str(1.0 - uv.y))
		output_lines.append("\n".join(uv_lines))
	
	if export_options.get("include_normals", true) and normals.size() > 0:
		var normal_lines = []
		for n in normals:
			normal_lines.append("vn " + str(n.x) + " " + str(n.y) + " " + str(n.z))
		output_lines.append("\n".join(normal_lines))
	
	if export_options.get("include_materials", true) and model_data.materials.size() > 0:
		var mtl_filename = file_path.get_file().get_basename() + ".mtl"
		output_lines.append("mtllib " + mtl_filename)
		
		_export_materials(model_data.materials, file_path.get_base_dir() + "/" + mtl_filename)

	var has_uvs = uvs.size() > 0
	var has_normals = normals.size() > 0
	var has_both = has_uvs and has_normals
	
	if model_data.has_part_metadata(part_idx, "original_faces"):
		var original_faces = model_data.get_part_metadata(part_idx, "original_faces")
		var face_lines = []
		var current_material = "default"
		var material_index = -1
		var materials = model_data.materials
		var material_indices = model_data.part_material_indices[part_idx]
		
		for face_idx in range(original_faces.size()):
			var face = original_faces[face_idx]
			
			if material_indices.size() > face_idx:
				var face_material_idx = material_indices[face_idx]
				if face_material_idx != material_index and face_material_idx < materials.size():
					material_index = face_material_idx
					var material = materials[material_index]
					current_material = material.resource_name if material.resource_name else "material_" + str(material_index)
					face_lines.append("usemtl " + current_material)
			
			var face_parts = []
			face_parts.append("f")
			
			for idx in face:
				var obj_idx = str(int(idx) + 1)
				
				if has_both:
					face_parts.append(obj_idx + "/" + obj_idx + "/" + obj_idx)
				elif has_uvs:
					face_parts.append(obj_idx + "/" + obj_idx)
				elif has_normals:
					face_parts.append(obj_idx + "//" + obj_idx)
				else:
					face_parts.append(obj_idx)
			
			face_lines.append(" ".join(face_parts))
		
		output_lines.append("\n".join(face_lines))
	
	else:
		var face_lines = []
		var current_material = "default"
		var material_index = -1
		
		for i in range(0, indices.size(), 3):
			var face_idx = i / 3
			if model_data.part_material_indices[part_idx].size() > face_idx:
				var face_material_idx = model_data.part_material_indices[part_idx][face_idx]
				if face_material_idx != material_index and face_material_idx < model_data.materials.size():
					material_index = face_material_idx
					var material = model_data.materials[material_index]
					current_material = material.resource_name if material.resource_name else "material_" + str(material_index)
					face_lines.append("usemtl " + current_material)
			
			if i + 2 < indices.size():
				var idx1 = indices[i]
				var idx2 = indices[i+1]
				var idx3 = indices[i+2]
				
				var face_parts = []
				face_parts.append("f")
				
				for idx in [idx1, idx2, idx3]:
					var obj_idx = str(idx + 1)
					
					if has_both:
						face_parts.append(obj_idx + "/" + obj_idx + "/" + obj_idx)
					elif has_uvs:
						face_parts.append(obj_idx + "/" + obj_idx)
					elif has_normals:
						face_parts.append(obj_idx + "//" + obj_idx)
					else:
						face_parts.append(obj_idx)
				
				face_lines.append(" ".join(face_parts))
		
		output_lines.append("\n".join(face_lines))
	
	var final_content = "\n".join(output_lines) + "\n"
	
	var output_file = FileAccess.open(file_path, FileAccess.WRITE)
	if output_file == null:
		result.error = "Failed to create output file - " + str(FileAccess.get_open_error())
		return result
	
	output_file.store_string(final_content)
	output_file.close()
	
	result.success = true
	return result

func _export_materials(materials: Array, output_path: String) -> bool:
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		push_warning("OBJFormat: Failed to create material file: " + output_path)
		return false
	
	file.store_line("# Material file exported from Mesh Framework")
	file.store_line("# " + Time.get_datetime_string_from_system())
	
	for i in range(materials.size()):
		var material = materials[i]
		var material_name = material.resource_name if material.resource_name else "material_" + str(i)
		
		file.store_line("newmtl " + material_name)
		
		if material is StandardMaterial3D:
			var albedo_color = material.albedo_color
			file.store_line("Kd " + str(albedo_color.r) + " " + str(albedo_color.g) + " " + str(albedo_color.b))
			file.store_line("d " + str(albedo_color.a))
			
			var roughness = material.roughness
			file.store_line("Ns " + str((1.0 - roughness) * 100.0))
			
			var metallic = material.metallic
			var spec_value = metallic * 0.8 + 0.2
			file.store_line("Ks " + str(spec_value) + " " + str(spec_value) + " " + str(spec_value))
			
			if material.albedo_texture:
				var texture_path = material.albedo_texture.resource_path
				if texture_path.is_empty():
					texture_path = output_path.get_base_dir() + "/" + material_name + ".png"
				
				file.store_line("map_Kd " + texture_path.get_file())
		else:
			file.store_line("Kd 0.8 0.8 0.8")
			file.store_line("Ks 0.2 0.2 0.2")
			file.store_line("Ns 10.0")
		
		file.store_line("")
	
	file.close()
	return true

func create_wireframe_mesh(model_data: ModelData) -> MeshInstance3D:
	print("Create Wireframe Mesh OBJ called")
	
	var file_path = model_data.get_metadata("source_path") if model_data.has_metadata("source_path") else ""
	
	print("Source path found: " + (file_path if not file_path.is_empty() else "EMPTY"))
	
	if file_path.is_empty() or !FileAccess.file_exists(file_path):
		print("Falling back to default wireframe implementation")
		return super.create_wireframe_mesh(model_data)
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return super.create_wireframe_mesh(model_data)
	
	var vertices = []
	var faces = []
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		if line.begins_with("v "):
			var parts = line.split(" ", false)
			if parts.size() >= 4:
				vertices.append(Vector3(
					float(parts[1]),
					float(parts[2]),
					float(parts[3])
				))
		elif line.begins_with("f "):
			var parts = line.split(" ", false)
			var face = []
			for i in range(1, parts.size()):
				var vert_parts = parts[i].split("/")
				face.append(int(vert_parts[0]) - 1)
			faces.append(face)
	
	file.close()
	
	var imm = ImmediateMesh.new()
	var wireframe_mesh = MeshInstance3D.new()
	wireframe_mesh.mesh = imm
	
	var line_material = StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color(0, 0.8, 1.0)
	line_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var added_edges = {}
	
	for face in faces:
		var face_size = face.size()
		
		for i in range(face_size):
			var v1_idx = face[i]
			var v2_idx = face[(i + 1) % face_size]
			
			var edge_key = min(v1_idx, v2_idx) * 1000000 + max(v1_idx, v2_idx)
			
			if not edge_key in added_edges:
				added_edges[edge_key] = true
				
				if v1_idx < vertices.size() and v2_idx < vertices.size():
					imm.surface_add_vertex(vertices[v1_idx])
					imm.surface_add_vertex(vertices[v2_idx])
	
	imm.surface_end()
	wireframe_mesh.material_override = line_material
	
	return wireframe_mesh

static func get_default_import_options() -> Dictionary:
	return {
		"calculate_normals": true,
		"generate_uvs": true,
		"load_materials": true
	}

static func get_default_export_options() -> Dictionary:
	return {
		"include_materials": true,
		"include_normals": true,
		"include_uvs": true
	}
