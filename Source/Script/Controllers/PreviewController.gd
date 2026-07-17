extends Node

var config_manager = null
var format_registry = null
var browser_controller = null

var model_renderer = null
var camera_controller = null

const _WORLD_GRID_SCENE = preload("res://Scenes/WorldGrid.tscn")

var mesh_colors = {
	0: Color.WHITE,
	1: Color.GREEN,
	2: Color.BLACK,
	3: Color.RED,
	4: Color.CYAN,
	5: Color.PURPLE,
	6: Color.WEB_GRAY
}
var wireframe_colors = {
	0: Color(0.0, 0.8, 1.0, 1.0),
	1: Color.GREEN,
	2: Color.BLACK,
	3: Color.RED,
	4: Color.WHITE,
	5: Color.PURPLE,
	6: Color(1.0, 0.6, 0.0, 1.0)
}

@onready var subviewport_container = %SubViewportContainer_U
@onready var subviewport = %SubViewport_U
@onready var model_root = %model_root
@onready var camera = %"3DView"
@onready var preview_path_field = %PreviewPathInput
@onready var browse_button = %PreviewBrowseButton
@onready var brightness_slider = %BrightnessSlider
@onready var lighting_slider = %LightingSlider
@onready var wireframe_toggle = %WireframeToggle
@onready var wireframe_overlay_toggle = %WireframeOverlayToggle
@onready var world_grid_toggle = %WorldGridToggle
@onready var recenter_button = %RecenterButton
@onready var armor_view_toggle = %ArmorViewToggle
@onready var wireframe_color_option = %WireframeOptionButton
@onready var mesh_color_option = %MeshOptionButton
@onready var tab_container = %TabContainer_U
@onready var status_label = %StatusLabel

func initialize(p_config_manager, p_format_registry, p_browser_controller) -> void:
	config_manager = p_config_manager
	format_registry = p_format_registry
	browser_controller = p_browser_controller

	# World grid
	var world_grid = _WORLD_GRID_SCENE.instantiate()
	model_root.add_child(world_grid)

	# Renderer
	model_renderer = ModelRenderer.new()
	model_renderer.set_target_viewport(subviewport)
	subviewport.add_child(model_renderer)

	# Camera
	camera_controller = CameraController.new(camera)
	camera_controller.initialize(config_manager)
	subviewport.add_child(camera_controller)
	subviewport_container.gui_input.connect(camera_controller._on_viewport_gui_input)
	camera_controller.orbit_point = model_root.global_position
	camera_controller.initial_model_position = model_root.global_position

	# Initial grid state
	var grid_visible = config_manager.get_grid_visible()
	world_grid_toggle.set_pressed_no_signal(grid_visible)
	_set_grid_visible(grid_visible)

	# UI signals
	brightness_slider.value_changed.connect(_on_brightness_changed)
	lighting_slider.value_changed.connect(_on_lighting_changed)
	wireframe_toggle.toggled.connect(_on_wireframe_toggled)
	wireframe_overlay_toggle.toggled.connect(_on_wireframe_overlay_toggled)
	armor_view_toggle.toggled.connect(_on_armor_toggled)
	world_grid_toggle.toggled.connect(_on_grid_toggled)
	recenter_button.pressed.connect(reset_camera)
	browse_button.pressed.connect(_on_browse_preview_pressed)
	tab_container.tab_changed.connect(_on_tab_changed)

	config_manager.config_loaded.connect(apply_loaded_config)

func _process(delta):
	if tab_container.current_tab == 1 and camera_controller:
		camera_controller.process_camera(delta)
		camera_controller.handle_keyboard_navigation(delta)

#========================
# PUBLIC API
#========================
func set_preview_path_text(text: String) -> void:
	preview_path_field.text = text

func set_camera_fov(value) -> void:
	if camera_controller:
		camera_controller.set_camera_fov(value)

func reset_camera() -> void:
	if camera_controller:
		camera_controller.reset_camera()

