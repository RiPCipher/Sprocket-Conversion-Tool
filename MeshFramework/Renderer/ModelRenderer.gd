class_name ModelRenderer
extends Node3D

signal rendering_completed()
signal rendering_started()

enum RenderMode {
	SOLID,
	WIREFRAME,
	TEXTURED,
	WIREFRAME_OVERLAY,
	NORMALS,
	VERTEX_COLORS
}

# Properties
@export var render_mode: RenderMode = RenderMode.SOLID
@export var auto_center: bool = false
@export var auto_scale: bool = false
@export var wireframe_color: Color = Color(0.0, 0.8, 1.0, 1.0)
@export_range(0.1, 3.0) var wireframe_thickness: float = 1.0

# References
var _current_model_data = null
var _model_root: Node3D = null
var _mesh_instances: Array[MeshInstance3D] = []
var _wireframe_instances: Array[Node3D] = []
var target_viewport = null

# Materials
var _default_material: StandardMaterial3D = null
var _wireframe_material: StandardMaterial3D = null
var _internal_material: StandardMaterial3D = null

func _init():
	_initialize_materials()
	
	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	add_child(_model_root)

func _initialize_materials():
	_default_material = StandardMaterial3D.new()
	_default_material.albedo_color = Color.BEIGE
	_default_material.roughness = 0.5
	_default_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_default_material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	_default_material.backlight_enabled = true
	_default_material.backlight = Color(1,1,1,0.1)
	
	_internal_material = StandardMaterial3D.new()
	_internal_material.albedo_color = Color.WHITE
	_internal_material.roughness = 0.5
	_internal_material.cull_mode = BaseMaterial3D.CULL_BACK
	
	_wireframe_material = StandardMaterial3D.new()
	_wireframe_material.albedo_color = wireframe_color
	_wireframe_material.roughness = 1.0
	_wireframe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wireframe_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	_wireframe_material.render_priority = 1
	
	_wireframe_material.params_line_width = wireframe_thickness
	_wireframe_material.params_depth_bias = 0.01

func set_target_viewport(viewport):
	target_viewport = viewport

func render_model(model_data: ModelData) -> bool:
	if not model_data:
		push_error("ModelRenderer: Cannot render null model data")
		return false
	
	emit_signal("rendering_started")
	
	for child in _model_root.get_children():
		child.queue_free()
	
	_mesh_instances.clear()
	_wireframe_instances.clear()
	
	_current_model_data = model_data
	
	var part_count = model_data.get_mesh_part_count()
	
	for i in range(part_count):
		var mesh_instance = model_data.create_mesh_instance_for_part(i)
		if mesh_instance:
			var part_name = "Part_" + str(i)
			if i < model_data.part_names.size() and not model_data.part_names[i].is_empty():
				part_name = model_data.part_names[i]
				
			mesh_instance.name = part_name
			_model_root.add_child(mesh_instance)
			_mesh_instances.append(mesh_instance)
	
	if auto_center and not model_data.has_metadata("disable_auto_center"):
		center_model()
	
	_create_wireframe()
	set_wireframe_color(wireframe_color)
	set_render_mode(render_mode)
	
	emit_signal("rendering_completed")
	return true

func _create_wireframe():
	for wireframe in _wireframe_instances:
		if wireframe:
			wireframe.queue_free()
	_wireframe_instances.clear()
	
	var format_handler = null
	
	if _current_model_data and _current_model_data.source_format:
		print("Model source format: " + _current_model_data.source_format)
		format_handler = FormatRegistry.get_format_handler_for_extension(_current_model_data.source_format)
		
		if format_handler:
			print("Format handler found: " + format_handler.get_class())
			var wireframe_instance = format_handler.create_wireframe_mesh(_current_model_data)
			
			if wireframe_instance:
				print("Format-specific wireframe created")
				_model_root.add_child(wireframe_instance)
				_wireframe_instances.append(wireframe_instance)
				return
			else:
				print("Format handler returned null wireframe, falling back to default")
	
	# If no format handler or it failed, create basic wireframes for mesh
	for mesh_instance in _mesh_instances:
		if mesh_instance and mesh_instance.mesh:
			var wireframe_mesh = _create_wireframe_for_mesh(mesh_instance.mesh)
			_model_root.add_child(wireframe_mesh)
			_wireframe_instances.append(wireframe_mesh)

# Create wireframe as a fallback in case the original fails
func _create_wireframe_for_mesh(mesh: Mesh) -> MeshInstance3D:
	var imm = ImmediateMesh.new()
	var wireframe_mesh = MeshInstance3D.new()
	wireframe_mesh.mesh = imm
	wireframe_mesh.material_override = _wireframe_material.duplicate()
	
	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var added_edges = {}
	var vertices_added = false
	
	for surface_idx in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface_idx)
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		
		if indices and indices.size() > 0:
			for i in range(0, indices.size(), 3):
				if i + 2 < indices.size():
					var idx1 = indices[i]
					var idx2 = indices[i+1]
					var idx3 = indices[i+2]
					
					for edges in [[idx1, idx2], [idx2, idx3], [idx3, idx1]]:
						var v1_idx = edges[0]
						var v2_idx = edges[1]
						
						var edge_key = min(v1_idx, v2_idx) * 1000000 + max(v1_idx, v2_idx)
						
						if not edge_key in added_edges:
							added_edges[edge_key] = true
							
							if v1_idx >= 0 and v2_idx >= 0 and v1_idx < vertices.size() and v2_idx < vertices.size():
								imm.surface_add_vertex(vertices[v1_idx])
								imm.surface_add_vertex(vertices[v2_idx])
								vertices_added = true
		else:
			for i in range(0, vertices.size(), 3):
				if i + 2 < vertices.size():
					imm.surface_add_vertex(vertices[i])
					imm.surface_add_vertex(vertices[i+1])
					
					imm.surface_add_vertex(vertices[i+1])
					imm.surface_add_vertex(vertices[i+2])
					
					imm.surface_add_vertex(vertices[i+2])
					imm.surface_add_vertex(vertices[i])
					
					vertices_added = true
	
	if vertices_added:
		imm.surface_end()
	else:
		imm.surface_add_vertex(Vector3.ZERO)
		imm.surface_add_vertex(Vector3(0, 0, 0.001))
		imm.surface_end()
	
	return wireframe_mesh

