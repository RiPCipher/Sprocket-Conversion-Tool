class_name ConversionWorker
extends RefCounted

signal conversion_started(task_id, source_path, target_path)
signal conversion_progress(task_id, progress)
signal conversion_completed(task_id, result)
signal conversion_error(task_id, error_message)
signal worker_idle()

enum WorkerState {
	IDLE,
	WORKING,
	CANCELING,
	ERROR
}

var _thread: Thread = null
var _mutex: Mutex = null
var _semaphore: Semaphore = null
var _exit_thread: bool = false
var _state: int = WorkerState.IDLE
var _current_task: Dictionary = {}
var _worker_id: int = 0
var _format_registry = null

func _init(worker_id: int, format_registry = null):
	_worker_id = worker_id
	_format_registry = format_registry
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	_start_thread()

func shutdown():
	_mutex.lock()
	_exit_thread = true
	_mutex.unlock()
	
	_semaphore.post()
	
	if _thread and _thread.is_started():
		_thread.wait_to_finish()

func _pre_allocate_resources():
	_thread = Thread.new()
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()

func _start_thread():
	if _thread and _thread.is_started():
		return
	
	_thread = Thread.new()
	_thread.start(Callable(self, "_thread_function"))

func _thread_function():
	while true:
		_semaphore.wait()
		
		_mutex.lock()
		if _exit_thread:
			_mutex.unlock()
			break
		
		var task = _current_task.duplicate()
		_mutex.unlock()
		
		if task.is_empty():
			continue
		
		call_deferred("emit_signal", "conversion_started", task.id, task.source_path, task.target_path)
		
		var result = _process_task(task)
		
		call_deferred("_on_conversion_completed", task.id, result)

func _process_task(task: Dictionary) -> Dictionary:
	var result = {
		"success": false,
		"task_id": task.id,
		"source_path": task.source_path,
		"target_path": task.target_path,
		"source_format": task.source_format,
		"target_format": task.target_format,
		"error": "",
		"statistics": {}
	}
	
	_mutex.lock()
	_state = WorkerState.WORKING
	_mutex.unlock()
	
	var progress_callback = Callable(self, "_report_progress").bind(task.id)
	
	if _should_cancel():
		result.error = "Conversion cancelled"
		return result
	
	var source_format_handler = null
	var target_format_handler = null
	
	if _format_registry:
		source_format_handler = _format_registry.get_import_handler_for_extension(task.source_format)
		target_format_handler = _format_registry.get_export_handler_for_extension(task.target_format)
	
	if not source_format_handler:
		result.error = "Unsupported source format: " + task.source_format
		_report_error(task.id, result.error)
		return result
	
	if not target_format_handler:
		result.error = "Unsupported target format: " + task.target_format
		_report_error(task.id, result.error)
		return result
	
	_report_progress(task.id, 0.0)
	
	var model_data = null
	
	var error = OK
	
	if error == OK:
		model_data = source_format_handler.import_model(task.source_path, task.options)
		
		if not model_data:
			result.error = "Failed to import model from " + task.source_path
			_report_error(task.id, result.error)
			return result
	else:
		result.error = "Error during import: " + str(error)
		_report_error(task.id, result.error)
		return result
	
	if _should_cancel():
		result.error = "Conversion cancelled"
		return result
	
	_report_progress(task.id, 0.5)
	
	if task.options.has("transformations"):
		for transform in task.options.transformations:
			match transform.type:
				"scale":
					var scale_transform = Transform3D().scaled(Vector3(transform.x, transform.y, transform.z))
					model_data.transform(scale_transform)
				"rotate":
					var rotation = Basis().rotated(Vector3.RIGHT, transform.x) \
										 .rotated(Vector3.UP, transform.y) \
										 .rotated(Vector3.FORWARD, transform.z)
					model_data.transform(Transform3D(rotation, Vector3.ZERO))
				"translate":
					var translation = Transform3D(Basis(), Vector3(transform.x, transform.y, transform.z))
					model_data.transform(translation)
	
	if _should_cancel():
		result.error = "Conversion cancelled"
		return result
	
	var validation = target_format_handler.validate_for_export(model_data)
	if not validation.valid:
		result.error = "Validation failed for export: " + str(validation.errors)
		_report_error(task.id, result.error)
		return result
	
	if validation.warnings.size() > 0:
		result["warnings"] = validation.warnings
	
	var export_result = {}
	
	if error == OK:
		export_result = target_format_handler.export_model(model_data, task.target_path, task.options)
		
		if not export_result.success:
			result.error = "Failed to export model: " + export_result.error
			_report_error(task.id, result.error)
			return result
	else:
		result.error = "Error during export: " + str(error)
		_report_error(task.id, result.error)
		return result
	
	_report_progress(task.id, 1.0)
	
	result.statistics = {
		"vertex_count": model_data.vertices.size(),
		"face_count": model_data.get_face_count(),
		"material_count": model_data.materials.size(),
		"triangle_count": model_data.metadata.get("triangle_count", 0),
		"quad_count": model_data.metadata.get("quad_count", 0)
	}
	
	for key in export_result:
		if key != "success" and key != "error":
			result[key] = export_result[key]
	
	result.success = true
	return result

func assign_task(task: Dictionary) -> bool:
	_mutex.lock()
	
	if _state != WorkerState.IDLE:
		_mutex.unlock()
		return false
	
	_current_task = task
	_state = WorkerState.WORKING
	_mutex.unlock()
	
	_semaphore.post()
	return true

func cancel_current_task() -> bool:
	_mutex.lock()
	
	if _state != WorkerState.WORKING:
		_mutex.unlock()
		return false
	
	_state = WorkerState.CANCELING
	_mutex.unlock()
	return true

func _should_cancel() -> bool:
	_mutex.lock()
	var should_cancel = _state == WorkerState.CANCELING
	_mutex.unlock()
	return should_cancel

func _report_progress(task_id: int, progress: float) -> void:
	call_deferred("emit_signal", "conversion_progress", task_id, progress)

func _report_error(task_id: int, error: String) -> void:
	_mutex.lock()
	_state = WorkerState.ERROR
	_mutex.unlock()
	
	call_deferred("emit_signal", "conversion_error", task_id, error)

func _on_conversion_completed(task_id: int, result: Dictionary) -> void:
	_mutex.lock()
	_state = WorkerState.IDLE
	_current_task = {}
	_mutex.unlock()
	
	emit_signal("conversion_completed", task_id, result)
	emit_signal("worker_idle")

func get_state() -> int:
	_mutex.lock()
	var state = _state
	_mutex.unlock()
	return state

func get_worker_id() -> int:
	return _worker_id

func is_busy() -> bool:
	_mutex.lock()
	var busy = _state != WorkerState.IDLE
	_mutex.unlock()
	return busy
