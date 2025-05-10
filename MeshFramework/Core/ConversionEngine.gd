class_name ConversionEngine
extends Node

signal conversion_started(source_path, target_path)
signal conversion_progress(progress)
signal conversion_completed(result)
signal conversion_error(error_message)

var _conversion_queue = []
var _current_conversion = null
var _format_registry = null

func _ready():
	_format_registry = FormatRegistry.new()

func queue_conversion(source_path: String, target_path: String, options: Dictionary = {}):
	var source_format = source_path.get_extension().to_lower()
	var target_format = target_path.get_extension().to_lower()

	var task = {
		"source_path": source_path,
		"target_path": target_path,
		"source_format": source_format,
		"target_format": target_format,
		"options": options
	}

	_conversion_queue.append(task)
	_process_queue()

func _process_queue():
	if _current_conversion or _conversion_queue.size() == 0:
		return
	
	_current_conversion = _conversion_queue.pop_front()
	emit_signal("conversion_started", _current_conversion.source_path, _current_conversion.target_path)

	call_deferred("_process_conversion", _current_conversion)

func _process_conversion(task):
	var result = {
		"success": false,
		"source_path": task.source_path,
		"target_path": task.target_path,
		"error": "",
		"statistics": {}
	}

	var model_data = _format_registry.load(task.source_path, task.source_format)
	if not model_data:
		result.error = "Failed to load source file"
		emit_signal("conversion_error", result.error)
		_finalize_conversion()
		return

	emit_signal("conversion_progress", 0.3)
	print("30%")
	
	debug_model_topology(model_data)
	
	_apply_transformations(model_data, task.options)

	emit_signal("conversion_progress", 0.6)
	print("60%")

	var save_result = _format_registry.save(model_data, task.target_path, task.target_format, task.options)
	print("65%")
	if not save_result.success:
		result.error = save_result.error
		emit_signal("conversion_error", result.error)
		_finalize_conversion()
		return
	
	emit_signal("conversion_progress", 1.0)
	print("100%")
	result.success = true
	result.statistics = {
		"vertex_count": model_data.vertices.size(),
		"face_count": model_data.get_face_count(),
		"material_count": model_data.materials.size()
	}
	emit_signal("conversion_completed", result)
	
	debug_model_topology(model_data)
	_finalize_conversion()

func _apply_transformations(model_data, options):
	if options.has("transformations"):
		for transform in options.transformations:
			match transform.type:
				"scale":
					model_data.transform(Transform3D().scaled(Vector3(transform.x, transform.y, transform.z)))
				"rotate":
					var rotation = Basis().rotated(Vector3.RIGHT, transform.x).rotated(Vector3.UP, transform.y).rotated(Vector3.FORWARD, transform.z)
					model_data.transform(Transform3D(rotation, Vector3.ZERO))
				"translate":
					model_data.transform(Transform3D(Basis(), Vector3(transform.x, transform.y, transform.z)))

func _finalize_conversion():
	_current_conversion = null
	_process_queue()


func debug_model_topology(model_data: ModelData) -> void:
	print("=== MODEL TOPOLOGY DEBUG ===")
	print("Vertex count: ", model_data.vertices.size())
	print("Index count: ", model_data.indices.size())
	print("Is quad mesh: ", model_data.topology.is_quad_mesh)
	print("Quad count: ", model_data.topology.quads.size())
	print("Has original faces: ", model_data.has_metadata("original_faces"))
	
	if model_data.has_metadata("original_faces"):
		var faces = model_data.get_metadata("original_faces")
		print("Original face count: ", faces.size())
		
		var tri_count = 0
		var quad_count = 0
		var other_count = 0
		
		for face in faces:
			if face.size() == 3:
				tri_count += 1
			elif face.size() == 4:
				quad_count += 1
			else:
				other_count += 1
		
		print("Face types - Triangles: ", tri_count, 
			  ", Quads: ", quad_count, 
			  ", Other: ", other_count)
	print("==========================")