func apply_loaded_config() -> void:
	_setup_color_options()
	_set_grid_visible(config_manager.get_grid_visible())

	if model_renderer:
		var wireframe_index = config_manager.get_wireframe_color_index()
		var mesh_index = config_manager.get_mesh_color_index()

		if wireframe_colors.has(wireframe_index):
			model_renderer.set_wireframe_color(wireframe_colors[wireframe_index])
		if mesh_colors.has(mesh_index):
			model_renderer.set_default_material_color(mesh_colors[mesh_index])

	if not wireframe_color_option.item_selected.is_connected(_on_wireframe_color_selected):
		wireframe_color_option.item_selected.connect(_on_wireframe_color_selected)
	if not mesh_color_option.item_selected.is_connected(_on_mesh_color_selected):
		mesh_color_option.item_selected.connect(_on_mesh_color_selected)

#========================
# PREVIEW
#========================
func preview_file(file_path):
	if not model_renderer:
		return

	if not (file_path.ends_with(".obj") or file_path.ends_with(".blueprint")):
		return

	var format_handler = null
	if file_path.ends_with(".obj"):
		format_handler = format_registry.get_import_handler_for_extension("obj")
	else:
		format_handler = format_registry.get_import_handler_for_extension("blueprint")

	if not format_handler:
		return

	var model_data = format_handler.import_model(file_path)
	if not model_data:
		return

	model_renderer.render_model(model_data)
	model_renderer.center_model()

	### Lighting Stuff ###
	await get_tree().process_frame

	var combined_aabb = AABB()
	var has_valid_mesh = false

	for mesh_instance in model_renderer._mesh_instances:
		if mesh_instance and mesh_instance.mesh:
			var mesh_aabb = mesh_instance.get_aabb()
			if !has_valid_mesh:
				combined_aabb = mesh_aabb
				has_valid_mesh = true
			else:
				combined_aabb = combined_aabb.merge(mesh_aabb)

	if !has_valid_mesh:
		return

	var model_center = combined_aabb.position + combined_aabb.size / 2
	var half_extents = combined_aabb.size / 2

	var padding = 3.0
	var x_extent = half_extents.x + padding
	var y_extent = half_extents.y + padding
	var z_extent = half_extents.z + padding

	var omni_lights_parent = subviewport.get_node_or_null("World/Omni-Lights")
	var omni_lights = omni_lights_parent.get_children() if omni_lights_parent else []

	if omni_lights.size() >= 6:
		var positions = [
			Vector3(x_extent, 0, 0),
			Vector3(-x_extent, 0, 0),
			Vector3(0, y_extent, 0),
			Vector3(0, -y_extent, 0),
			Vector3(0, 0, z_extent),
			Vector3(0, 0, -z_extent)
		]

		for i in range(min(omni_lights.size(), 6)):
			omni_lights[i].global_position = model_center + positions[i]
			var max_extent = max(max(x_extent, y_extent), z_extent)
			omni_lights[i].omni_range = max_extent * 2

	preview_path_field.text = file_path

	var triangle_count = 0
	var quad_count = 0
	var vertex_count = model_data.get_vertex_count()
	var part_idx = model_data.get_active_part_index()

	if model_data.has_metadata("triangle_count"):
		triangle_count = model_data.get_metadata("triangle_count")
		quad_count = model_data.get_metadata("quad_count", 0)
	elif model_data.has_part_metadata(part_idx, "triangle_count"):
		triangle_count = model_data.get_part_metadata(part_idx, "triangle_count", 0)
		quad_count = model_data.get_part_metadata(part_idx, "quad_count", 0)

	var stats_text = ""
	if file_path.ends_with(".blueprint"):
		stats_text = "Loaded blueprint: " + file_path.get_file() + " (" + str(vertex_count) + " vertices, " + str(triangle_count) + " triangles, " + str(quad_count) + " quads)"
	else:
		stats_text = "Loaded model: " + file_path.get_file() + " (" + str(vertex_count) + " vertices, " + str(triangle_count) + " triangles, " + str(quad_count) + " quads)"

	status_label.text = stats_text

	_update_render_mode()
	camera_controller.focus_on_point(model_root.global_position)

	if tab_container.current_tab != 1:
		tab_container.current_tab = 1

