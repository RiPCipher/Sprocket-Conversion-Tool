class_name BaseFormat
extends RefCounted

var can_import: bool = false
var can_export: bool = false
var supports_materials: bool = false
var supports_animations: bool = false
var supports_skeletons: bool = false
var supports_morph_targets: bool = false

static func get_format_name() -> String:
	return "Unknown Format"

static func get_format_extension() -> String:
	return ""

static func get_format_description() -> String:
	return "Unknown Format"

func import_model(file_path: String, options: Dictionary = {}) -> ModelData:
	push_error("BaseFormat.import_model: Not implemented")
	return null

func export_model(model_data: ModelData, file_path: String, options: Dictionary = {}) -> Dictionary:
	push_error("BaseFormat.export_model: Not implemented")
	return {"success": false, "error": "Not implemented"}

static func get_default_import_options() -> Dictionary:
	return {
		"calculate_normals": true,
		"generate_uvs": true,
		"optimize": false
	}

static func get_default_export_options() -> Dictionary:
	return {
		"precision": 6,
		"include_materials": true,
		"include_normals": true,
		"include_uvs": true
	}

func validate_for_export(model_data: ModelData) -> Dictionary:
	var result = {
		"valid": true,
		"errors": [],
		"warnings": []
	}
	
	if model_data.vertices.size() == 0:
		result.errors.append("No vertices in model")
		result.valid = false
	
	if model_data.indices.size() == 0:
		result.errors.append("No indices in model")
		result.valid = false
	
	return result

static func find_by_extension(extension: String) -> BaseFormat:
	var registry = FormatRegistry.get_instance()
	return registry.get_format_handler_for_extension(extension)
	
func create_wireframe_mesh(model_data: ModelData) -> MeshInstance3D:
	var imm = ImmediateMesh.new()
	var wireframe_mesh = MeshInstance3D.new()
	wireframe_mesh.mesh = imm
	
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0, 0.8, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var vertices_added = false
	var added_edges = {}
	var surface_arrays = model_data.get_surface_arrays(0)
	var vertices = surface_arrays[Mesh.ARRAY_VERTEX]
	
	if model_data.topology and model_data.topology.has("is_quad_mesh") and model_data.topology["is_quad_mesh"]:
		for quad in model_data.topology["quads"]:
			if quad.size() == 4:
				for i in range(4):
					var v1_idx = quad[i]
					var v2_idx = quad[(i + 1) % 4]
					
					var edge_key = min(v1_idx, v2_idx) * 1000000 + max(v1_idx, v2_idx)
					
					if not edge_key in added_edges:
						added_edges[edge_key] = true
						if v1_idx < vertices.size() and v2_idx < vertices.size():
							imm.surface_add_vertex(vertices[v1_idx])
							imm.surface_add_vertex(vertices[v2_idx])
							vertices_added = true
	
	if added_edges.size() == 0:
		var indices = surface_arrays[Mesh.ARRAY_INDEX]
		for i in range(0, indices.size(), 3):
			if i + 2 < indices.size():
				for edges in [[i, i+1], [i+1, i+2], [i+2, i]]:
					var v1_idx = indices[edges[0]]
					var v2_idx = indices[edges[1]]
					
					var edge_key = min(v1_idx, v2_idx) * 1000000 + max(v1_idx, v2_idx)
					
					if not edge_key in added_edges:
						added_edges[edge_key] = true
						if v1_idx < vertices.size() and v2_idx < vertices.size():
							imm.surface_add_vertex(vertices[v1_idx])
							imm.surface_add_vertex(vertices[v2_idx])
							vertices_added = true
	
	if vertices_added:
		imm.surface_end()
	else:
		imm.surface_add_vertex(Vector3.ZERO)
		imm.surface_add_vertex(Vector3(0, 0, 0.001))
		imm.surface_end()
	
	wireframe_mesh.material_override = material
	return wireframe_mesh
