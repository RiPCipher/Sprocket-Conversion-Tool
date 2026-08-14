extends MarginContainer

const ROW_HEIGHT = 32

@onready var Content = %PackedContent
@onready var browser_controller = %BrowserController
@onready var config_manager = %ConfigManager
@onready var status_label = %StatusLabel
@onready var preview_controller = %PreviewController
@onready var left: VBoxContainer = %BP_Left
@onready var center: VBoxContainer = %BP_Center
@onready var right: VBoxContainer = %BP_Right

func _ready() -> void:
	_populate(Content.manifest.get("Blueprints", {}))

func _populate(blueprints: Dictionary) -> void:
	for vbox in [left, center, right]:
		for child in vbox.get_children():
			vbox.remove_child(child)
			child.queue_free()

	for display_name in blueprints:
		var file_name: String = blueprints[display_name]

		var label = Label.new()
		label.text = display_name
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size.y = ROW_HEIGHT
		left.add_child(label)

		var preview_button = Button.new()
		preview_button.text = "Preview"
		preview_button.custom_minimum_size.y = ROW_HEIGHT
		preview_button.pressed.connect(_on_preview_pressed.bind(display_name, file_name))
		center.add_child(preview_button)

		var save_button = Button.new()
		save_button.text = "Save"
		save_button.custom_minimum_size.y = ROW_HEIGHT
		save_button.pressed.connect(_on_download_pressed.bind(display_name, file_name))
		right.add_child(save_button)

func _on_preview_pressed(display_name: String, file_name: String) -> void:
	var source_path: String = Content.BLUEPRINTS_PATH.path_join(file_name)
	if not FileAccess.file_exists(source_path):
		push_error("Bundled blueprint missing: %s" % source_path)
		if status_label:
			status_label.text = "Error: bundled blueprint '%s' not found" % display_name
		return

	preview_controller.preview_file(source_path)

func _on_download_pressed(display_name: String, file_name: String) -> void:
	var output_dir: String = config_manager.get_output_dir()
	if output_dir.is_empty() or not DirAccess.dir_exists_absolute(output_dir):
		output_dir = ""

	var filters := PackedStringArray(["Blueprint (*.blueprint)"])
	browser_controller.browse_save_file(output_dir, filters, file_name, _on_save_location_chosen.bind(display_name, file_name))

func _on_save_location_chosen(dest_path: String, display_name: String, file_name: String) -> void:
	var source_path: String = Content.BLUEPRINTS_PATH.path_join(file_name)
	if not FileAccess.file_exists(source_path):
		push_error("Bundled blueprint missing: %s" % source_path)
		if status_label:
			status_label.text = "Error: bundled blueprint '%s' not found" % display_name
		return

	var err := DirAccess.copy_absolute(source_path, dest_path)
	if err != OK:
		push_error("Failed to copy blueprint to %s (error %d)" % [dest_path, err])
		if status_label:
			status_label.text = "Error: could not save '%s'" % display_name
		return

	if status_label:
		status_label.text = "Saved %s to %s" % [display_name, dest_path]
