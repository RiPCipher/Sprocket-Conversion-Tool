class_name ThreadPool
extends RefCounted

signal conversion_started(task_id, source_path, target_path)
signal conversion_progress(task_id, progress)
signal conversion_completed(task_id, result)
signal conversion_error(task_id, error_message)
signal all_tasks_completed()

var _workers = []
var _task_queue = []
var _active_tasks = {}
var _next_task_id = 1
var _mutex: Mutex = null
var _format_registry = null
var _max_concurrent_tasks: int = 4

func _init(format_registry = null, max_concurrent_tasks: int = 4):
	_format_registry = format_registry
	_max_concurrent_tasks = max_concurrent_tasks
	_mutex = Mutex.new()
	_initialize_workers()

func _initialize_workers():
	for i in range(_max_concurrent_tasks):
		var worker = ConversionWorker.new(i, _format_registry)
		
		worker.conversion_started.connect(_on_worker_conversion_started)
		worker.conversion_progress.connect(_on_worker_conversion_progress)
		worker.conversion_completed.connect(_on_worker_conversion_completed)
		worker.conversion_error.connect(_on_worker_conversion_error)
		worker.worker_idle.connect(_on_worker_idle)
		
		_workers.append(worker)
	
	for worker in _workers:
		worker._pre_allocate_resources()

func shutdown():
	_mutex.lock()
	_task_queue.clear()
	_mutex.unlock()
	
	for worker in _workers:
		worker.cancel_current_task()
		worker.shutdown()
	
	_workers.clear()

func queue_conversion(source_path: String, target_path: String, options: Dictionary = {}) -> int:
	var source_format = source_path.get_extension().to_lower()
	var target_format = target_path.get_extension().to_lower()
	
	_mutex.lock()
	
	var task_id = _next_task_id
	_next_task_id += 1
	
	var task = {
		"id": task_id,
		"source_path": source_path,
		"target_path": target_path,
		"source_format": source_format,
		"target_format": target_format,
		"options": options,
		"queued_time": Time.get_ticks_msec()
	}
	
	_task_queue.append(task)
	_mutex.unlock()
	
	_assign_tasks_to_idle_workers()
	
	return task_id

func _assign_tasks_to_idle_workers() -> void:
	if _task_queue.size() == 0:
		return
	
	var workers_to_assign = []
	var tasks_to_assign = []
	
	_mutex.lock()
	
	for worker in _workers:
		if worker.get_state() == 0 and _task_queue.size() > 0:
			tasks_to_assign.append(_task_queue.pop_front())
			workers_to_assign.append(worker)
			_active_tasks[tasks_to_assign[-1].id] = tasks_to_assign[-1]
	
	_mutex.unlock()
	
	for i in range(workers_to_assign.size()):
		workers_to_assign[i].assign_task(tasks_to_assign[i].duplicate())

func cancel_task(task_id: int) -> bool:
	_mutex.lock()
	
	for i in range(_task_queue.size()):
		if _task_queue[i].id == task_id:
			_task_queue.remove_at(i)
			_mutex.unlock()
			return true
	
	if _active_tasks.has(task_id):
		var task = _active_tasks[task_id]
		_mutex.unlock()
		
		for worker in _workers:
			_mutex.lock()
			var current_task = worker._current_task
			_mutex.unlock()
			
			if current_task.has("id") and current_task.id == task_id:
				return worker.cancel_current_task()
		
		return false
	
	_mutex.unlock()
	return false

func cancel_all_tasks() -> void:
	_mutex.lock()
	
	_task_queue.clear()
	
	var active_ids = _active_tasks.keys()
	
	_mutex.unlock()
	
	for task_id in active_ids:
		cancel_task(task_id)

func get_pending_task_count() -> int:
	_mutex.lock()
	var count = _task_queue.size()
	_mutex.unlock()
	return count

func get_active_task_count() -> int:
	_mutex.lock()
	var count = _active_tasks.size()
	_mutex.unlock()
	return count

func get_all_task_ids() -> Array:
	_mutex.lock()
	
	var ids = []
	
	for task_id in _active_tasks:
		ids.append(task_id)
	
	for task in _task_queue:
		ids.append(task.id)
	
	_mutex.unlock()
	return ids

func _on_worker_conversion_started(task_id: int, source_path: String, target_path: String) -> void:
	emit_signal("conversion_started", task_id, source_path, target_path)

func _on_worker_conversion_progress(task_id: int, progress: float) -> void:
	emit_signal("conversion_progress", task_id, progress)

func _on_worker_conversion_completed(task_id: int, result: Dictionary) -> void:
	_mutex.lock()
	if _active_tasks.has(task_id):
		_active_tasks.erase(task_id)
	_mutex.unlock()
	
	emit_signal("conversion_completed", task_id, result)
	
	_check_all_completed()

func _on_worker_conversion_error(task_id: int, error_message: String) -> void:
	_mutex.lock()
	if _active_tasks.has(task_id):
		_active_tasks.erase(task_id)
	_mutex.unlock()
	
	emit_signal("conversion_error", task_id, error_message)
	
	_check_all_completed()

func _on_worker_idle() -> void:
	_assign_tasks_to_idle_workers()

func _check_all_completed() -> void:
	_mutex.lock()
	var pending_count = _task_queue.size()
	var active_count = _active_tasks.size()
	_mutex.unlock()
	
	if pending_count == 0 and active_count == 0:
		emit_signal("all_tasks_completed")

# Never should be a task queue, but might expand in the future and be needed
func prioritize_queue(criteria: String = "time") -> void:
	_mutex.lock()
	
	match criteria:
		"time":
			_task_queue.sort_custom(func(a, b): return a.queued_time < b.queued_time)
		"size":
			_task_queue.sort_custom(func(a, b): 
				var a_file = FileAccess.open(a.source_path, FileAccess.READ)
				var b_file = FileAccess.open(b.source_path, FileAccess.READ)
				var a_size = a_file.get_length() if a_file else 0
				var b_size = b_file.get_length() if b_file else 0
				if a_file: a_file.close()
				if b_file: b_file.close()
				return a_size < b_size
			)
	
	_mutex.unlock()
