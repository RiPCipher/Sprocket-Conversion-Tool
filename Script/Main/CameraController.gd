class_name CameraController
extends Node

signal camera_moved(position, rotation)
signal zoom_changed(zoom_level)
signal fov_changed(value)

var camera: Camera3D

enum CameraMode {
	ORBIT,
	FREE
}

var orbit_point: Vector3 = Vector3.ZERO
var initial_model_position: Vector3 = Vector3.ZERO

var vertical_rotation_limit: float = 1.5  # ~80 degrees
var max_pan_distance: float = 10.0
var pan_sensitivity: float = 0.01
var rotation_sensitivity: float = 0.005
var camera_zoom_speed: float = 0.5
var camera_min_distance: float = 0.5
var camera_max_distance: float = 20.0
var camera_bounds_radius: float = 15.0
var constraint_margin: float = 0.5
var zoom_step: float = 0.01
var zoom_smoothing: float = 10.0
var camera_fov_change_amount = 1.0
var min_fov = 30.0
var max_fov = 120.0

var target_zoom_distance: float = 5.0
var last_camera_distance: float = 5.0
var zoom_acceleration: float = 0.0
var is_panning: bool = false
var is_rotating: bool = false
var camera_distance_locked: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO
var free_camera_mode: bool = false
var original_camera_transform: Transform3D

var mouse_captured = false
var mouse_sensitivity = 0.002

var prev_free_cam_pressed: bool = false
var prev_key_1_pressed: bool = false
var prev_key_2_pressed: bool = false

var config_manager = null

func _init(p_camera: Camera3D):
	camera = p_camera
	
	target_zoom_distance = 5.0
	last_camera_distance = 5.0
	
	original_camera_transform = camera.global_transform

func initialize(p_config_manager = null):
	config_manager = p_config_manager
	
	if config_manager and config_manager.settings.has("preview") and config_manager.settings.preview.has("camera_fov"):
		set_camera_fov(config_manager.settings.preview.camera_fov)

func set_camera_fov(fov_value: float):
	fov_value = clamp(fov_value, min_fov, max_fov)
	camera.fov = fov_value
		
	if config_manager and config_manager.settings.has("preview"):
		config_manager.settings.preview.camera_fov = fov_value
	
	emit_signal("fov_changed", fov_value)

func process_camera(delta):
	if free_camera_mode:
		return
		
	var current_distance = camera.global_position.distance_to(orbit_point)
	
	if abs(current_distance - target_zoom_distance) <= 0.001:
		zoom_acceleration = 0.0
		return
	
	var zoom_direction = sign(target_zoom_distance - current_distance)
	var zoom_distance = abs(target_zoom_distance - current_distance)
	
	zoom_acceleration = lerp(zoom_acceleration, zoom_direction * min(zoom_distance, 0.3), delta * 3.0)
	
	var new_distance = current_distance + zoom_acceleration * delta * 15.0
	
	if zoom_direction > 0 and new_distance > target_zoom_distance:
		new_distance = target_zoom_distance
		zoom_acceleration = 0.0
	elif zoom_direction < 0 and new_distance < target_zoom_distance:
		new_distance = target_zoom_distance
		zoom_acceleration = 0.0
		
	var direction = (camera.global_position - orbit_point).normalized()
	
	camera.global_position = orbit_point + direction * new_distance
	
	last_camera_distance = camera.global_position.distance_to(orbit_point)
	_constrain_camera_to_bounds()

