class_name OverlayView
extends BaseView

var _mesh_color_options = {
	0: Color.WHITE,
	1: Color.GREEN,
	2: Color.BLACK,
	3: Color.RED,
	4: Color.CYAN,
	5: Color.PURPLE,
	6: Color.WEB_GRAY
}

# Wireframe color options
var _wireframe_color_options = {
	0: Color(0.0, 0.8, 1.0, 1.0), # Blue (Default)
	1: Color.GREEN,
	2: Color.BLACK,
	3: Color.RED,
	4: Color.WHITE,
	5: Color.PURPLE,
	6: Color(1.0, 0.6, 0.0, 1.0) # Orange
}

var _current_mesh_color: Color = Color.WHITE
var _current_wireframe_color: Color = Color(0.0, 0.8, 1.0, 1.0)
var _wireframe_thickness: float = 1.0

func get_view_name() -> String:
	return "Overlay"

func supports_wireframe() -> bool:
	return true

func supports_color_selection() -> bool:
	return true

func get_supported_colors() -> Dictionary:
	return _mesh_color_options

func activate() -> void:
	if is_active:
		return
		
	print("OverlayView: Activating overlay view")
	
	# Show both meshes and wireframes
	apply_visibility(true, true)
	_apply_mesh_materials()
	_apply_wireframe_materials()
	
	is_active = true
	emit_signal("view_activated")

func deactivate() -> void:
	if not is_active:
		return
		
	print("OverlayView: Deactivating overlay view")
	
	is_active = false
	emit_signal("view_deactivated")

func set_color(color: Color) -> void:
	_current_mesh_color = color
	
	if is_active:
		_apply_mesh_materials()

func set_wireframe_color(color: Color) -> void:
	_current_wireframe_color = color
	
	if is_active:
		_apply_wireframe_materials()

func set_wireframe_thickness(thickness: float) -> void:
	_wireframe_thickness = thickness
	
	if is_active:
		_apply_wireframe_materials()

func get_wireframe_color_options() -> Dictionary:
	return _wireframe_color_options

func _apply_mesh_materials() -> void:
	var base_material = model_materials.create_colored_material("default_solid", _current_mesh_color)
	
	if base_material:
		apply_material_to_meshes(base_material)
		print("OverlayView: Applied mesh material with color: ", _current_mesh_color)
	else:
		# Fallback material
		var fallback_material = StandardMaterial3D.new()
		fallback_material.albedo_color = _current_mesh_color
		fallback_material.roughness = 0.5
		apply_material_to_meshes(fallback_material)
		print("OverlayView: Applied fallback mesh material")

func _apply_wireframe_materials() -> void:
	var wireframe_material = model_materials.create_wireframe_material(_current_wireframe_color, _wireframe_thickness)
	
	if wireframe_material:
		for wireframe in wireframe_instances:
			if wireframe and wireframe is MeshInstance3D:
				wireframe.material_override = wireframe_material
		
		print("OverlayView: Applied wireframe material with color: ", _current_wireframe_color)
	else:
		# Fallback wireframe material
		var fallback_material = StandardMaterial3D.new()
		fallback_material.albedo_color = _current_wireframe_color
		fallback_material.roughness = 1.0
		fallback_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fallback_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		fallback_material.render_priority = 1
		fallback_material.params_line_width = _wireframe_thickness
		fallback_material.params_depth_bias = 0.01
		
		for wireframe in wireframe_instances:
			if wireframe and wireframe is MeshInstance3D:
				wireframe.material_override = fallback_material
		
		print("OverlayView: Applied fallback wireframe material")
