class_name BaseView
extends RefCounted

signal view_activated()
signal view_deactivated()

# References
var model_renderer: ModelRenderer = null
var model_materials: ModelMaterials = null
var model_data: ModelData = null

var mesh_instances: Array[MeshInstance3D] = []
var wireframe_instances: Array[Node3D] = []
var model_root: Node3D = null

# View state
var is_active: bool = false

func activate() -> void:
	assert(false, "BaseView.activate() must be implemented by subclasses")

func deactivate() -> void:
	assert(false, "BaseView.deactivate() must be implemented by subclasses")

func get_view_name() -> String:
	assert(false, "BaseView.get_view_name() must be implemented by subclasses")
	return ""

func supports_wireframe() -> bool:
	return false

func supports_color_selection() -> bool:
	return false

func get_supported_colors() -> Dictionary:
	return {}

func set_color(color: Color) -> void:
	pass

func cleanup() -> void:
	pass

func set_references(renderer: ModelRenderer, materials: ModelMaterials, data: ModelData) -> void:
	model_renderer = renderer
	model_materials = materials
	model_data = data
	
	if renderer:
		mesh_instances = renderer._mesh_instances
		wireframe_instances = renderer._wireframe_instances
		model_root = renderer._model_root

func apply_visibility(meshes_visible: bool, wireframes_visible: bool) -> void:
	for mesh in mesh_instances:
		if mesh:
			mesh.visible = meshes_visible
	
	for wireframe in wireframe_instances:
		if wireframe:
			wireframe.visible = wireframes_visible

func apply_material_to_meshes(material: Material) -> void:
	for mesh in mesh_instances:
		if mesh:
			mesh.material_override = material

func get_material_by_name(material_name: String) -> Material:
	if model_materials:
		return model_materials.get_material(material_name)
	return null
