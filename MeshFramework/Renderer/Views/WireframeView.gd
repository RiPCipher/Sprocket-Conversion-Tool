class_name WireframeView
extends BaseView

var _color_options = {
	0: Color(0.0, 0.8, 1.0, 1.0), # Blue (Default)
	1: Color.GREEN,
	2: Color.BLACK,
	3: Color.RED,
	4: Color.WHITE,
	5: Color.PURPLE,
	6: Color(1.0, 0.6, 0.0, 1.0) # Orange
}

var _current_color: Color = Color(0.0, 0.8, 1.0, 1.0)
var _wireframe_thickness: float = 1.0

func get_view_name() -> String:
	return "Wireframe"

func supports_wireframe() -> bool:
	return true

func supports_color_selection() -> bool:
	return true

func get_supported_colors() -> Dictionary:
	return _color_options

func activate() -> void:
	if is_active:
		return
		
	print("WireframeView: Activating wireframe view")
	
	# Hide meshes, show wireframes
	apply_visibility(false, true)
	
	# Apply wireframe materials
	_apply_wireframe_materials()
	
	is_active = true
	emit_signal("view_activated")

func deactivate() -> void:
	if not is_active:
		return
		
	print("WireframeView: Deactivating wireframe view")
	
	is_active = false
	emit_signal("view_deactivated")

func set_color(color: Color) -> void:
	_current_color = color
	
	if is_active:
		_apply_wireframe_materials()

func set_wireframe_thickness(thickness: float) -> void:
	_wireframe_thickness = thickness
	
	if is_active:
		_apply_wireframe_materials()

func _apply_wireframe_materials() -> void:
	"""Apply wireframe materials to all wireframe instances"""
	var wireframe_material = model_materials.create_wireframe_material(_current_color, _wireframe_thickness)
	
	if wireframe_material:
		for wireframe in wireframe_instances:
			if wireframe and wireframe is MeshInstance3D:
				wireframe.material_override = wireframe_material
		
		print("WireframeView: Applied wireframe material with color: ", _current_color)
	else:
		# Fallback wireframe material
		var fallback_material = StandardMaterial3D.new()
		fallback_material.albedo_color = _current_color
		fallback_material.roughness = 1.0
		fallback_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fallback_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		fallback_material.render_priority = 1
		fallback_material.params_line_width = _wireframe_thickness
		fallback_material.params_depth_bias = 0.01
		
		for wireframe in wireframe_instances:
			if wireframe and wireframe is MeshInstance3D:
				wireframe.material_override = fallback_material
		
		print("WireframeView: Applied fallback wireframe material")
