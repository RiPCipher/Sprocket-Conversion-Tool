extends Node

const MANIFEST_PATH = "res://Bundled/Manifest.json"
const BLUEPRINTS_PATH = "res://Bundled/Blueprints"

var manifest


func _ready() -> void:
	manifest = _load_manifest(MANIFEST_PATH)

func _load_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Manifest not found: %s" % path)
		return {}
	var json = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("Manifest line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {}
	return json.data if json.data is Dictionary else {}
