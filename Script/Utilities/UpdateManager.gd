extends Node

# Current version - UPDATE THIS WITH EACH RELEASE
const CURRENT_VERSION = "0.6.1" # Previous: 0.6

# API
const GITHUB_API_URL = "https://api.github.com/repos/RiPCipher/Sprocket-Conversion-Tool/releases/latest"

# Signals for UI
signal update_available(new_version: String)
signal launcher_outdated(new_version: String, download_url: String)
signal download_progress(percent: float)
signal download_complete()
signal download_failed(error: String)

var latest_version: String = ""
var pck_download_url: String = ""
var changelog: String = ""
var compatible_launchers: Array = []

var version_check_request: HTTPRequest
var download_request: HTTPRequest

func _ready():
	version_check_request = HTTPRequest.new()
	add_child(version_check_request)
	version_check_request.request_completed.connect(_on_version_check_completed)
	
	download_request = HTTPRequest.new()
	add_child(download_request)
	download_request.request_completed.connect(_on_download_completed)
	
	await get_tree().process_frame
	
	if %ConfigManager.settings.ui.get("network_enabled", false):
		check_for_updates()

func check_for_updates():
	if not %ConfigManager.settings.ui.get("network_enabled", false):
		return
	
	Debug.log("Checking for updates...")
	
	var err = version_check_request.request(GITHUB_API_URL)
	if err != OK:
		Debug.log("Failed to send update check request: " + error_string(err))

func _on_version_check_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		Debug.log("Update check failed: " + str(result))
		return
	
	if response_code != 200:
		Debug.log("Update check returned code: " + str(response_code))
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		Debug.log("Failed to parse update check response")
		return
	
	var data = json.data
	latest_version = data.get("tag_name", "")
	changelog = data.get("body", "No changelog available")
	
	if latest_version == "":
		Debug.log("No version found in response")
		return
	
	compatible_launchers = _parse_compatible_launchers(changelog)
	
	# Compare versions
	if _is_newer_version(latest_version, CURRENT_VERSION):
		Debug.log("Update available! Current: " + CURRENT_VERSION + " Latest: " + latest_version)
		
		# Find the .pck file in the assets
		var assets = data.get("assets", [])
		for asset in assets:
			var asset_name = asset.get("name", "")
			if asset_name == "Sprocket_Conversion_Tool.pck":
				pck_download_url = asset.get("browser_download_url", "")
				break
		
		if pck_download_url == "":
			Debug.log("No .pck file found in latest release")
			return
		
		# Check launcher compatibility
		if _is_launcher_compatible():
			Debug.log("Launcher is compatible - showing update")
			emit_signal("update_available", latest_version)
		else:
			Debug.log("Launcher is outdated - need to download new launcher")
			# Find launcher executable in release assets
			var launcher_url = _find_launcher_download_url(assets)
			emit_signal("launcher_outdated", latest_version, launcher_url)
	else:
		Debug.log("Already on latest version!")

func _parse_compatible_launchers(release_body: String) -> Array:
	var launchers = []
	
	# Look for "Compatible Launcher(s):"
	var lines = release_body.split("\n")
	for line in lines:
		var lower_line = line.to_lower()
		if "compatible launcher" in lower_line:
			var colon_pos = line.find(":")
			if colon_pos != -1:
				var versions_str = line.substr(colon_pos + 1).strip_edges()
				var version_parts = versions_str.split(",")
				for version in version_parts:
					var clean_version = version.strip_edges()
					if clean_version != "":
						launchers.append(clean_version)
				break
	
	if launchers.is_empty():
		Debug.log("No compatible launchers found in changelog - defaulting to 1.0")
		# If no compatibility info found, assume all launchers are  compatible
		return ["v1.0"] 
	
	Debug.log("Compatible launchers: " + str(launchers))
	return launchers

func _is_launcher_compatible() -> bool:
	var launcher = get_node_or_null("/root/Launcher")
	if not launcher:
		Debug.log("ERROR: Launcher autoload not found!")
		return false

	var current_launcher_version = launcher.LAUNCHER_VERSION
	Debug.log("Current launcher version: " + current_launcher_version)
	
	# If no compatible launchers specified, assume compatible
	if compatible_launchers.is_empty():
		return true
	
	# Check if current launcher version is in the compatible list
	for version in compatible_launchers:
		if version == current_launcher_version:
			return true
	
	return false

func _find_launcher_download_url(assets: Array) -> String:
	return "https://github.com/RiPCipher/Sprocket-Conversion-Tool/releases/latest"

func _is_newer_version(latest: String, current: String) -> bool:
	"""Compare version strings (assumes format v1.2.3)"""
	var latest_clean = latest.trim_prefix("v")
	var current_clean = current.trim_prefix("v")
	
	var latest_parts = latest_clean.split(".")
	var current_parts = current_clean.split(".")
	
	for i in range(max(latest_parts.size(), current_parts.size())):
		var latest_num = int(latest_parts[i]) if i < latest_parts.size() else 0
		var current_num = int(current_parts[i]) if i < current_parts.size() else 0
		
		if latest_num > current_num:
			return true
		elif latest_num < current_num:
			return false
	
	return false

func download_update():
	if pck_download_url == "":
		emit_signal("download_failed", "No download URL available")
		return
	
	Debug.log("Starting download: " + pck_download_url)
	
	var err = download_request.request(pck_download_url)
	if err != OK:
		emit_signal("download_failed", "Failed to start download: " + error_string(err))

func _process(_delta):
	# Update download progress
	if download_request.get_http_client_status() == HTTPClient.STATUS_BODY:
		var body_size = download_request.get_body_size()
		var downloaded = download_request.get_downloaded_bytes()
		
		if body_size > 0:
			var percent = (float(downloaded) / float(body_size)) * 100.0
			emit_signal("download_progress", percent)

func _on_download_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("download_failed", "Download failed: " + str(result))
		return
	
	if response_code != 200:
		emit_signal("download_failed", "Download returned code: " + str(response_code))
		return
	
	# Save the downloaded .pck file to the data folder
	var exe_dir = OS.get_executable_path().get_base_dir()
	var data_dir = exe_dir.path_join("data")
	var update_path = data_dir.path_join("Sprocket_Conversion_Tool_UPDATE.pck")
	
	# Ensure data folder exist
	if not DirAccess.dir_exists_absolute(data_dir):
		DirAccess.make_dir_recursive_absolute(data_dir)
	
	Debug.log("Saving update to: " + update_path)
	
	var file = FileAccess.open(update_path, FileAccess.WRITE)
	if file == null:
		var error_msg = "Failed to save update file: " + error_string(FileAccess.get_open_error())
		emit_signal("download_failed", error_msg)
		Debug.log(error_msg)
		return
	
	file.store_buffer(body)
	file.close()
	
	Debug.log("Update downloaded successfully!")
	emit_signal("download_complete")

func restart_to_apply_update():
	var launcher_path = OS.get_executable_path()
	Debug.log("Restarting launcher: " + launcher_path)
	
	var pid = OS.create_process(launcher_path, [])
	if pid == -1:
		Debug.log("Failed to restart launcher")
		return
	
	Debug.log("New process started, quitting...")
	get_tree().quit()
