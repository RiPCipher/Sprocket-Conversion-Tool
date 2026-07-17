extends Node

var config_manager = null
var update_manager = null
var update_button = null

@onready var network_checkbutton = %NetworkButton
@onready var status_label = %StatusLabel
@onready var progress_bar = %ProgressBar_U
@onready var percent_label = %PercentLabel
@onready var version_label = %Version

func initialize(p_config_manager, p_update_manager, p_update_button) -> void:
	config_manager = p_config_manager
	update_manager = p_update_manager
	update_button = p_update_button

	version_label.set_text(update_manager.CURRENT_VERSION)

	update_manager.update_available.connect(_on_update_available)
	update_manager.launcher_outdated.connect(_on_launcher_outdated)
	update_manager.download_progress.connect(_on_download_progress)
	update_manager.download_complete.connect(_on_download_complete)
	update_manager.download_failed.connect(_on_download_failed)
	update_button.pressed.connect(_on_update_button_pressed)
	network_checkbutton.toggled.connect(_on_network_toggled)

	# Initial network state from config
	if config_manager.settings.ui.has("network_enabled"):
		network_checkbutton.set_pressed_no_signal(config_manager.settings.ui["network_enabled"])
	else:
		config_manager.settings.ui["network_enabled"] = false
		network_checkbutton.set_pressed_no_signal(false)

func _on_network_toggled(button_pressed: bool):
	config_manager.settings.ui["network_enabled"] = button_pressed
	config_manager.save_config()

	if button_pressed:
		update_manager.check_for_updates()
	else:
		update_button.visible = false

func _on_launcher_outdated(new_version: String, download_url: String):
	update_button.visible = true
	update_button.disabled = true
	update_button.text = "Launcher Update Required"
	status_label.text = "New version " + new_version + " requires updated launcher. Click to download."

	update_button.set_meta("launcher_download_url", download_url)

	if update_button.pressed.is_connected(_on_update_button_pressed):
		update_button.pressed.disconnect(_on_update_button_pressed)
	update_button.pressed.connect(_on_launcher_download_button_pressed)
	update_button.disabled = false

func _on_launcher_download_button_pressed():
	var download_url = update_button.get_meta("launcher_download_url", "")
	if download_url != "":
		OS.shell_open(download_url)
		status_label.text = "Opening download page in browser..."
	else:
		status_label.text = "Error: No download URL available"

func _on_update_available(new_version: String):
	update_button.visible = true
	update_button.text = "Download Update (" + new_version + ")"
	status_label.text = "Update available: " + new_version

func _on_update_button_pressed():
	update_button.disabled = true
	update_button.text = "Downloading..."
	progress_bar.visible = true
	percent_label.visible = true
	status_label.text = "Downloading update..."
	update_manager.download_update()

func _on_download_progress(percent: float):
	progress_bar.value = percent
	percent_label.text = "%.1f%%" % percent

func _on_download_complete():
	progress_bar.value = 100
	percent_label.text = "100%"
	status_label.text = "Update downloaded! Restarting in 2 seconds..."
	await get_tree().create_timer(2.0).timeout
	update_manager.restart_to_apply_update()

func _on_download_failed(error: String):
	status_label.text = "Download failed: " + error
	update_button.disabled = false
	update_button.text = "Download Update (" + update_manager.latest_version + ")"
	progress_bar.visible = false
	percent_label.visible = false