func _add_wireframe_edge(imm: ImmediateMesh, vertices: PackedVector3Array, idx1: int, idx2: int, edges_added: Dictionary) -> bool:
	if idx1 < 0 or idx2 < 0 or idx1 >= vertices.size() or idx2 >= vertices.size():
		return false
	
	var low = min(idx1, idx2)
	var high = max(idx1, idx2)
	var edge_key = str(low) + "_" + str(high)
	
	if edges_added.has(edge_key):
		return false
	
	edges_added[edge_key] = true
	imm.surface_add_vertex(vertices[idx1])
	imm.surface_add_vertex(vertices[idx2])
	return true

func set_render_mode(mode: RenderMode):
	render_mode = mode
	
	if _mesh_instances.size() == 0 or _wireframe_instances.size() == 0:
		return
	
	match mode:
		RenderMode.SOLID:
			for mesh in _mesh_instances:
				mesh.visible = true
				mesh.material_override = _default_material
			
			for wireframe in _wireframe_instances:
				wireframe.visible = false
			
		RenderMode.WIREFRAME:
			for mesh in _mesh_instances:
				mesh.visible = false
			
			for wireframe in _wireframe_instances:
				wireframe.visible = true
			
		RenderMode.TEXTURED:
			for mesh in _mesh_instances:
				mesh.visible = true
				mesh.material_override = _internal_material #_default_material
			
			for wireframe in _wireframe_instances:
				wireframe.visible = false
			
		RenderMode.WIREFRAME_OVERLAY:
			for mesh in _mesh_instances:
				mesh.visible = true
			
			for wireframe in _wireframe_instances:
				wireframe.visible = true
			
		RenderMode.NORMALS, RenderMode.VERTEX_COLORS:
			for mesh in _mesh_instances:
				mesh.visible = true
				
				var material = StandardMaterial3D.new()
				if mode == RenderMode.VERTEX_COLORS:
					material.vertex_color_use_as_albedo = true
				else:
					material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
				
				mesh.material_override = material
			
			for wireframe in _wireframe_instances:
				wireframe.visible = false

func center_model():
	if _mesh_instances.size() == 0:
		return
	
	var combined_aabb = AABB()
	var first = true
	
	for mesh in _mesh_instances:
		var mesh_aabb = mesh.get_aabb()
		
		var transform = mesh.global_transform
		var transformed_aabb = _transform_aabb(mesh_aabb, transform)
		
		if first:
			combined_aabb = transformed_aabb
			first = false
		else:
			combined_aabb = combined_aabb.merge(transformed_aabb)
	
	var center = combined_aabb.position + (combined_aabb.size / 2)

	_model_root.position = -center

func _transform_aabb(aabb: AABB, transform: Transform3D) -> AABB:
	var points = [
		transform * Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
		transform * Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z),
		transform * Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z),
		transform * Vector3(aabb.position.x, aabb.position.y, aabb.position.z + aabb.size.z),
		transform * Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z),
		transform * Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z + aabb.size.z),
		transform * Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z),
		transform * Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z)
	]
	
	var min_pos = points[0]
	var max_pos = points[0]
	
	for i in range(1, points.size()):
		min_pos.x = min(min_pos.x, points[i].x)
		min_pos.y = min(min_pos.y, points[i].y)
		min_pos.z = min(min_pos.z, points[i].z)
		
		max_pos.x = max(max_pos.x, points[i].x)
		max_pos.y = max(max_pos.y, points[i].y)
		max_pos.z = max(max_pos.z, points[i].z)
	
	return AABB(min_pos, max_pos - min_pos)

func set_wireframe_color(color: Color):
	wireframe_color = color
	if _wireframe_material:
		_wireframe_material.albedo_color = color
		
		for wireframe in _wireframe_instances:
			if wireframe is MeshInstance3D and wireframe.material_override:
				wireframe.material_override = wireframe.material_override.duplicate()
				wireframe.material_override.albedo_color = color
				
				# The color change might not be immediately visible without this
				# I hate materials
				wireframe.material_override.emission_enabled = true
				wireframe.material_override.emission = color
				wireframe.material_override.emission_energy_multiplier = 0.4

func set_default_material_color(color: Color):
	if _default_material:
		_default_material.albedo_color = color
		
		if render_mode == RenderMode.SOLID:
			for mesh in _mesh_instances:
				if mesh.material_override == _default_material:
					mesh.material_override = _default_material.duplicate()
					mesh.material_override.albedo_color = color
