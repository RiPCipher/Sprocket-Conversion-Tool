@tool
extends EditorPlugin

const LOG_PATH = "res://addons/_editor_debug/editor_log.txt"

var _save_button: Button
var _error_tree: Tree
var _attempts = 0


func _enter_tree() -> void:
	_try_inject.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(_save_button):
		_save_button.queue_free()
	_save_button = null
	_error_tree = null


func _try_inject() -> void:
	if _inject_button():
		return
	_attempts += 1
	if _attempts > 20:
		push_warning("[_editor_debug] Could not locate the Errors toolbar; Save Log button not added.")
		return
	get_tree().create_timer(0.2).timeout.connect(_try_inject)


func _inject_button() -> bool:
	if is_instance_valid(_save_button):
		return true

	var base = EditorInterface.get_base_control()
	var expand_btn = _find_button(base, "Expand All")
	if expand_btn == null:
		return false

	var toolbar = expand_btn.get_parent()
	_error_tree = _find_tree(toolbar.get_parent())
	if _error_tree == null:
		return false

	_save_button = Button.new()
	_save_button.text = "Save Log"
	_save_button.pressed.connect(_on_save_pressed)
	toolbar.add_child(_save_button)
	return true


func _find_button(node: Node, label: String) -> Button:
	if node is Button and (node as Button).text == label:
		return node
	for child in node.get_children():
		var found = _find_button(child, label)
		if found:
			return found
	return null


func _find_tree(node: Node) -> Tree:
	if node is Tree:
		return node
	for child in node.get_children():
		var found = _find_tree(child)
		if found:
			return found
	return null


func _on_save_pressed() -> void:
	if not is_instance_valid(_error_tree):
		push_warning("[_editor_debug] Error tree is no longer valid.")
		return

	var base = EditorInterface.get_base_control()
	var warn_icon = base.get_theme_icon("Warning", "EditorIcons")

	var entry_lines: PackedStringArray = []
	var warnings = 0
	var errors = 0

	var root = _error_tree.get_root()
	if root:
		var item := root.get_first_child()
		while item:
			var is_warning = item.get_icon(0) == warn_icon
			if is_warning:
				warnings += 1
			else:
				errors += 1
			entry_lines.append((("W " if is_warning else "E ")) + item.get_text(0) + "   " + item.get_text(1))
			var child = item.get_first_child()
			while child:
				entry_lines.append("  " + child.get_text(0) + child.get_text(1))
				child = child.get_next()
			item = item.get_next()

	var project_name = str(ProjectSettings.get_setting("application/config/name", "Project"))
	var lines: PackedStringArray = []
	lines.append(project_name + " — Editor Log")
	lines.append("Saved: " + Time.get_datetime_string_from_system(false, true))
	lines.append("Warnings: %d   Errors: %d" % [warnings, errors])
	lines.append("----------------------------------------")
	lines.append_array(entry_lines)

	var file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[_editor_debug] Could not open %s for writing (error %d)." % [LOG_PATH, FileAccess.get_open_error()])
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()

	EditorInterface.get_resource_filesystem().update_file(LOG_PATH)
	print("[_editor_debug] Saved %d entries to %s" % [warnings + errors, LOG_PATH])
