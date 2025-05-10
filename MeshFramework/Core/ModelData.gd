class_name ModelData
extends Resource

signal data_changed()

var meshes: Array[ArrayMesh] = []
var part_names: Array[String] = []
var part_materials: Array[Array] = []
var part_material_indices: Array[PackedInt32Array] = []
var part_original_vertices: Array[PackedVector3Array] = []
var part_original_indices: Array[PackedInt32Array] = []
var part_topology: Array[Dictionary] = []
var part_metadata: Array[Dictionary] = []

# GLOBAL DATA
var materials: Array[Material] = []
var metadata: Dictionary = {}
var source_format: String = ""
var format_version: String = ""
var active_mesh_index: int = -1

# Init #
func _init():
	_add_default_mesh_part()

func _add_default_mesh_part() -> void:
	var new_mesh = ArrayMesh.new()
	meshes.append(new_mesh)
	part_names.append("Part_0")
	part_materials.append([])
	part_material_indices.append(PackedInt32Array())
	part_original_vertices.append(PackedVector3Array())
	part_original_indices.append(PackedInt32Array())
	
	var topology = {
		"is_quad_mesh": false,
		"quads": []
	}
	part_topology.append(topology)
	part_metadata.append({})
	
	active_mesh_index = 0

# Mesh Management #

func has_part_metadata(part_index: int, key: String) -> bool:
	if part_index >= 0 and part_index < part_metadata.size():
		if part_metadata[part_index].has(key):
			return true
	return false

func get_active_mesh() -> ArrayMesh:
	var idx = get_active_part_index()
	return meshes[idx]

func add_mesh_part(name: String = "") -> int:
	var mesh_index = meshes.size()
	var part_name = name if not name.is_empty() else "Part_" + str(mesh_index)
	
	var new_mesh = ArrayMesh.new()
	meshes.append(new_mesh)
	part_names.append(part_name)
	part_materials.append([])
	part_material_indices.append(PackedInt32Array())
	part_original_vertices.append(PackedVector3Array())
	part_original_indices.append(PackedInt32Array())
	
	var topology = {
		"is_quad_mesh": false,
		"quads": []
	}
	part_topology.append(topology)
	part_metadata.append({})
	
	active_mesh_index = mesh_index
	emit_signal("data_changed")
	return mesh_index

func set_active_mesh_part(index: int) -> bool:
	if index >= 0 and index < meshes.size():
		active_mesh_index = index
		return true
	return false

func remove_mesh_part(index: int) -> bool:
	if index >= 0 and index < meshes.size():
		meshes.remove_at(index)
		part_names.remove_at(index)
		part_materials.remove_at(index)
		part_material_indices.remove_at(index)
		part_original_vertices.remove_at(index)
		part_original_indices.remove_at(index)
		part_topology.remove_at(index)
		part_metadata.remove_at(index)
		
		if active_mesh_index >= meshes.size():
			active_mesh_index = max(0, meshes.size() - 1)
		
		emit_signal("data_changed")
		return true
	return false

func get_mesh_part_count() -> int:
	return meshes.size()

func get_active_part_index() -> int:
	if active_mesh_index < 0 or active_mesh_index >= meshes.size():
		if meshes.size() > 0:
			active_mesh_index = 0
		else:
			_add_default_mesh_part()
	
	return active_mesh_index

# Surface Operations #
func add_surface_from_arrays(primitive_type: int, arrays: Array, material: Material = null) -> int:
	var part_index = get_active_part_index()
	
	var surface_idx = meshes[part_index].get_surface_count()
	meshes[part_index].add_surface_from_arrays(primitive_type, arrays)
	
	if material:
		meshes[part_index].surface_set_material(surface_idx, material)
		part_materials[part_index].append(material)
	
	if surface_idx == 0 && arrays[Mesh.ARRAY_INDEX].size() > 0:
		var face_count = arrays[Mesh.ARRAY_INDEX].size() / 3
		
		var mat_indices = part_material_indices[part_index]
		if mat_indices.size() < face_count:
			mat_indices.resize(face_count)
			for i in range(mat_indices.size()):
				mat_indices[i] = 0 
			
			part_material_indices[part_index] = mat_indices
	
	emit_signal("data_changed")
	return surface_idx

