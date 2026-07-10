class_name MeshUtility
extends RefCounted

static func calculate_normals(model_data: ModelData) -> void:
	var part_idx = model_data.get_active_part_index()
	
	if model_data.meshes[part_idx].get_surface_count() == 0:
		return
		
	var surface_arrays = model_data.meshes[part_idx].surface_get_arrays(0)
	if surface_arrays.size() <= Mesh.ARRAY_VERTEX:
		return
		
	var vertices = surface_arrays[Mesh.ARRAY_VERTEX]
	var indices = surface_arrays[Mesh.ARRAY_INDEX]
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO
	
	var contribution_counts = []
	contribution_counts.resize(vertices.size())
	for i in range(contribution_counts.size()):
		contribution_counts[i] = 0
	
	var face_count = indices.size() / 3
	for face_idx in range(face_count):
		var base_idx = face_idx * 3
		
		if base_idx + 2 >= indices.size():
			continue
			
		var idx1 = indices[base_idx]
		var idx2 = indices[base_idx + 1]
		var idx3 = indices[base_idx + 2]
		
		if idx1 < 0 or idx1 >= vertices.size() or \
		   idx2 < 0 or idx2 >= vertices.size() or \
		   idx3 < 0 or idx3 >= vertices.size():
			continue
		
		var v1 = vertices[idx1]
		var v2 = vertices[idx2]
		var v3 = vertices[idx3]
		
		var edge1 = v2 - v1
		var edge2 = v3 - v1
		
		if edge1.length_squared() < 0.0001 or edge2.length_squared() < 0.0001:
			continue
			
		var face_normal = edge1.cross(edge2)
		
		if face_normal.length_squared() < 0.0001:
			continue
			
		face_normal = face_normal.normalized()
		
		var face_area = face_normal.length() * 0.5
		face_normal = face_normal.normalized()
		
		normals[idx1] += face_normal * face_area
		normals[idx2] += face_normal * face_area
		normals[idx3] += face_normal * face_area
		
		contribution_counts[idx1] += 1
		contribution_counts[idx2] += 1
		contribution_counts[idx3] += 1
	
	for i in range(normals.size()):
		if contribution_counts[i] > 0:
			normals[i] = normals[i] / contribution_counts[i]
			
		if normals[i].length_squared() > 0.0001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP

	surface_arrays[Mesh.ARRAY_NORMAL] = normals
	
	model_data.meshes[part_idx].clear_surfaces()
	model_data.meshes[part_idx].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)

static func generate_planar_uvs(model_data: ModelData, axis: Vector3 = Vector3.UP) -> void:
	var part_idx = model_data.get_active_part_index()
	
	if model_data.meshes[part_idx].get_surface_count() == 0:
		return
		
	var surface_arrays = model_data.meshes[part_idx].surface_get_arrays(0)
	if surface_arrays.size() <= Mesh.ARRAY_VERTEX:
		return
		
	var vertices = surface_arrays[Mesh.ARRAY_VERTEX]
	
	var min_pos = Vector3(INF, INF, INF)
	var max_pos = Vector3(-INF, -INF, -INF)
	
	for v in vertices:
		min_pos.x = min(min_pos.x, v.x)
		min_pos.y = min(min_pos.y, v.y)
		min_pos.z = min(min_pos.z, v.z)
		max_pos.x = max(max_pos.x, v.x)
		max_pos.y = max(max_pos.y, v.y)
		max_pos.z = max(max_pos.z, v.z)
	
	var uvs = PackedVector2Array()
	uvs.resize(vertices.size())
	
	for i in range(vertices.size()):
		var v = vertices[i]
		var uv = Vector2()
		
		if abs(axis.dot(Vector3.UP)) > 0.99:
			var size_x = max_pos.x - min_pos.x
			var size_z = max_pos.z - min_pos.z
			if size_x < 0.0001: size_x = 1.0
			if size_z < 0.0001: size_z = 1.0
			uv.x = (v.x - min_pos.x) / size_x
			uv.y = (v.z - min_pos.z) / size_z
		elif abs(axis.dot(Vector3.RIGHT)) > 0.99:
			var size_y = max_pos.y - min_pos.y
			var size_z = max_pos.z - min_pos.z
			if size_y < 0.0001: size_y = 1.0
			if size_z < 0.0001: size_z = 1.0
			uv.x = (v.y - min_pos.y) / size_y
			uv.y = (v.z - min_pos.z) / size_z
		else:
			var size_x = max_pos.x - min_pos.x
			var size_y = max_pos.y - min_pos.y
			if size_x < 0.0001: size_x = 1.0
			if size_y < 0.0001: size_y = 1.0
			uv.x = (v.x - min_pos.x) / size_x
			uv.y = (v.y - min_pos.y) / size_y
		
		uvs[i] = uv
	
	surface_arrays[Mesh.ARRAY_TEX_UV] = uvs
	
	model_data.meshes[part_idx].clear_surfaces()
	model_data.meshes[part_idx].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)

