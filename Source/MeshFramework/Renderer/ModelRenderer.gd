class_name ModelRenderer
extends Node3D

signal rendering_completed()
signal rendering_started()

# Import view classes
const DefaultView = preload("res://MeshFramework/Renderer/Views/DefaultView.gd")
const WireframeView = preload("res://MeshFramework/Renderer/Views/WireframeView.gd")
const OverlayView = preload("res://MeshFramework/Renderer/Views/OverlayView.gd")
const ArmorView = preload("res://MeshFramework/Renderer/Views/ArmorView.gd")
const ModelMaterials = preload("res://MeshFramework/Renderer/ModelMaterials.gd")

enum RenderMode {
	SOLID,
	WIREFRAME, 
	WIREFRAME_OVERLAY,
	ARMOR,
	TEXTURED  # Keep for compatibility, maps to SOLID // delete??
}

# Properties
@export var render_mode: RenderMode = RenderMode.SOLID
@export var auto_center: bool = false
@export var auto_scale: bool = false
@export var wireframe_color: Color = Color(0.0, 0.8, 1.0, 1.0)
@export_range(0.1, 3.0) var wireframe_thickness: float = 1.0

# Core components
var _current_model_data = null
var _model_root: Node3D = null
var _mesh_instances: Array[MeshInstance3D] = []
var _wireframe_instances: Array[Node3D] = []
var target_viewport = null

var _model_materials: ModelMaterials = null
var _views: Dictionary = {}
var _current_view: BaseView = null

func _init():
	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	add_child(_model_root)
	_model_materials = ModelMaterials.new()
	
	_initialize_views()

func _initialize_views() -> void:
	"""Create and initialize all view instances"""
	print("ModelRenderer: Initializing view system...")
	
	_views["solid"] = DefaultView.new()
	_views["wireframe"] = WireframeView.new()
	_views["overlay"] = OverlayView.new()
	_views["armor"] = ArmorView.new()
	
	# Set up view references
	for view_name in _views:
		var view = _views[view_name]
		view.set_references(self, _model_materials, _current_model_data)
		
		# Connect signals
		view.connect("view_activated", Callable(self, "_on_view_activated").bind(view_name))
		view.connect("view_deactivated", Callable(self, "_on_view_deactivated").bind(view_name))
	
	print("ModelRenderer: Initialized ", _views.size(), " views")

func set_target_viewport(viewport):
	target_viewport = viewport

func render_model(model_data: ModelData) -> bool:
	if not model_data:
		push_error("ModelRenderer: Cannot render null model data")
		return false
	
	emit_signal("rendering_started")
	
	# Clear existing display meshes
	for child in _model_root.get_children():
		child.queue_free()
	
	_mesh_instances.clear()
	_wireframe_instances.clear()
	
	_current_model_data = model_data
	
	# Create mesh instances from model data
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
	
	# Meshes are ready for display with their original normals
	print("ModelRenderer: Created ", _mesh_instances.size(), " display meshes")
	
	# Auto-center if enabled
	if auto_center and not model_data.has_metadata("disable_auto_center"):
		center_model()
	
	# Create wireframe representation
	_create_wireframe()
	
	# Update view references with new data
	_update_view_references()
	
	# Apply current render mode
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
		Debug.log("Model source format: " + _current_model_data.source_format)
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
	
	# Fallback wireframe creation
	for mesh_instance in _mesh_instances:
		if mesh_instance and mesh_instance.mesh:
			var wireframe_mesh = _create_wireframe_for_mesh(mesh_instance.mesh)
			_model_root.add_child(wireframe_mesh)
			_wireframe_instances.append(wireframe_mesh)

func _create_wireframe_for_mesh(mesh: Mesh) -> MeshInstance3D:
	var imm = ImmediateMesh.new()
	var wireframe_mesh = MeshInstance3D.new()
	wireframe_mesh.mesh = imm
	
	# Use materials system for wireframe material
	var wireframe_material = _model_materials.create_wireframe_material(wireframe_color, wireframe_thickness)
	wireframe_mesh.material_override = wireframe_material
	
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

func _update_view_references() -> void:
	for view_name in _views:
		var view = _views[view_name]
		view.set_references(self, _model_materials, _current_model_data)

func set_render_mode(mode: RenderMode) -> void:
	render_mode = mode
	
	# Deactivate current view
	if _current_view:
		_current_view.deactivate()
		_current_view = null
	
	# Activate new view
	match mode:
		RenderMode.SOLID:
			_current_view = _views["solid"]
		RenderMode.WIREFRAME:
			_current_view = _views["wireframe"]
		RenderMode.WIREFRAME_OVERLAY:
			_current_view = _views["overlay"]
		RenderMode.ARMOR:
			_current_view = _views["armor"]
	
	if _current_view:
		_current_view.activate()
		print("ModelRenderer: Activated ", _current_view.get_view_name(), " view")

func set_wireframe_color(color: Color) -> void:
	wireframe_color = color
	
	# Update wireframe views
	if _views.has("wireframe"):
		_views["wireframe"].set_color(color)
	
	if _views.has("overlay"):
		_views["overlay"].set_wireframe_color(color)

func set_wireframe_thickness(thickness: float) -> void:
	wireframe_thickness = thickness
	
	# Update wireframe views
	if _views.has("wireframe"):
		_views["wireframe"].set_wireframe_thickness(thickness)
	
	if _views.has("overlay"):
		_views["overlay"].set_wireframe_thickness(thickness)

func set_mesh_color(color: Color) -> void:
	if _views.has("solid"):
		_views["solid"].set_color(color)
	
	if _views.has("overlay"):
		_views["overlay"].set_color(color)

# compatibility methods // Delete??
func set_default_material_color(color: Color) -> void:
	print("set default material: compatability")
	set_mesh_color(color)

# View information methods
func get_current_view() -> BaseView:
	return _current_view

func get_view_by_name(name: String) -> BaseView:
	if _views.has(name):
		return _views[name]
	return null

func get_available_views() -> Array[String]:
	return _views.keys()

func supports_color_selection() -> bool:
	if _current_view:
		return _current_view.supports_color_selection()
	return false

func get_supported_colors() -> Dictionary:
	if _current_view:
		return _current_view.get_supported_colors()
	return {}

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

# Signal callbacks
func _on_view_activated(view_name: String) -> void:
	print("ModelRenderer: View activated: ", view_name)

func _on_view_deactivated(view_name: String) -> void:
	print("ModelRenderer: View deactivated: ", view_name)