func get_surface_arrays(part_index: int, surface_idx: int = 0) -> Array:
	if part_index < 0 or part_index >= meshes.size():
		push_error("ModelData: Invalid part index: " + str(part_index))
		return []
	
	if surface_idx >= meshes[part_index].get_surface_count():
		push_error("ModelData: Invalid surface index: " + str(surface_idx))
		return []
	
	return meshes[part_index].surface_get_arrays(surface_idx)

func get_active_surface_arrays(surface_idx: int = 0) -> Array:
	return get_surface_arrays(get_active_part_index(), surface_idx)

# Instance Creation #
func create_mesh_instance_for_part(part_index: int) -> MeshInstance3D:
	if part_index < 0 or part_index >= meshes.size():
		push_error("ModelData: Invalid part index: " + str(part_index))
		return null
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = meshes[part_index]
	
	# Set material overrides
	for i in range(min(part_materials[part_index].size(), mesh_instance.mesh.get_surface_count())):
		if part_materials[part_index][i]:
			mesh_instance.set_surface_override_material(i, part_materials[part_index][i])
	
	return mesh_instance

func create_mesh_instance() -> Node3D:
	if meshes.size() == 1:
		# Single mesh, return directly
		return create_mesh_instance_for_part(0)
	else:
		var root = Node3D.new()
		root.name = "Model"
		
		for i in range(meshes.size()):
			var mesh_instance = create_mesh_instance_for_part(i)
			if mesh_instance:
				mesh_instance.name = part_names[i]
				root.add_child(mesh_instance)
		
		return root

# Metadata #
func set_metadata(key: String, value) -> void:
	metadata[key] = value
	emit_signal("data_changed")

func get_metadata(key: String, default_value = null):
	if metadata.has(key):
		return metadata[key]
	return default_value

func has_metadata(key: String) -> bool:
	return metadata.has(key)

func remove_metadata(key: String) -> bool:
	if metadata.has(key):
		metadata.erase(key)
		emit_signal("data_changed")
		return true
	return false

func set_part_metadata(part_index: int, key: String, value) -> bool:
	if part_index >= 0 and part_index < part_metadata.size():
		part_metadata[part_index][key] = value
		emit_signal("data_changed")
		return true
	return false

func get_part_metadata(part_index: int, key: String, default_value = null):
	if part_index >= 0 and part_index < part_metadata.size():
		if part_metadata[part_index].has(key):
			return part_metadata[part_index][key]
	return default_value

func get_part_topology(part_index: int) -> Dictionary:
	if part_index >= 0 and part_index < part_topology.size():
		return part_topology[part_index]
	return {}

# Topology #
func set_part_topology(part_index: int, topology: Dictionary) -> bool:
	if part_index >= 0 and part_index < part_topology.size():
		part_topology[part_index] = topology
		emit_signal("data_changed")
		return true
	return false

func get_active_topology() -> Dictionary:
	return get_part_topology(get_active_part_index())

func set_active_topology(topology: Dictionary) -> bool:
	return set_part_topology(get_active_part_index(), topology)

# Material Indices #
func get_part_material_indices(part_index: int) -> PackedInt32Array:
	if part_index >= 0 and part_index < part_material_indices.size():
		return part_material_indices[part_index]
	return PackedInt32Array()

func set_part_material_indices(part_index: int, indices: PackedInt32Array) -> bool:
	if part_index >= 0 and part_index < part_material_indices.size():
		part_material_indices[part_index] = indices
		emit_signal("data_changed")
		return true
	return false

func get_material_indices() -> PackedInt32Array:
	return get_part_material_indices(get_active_part_index())

func set_material_indices(indices: PackedInt32Array) -> void:
	set_part_material_indices(get_active_part_index(), indices)

# Statistics and Metrics #
func get_vertex_count() -> int:
	var count = 0
	for i in range(meshes.size()):
		count += get_part_vertex_count(i)
	return count

func get_part_vertex_count(part_index: int) -> int:
	if part_index < 0 or part_index >= meshes.size():
		return 0
		
	var count = 0
	for i in range(meshes[part_index].get_surface_count()):
		var arrays = meshes[part_index].surface_get_arrays(i)
		count += arrays[Mesh.ARRAY_VERTEX].size()
	return count

func get_face_count() -> int:
	var count = 0
	for i in range(meshes.size()):
		count += get_part_face_count(i)
	return count