func handle_keyboard_navigation(delta):
	if free_camera_mode:
		var input_dir = Vector3()
		var speed = 1.0
		if Input.is_key_pressed(KEY_SHIFT):
			speed = 5.0
		if Input.is_key_pressed(KEY_W):
			input_dir += -camera.global_transform.basis.z
		if Input.is_key_pressed(KEY_S):
			input_dir += camera.global_transform.basis.z
		if Input.is_key_pressed(KEY_A):
			input_dir += -camera.global_transform.basis.x
		if Input.is_key_pressed(KEY_D):
			input_dir += camera.global_transform.basis.x
		if Input.is_key_pressed(KEY_E):
			input_dir += Vector3.UP
		if Input.is_key_pressed(KEY_Q):
			input_dir += -Vector3.UP
		
		if input_dir.length() > 0:
			input_dir = input_dir.normalized()
			camera.global_position += input_dir * delta * speed
	else:
		if Input.is_key_pressed(KEY_W):
			var orbit_delta = Vector2(0.0, 7.0)
			orbit_camera(orbit_delta)
		if Input.is_key_pressed(KEY_S):
			var orbit_delta = Vector2(0.0, -7.0)
			orbit_camera(orbit_delta)
		if Input.is_key_pressed(KEY_A):
			var orbit_delta = Vector2(7.0, 0.0)
			orbit_camera(orbit_delta)
		if Input.is_key_pressed(KEY_D):
			var orbit_delta = Vector2(-7.0, 0.0)
			orbit_camera(orbit_delta)
	
	if config_manager and config_manager.settings.has("keybinds"):
		var recenter_key = config_manager.get_keybind("recenter_key")
		if recenter_key != 0 and Input.is_key_pressed(recenter_key):
			reset_camera()
		
		var zoom_out_key = config_manager.get_keybind("zoom_out_key")
		if zoom_out_key != 0 and Input.is_key_pressed(zoom_out_key):
			zoom_camera_buttons(camera_zoom_speed * 0.5)
		
		var zoom_in_key = config_manager.get_keybind("zoom_in_key")
		if zoom_in_key != 0 and Input.is_key_pressed(zoom_in_key):
			zoom_camera_buttons(-camera_zoom_speed * 0.5)
			
		var increase_fov_key = config_manager.get_keybind("increase_fov_key")
		if increase_fov_key != 0 and Input.is_key_pressed(increase_fov_key):
			increase_camera_fov()
		
		var decrease_fov_key = config_manager.get_keybind("decrease_fov_key")
		if decrease_fov_key != 0 and Input.is_key_pressed(decrease_fov_key):
			decrease_camera_fov()
			
		var free_cam_key = config_manager.get_keybind("free_cam_key")
		if free_cam_key != 0:
			var is_pressed = Input.is_key_pressed(free_cam_key)
			if is_pressed and !prev_free_cam_pressed:
				toggle_free_camera()
			prev_free_cam_pressed = is_pressed
		
		var key_1_pressed = Input.is_key_pressed(KEY_1)
		if key_1_pressed and !prev_key_1_pressed:
			set_top_view()
		prev_key_1_pressed = key_1_pressed
	
		var key_2_pressed = Input.is_key_pressed(KEY_2)
		if key_2_pressed and !prev_key_2_pressed:
			set_side_view()
		prev_key_2_pressed = key_2_pressed

func orbit_camera(delta: Vector2):
	var current_distance = camera.global_position.distance_to(orbit_point)
	var current_vertical_angle = get_vertical_angle()
	var rotation_y = Quaternion(Vector3.UP, -delta.x * rotation_sensitivity)
	var camera_right = camera.global_transform.basis.x
	var rotation_x = Quaternion(camera_right, -delta.y * rotation_sensitivity)
	var relative_pos = camera.global_position - orbit_point
	
	relative_pos = rotation_y * relative_pos
	
	var new_vertical_angle = current_vertical_angle - delta.y * rotation_sensitivity
	if new_vertical_angle > -vertical_rotation_limit and new_vertical_angle < vertical_rotation_limit:
		relative_pos = rotation_x * relative_pos
	
	relative_pos = relative_pos.normalized() * current_distance
	
	camera.global_position = orbit_point + relative_pos
	
	camera.look_at(orbit_point)
	
	last_camera_distance = current_distance

func get_vertical_angle() -> float:
	var forward = (orbit_point - camera.global_position).normalized()
	var up = Vector3.UP
	var right = forward.cross(up).normalized()
	var actual_up = right.cross(forward).normalized()
	return asin(forward.dot(up))

func zoom_camera(zoom_amount: float):
	var adjusted_amount = zoom_amount * 0.5
	
	target_zoom_distance = clamp(target_zoom_distance + adjusted_amount, camera_min_distance, camera_max_distance)
	
	zoom_acceleration = zoom_acceleration + (adjusted_amount * 0.5)
	
	emit_signal("zoom_changed", target_zoom_distance)

func zoom_camera_buttons(zoom_amount: float):
	target_zoom_distance = clamp(target_zoom_distance + (zoom_amount * 0.5), camera_min_distance, camera_max_distance)
	zoom_acceleration = zoom_acceleration + (zoom_amount * 0.5) * 0.5
	
	emit_signal("zoom_changed", target_zoom_distance)

func _constrain_camera_to_bounds():
	if free_camera_mode:
		return
	
	var camera_pos = camera.global_position
	var model_pos = orbit_point
	
	var to_camera = camera_pos - model_pos
	var distance = to_camera.length()
	
	if distance > camera_bounds_radius - constraint_margin:
		camera.global_position = model_pos + to_camera.normalized() * (camera_bounds_radius - constraint_margin)

