class_name ModelMaterials
extends RefCounted

var _materials: Dictionary = {}
var _shaders: Dictionary = {}
var _initialized: bool = false

# Default material paths
const DEFAULT_MATERIALS = {
	"base_material": "res://Textures/Materials/base_material.tres",
	"armor_default": "res://Textures/Materials/armor_default.tres",
	"armor_side": "res://Textures/Materials/armor_side.tres",
	"armor_front": "res://Textures/Materials/semi_transparent.tres"
}

# Default shader paths
const DEFAULT_SHADERS = {
	"internals": "res://Textures/Shaders/Internals.gdshader"
}

func _init():
	_initialize_materials()

func _initialize_materials() -> void:
	if _initialized:
		return
	
	print("ModelMaterials: Initializing materials system...")
	
	_load_default_materials()
	_create_procedural_materials()
	_load_shaders()
	
	_initialized = true
	print("ModelMaterials: Loaded ", _materials.size(), " materials and ", _shaders.size(), " shaders")

func _load_default_materials() -> void:
	for name in DEFAULT_MATERIALS:
		var path = DEFAULT_MATERIALS[name]
		var material = load(path)
		if material:
			_materials[name] = material
			print("  Loaded material: ", name)
		else:
			push_warning("ModelMaterials: Failed to load material: " + name + " at " + path)

func _create_procedural_materials() -> void:
	# Default wireframe material
	var wireframe_material = StandardMaterial3D.new()
	wireframe_material.albedo_color = Color(0.0, 0.8, 1.0, 1.0)
	wireframe_material.roughness = 1.0
	wireframe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wireframe_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	wireframe_material.render_priority = 1
	wireframe_material.params_line_width = 1.0
	wireframe_material.params_depth_bias = 0.01
	_materials["wireframe"] = wireframe_material
	
	# Default solid material
	var default_material = StandardMaterial3D.new()
	default_material.albedo_color = Color.BEIGE
	default_material.roughness = 0.5
	default_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	default_material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	default_material.backlight_enabled = true
	default_material.backlight = Color(1,1,1,0.1)
	_materials["default_solid"] = default_material
	
	# Internal/textured material
	var internal_material = StandardMaterial3D.new()
	internal_material.albedo_color = Color.WHITE
	internal_material.roughness = 0.5
	internal_material.cull_mode = BaseMaterial3D.CULL_BACK
	_materials["internal"] = internal_material
	
	print("  Created ", 3, " procedural materials")

func _load_shaders() -> void:
	for name in DEFAULT_SHADERS:
		var path = DEFAULT_SHADERS[name]
		var shader = load(path)
		if shader:
			_shaders[name] = shader
			print("  Loaded shader: ", name)
		else:
			push_warning("ModelMaterials: Failed to load shader: " + name + " at " + path)

func get_material(name: String) -> Material:
	if not _initialized:
		_initialize_materials()
	
	if _materials.has(name):
		return _materials[name]
	
	push_warning("ModelMaterials: Material not found: " + name)
	return null

func get_material_duplicate(name: String) -> Material:
	var material = get_material(name)
	if material:
		return material.duplicate()
	return null

func get_shader(name: String) -> Shader:
	if not _initialized:
		_initialize_materials()
	
	if _shaders.has(name):
		return _shaders[name]
	
	push_warning("ModelMaterials: Shader not found: " + name)
	return null

func create_colored_material(base_material_name: String, color: Color) -> Material:
	var base_material = get_material_duplicate(base_material_name)
	if base_material and base_material is StandardMaterial3D:
		base_material.albedo_color = color
		return base_material
	return null

func create_wireframe_material(color: Color, thickness: float = 1.0) -> Material:
	var wireframe_material = get_material_duplicate("wireframe")
	if wireframe_material and wireframe_material is StandardMaterial3D:
		wireframe_material.albedo_color = color
		wireframe_material.params_line_width = thickness
		# Add emission for better visibility
		wireframe_material.emission_enabled = true
		wireframe_material.emission = color
		wireframe_material.emission_energy_multiplier = 0.4
		return wireframe_material
	return null

func has_material(name: String) -> bool:
	"""Check if a material exists"""
	if not _initialized:
		_initialize_materials()
	return _materials.has(name)

func get_available_materials() -> Array[String]:
	if not _initialized:
		_initialize_materials()
	return _materials.keys()

# for pck support
func register_material(name: String, material: Material) -> void:
	_materials[name] = material
	print("ModelMaterials: Registered new material: ", name)

func register_shader(name: String, shader: Shader) -> void:
	_shaders[name] = shader
	print("ModelMaterials: Registered new shader: ", name)

func scan_for_additional_materials(base_path: String = "res://Textures/Materials/") -> void:
	# prolly should remove this 
	pass