func get_part_face_count(part_index: int) -> int:
	if part_index < 0 or part_index >= meshes.size():
		return 0
		
	var count = 0
	for i in range(meshes[part_index].get_surface_count()):
		var arrays = meshes[part_index].surface_get_arrays(i)
		var indices = arrays[Mesh.ARRAY_INDEX]
		
		if indices and indices.size() > 0:
			count += indices.size() / 3
		else:
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			if vertices:
				count += vertices.size() / 3
	return count

func get_material_count() -> int:
	return materials.size()

# Legacy - Used by OBJ Format
var mesh: ArrayMesh:
	get:
		if meshes.size() > 0:
			return meshes[get_active_part_index()]
		else:
			var new_mesh = ArrayMesh.new()
			meshes.append(new_mesh)
			part_names.append("Part_0")
			part_materials.append([])
			part_material_indices.append(PackedInt32Array())
			part_original_vertices.append(PackedVector3Array())
			part_original_indices.append(PackedInt32Array())
			part_topology.append({
				"is_quad_mesh": false,
				"quads": []
			})
			part_metadata.append({})
			active_mesh_index = 0
			return new_mesh
	set(value):
		if meshes.size() == 0:
			meshes.append(value)
			part_names.append("Part_0")
			part_materials.append([])
			part_material_indices.append(PackedInt32Array())
			part_original_vertices.append(PackedVector3Array())
			part_original_indices.append(PackedInt32Array())
			part_topology.append({
				"is_quad_mesh": false,
				"quads": []
			})
			part_metadata.append({})
			active_mesh_index = 0
		else:
			meshes[get_active_part_index()] = value

# Legacy - Used by OBJ Format
var topology: Dictionary:
	get:
		var idx = get_active_part_index()
		if idx >= 0 and idx < part_topology.size():
			return part_topology[idx]
		return {}
	set(value):
		var idx = get_active_part_index()
		if idx >= 0 and idx < part_topology.size():
			part_topology[idx] = value
			emit_signal("data_changed")

# Legacy - Used by OBJ Format
var vertices: PackedVector3Array:
	get:
		var idx = get_active_part_index()
		if idx >= 0 and idx < meshes.size() and meshes[idx].get_surface_count() > 0:
			var arrays = meshes[idx].surface_get_arrays(0)
			if arrays.size() > Mesh.ARRAY_VERTEX:
				return arrays[Mesh.ARRAY_VERTEX]
		return PackedVector3Array()
	set(value):
		var idx = get_active_part_index()
		if idx < 0 or idx >= meshes.size():
			push_error("ModelData: Invalid active mesh index for vertices setter: " + str(idx))
			return
			
		var arrays = []
		if meshes[idx].get_surface_count() > 0:
			arrays = meshes[idx].surface_get_arrays(0)
		else:
			arrays.resize(Mesh.ARRAY_MAX)
			
		arrays[Mesh.ARRAY_VERTEX] = value
		
		if meshes[idx].get_surface_count() > 0:
			meshes[idx].surface_remove(0)
		
		if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0:
			meshes[idx].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			emit_signal("data_changed")

# Legacy - Used by OBJ Format
var indices: PackedInt32Array:
	get:
		var idx = get_active_part_index()
		if idx >= 0 and idx < meshes.size() and meshes[idx].get_surface_count() > 0:
			var arrays = meshes[idx].surface_get_arrays(0)
			if arrays.size() > Mesh.ARRAY_INDEX:
				return arrays[Mesh.ARRAY_INDEX]
		return PackedInt32Array()
	set(value):
		var idx = get_active_part_index()
		if idx < 0 or idx >= meshes.size():
			push_error("ModelData: Invalid active mesh index for indices setter: " + str(idx))
			return
			
		var arrays = []
		if meshes[idx].get_surface_count() > 0:
			arrays = meshes[idx].surface_get_arrays(0)
		else:
			arrays.resize(Mesh.ARRAY_MAX)
			
		arrays[Mesh.ARRAY_INDEX] = value
		
		if meshes[idx].get_surface_count() > 0:
			meshes[idx].surface_remove(0)
		
		if arrays[Mesh.ARRAY_VERTEX] != null and arrays[Mesh.ARRAY_VERTEX].size() > 0:
			meshes[idx].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			emit_signal("data_changed")

