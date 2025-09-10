class_name ConversionWorker
extends RefCounted

signal conversion_started(source_path, target_path)
signal conversion_progress(progress)
signal conversion_completed(result)
signal conversion_error(error_message)

var _thread: Thread = null
var _mutex: Mutex = null
var _exit_thread: bool = false
var _is_processing: bool = false
var _current_task: Dictionary = {}
var _format_registry = null

func _init(format_registry = null):
	_format_registry = format_registry
	_mutex = Mutex.new()
	Debug.log("(ConversionWorker) Initialized")

func shutdown():
	Debug.log("(ConversionWorker) Shutting down")
	_mutex.lock()
	_exit_thread = true
	_mutex.unlock()
	
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	Debug.log("(ConversionWorker) Shutdown complete")

func is_busy() -> bool:
	_mutex.lock()
	var busy = _is_processing
	_mutex.unlock()
	return busy

func start_conversion(source_path: String, target_path: String, options: Dictionary = {}) -> bool:
	_mutex.lock()
	
	if _is_processing:
		_mutex.unlock()
		Debug.log("(ConversionWorker) Already processing, rejecting new task")
		return false
	
	var source_format = source_path.get_extension().to_lower()
	var target_format = target_path.get_extension().to_lower()
	
	_current_task = {
		"source_path": source_path,
		"target_path": target_path,
		"source_format": source_format,
		"target_format": target_format,
		"options": options
	}
	
	_is_processing = true
	_mutex.unlock()
	
	# Start the conversion thread
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	
	_thread = Thread.new()
	_thread.start(Callable(self, "_thread_function"))
	
	Debug.log("(ConversionWorker) Conversion started: ", source_path, " -> ", target_path)
	return true

func cancel_conversion() -> bool:
	_mutex.lock()
	
	if not _is_processing:
		_mutex.unlock()
		return false
	
	# Set exit flag to signal cancellation
	_exit_thread = true
	_mutex.unlock()
	
	Debug.log("(ConversionWorker) Cancellation requested")
	return true

func _thread_function():
	Debug.call_deferred("log", "(ConversionWorker) Thread started")
	
	_mutex.lock()
	var task = _current_task.duplicate()
	_mutex.unlock()
	
	if task.is_empty():
		_cleanup_after_completion()
		return
	
	call_deferred("emit_signal", "conversion_started", task.source_path, task.target_path)
	
	var result = _process_task(task)
	
	if result.has("error") and not result.error.is_empty():
		call_deferred("emit_signal", "conversion_error", result.error)
	else:
		call_deferred("emit_signal", "conversion_completed", result)
	
	_cleanup_after_completion()

func _cleanup_after_completion():
	_mutex.lock()
	_is_processing = false
	_current_task = {}
	_exit_thread = false
	_mutex.unlock()
	Debug.call_deferred("log", "(ConversionWorker) Thread completed and cleaned up")

