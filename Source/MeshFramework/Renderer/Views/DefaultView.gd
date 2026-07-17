class_name DefaultView
extends BaseView

var _color_options = {
	0: Color.WHITE,
	1: Color.GREEN, 
	2: Color.BLACK,
	3: Color.RED,
	4: Color.CYAN,
	5: Color.PURPLE,
	6: Color.WEB_GRAY
}

var _current_color: Color = Color.WHITE

func get_view_name() -> String:
	return "Default"

func supports_color_selection() -> bool:
	return true

func get_supported_colors() -> Dictionary:
	return _color_options

func activate() -> void:
	if is_active:
		return
		
	print("DefaultView: Activating solid view")
	
	# Show meshes, hide wireframes
	apply_visibility(true, false)
	_apply_default_material()
	
	is_active = true
	emit_signal("view_activated")

func deactivate() -> void:
	if not is_active:
		return
		
	print("DefaultView: Deactivating solid view")
	
	is_active = false
	emit_signal("view_deactivated")

func set_color(color: Color) -> void:
	_current_color = color
	
	if is_active:
		_apply_default_material()

func _apply_default_material() -> void:
	var base_material = model_materials.create_colored_material("default_solid", _current_color)
	
	if base_material:
		apply_material_to_meshes(base_material)
		print("DefaultView: Applied colored material with color: ", _current_color)
	else:
		var fallback_material = StandardMaterial3D.new()
		fallback_material.albedo_color = _current_color
		fallback_material.roughness = 0.5
		apply_material_to_meshes(fallback_material)
		print("DefaultView: Applied fallback material")
