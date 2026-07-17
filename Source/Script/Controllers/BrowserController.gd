extends Node

enum BrowserMode {
	OPEN_FILE,
	SAVE_FILE,
	SELECT_DIR
}

const _BROWSER_SCENE = preload("res://Scenes/Browser.tscn")

var config_manager = null

var _browser_instance = null
var _native_dialog: FileDialog = null
var _file_callback: Callable = Callable()
var _dir_callback: Callable = Callable()

func initialize(p_config_manager) -> void:
	config_manager = p_config_manager

func browse_open_file(path: String = "", filters: PackedStringArray = [], file_cb: Callable = Callable()) -> void:
	_file_callback = file_cb
	_dir_callback = Callable()
	_show(BrowserMode.OPEN_FILE, path, filters, "")

func browse_save_file(path: String = "", filters: PackedStringArray = [], initial_name: String = "", file_cb: Callable = Callable()) -> void:
	_file_callback = file_cb
	_dir_callback = Callable()
	_show(BrowserMode.SAVE_FILE, path, filters, initial_name)

func browse_select_dir(path: String = "", dir_cb: Callable = Callable()) -> void:
	_dir_callback = dir_cb
	_file_callback = Callable()
	_show(BrowserMode.SELECT_DIR, path, [], "")

func _ensure_instance() -> void:
	if _browser_instance:
		return

	_browser_instance = _BROWSER_SCENE.instantiate()
	add_child(_browser_instance)
	_browser_instance.initialize(config_manager)
	_browser_instance.file_selected.connect(_on_file_selected)
	_browser_instance.dir_selected.connect(_on_dir_selected)
	_browser_instance.canceled.connect(_on_canceled)

func _show(mode: int, path: String, filters: PackedStringArray, initial_name: String) -> void:
	if _use_native():
		_show_native(mode, path, filters, initial_name)
		return

	_ensure_instance()

	var main_window_size = DisplayServer.window_get_size()
	var main_window_position = DisplayServer.window_get_position()
	var window_size = _browser_instance.size
	_browser_instance.position = main_window_position + (main_window_size - window_size) / 2

	_browser_instance.open(mode, path, filters, initial_name)

func _use_native() -> bool:
	return config_manager != null and config_manager.get_native()

func _ensure_native_dialog() -> void:
	if _native_dialog:
		return

	_native_dialog = FileDialog.new()
	_native_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_native_dialog.use_native_dialog = true
	add_child(_native_dialog)
	_native_dialog.file_selected.connect(_on_file_selected)
	_native_dialog.dir_selected.connect(_on_dir_selected)
	_native_dialog.canceled.connect(_on_canceled)

func _show_native(mode: int, path: String, filters: PackedStringArray, initial_name: String) -> void:
	_ensure_native_dialog()

	match mode:
		BrowserMode.OPEN_FILE:
			_native_dialog.title = "Open File"
			_native_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		BrowserMode.SAVE_FILE:
			_native_dialog.title = "Save File"
			_native_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		BrowserMode.SELECT_DIR:
			_native_dialog.title = "Select Folder"
			_native_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR

	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	_native_dialog.current_dir = path

	if mode != BrowserMode.SELECT_DIR:
		_native_dialog.filters = _to_godot_filters(filters)
		_native_dialog.current_file = initial_name

	_native_dialog.popup_centered()

# Converts the custom browser's "Label (*.ext)" filter strings into Godot's
# native "*.ext ; Label" format.
func _to_godot_filters(filters: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()

	if filters.is_empty():
		result.append("*.* ; All Files")
		return result

	for filter in filters:
		var pattern := filter.strip_edges()
		var label := ""
		var open_paren := filter.find("(")
		var close_paren := filter.rfind(")")
		if open_paren != -1 and close_paren > open_paren:
			pattern = filter.substr(open_paren + 1, close_paren - open_paren - 1).strip_edges()
			label = filter.substr(0, open_paren).strip_edges()

		if label.is_empty():
			label = "Files"
		result.append(pattern + " ; " + label)

	return result

func _on_file_selected(path) -> void:
	if _file_callback.is_valid():
		_file_callback.call(path)

func _on_dir_selected(path) -> void:
	if _dir_callback.is_valid():
		_dir_callback.call(path)

func _on_canceled() -> void:
	pass
