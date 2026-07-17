class_name ArmorView
extends BaseView

const ARMOR_THICKNESS_MM: float = 10.0
const THICKNESS_SCALE: float = 0.001  # Convert mm to meters

var _armor_instances: Array[Node3D] = []

func get_view_name() -> String:
	return "Armor"

func activate() -> void:
	if is_active:
		return
		
	print("ArmorView: Activating armor view")
	
	# Show meshes, hide standard wireframes
	apply_visibility(true, false)
	_apply_front_materials()
	_create_armor_geometry()
	
	is_active = true
	emit_signal("view_activated")

func deactivate() -> void:
	if not is_active:
		return
		
	print("ArmorView: Deactivating armor view")
	_cleanup_armor_geometry()
	
	is_active = false
	emit_signal("view_deactivated")

func cleanup() -> void:
	_cleanup_armor_geometry()

func _apply_front_materials() -> void:
	var front_material = model_materials.get_material_duplicate("armor_front")
	
	if not front_material:
		front_material = StandardMaterial3D.new()
		front_material.albedo_color = Color(0.8, 0.8, 0.8, 0.6)
		front_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		print("ArmorView: Using fallback front material")
	
	front_material.params_depth_bias = -0.001
	front_material.render_priority = -1
	
	apply_material_to_meshes(front_material)
	print("ArmorView: Applied front materials")

func _create_armor_geometry() -> void:
	if not model_data:
		print("ArmorView: No model data available")
		return
	
	var part_count = model_data.get_mesh_part_count()
	
	for part_idx in range(part_count):
		if part_idx < mesh_instances.size() and mesh_instances[part_idx]:
			var armor_instance = _create_armor_for_part(part_idx)
			if armor_instance:
				model_root.add_child(armor_instance)
				_armor_instances.append(armor_instance)
				print("ArmorView: Created armor geometry for part ", part_idx)

func _create_armor_for_part(part_idx: int) -> Node3D:
	if part_idx >= mesh_instances.size() or not mesh_instances[part_idx]:
		return null
	
	var mesh_instance = mesh_instances[part_idx]
	var mesh = mesh_instance.mesh
	
	if not mesh or mesh.get_surface_count() == 0:
		return null
	
	# Get vertices and faces
	var vertices = PackedVector3Array()
	var original_faces = []
	var original_uvs = PackedVector2Array()
	
	# Try to get original topology data first
	if part_idx < model_data.part_original_vertices.size():
		vertices = model_data.part_original_vertices[part_idx]
		print("ArmorView: Using original vertices for part ", part_idx, " (", vertices.size(), " vertices)")
	
	if model_data.has_part_metadata(part_idx, "original_faces"):
		original_faces = model_data.get_part_metadata(part_idx, "original_faces")
		print("ArmorView: Using original faces for part ", part_idx, " (", original_faces.size(), " faces)")
	
	# Fallback to surface arrays if no original data
	if vertices.size() == 0 or original_faces.size() == 0:
		print("ArmorView: No original topology data, using surface arrays as fallback")
		var surface_arrays = mesh.surface_get_arrays(0)
		vertices = surface_arrays[Mesh.ARRAY_VERTEX]
		original_uvs = surface_arrays[Mesh.ARRAY_TEX_UV] if surface_arrays[Mesh.ARRAY_TEX_UV] else PackedVector2Array()
		
		# Generate simple faces from indices
		var indices = surface_arrays[Mesh.ARRAY_INDEX] if surface_arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()
		if indices.size() > 0:
			for i in range(0, indices.size(), 3):
				if i + 2 < indices.size():
					original_faces.append([indices[i], indices[i+1], indices[i+2]])
		else:
			# No indices, assume triangles
			for i in range(0, vertices.size(), 3):
				if i + 2 < vertices.size():
					original_faces.append([i, i+1, i+2])
	else:
		# Get UVs from surface arrays
		var surface_arrays = mesh.surface_get_arrays(0)
		original_uvs = surface_arrays[Mesh.ARRAY_TEX_UV] if surface_arrays[Mesh.ARRAY_TEX_UV] else PackedVector2Array()
	
	if vertices.size() == 0 or original_faces.size() == 0:
		print("ArmorView: No valid geometry for part ", part_idx)
		return null
	
	# Create root container for this parts armor
	var root_instance = Node3D.new()
	root_instance.name = mesh_instance.name + "_Armor"
	
	# Create armor components
	var sides_mesh = _create_armor_sides(vertices, original_faces, original_uvs)
	var back_caps_mesh = _create_armor_back_caps(vertices, original_faces, original_uvs)
	
	if sides_mesh:
		var sides_instance = MeshInstance3D.new()
		sides_instance.name = "ArmorSides"
		sides_instance.mesh = sides_mesh
		
		var sides_material = model_materials.get_material_duplicate("armor_side")
		if sides_material:
			sides_material.params_depth_bias = 0.001
			sides_material.render_priority = 1
			sides_instance.material_override = sides_material
		
		root_instance.add_child(sides_instance)
	
	if back_caps_mesh:
		var back_instance = MeshInstance3D.new()
		back_instance.name = "ArmorBackCaps"
		back_instance.mesh = back_caps_mesh
		
		var back_material = model_materials.get_material_duplicate("armor_default")
		if back_material:
			back_material.cull_mode = BaseMaterial3D.CULL_FRONT
			back_material.params_depth_bias = -0.001
			back_material.render_priority = 0
			back_instance.material_override = back_material
		
		root_instance.add_child(back_instance)
	
	return root_instance

