extends Node

var config_manager = null
var format_registry = null
var error_handler = null
var browser_controller = null
var preview_controller = null

var conversion_worker = null

@onready var input_path_field = %PathInput
@onready var output_path_field = %OutputPathInput
@onready var browse_input_button = %In_BrowseButton
@onready var browse_output_button = %Out_BrowseButton
@onready var convert_button = %ConvertButton
@onready var status_label = %StatusLabel
@onready var progress_bar = %ProgressBar_U
@onready var percent_label = %PercentLabel

func initialize(p_config_manager, p_format_registry, p_error_handler, p_browser_controller, p_preview_controller) -> void:
	config_manager = p_config_manager
	format_registry = p_format_registry
	error_handler = p_error_handler
	browser_controller = p_browser_controller
	preview_controller = p_preview_controller

	conversion_worker = ConversionWorker.new(format_registry)
	conversion_worker.conversion_started.connect(_on_conversion_started)
	conversion_worker.conversion_progress.connect(_on_conversion_progress)
	conversion_worker.conversion_completed.connect(_on_conversion_completed)
	conversion_worker.conversion_error.connect(_on_conversion_error)

	browse_input_button.pressed.connect(_on_browse_input_pressed)
	browse_output_button.pressed.connect(_on_browse_output_pressed)
	convert_button.pressed.connect(_on_convert_pressed)


func set_input_file(path: String) -> void:
	input_path_field.text = path
	status_label.text = "File selected: " + path.get_file()

	var extension = path.get_extension().to_lower()
	var output_dir = config_manager.get_output_dir()
	if output_dir.is_empty():
		output_dir = path.get_base_dir()

	if extension == "obj":
		output_path_field.text = output_dir + "/" + path.get_file().get_basename() + ".blueprint"
	elif extension == "blueprint":
		output_path_field.text = output_dir + "/" + path.get_file().get_basename() + ".obj"

	if config_manager.get_auto_preview() and preview_controller:
		preview_controller.set_preview_path_text(path)
		preview_controller.preview_file(path)

#========================
# BROWSE HANDLERS
#========================
func _on_browse_input_pressed():
	var input_dir = config_manager.get_input_dir()
	var filters = PackedStringArray(["*.obj", "*.blueprint"])
	if !input_dir.is_empty() && DirAccess.dir_exists_absolute(input_dir):
		browser_controller.browse_open_file(input_dir, filters, set_input_file)
	else:
		browser_controller.browse_open_file("", filters, set_input_file)

func _on_browse_output_pressed():
	var input_path = input_path_field.text.strip_edges()
	var current_output_path = output_path_field.text.strip_edges()
	var initial_filename = ""

	if !current_output_path.is_empty():
		initial_filename = current_output_path.get_file()
	elif !input_path.is_empty():
		var basename = input_path.get_file().get_basename()
		var extension = input_path.get_extension().to_lower()
		if extension == "obj":
			initial_filename = basename + ".blueprint"
		elif extension == "blueprint":
			initial_filename = basename + ".obj"

	var filters = PackedStringArray(["*.blueprint"])
	var output_dir = config_manager.get_output_dir()
	if !output_dir.is_empty() && DirAccess.dir_exists_absolute(output_dir):
		browser_controller.browse_save_file(output_dir, filters, initial_filename, _on_output_file_selected)
	else:
		browser_controller.browse_save_file(input_path.get_base_dir(), filters, initial_filename, _on_output_file_selected)

func _on_output_file_selected(path):
	output_path_field.text = path
	status_label.text = "Output will be saved to: " + path

#========================
# CONVERSION
#========================
func _on_convert_pressed():
	var input_path = input_path_field.text.strip_edges()
	var output_path = output_path_field.text.strip_edges()

	if input_path.is_empty():
		status_label.text = "Error: Please select an input file"
		return

	if output_path.is_empty():
		status_label.text = "Error: Please select an output file"
		return

	var input_extension = input_path.get_extension().to_lower()
	var output_extension = output_path.get_extension().to_lower()

	if input_extension == "obj" and output_extension == "blueprint":
		if not _validate_obj_for_blueprint_conversion(input_path):
			return

	status_label.text = "Converting file..."
	progress_bar.visible = true
	percent_label.visible = true
	progress_bar.value = 0

	_set_buttons_enabled(false)

	var options = {
		"include_materials": false,
		"include_normals": false,
		"calculate_normals": true,
		"smooth_shading": false
	}

	if not conversion_worker.is_busy():
		conversion_worker.start_conversion(input_path, output_path, options)
	else:
		ErrorHandler.show_error_popup("Operation is Busy", "Try Again")

func _on_conversion_started(source_path, target_path):
	status_label.text = "Converting " + source_path.get_file() + " to " + target_path.get_file() + "..."

func _on_conversion_progress(progress):
	progress_bar.value = progress * 100
	percent_label.text = str(int(progress * 100)) + "%"
	await get_tree().process_frame

func _on_conversion_completed(result):
	_set_buttons_enabled(true)

	if result.success:
		var triangle_count = result.statistics.get("triangle_count", 0)
		var quad_count = result.statistics.get("quad_count", 0)
		var vertex_count = result.statistics.get("vertex_count", 0)

		var stats_text = "Vertices: " + str(vertex_count)
		if triangle_count > 0 or quad_count > 0:
			stats_text += ", Triangles: " + str(triangle_count) + ", Quads: " + str(quad_count)
		else:
			stats_text += ", Faces: " + str(result.statistics.get("face_count", 0))

		status_label.text = "Success: Conversion completed. " + stats_text

		if config_manager.get_auto_preview() and result.has("target_path") and preview_controller:
			preview_controller.preview_file(result.target_path)
	else:
		if result.has("error_type"):
			var replacements = {
				"FILENAME": result.get("error_file", "file"),
				"VERSION": result.get("error_version", "unknown"),
				"REQUIRED_VERSION": "0.2"
			}
			ErrorHandler.popup_error("file_errors." + result.error_type, replacements)
		elif not result.get("error_already_handled", false):
			var error_key = "file_access_errors." + ErrorHandler._get_error_key_from_code(result.get("error_code", 0))
			ErrorHandler.popup_error(error_key, {"FILENAME": result.get("target_path", "file").get_file()})

		status_label.text = "Conversion failed"

	progress_bar.visible = false
	percent_label.visible = false
	progress_bar.value = 0

func _on_conversion_error(error_message):
	_set_buttons_enabled(true)

	ErrorHandler.popup_error("file_access_errors.unknown", {
		"ERROR_CODE": "0",
		"ACTION": "convert file",
		"FILENAME": "file"
	})
	status_label.text = "Conversion failed"

	progress_bar.visible = false
	percent_label.visible = false

#========================
# HELPERS
#========================
func _set_buttons_enabled(enabled: bool):
	convert_button.disabled = !enabled
	browse_input_button.disabled = !enabled
	browse_output_button.disabled = !enabled

func _validate_obj_for_blueprint_conversion(file_path: String) -> bool:
	var format_handler = format_registry.get_import_handler_for_extension("obj")
	if not format_handler:
		return true

	var model_data = format_handler.import_model(file_path, {"quick_validation": true})
	if not model_data:
		return true

	if model_data.has_metadata("ngon_count"):
		var ngon_count = model_data.get_metadata("ngon_count", 0)
		if ngon_count > 0:
			error_handler.popup_error("file_errors.ngons", {"COUNT": ngon_count})
			status_label.text = "Conversion aborted: N-gons detected in OBJ file"
			return false

	return true