func pan_camera(delta: Vector2):
	var current_distance = camera.global_position.distance_to(orbit_point)
	
	var forward = (orbit_point - camera.global_position).normalized()
	var right = forward.cross(Vector3.UP).normalized()
	var up = right.cross(forward).normalized()
	
	var distance_factor = clamp(current_distance * 0.08, 0.1, 10.0)
	var movement = right * -delta.x * pan_sensitivity * distance_factor + up * delta.y * pan_sensitivity * distance_factor
	
	var new_pivot_position = orbit_point + movement
	
	var distance_from_model = new_pivot_position.distance_to(initial_model_position)
	
	if distance_from_model <= max_pan_distance:
		camera.global_position += movement
		orbit_point += movement
	else:
		var dir_to_model = (initial_model_position - orbit_point).normalized()
		var clamped_position = initial_model_position + (new_pivot_position - initial_model_position).normalized() * max_pan_distance
		
		var actual_movement = clamped_position - orbit_point
		camera.global_position += actual_movement
		orbit_point = clamped_position
	
	camera.look_at(orbit_point)

func _on_viewport_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(-camera_zoom_speed)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(camera_zoom_speed) 
			get_viewport().set_input_as_handled()
			return
	
	if free_camera_mode:
		if event is InputEventMouseMotion:
			camera.rotate_y(-event.relative.x * mouse_sensitivity)
			var rotation_axis = camera.global_transform.basis.x
			camera.rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
			var camera_up = camera.global_transform.basis.y
			var dot = camera_up.dot(Vector3.UP)
			if dot < 0.1:
				var correction_angle = 0.1 - dot
				camera.rotate_object_local(Vector3.RIGHT, -correction_angle)
		
			get_viewport().set_input_as_handled()
			return
	
	if !free_camera_mode:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var pan_key = KEY_SHIFT
				
				if config_manager and config_manager.settings.has("keybinds"):
					pan_key = config_manager.get_keybind("pan_key")
				
				if Input.is_key_pressed(pan_key):
					is_panning = event.pressed
					is_rotating = false
				else:
					is_rotating = event.pressed
					is_panning = false
				
				last_mouse_pos = event.position
		
		elif event is InputEventMouseMotion:
			var delta = event.position - last_mouse_pos
			last_mouse_pos = event.position
			
			if is_rotating and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
				orbit_camera(delta)
			
			elif is_panning and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
				pan_camera(delta)

func focus_on_point(point: Vector3, distance: float = 5.0):
	orbit_point = point
	initial_model_position = point
	target_zoom_distance = distance
	
	var current_dir = (camera.global_position - orbit_point).normalized()
	camera.global_position = orbit_point + current_dir * target_zoom_distance
	
	camera.look_at(orbit_point)
	
	last_camera_distance = target_zoom_distance

func reset_camera():
	orbit_point = initial_model_position
	var current_dir = (camera.global_position - orbit_point).normalized()
	camera.global_position = orbit_point + current_dir * target_zoom_distance
	camera.look_at(orbit_point)
	
	last_camera_distance = target_zoom_distance
	camera_distance_locked = false

func increase_camera_fov():
	if camera:
		var new_fov = camera.fov + camera_fov_change_amount
		set_camera_fov(new_fov)
		return new_fov
	return 0.0

func decrease_camera_fov():
	if camera:
		var new_fov = camera.fov - camera_fov_change_amount
		set_camera_fov(new_fov)
		return new_fov
	return 0.0

func toggle_free_camera():
	free_camera_mode = !free_camera_mode
	
	if free_camera_mode:
		original_camera_transform = camera.global_transform
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		camera.global_transform = original_camera_transform
		camera.look_at(orbit_point)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func set_top_view():
	var current_distance = camera.global_position.distance_to(orbit_point)
	
	camera.global_transform = Transform3D()
	
	camera.global_position = orbit_point + Vector3(0.001, current_distance, 0.001)
	
	camera.rotation_degrees = Vector3(-90, 0, 0)
	
	target_zoom_distance = current_distance
	last_camera_distance = current_distance

func set_side_view():
	var current_distance = camera.global_position.distance_to(orbit_point)
		
	camera.global_position = orbit_point + Vector3(current_distance, 0, 0)
	camera.look_at(orbit_point)
		
	target_zoom_distance = current_distance
	last_camera_distance = current_distance