# Legacy - Used by OBJ Format
var normals: PackedVector3Array:
	get:
		var idx = get_active_part_index()
		if idx >= 0 and idx < meshes.size() and meshes[idx].get_surface_count() > 0:
			var arrays = meshes[idx].surface_get_arrays(0)
			if arrays.size() > Mesh.ARRAY_NORMAL:
				return arrays[Mesh.ARRAY_NORMAL]
		return PackedVector3Array()
	set(value):
		var idx = get_active_part_index()
		if idx < 0 or idx >= meshes.size():
			push_error("ModelData: Invalid active mesh index for normals setter: " + str(idx))
			return
			
		var arrays = []
		if meshes[idx].get_surface_count() > 0:
			arrays = meshes[idx].surface_get_arrays(0)
		else:
			arrays.resize(Mesh.ARRAY_MAX)
			
		arrays[Mesh.ARRAY_NORMAL] = value
		
		if meshes[idx].get_surface_count() > 0:
			meshes[idx].surface_remove(0)
		
		if arrays[Mesh.ARRAY_VERTEX] != null and arrays[Mesh.ARRAY_VERTEX].size() > 0:
			meshes[idx].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			emit_signal("data_changed")

# Legacy - Used by OBJ Format
var uvs: PackedVector2Array:
	get:
		var idx = get_active_part_index()
		if idx >= 0 and idx < meshes.size() and meshes[idx].get_surface_count() > 0:
			var arrays = meshes[idx].surface_get_arrays(0)
			if arrays.size() > Mesh.ARRAY_TEX_UV:
				return arrays[Mesh.ARRAY_TEX_UV]
		return PackedVector2Array()
	set(value):
		var idx = get_active_part_index()
		if idx < 0 or idx >= meshes.size():
			push_error("ModelData: Invalid active mesh index for UVs setter: " + str(idx))
			return
			
		var arrays = []
		if meshes[idx].get_surface_count() > 0:
			arrays = meshes[idx].surface_get_arrays(0)
		else:
			arrays.resize(Mesh.ARRAY_MAX)
			
		arrays[Mesh.ARRAY_TEX_UV] = value
		
		if meshes[idx].get_surface_count() > 0:
			meshes[idx].surface_remove(0)
		
		if arrays[Mesh.ARRAY_VERTEX] != null and arrays[Mesh.ARRAY_VERTEX].size() > 0:
			meshes[idx].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			emit_signal("data_changed")

# Legacy - Used by OBJ Format
var colors: PackedColorArray:
	get:
		var idx = get_active_part_index()
		if idx >= 0 and idx < meshes.size() and meshes[idx].get_surface_count() > 0:
			var arrays = meshes[idx].surface_get_arrays(0)
			if arrays.size() > Mesh.ARRAY_COLOR:
				return arrays[Mesh.ARRAY_COLOR]
		return PackedColorArray()
	set(value):
		var idx = get_active_part_index()
		if idx < 0 or idx >= meshes.size():
			push_error("ModelData: Invalid active mesh index for colors setter: " + str(idx))
			return
			
		var arrays = []
		if meshes[idx].get_surface_count() > 0:
			arrays = meshes[idx].surface_get_arrays(0)
		else:
			arrays.resize(Mesh.ARRAY_MAX)
			
		arrays[Mesh.ARRAY_COLOR] = value
		
		if meshes[idx].get_surface_count() > 0:
			meshes[idx].surface_remove(0)
		
		if arrays[Mesh.ARRAY_VERTEX] != null and arrays[Mesh.ARRAY_VERTEX].size() > 0:
			meshes[idx].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			emit_signal("data_changed")

func transform(transform_matrix: Transform3D) -> void:
	for i in range(meshes.size()):
		if meshes[i].get_surface_count() > 0:
			var arrays = meshes[i].surface_get_arrays(0)
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			var normals = arrays[Mesh.ARRAY_NORMAL] if arrays.size() > Mesh.ARRAY_NORMAL else null
			
			var new_vertices = PackedVector3Array()
			new_vertices.resize(vertices.size())
			for v in range(vertices.size()):
				new_vertices[v] = transform_matrix * vertices[v]
			
			var new_normals = null
			if normals and normals.size() > 0:
				new_normals = PackedVector3Array()
				new_normals.resize(normals.size())
				for n in range(normals.size()):
					new_normals[n] = transform_matrix.basis * normals[n]
			
			arrays[Mesh.ARRAY_VERTEX] = new_vertices
			if new_normals:
				arrays[Mesh.ARRAY_NORMAL] = new_normals
			
			meshes[i].clear_surfaces()
			meshes[i].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	emit_signal("data_changed")
