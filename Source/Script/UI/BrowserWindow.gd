extends Window

signal file_selected(path)
signal dir_selected(path)
signal canceled

enum BrowserMode {
	OPEN_FILE,
	SAVE_FILE,
	SELECT_DIR
}

var current_mode: int = BrowserMode.OPEN_FILE
var current_path: String = ""
var current_filters: PackedStringArray = []
var selected_filter_index: int = 0
var config_manager = null

# UI References
@onready var file_list = %FileList
@onready var path_option = %PathOptions
@onready var path_input = %PathInput
@onready var filename_section = %FileNameSection
@onready var filename_input = %FileNameInput
@onready var extension_option = %ValidExtension
@onready var select_button = %Select
@onready var cancel_button = %Cancel
@onready var parent_button = %ParentFolder
@onready var refresh_button = %Refresh
@onready var last_page_button = %LastPage
@onready var next_page_button = %NextPage

var file_icons = {}
var folder_icon: Texture2D = null
var default_file_icon: Texture2D = null
var parent_folder_icon: Texture2D = null
var format_icons = {}

var history = []
var history_index = -1

func _ready():
	file_list.item_activated.connect(_on_item_activated)
	file_list.item_selected.connect(_on_item_selected)
	path_input.text_submitted.connect(_on_path_submitted)
	path_option.item_selected.connect(_on_drive_selected)
	select_button.pressed.connect(_on_select_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	parent_button.pressed.connect(_on_parent_folder_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	last_page_button.pressed.connect(_on_last_page_pressed)
	next_page_button.pressed.connect(_on_next_page_pressed)
	
	size = Vector2i(820, 500) ## was 800
	title = "File Browser"
	transient = true
	exclusive = true
	unresizable = false
	close_requested.connect(_on_cancel_pressed)
	
	file_list.allow_reselect = true
	file_list.select_mode = ItemList.SELECT_SINGLE
	
	visible = false
	
	if not file_list.is_connected("gui_input", Callable(self, "_on_file_list_gui_input")):
		file_list.connect("gui_input", Callable(self, "_on_file_list_gui_input"))
	if not file_list.is_connected("item_activated", Callable(self, "_on_item_activated")):
		file_list.connect("item_activated", Callable(self, "_on_item_activated"))

func initialize(p_config_manager = null):
	config_manager = p_config_manager
	

	_load_icons()
	_populate_drives()

func _load_icons():
	folder_icon = preload("res://Textures/2D/Settings/Icons/Folder_Icon16px.png")
	parent_folder_icon = preload("res://Textures/2D/Settings/Icons/Folder_Icon16px.png") 
	default_file_icon = preload("res://Textures/2D/Settings/Icons/File_Icon16px.png")

	format_icons["obj"] = preload("res://Textures/2D/Settings/Icons/OBJ_Icon16px.png")
	format_icons["blueprint"] = preload("res://Textures/2D/Settings/Icons/Blueprint_Icon16px.png")

func open(mode: int, path: String = "", filters: PackedStringArray = [], initial_name: String = ""):
	current_mode = mode
	if filters.is_empty():
		var default_filters = PackedStringArray([
			"All Files (*.*)",
			"OBJ Files (*.obj)",
			"Blueprint Files (*.blueprint)"
		])
		current_filters = default_filters
	else:
		current_filters = filters
	
	match mode:
		BrowserMode.OPEN_FILE:
			title = "Open File"
			select_button.text = "  Open  "
			filename_section.visible = true
		BrowserMode.SAVE_FILE:
			title = "Save File"
			select_button.text = "  Save  "
			filename_section.visible = true
		BrowserMode.SELECT_DIR:
			title = "Select Folder"
			select_button.text = "Select Current Folder"
			filename_section.visible = false
	
	if path.is_empty() or !DirAccess.dir_exists_absolute(path):
		path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	
	_navigate_to(path)
	
	_setup_extension_options(current_filters)
	
	if !initial_name.is_empty() and current_mode != BrowserMode.SELECT_DIR:
		filename_input.text = initial_name
	
	show()
	grab_focus()

func _populate_drives():
	path_option.clear()
	
	if OS.get_name() == "Windows":
		for letter in range(65, 91):  # A-Z
			var drive = char(letter) + ":/"
			if DirAccess.dir_exists_absolute(drive):
				path_option.add_item(drive)
	else:
		path_option.add_item("/")
		var home = OS.get_environment("HOME")
		if !home.is_empty():
			path_option.add_item(home)

func _navigate_to(path: String):
	if path.is_empty():
		return
	
	if !DirAccess.dir_exists_absolute(path):
		print("Directory doesn't exist: ", path)
		return
	
	current_path = path
	path_input.text = current_path
	
	if history_index < history.size() - 1:
		history = history.slice(0, history_index + 1)
	
	history.append(current_path)
	history_index = history.size() - 1
	
	_populate_file_list()
	
	for i in range(path_option.get_item_count()):
		var drive = path_option.get_item_text(i)
		if current_path.begins_with(drive):
			path_option.select(i)
			break

func _ext_from_filter(filter_text: String) -> String:
	var star = filter_text.find("*.")
	if star == -1:
		return ""
	var rest = filter_text.substr(star + 2)
	var ext = ""
	for i in rest.length():
		var c = rest[i]
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			ext += c
		else:
			break
	return ext.to_lower()

func _populate_file_list():
	file_list.clear()
	
	var dir = DirAccess.open(current_path)
	if dir == null:
		print("Error accessing directory: ", current_path, " - ", DirAccess.get_open_error())
		return
	
	# Add parent directory option if not at root
	if current_path != "/" and not current_path.ends_with(":/"):
		file_list.add_item("..", parent_folder_icon, false)
	
	# First add directories
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			file_list.add_item(file_name + "/", folder_icon, false)
		file_name = dir.get_next()
	
	# Then add files based on selected filter
	dir.list_dir_begin()
	file_name = dir.get_next()
	
	var selected_filter = ""
	if extension_option.selected >= 0:
		selected_filter = extension_option.get_item_text(extension_option.selected)
	
	while file_name != "":
		if not dir.current_is_dir() and not file_name.begins_with("."):
			var file_ext = file_name.get_extension().to_lower()
			var file_matches = false
			
			if selected_filter.begins_with("All Files") or selected_filter.is_empty():
				file_matches = true
			else:
				var filter_ext = _ext_from_filter(selected_filter)
				file_matches = filter_ext.is_empty() or filter_ext == file_ext
			
			if file_matches:
				var icon = format_icons.get(file_ext, default_file_icon)
				file_list.add_item(file_name, icon, false)
				
				if filename_input.text == file_name:
					file_list.select(file_list.get_item_count() - 1)
		
		file_name = dir.get_next()

	if not filename_input.text.is_empty():
		var file_to_select = filename_input.text
		for i in range(file_list.get_item_count()):
			if file_list.get_item_text(i) == file_to_select:
				file_list.select(i)
				break

func _setup_extension_options(filters: PackedStringArray):
	extension_option.clear()
	extension_option.add_item("All Files (*.*)")
	
	var has_obj = false
	var has_blueprint = false
	
	for filter in filters:
		if filter.contains("*.obj") or filter.contains(".obj"):
			has_obj = true
		if filter.contains("*.blueprint") or filter.contains(".blueprint"):
			has_blueprint = true
	
	if has_obj:
		extension_option.add_item("OBJ Files (*.obj)")
	
	if has_blueprint:
		extension_option.add_item("Blueprint Files (*.blueprint)")
	
	for filter in filters:
		if not filter.contains("All Files") and not (has_obj and filter.contains("*.obj")) and not (has_blueprint and filter.contains("*.blueprint")):
			extension_option.add_item(filter)
	
	if selected_filter_index < extension_option.get_item_count():
		extension_option.select(selected_filter_index)
	else:
		extension_option.select(0)
	
	if not extension_option.is_connected("item_selected", Callable(self, "_on_extension_selected")):
		extension_option.connect("item_selected", Callable(self, "_on_extension_selected"))
		
func _on_extension_selected(index: int):
	selected_filter_index = index
	
	if not filename_input.text.is_empty() and current_mode == BrowserMode.SAVE_FILE:
		var basename = filename_input.text.get_basename()
		var ext = _ext_from_filter(extension_option.get_item_text(index))
		if ext.is_empty():
			filename_input.text = basename
		else:
			filename_input.text = basename + "." + ext
	
	_populate_file_list()
	
func _on_item_activated(index: int):
	var item_text = file_list.get_item_text(index)
	
	if item_text == "..":
		_on_parent_folder_pressed()
		return
	
	if item_text.ends_with("/"):
		var new_path = current_path.path_join(item_text.trim_suffix("/"))
		_navigate_to(new_path)
	else:
		if current_mode != BrowserMode.SELECT_DIR:
			filename_input.text = item_text
			_on_select_pressed()

func _on_item_selected(index: int):
	var item_text = file_list.get_item_text(index)
	
	if not item_text.ends_with("/") and not item_text == "..":
		if current_mode != BrowserMode.SELECT_DIR:
			filename_input.text = item_text
			
			_update_extension_for_file(item_text)
			
			filename_input.grab_focus()
	
	select_button.grab_focus()

func _update_extension_for_file(filename: String):
	var file_ext = filename.get_extension().to_lower()
	
	for i in range(extension_option.get_item_count()):
		if _ext_from_filter(extension_option.get_item_text(i)) == file_ext:
			extension_option.select(i)
			selected_filter_index = i
			break
			
func _on_path_submitted(text: String):
	if DirAccess.dir_exists_absolute(text):
		_navigate_to(text)
	else:
		var parent = text.get_base_dir()
		if DirAccess.dir_exists_absolute(parent):
			_navigate_to(parent)
			if current_mode != BrowserMode.SELECT_DIR:
				filename_input.text = text.get_file()

func _on_drive_selected(index: int):
	var drive = path_option.get_item_text(index)
	_navigate_to(drive)

func _on_select_pressed():
	match current_mode:
		BrowserMode.OPEN_FILE:
			if filename_input.text.is_empty():
				return
				
			var file_path = current_path.path_join(filename_input.text)
			if not FileAccess.file_exists(file_path):
				print("File doesn't exist:", file_path)
				return
				
			emit_signal("file_selected", file_path)
			hide()
			
		BrowserMode.SAVE_FILE:
			if filename_input.text.is_empty():
				return
				
			var file_path = current_path.path_join(filename_input.text)
			
			if not file_path.get_extension():
				var ext = _ext_from_filter(extension_option.get_item_text(extension_option.selected))
				if not ext.is_empty():
					file_path += "." + ext
			
			emit_signal("file_selected", file_path)
			hide()
			
		BrowserMode.SELECT_DIR:
			emit_signal("dir_selected", current_path)
			hide()

func _on_cancel_pressed():
	emit_signal("canceled")
	hide()

func _on_parent_folder_pressed():
	var parent = current_path.get_base_dir()
	
	if parent.is_empty() or parent == current_path:
		if OS.get_name() == "Windows":
			_populate_drives()
		else:
			return
	else:
		_navigate_to(parent)

func _on_refresh_pressed():
	_populate_file_list()

func _on_last_page_pressed():
	if history_index > 0:
		history_index -= 1
		_navigate_to(history[history_index])

func _on_next_page_pressed():
	if history_index < history.size() - 1:
		history_index += 1
		_navigate_to(history[history_index])

func set_filter_index(index: int):
	selected_filter_index = index
	if extension_option.get_item_count() > index:
		extension_option.select(index)

func _save_last_used_path():
	if config_manager and !current_path.is_empty():
		match current_mode:
			BrowserMode.OPEN_FILE, BrowserMode.SAVE_FILE:
				if current_filters.size() > 0:
					var filter = current_filters[0]
					if filter.contains("OBJ Files"):
						config_manager.save_last_directory("obj_dir", current_path)
					elif filter.contains("Blueprint Files"):
						config_manager.save_last_directory("blueprint_dir", current_path)
					else:
						config_manager.save_last_directory("preview_dir", current_path)
			BrowserMode.SELECT_DIR:
				pass

func _on_file_list_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_index = file_list.get_item_at_position(event.position, true)
		
		if clicked_index != -1: 
			file_list.select(clicked_index)
			
			var item_text = file_list.get_item_text(clicked_index)
			if not item_text.ends_with("/") and not item_text == ".." and current_mode != BrowserMode.SELECT_DIR:
				filename_input.text = item_text