static func triangulate_quads(model_data: ModelData) -> void:
	var part_idx = model_data.get_active_part_index()
	
	var topology = model_data.part_topology[part_idx]
	if not topology.has("is_quad_mesh"):
		return
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var arrays = model_data.meshes[part_idx].surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL] if arrays.size() > Mesh.ARRAY_NORMAL else []
	var uvs = arrays[Mesh.ARRAY_TEX_UV] if arrays.size() > Mesh.ARRAY_TEX_UV else []
	
	var quads = topology.quads
	for quad in quads:
		for tri_idx in [[0,1,2], [0,2,3]]:
			for idx in tri_idx:
				var vtx_idx = quad[idx]
				
				if normals.size() > vtx_idx: 
					st.set_normal(normals[vtx_idx])
				if uvs.size() > vtx_idx: 
					st.set_uv(uvs[vtx_idx])
				
				st.add_vertex(vertices[vtx_idx])
	st.index()
	model_data.meshes[part_idx].clear_surfaces()
	st.commit(model_data.meshes[part_idx])
	
	model_data.part_topology[part_idx]["is_quad_mesh"] = false

static func calculate_bounds(model_data: ModelData) -> AABB:
	var part_idx = model_data.get_active_part_index()
	
	if model_data.meshes[part_idx].get_surface_count() == 0:
		return AABB()
		
	var surface_arrays = model_data.meshes[part_idx].surface_get_arrays(0)
	if surface_arrays.size() <= Mesh.ARRAY_VERTEX:
		return AABB()
	
	var vertices = surface_arrays[Mesh.ARRAY_VERTEX]
	
	var aabb = AABB()
	
	if vertices.size() > 0:
		aabb.position = vertices[0]
		for i in range(1, vertices.size()):
			aabb = aabb.expand(vertices[i])
	
	return aabb

# Remove duplicate vertices // No longer used
static func optimize_mesh(model_data: ModelData, epsilon: float = 0.0001) -> void:
	var part_idx = model_data.get_active_part_index()
	
	if model_data.meshes[part_idx].get_surface_count() == 0:
		return
		
	var surface_arrays = model_data.meshes[part_idx].surface_get_arrays(0)
	if surface_arrays.size() <= Mesh.ARRAY_VERTEX:
		return
		
	var vertices = surface_arrays[Mesh.ARRAY_VERTEX]
	var indices = surface_arrays[Mesh.ARRAY_INDEX]
	
	var unique_vertices = []
	var vertex_map = {}
	var new_indices = PackedInt32Array()
	
	for i in range(indices.size()):
		var old_idx = indices[i]
		var vertex = vertices[old_idx]
		var normal = Vector3.ZERO
		if surface_arrays.size() > Mesh.ARRAY_NORMAL and surface_arrays[Mesh.ARRAY_NORMAL].size() > old_idx:
			normal = surface_arrays[Mesh.ARRAY_NORMAL][old_idx]
			
		var uv = Vector2.ZERO
		if surface_arrays.size() > Mesh.ARRAY_TEX_UV and surface_arrays[Mesh.ARRAY_TEX_UV].size() > old_idx:
			uv = surface_arrays[Mesh.ARRAY_TEX_UV][old_idx]
		
		# Create a key from vertex position, normal, and uv
		var key = "%d,%d,%d,%d,%d,%d,%d,%d" % [
			int(vertex.x / epsilon),
			int(vertex.y / epsilon),
			int(vertex.z / epsilon),
			int(normal.x / epsilon) if normal != Vector3.ZERO else 0,
			int(normal.y / epsilon) if normal != Vector3.ZERO else 0,
			int(normal.z / epsilon) if normal != Vector3.ZERO else 0,
			int(uv.x / epsilon) if uv != Vector2.ZERO else 0,
			int(uv.y / epsilon) if uv != Vector2.ZERO else 0
		]
		
		if not vertex_map.has(key):
			var new_idx = unique_vertices.size()
			vertex_map[key] = new_idx
			unique_vertices.append({
				"position": vertex,
				"normal": normal,
				"uv": uv,
				"old_idx": old_idx
			})
		
		new_indices.append(vertex_map[key])
	
	# Create new arrays
	var new_vertices = PackedVector3Array()
	var new_normals = PackedVector3Array()
	var new_uvs = PackedVector2Array()
	
	for v in unique_vertices:
		new_vertices.append(v.position)
		if surface_arrays.size() > Mesh.ARRAY_NORMAL:
			new_normals.append(v.normal)
		if surface_arrays.size() > Mesh.ARRAY_TEX_UV:
			new_uvs.append(v.uv)
	
	# Update surface arrays
	surface_arrays[Mesh.ARRAY_VERTEX] = new_vertices
	surface_arrays[Mesh.ARRAY_INDEX] = new_indices
	
	if surface_arrays.size() > Mesh.ARRAY_NORMAL:
		surface_arrays[Mesh.ARRAY_NORMAL] = new_normals
	
	if surface_arrays.size() > Mesh.ARRAY_TEX_UV:
		surface_arrays[Mesh.ARRAY_TEX_UV] = new_uvs
	
	# Update mesh
	model_data.meshes[part_idx].clear_surfaces()
	model_data.meshes[part_idx].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)