func _process_task(task: Dictionary) -> Dictionary:
	Debug.call_deferred("log", "=== CONVERSION STARTED ===")
	Debug.call_deferred("log", "Source: ", task.source_path)
	Debug.call_deferred("log", "Target: ", task.target_path)
	Debug.call_deferred("log", "Format: ", task.source_format, " -> ", task.target_format)
	
	var result = {
		"success": false,
		"source_path": task.source_path,
		"target_path": task.target_path,
		"source_format": task.source_format,
		"target_format": task.target_format,
		"error": "",
		"error_code": 0,
		"statistics": {}
	}
	
	if _should_cancel():
		Debug.call_deferred("log", "WORKER: Task cancelled before start")
		result.error = "Conversion cancelled"
		return result
	
	# === GET FORMAT HANDLERS ===
	Debug.call_deferred("log", "WORKER: Getting format handlers")
	var source_format_handler = null
	var target_format_handler = null
	
	if _format_registry:
		source_format_handler = _format_registry.get_import_handler_for_extension(task.source_format)
		target_format_handler = _format_registry.get_export_handler_for_extension(task.target_format)
	
	if not source_format_handler:
		Debug.call_deferred("log", "WORKER: ERROR - No import handler for: ", task.source_format)
		result.error = "Unsupported source format: " + task.source_format
		return result
	
	if not target_format_handler:
		Debug.call_deferred("log", "WORKER: ERROR - No export handler for: ", task.target_format)
		result.error = "Unsupported target format: " + task.target_format
		return result
	
	Debug.call_deferred("log", "WORKER: Format handlers found successfully")
	_report_progress(0.0)
	
	# === IMPORT MODEL ===
	Debug.call_deferred("log", "WORKER: Starting model import from ", task.source_format)
	var model_data = null
	var error = OK
	
	if error == OK:
		Debug.call_deferred("log", "WORKER: Calling import_model() on source handler")
		model_data = source_format_handler.import_model(task.source_path, task.options)
		
		if not model_data:
			Debug.call_deferred("log", "WORKER: ERROR - import_model() returned null")
			result.error = "Failed to import model from " + task.source_path
			return result
		else:
			Debug.call_deferred("log", "WORKER: Model imported successfully")
			Debug.call_deferred("log", "WORKER: Imported vertex count: ", model_data.vertices.size())
			Debug.call_deferred("log", "WORKER: Imported face count: ", model_data.get_face_count())
	else:
		Debug.call_deferred("log", "WORKER: ERROR during import setup: ", str(error))
		result.error = "Error during import: " + str(error)
		result.error_code = error
		return result
	
	if _should_cancel():
		Debug.call_deferred("log", "WORKER: Task cancelled after import")
		result.error = "Conversion cancelled"
		return result
	
	_report_progress(0.5)
	Debug.call_deferred("log", "WORKER: 50% - Import complete, starting transformations")
	
	# === APPLY TRANSFORMATIONS ===
	if task.options.has("transformations"):
		Debug.call_deferred("log", "WORKER: Applying ", task.options.transformations.size(), " transformations")
		for i in range(task.options.transformations.size()):
			var transform = task.options.transformations[i]
			Debug.call_deferred("log", "WORKER: Applying transformation ", i + 1, ": ", transform.type)
			match transform.type:
				"scale":
					var scale_transform = Transform3D().scaled(Vector3(transform.x, transform.y, transform.z))
					model_data.transform(scale_transform)
					Debug.call_deferred("log", "WORKER: Scale applied: ", Vector3(transform.x, transform.y, transform.z))
				"rotate":
					var rotation = Basis().rotated(Vector3.RIGHT, transform.x) \
										 .rotated(Vector3.UP, transform.y) \
										 .rotated(Vector3.FORWARD, transform.z)
					model_data.transform(Transform3D(rotation, Vector3.ZERO))
					Debug.call_deferred("log", "WORKER: Rotation applied")
				"translate":
					var translation = Transform3D(Basis(), Vector3(transform.x, transform.y, transform.z))
					model_data.transform(translation)
					Debug.call_deferred("log", "WORKER: Translation applied: ", Vector3(transform.x, transform.y, transform.z))
	else:
		Debug.call_deferred("log", "WORKER: No transformations to apply")
	
	if _should_cancel():
		Debug.call_deferred("log", "WORKER: Task cancelled after transformations")
		result.error = "Conversion cancelled"
		return result
	
	_report_progress(0.75)
	Debug.call_deferred("log", "WORKER: 75% - Transformations complete, starting export")
	
	# === EXPORT MODEL ===
	Debug.call_deferred("log", "WORKER: Starting export to ", task.target_format)
	var export_result = target_format_handler.export_model(model_data, task.target_path, task.options)
	
	if _should_cancel():
		Debug.call_deferred("log", "WORKER: Task cancelled during export")
		result.error = "Conversion cancelled"
		return result
	
	_report_progress(1.0)
	Debug.call_deferred("log", "WORKER: 100% - Export complete")
	
	if not export_result.success:
		Debug.call_deferred("log", "WORKER: Export failed: ", export_result.error)
		result.error = export_result.error
		return result
	
	# === FINALIZE RESULT ===
	result.statistics = {
		"vertex_count": model_data.vertices.size(),
		"face_count": model_data.get_face_count(),
		"material_count": model_data.metadata.get("material_count", 0),
		"triangle_count": model_data.metadata.get("triangle_count", 0),
		"quad_count": model_data.metadata.get("quad_count", 0)
	}
	
	Debug.call_deferred("log", "WORKER: Final statistics:")
	Debug.call_deferred("log", "  - Vertices: ", result.statistics.vertex_count)
	Debug.call_deferred("log", "  - Faces: ", result.statistics.face_count)
	Debug.call_deferred("log", "  - Materials: ", result.statistics.material_count)
	Debug.call_deferred("log", "  - Triangles: ", result.statistics.triangle_count)
	Debug.call_deferred("log", "  - Quads: ", result.statistics.quad_count)
	
	for key in export_result:
		if key != "success" and key != "error":
			result[key] = export_result[key]
	
	result.success = true
	Debug.call_deferred("log", "=== CONVERSION COMPLETED SUCCESSFULLY ===")
	return result

func _should_cancel() -> bool:
	_mutex.lock()
	var should_cancel = _exit_thread
	_mutex.unlock()
	return should_cancel

func _report_progress(progress: float) -> void:
	call_deferred("emit_signal", "conversion_progress", progress)
	Debug.call_deferred("log", "Conversion progress: ", progress)