#========================
# UI HANDLERS
#========================
func _on_tab_changed(tab_index):
	if tab_index == 2:
		reset_camera()

func _on_browse_preview_pressed():
	var preview_dir = config_manager.get_saved_path("preview_dir")
	if !preview_dir.is_empty() && DirAccess.dir_exists_absolute(preview_dir):
		browser_controller.browse_open_file(preview_dir, [], _on_preview_file_chosen)
	else:
		browser_controller.browse_open_file("", [], _on_preview_file_chosen)

func _on_preview_file_chosen(path):
	preview_path_field.text = path
	preview_file(path)

func _on_wireframe_toggled(enabled):
	if model_renderer:
		if enabled:
			wireframe_overlay_toggle.button_pressed = false
			armor_view_toggle.button_pressed = false
		_update_render_mode()

func _on_wireframe_overlay_toggled(enabled):
	if model_renderer:
		if enabled:
			wireframe_toggle.button_pressed = false
			armor_view_toggle.button_pressed = false
		_update_render_mode()

func _on_armor_toggled(enabled):
	if model_renderer:
		if enabled:
			wireframe_toggle.button_pressed = false
			wireframe_overlay_toggle.button_pressed = false
		_update_render_mode()

func _on_grid_toggled(enabled):
	_set_grid_visible(enabled)
	if config_manager:
		config_manager.set_grid_visible(enabled)

func _on_brightness_changed(value):
	var world_env = subviewport.get_node_or_null("World/WorldEnvironment")
	if world_env:
		world_env.environment.background_energy_multiplier = value

func _on_lighting_changed(value):
	var lights = get_tree().get_nodes_in_group("Lighting")
	for light in lights:
		light.light_energy = value

func _on_wireframe_color_selected(index):
	if model_renderer:
		model_renderer.set_wireframe_color(wireframe_colors[index])
		config_manager.set_wireframe_color_index(index)

func _on_mesh_color_selected(index):
	if model_renderer:
		model_renderer.set_default_material_color(mesh_colors[index])
		config_manager.set_mesh_color_index(index)

#========================
# HELPERS
#========================
func _set_grid_visible(grid_visible: bool) -> void:
	for child in model_root.get_children():
		if child.name == "WorldGrid":
			child.visible = grid_visible
			break

func _update_render_mode():
	if not model_renderer:
		return
	if armor_view_toggle.button_pressed:
		model_renderer.set_render_mode(ModelRenderer.RenderMode.ARMOR)
	elif wireframe_toggle.button_pressed:
		model_renderer.set_render_mode(ModelRenderer.RenderMode.WIREFRAME)
	elif wireframe_overlay_toggle.button_pressed:
		model_renderer.set_render_mode(ModelRenderer.RenderMode.WIREFRAME_OVERLAY)
	else:
		model_renderer.set_render_mode(ModelRenderer.RenderMode.SOLID)

func _setup_color_options():
	wireframe_color_option.clear()
	wireframe_color_option.add_item("Blue (Default)", 0)
	wireframe_color_option.add_item("Green", 1)
	wireframe_color_option.add_item("Black", 2)
	wireframe_color_option.add_item("Red", 3)
	wireframe_color_option.add_item("White", 4)
	wireframe_color_option.add_item("Purple", 5)
	wireframe_color_option.add_item("Orange", 6)

	var wireframe_index = config_manager.get_wireframe_color_index()
	var mesh_index = config_manager.get_mesh_color_index()

	if wireframe_color_option.get_item_count() > wireframe_index:
		wireframe_color_option.select(wireframe_index)

	mesh_color_option.clear()
	mesh_color_option.add_item("White (Default)", 0)
	mesh_color_option.add_item("Green", 1)
	mesh_color_option.add_item("Black", 2)
	mesh_color_option.add_item("Red", 3)
	mesh_color_option.add_item("Blue", 4)
	mesh_color_option.add_item("Purple", 5)
	mesh_color_option.add_item("Gray", 6)

	if mesh_color_option.get_item_count() > mesh_index:
		mesh_color_option.select(mesh_index)