#====================#
# Validation         #
#====================#
static func validate_model(model_data: ModelData) -> Dictionary:
	var result = {
		"valid": true,
		"errors": [],
		"warnings": []
	}
	
	var part_idx = model_data.get_active_part_index()
	if model_data.meshes[part_idx].get_surface_count() == 0:
		result.errors.append("No surfaces in mesh")
		result.valid = false
		return result

	var surface_arrays = model_data.meshes[part_idx].surface_get_arrays(0)
		
	if surface_arrays.size() <= Mesh.ARRAY_VERTEX:
		result.errors.append("Surface has no vertex data")
		result.valid = false
		return result
		
	var vertices = surface_arrays[Mesh.ARRAY_VERTEX]
	var indices = surface_arrays[Mesh.ARRAY_INDEX]
	
	# Check for basic geometry
	if vertices.size() == 0:
		result.errors.append("No vertices in model")
		result.valid = false
	
	if indices.size() == 0:
		result.errors.append("No indices in model")
		result.valid = false
	
	# Check for invalid indices
	for i in range(indices.size()):
		if indices[i] < 0 or indices[i] >= vertices.size():
			result.errors.append("Invalid index at position %d: %d" % [i, indices[i]])
			result.valid = false
	
	# Check for normals
	if surface_arrays.size() > Mesh.ARRAY_NORMAL and surface_arrays[Mesh.ARRAY_NORMAL].size() > 0:
		var normals = surface_arrays[Mesh.ARRAY_NORMAL]
		if normals.size() != vertices.size():
			result.warnings.append("Normal count (%d) does not match vertex count (%d)" % 
								 [normals.size(), vertices.size()])
	
	# Check for UVs
	if surface_arrays.size() > Mesh.ARRAY_TEX_UV and surface_arrays[Mesh.ARRAY_TEX_UV].size() > 0:
		var uvs = surface_arrays[Mesh.ARRAY_TEX_UV]
		if uvs.size() != vertices.size():
			result.warnings.append("UV count (%d) does not match vertex count (%d)" % 
								 [uvs.size(), vertices.size()])
	
	return result

static func validate_vertex_indices(model_data: ModelData) -> bool:
	var part_idx = model_data.get_active_part_index()
	
	if model_data.meshes[part_idx].get_surface_count() == 0:
		return false
		
	var surface_arrays = model_data.meshes[part_idx].surface_get_arrays(0)
	if surface_arrays.size() <= Mesh.ARRAY_VERTEX or surface_arrays.size() <= Mesh.ARRAY_INDEX:
		return false
		
	var vertices = surface_arrays[Mesh.ARRAY_VERTEX]
	var indices = surface_arrays[Mesh.ARRAY_INDEX]
	
	var max_index = -1
	
	for i in range(indices.size()):
		max_index = max(max_index, indices[i])
	
	if max_index >= vertices.size():
		push_error("Vertex index out of bounds: max index ", max_index, 
				   " >= vertex count ", vertices.size())
		return false
	
	return true
	
static func calculate_corner_normals(
	positions: PackedVector3Array,
	faces: Array,
	angle_degrees: float
) -> Array:
	var threshold := cos(deg_to_rad(clampf(angle_degrees, 0.0, 180.0))) - 1e-6

	var face_normals: Array[Vector3] = []
	for face in faces:
		var n := Vector3.ZERO
		var count = face.size()
		for i in count:
			var cur: Vector3 = positions[face[i]]
			var nxt: Vector3 = positions[face[(i + 1) % count]]
			n.x += (cur.y - nxt.y) * (cur.z + nxt.z)
			n.y += (cur.z - nxt.z) * (cur.x + nxt.x)
			n.z += (cur.x - nxt.x) * (cur.y + nxt.y)
		face_normals.append(n.normalized() if n.length_squared() > 1e-12 else Vector3.UP)

	var vertex_faces := {}
	for f in faces.size():
		for v in faces[f]:
			if not vertex_faces.has(v):
				vertex_faces[v] = []
			vertex_faces[v].append(f)

	var corner_normals := []
	for f in faces.size():
		var this_n: Vector3 = face_normals[f]
		var row: Array[Vector3] = []
		for v in faces[f]:
			var acc := Vector3.ZERO
			for other in vertex_faces[v]:
				if this_n.dot(face_normals[other]) >= threshold:
					acc += face_normals[other]
			row.append(-acc.normalized() if acc.length_squared() > 1e-12 else this_n)
		corner_normals.append(row)
	return corner_normals