func _create_armor_sides(vertices: PackedVector3Array, faces: Array, uvs: PackedVector2Array) -> ArrayMesh:
	var mesh_vertices = PackedVector3Array()
	var mesh_normals = PackedVector3Array()
	var mesh_uvs = PackedVector2Array()
	var mesh_indices = PackedInt32Array()
	
	var vertex_index = 0
	var thickness = ARMOR_THICKNESS_MM * THICKNESS_SCALE
	
	# Process each face
	for face in faces:
		if face.size() < 3:
			continue
		
		# Validate face indices
		var valid_face = true
		for idx in face:
			if int(idx) >= vertices.size() or int(idx) < 0:
				valid_face = false
				break
		
		if not valid_face:
			continue
		
		# Get face vertices
		var face_verts = []
		for idx in face:
			face_verts.append(vertices[int(idx)])
		
		# Calculate face normal
		var face_normal = (face_verts[1] - face_verts[0]).cross(face_verts[2] - face_verts[0]).normalized()
		
		# Create inner vertices
		var inner_verts = []
		for vert in face_verts:
			inner_verts.append(vert - face_normal * thickness)
		
		# Create side quads between each edge
		for i in range(face_verts.size()):
			var next_i = (i + 1) % face_verts.size()
			
			# Skip degenerate edges
			if face_verts[i].distance_squared_to(face_verts[next_i]) < 0.0001:
				continue
			
			var edge_dir = (face_verts[next_i] - face_verts[i]).normalized()
			var side_normal = edge_dir.cross(face_normal).normalized()
			
			# Quad vertices
			var v0 = face_verts[i]
			var v1 = face_verts[next_i]
			var v2 = inner_verts[next_i]
			var v3 = inner_verts[i]
			
			# Simple UV mapping for sides
			var u0 = Vector2(0, 0)
			var u1 = Vector2(1, 0)
			var u2 = Vector2(1, 1)
			var u3 = Vector2(0, 1)
			
			mesh_vertices.append_array([v0, v1, v2, v3])
			mesh_normals.append_array([side_normal, side_normal, side_normal, side_normal])
			mesh_uvs.append_array([u0, u1, u2, u3])
			
			# Two triangles for the quad
			mesh_indices.append_array([
				vertex_index, vertex_index + 1, vertex_index + 2,
				vertex_index, vertex_index + 2, vertex_index + 3
			])
			
			vertex_index += 4
	
	# Create the mesh
	var array_mesh = ArrayMesh.new()
	if mesh_vertices.size() > 0:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = mesh_vertices
		arrays[Mesh.ARRAY_NORMAL] = mesh_normals
		arrays[Mesh.ARRAY_TEX_UV] = mesh_uvs
		arrays[Mesh.ARRAY_INDEX] = mesh_indices
		
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		print("ArmorView: Created armor sides with ", mesh_vertices.size(), " vertices")
	
	return array_mesh

func _create_armor_back_caps(vertices: PackedVector3Array, faces: Array, uvs: PackedVector2Array) -> ArrayMesh:
	var mesh_vertices = PackedVector3Array()
	var mesh_normals = PackedVector3Array()
	var mesh_uvs = PackedVector2Array()
	var mesh_indices = PackedInt32Array()
	
	var vertex_index = 0
	var thickness = ARMOR_THICKNESS_MM * THICKNESS_SCALE
	
	# Process each face
	for face in faces:
		if face.size() < 3:
			continue
		
		# Validate face indices
		var valid_face = true
		var face_verts = []
		var face_uvs = []
		
		for idx in face:
			var vertex_idx = int(idx)
			if vertex_idx >= vertices.size() or vertex_idx < 0:
				valid_face = false
				break
			face_verts.append(vertices[vertex_idx])
			
			if vertex_idx < uvs.size():
				face_uvs.append(uvs[vertex_idx])
			else:
				face_uvs.append(Vector2.ZERO)
		
		if not valid_face:
			continue
		
		# Calculate face normal
		var face_normal = (face_verts[1] - face_verts[0]).cross(face_verts[2] - face_verts[0]).normalized()
		
		# Create inner vertices
		var inner_verts = []
		for vert in face_verts:
			inner_verts.append(vert - face_normal * thickness)
		
		mesh_vertices.append_array(inner_verts)
		for i in range(inner_verts.size()):
			mesh_normals.append(-face_normal)  # Reversed normal for back face
		mesh_uvs.append_array(face_uvs)
		
		# Triangulate the face
		if inner_verts.size() == 3:
			mesh_indices.append_array([vertex_index, vertex_index + 1, vertex_index + 2])
		elif inner_verts.size() == 4:
			mesh_indices.append_array([
				vertex_index, vertex_index + 1, vertex_index + 2,
				vertex_index, vertex_index + 2, vertex_index + 3
			])
		else:
			# Fan triangulation for n-gons
			for i in range(1, inner_verts.size() - 1):
				mesh_indices.append_array([
					vertex_index, vertex_index + i, vertex_index + i + 1
				])
		
		vertex_index += inner_verts.size()
	
	# Create the mesh
	var array_mesh = ArrayMesh.new()
	if mesh_vertices.size() > 0:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = mesh_vertices
		arrays[Mesh.ARRAY_NORMAL] = mesh_normals
		arrays[Mesh.ARRAY_TEX_UV] = mesh_uvs
		arrays[Mesh.ARRAY_INDEX] = mesh_indices
		
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		print("ArmorView: Created armor back caps with ", mesh_vertices.size(), " vertices")
	
	return array_mesh

func _cleanup_armor_geometry() -> void:
	for armor_instance in _armor_instances:
		if armor_instance and is_instance_valid(armor_instance):
			armor_instance.queue_free()
	
	_armor_instances.clear()
	print("ArmorView: Cleaned up armor geometry")
