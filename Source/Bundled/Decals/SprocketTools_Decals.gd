extends MarginContainer

const BASE_URL := "https://sprockettools.github.io/"

const CATEGORY_PAGES := {
	"Featured": "DecalsFeatured.html",
	"Chalk Writing": "DecalsChalkText.html",
	"Labels": "DecalsLabels.html",
	"Memes": "DecalsMemes.html",
	"Miscellaneous": "DecalsMisc.html",
	"Numbers": "DecalsNumbers.html",
	"Symbols": "DecalsSymbols.html",
	"Textures": "DecalsTextures.html",
}

const THUMB_DIR := "user://cache/decals/thumbs/"
const MANIFEST_FILE := "manifest.json"
const MANIFEST_VERSION := 1
const CACHE_TTL_SECONDS := 60 * 60 * 24
const MAX_CONCURRENT := 4
const REQUEST_TIMEOUT := 15.0
const ICON_SIZE := Vector2i(64, 64)
const THUMB_MAX_DIM := 128
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "bmp"]

signal decal_selected(decal_name: String, url: String)
signal catalog_refreshed(total_decals: int)

var _catalog: Dictionary = {}
var _textures: Dictionary = {}
var _thumbs_loaded: Dictionary = {}

var _lists: Dictionary = {}

var _queue: Array[Dictionary] = []
var _workers_active := 0
var _busy := false
var _cancelled := false
var _config_manager: Node = null
var _manifest_path := ""

signal _queue_drained

var _re_src: RegEx
var _re_copytext: RegEx
var _re_heading: RegEx
var _re_tags: RegEx

@onready var filter_edit = %filter_edit
@onready var refresh_button = %refresh_button
@onready var clear_cache_button = %Clear_Cache_Button
@onready var decal_status_label = %DecalStatusLabel
@onready var decals_list = %Decals
@onready var decals_container = %DecalsContainer

var _http_root

func _ready() -> void:
	_manifest_path = _cache_dir().path_join(MANIFEST_FILE)
	_compile_regex()

	_http_root = Node.new()
	_http_root.name = "HttpRequests"
	add_child(_http_root)

	filter_edit.clear_button_enabled = true
	filter_edit.text_changed.connect(_on_filter_changed)

	refresh_button.tooltip_text = "Refresh the decal catalog from Sprocket Tools"
	refresh_button.pressed.connect(_on_refresh_pressed)

	clear_cache_button.tooltip_text = "Delete all downloaded decal previews. They will be re-downloaded as needed."
	clear_cache_button.pressed.connect(_on_clear_cache_pressed)

	decals_container.tab_changed.connect(_on_tab_changed)

	decal_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	decal_status_label.text = ""

	_build_category_lists()

	DirAccess.make_dir_recursive_absolute(THUMB_DIR)

	if _load_cached_manifest():
		_populate_all_lists()
		_set_status("Loaded %d decals from cache." % _count_decals())
		_ensure_thumbnails_for_current_tab()
		if _cache_is_stale():
			_set_status("") ## TODO: Stale Cache Message
	else:
		if _network_enabled():
			refresh_catalog()
		else:
			_set_status("Network features are disabled. Enable them in Settings to download the decal catalog.")

func _exit_tree() -> void:
	_cancelled = true

func _compile_regex() -> void:
	_re_src = RegEx.create_from_string("(?i)src\\s*=\\s*[\"']([^\"']+)[\"']")
	_re_copytext = RegEx.create_from_string("(?i)copyText\\s*\\(\\s*['\"]([^'\"]+)['\"]\\s*\\)")
	_re_heading = RegEx.create_from_string("(?is)<h[1-6][^>]*>(.*?)</h[1-6]>")
	_re_tags = RegEx.create_from_string("(?s)<[^>]*>")

func _build_category_lists() -> void:
	var template: ItemList = null
	if decals_list is ItemList:
		template = decals_list.duplicate() as ItemList

	for child in decals_container.get_children():
		decals_container.remove_child(child)
		child.queue_free()

	for category in CATEGORY_PAGES:
		var list: ItemList
		if template:
			list = template.duplicate() as ItemList
		else:
			list = ItemList.new()
			list.max_columns = 0
			list.icon_mode = ItemList.ICON_MODE_TOP
			list.same_column_width = true
			list.fixed_column_width = 96
			list.fixed_icon_size = ICON_SIZE
			list.auto_height = false
			list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.name = category
		list.unique_name_in_owner = false
		list.clear()
		list.item_selected.connect(_on_item_selected.bind(category))
		decals_container.add_child(list)
		_lists[category] = list

func _set_status(text: String) -> void:
	if is_instance_valid(decal_status_label):
		decal_status_label.text = text
	_log(text)

func _log(msg: String) -> void:
	var dbg := get_node_or_null("/root/Debug")
	if dbg and dbg.has_method("log"):
		dbg.log("[Decals] " + msg)
	else:
		print("[Decals] ", msg)

func _network_enabled() -> bool:
	if _config_manager == null or not is_instance_valid(_config_manager):
		_config_manager = get_node_or_null("/root/ConfigManager")
		if _config_manager == null:
			_config_manager = get_tree().root.find_child("ConfigManager", true, false)
	if _config_manager == null:
		return false
	var settings = _config_manager.get("settings")
	if settings == null or not settings is Dictionary:
		return false
	var ui: Dictionary = settings.get("ui", {})
	return ui.get("network_enabled", false)

func _set_controls_locked(locked: bool) -> void:
	refresh_button.disabled = locked
	clear_cache_button.disabled = locked

func _on_clear_cache_pressed() -> void:
	if _busy:
		_set_status("Please wait for the current download to finish before clearing the cache.")
		return

	var count := _count_cached_thumbnails()
	if count == 0:
		_set_status("No cached decal previews to clear.")
		return

	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("_show_confirm_popup"):
		main_scene._show_confirm_popup(
			"Clear Decal Cache?",
			"This will delete %d cached decal preview%s.

Previews are re-downloaded the next time you open a category (network features must be enabled)." % [count, "" if count == 1 else "s"],
			"Clear", "Cancel",
			clear_thumbnail_cache
		)
	else:
		clear_thumbnail_cache()

func _on_refresh_pressed() -> void:
	if _busy:
		return
	if not _network_enabled():
		_set_status("Network features are disabled. Enable them in Settings first.")
		return
	refresh_catalog()


func refresh_catalog() -> void:
	if _busy:
		return
	_busy = true
	_set_controls_locked(true)
	_set_status("Fetching decal catalog...")

	var scraped: Dictionary = {}
	var failed: Array[String] = []

	_queue.clear()
	for category in CATEGORY_PAGES:
		_queue.append({
			"url": BASE_URL + CATEGORY_PAGES[category],
			"category": category,
			"callback": func(job: Dictionary, res: Dictionary) -> void:
				if not res["ok"]:
					failed.append(job["category"])
					return
				var html: String = res["body"].get_string_from_utf8()
				var items := _parse_catalog_page(html)
				if items.is_empty():
					failed.append(job["category"])
				else:
					scraped[job["category"]] = items
		})

	await _drain_queue()

	if scraped.is_empty():
		_busy = false
		_set_controls_locked(false)
		if _catalog.is_empty():
			_set_status("Couldn't reach the decal catalog")
		else:
			_set_status("Refresh failed. Still showing the previously cached catalog.")
		return

	for category in scraped:
		_catalog[category] = scraped[category]

	_save_manifest()
	_populate_all_lists()

	var total := _count_decals()
	if failed.is_empty():
		_set_status("Loaded %d decals across %d categories." % [total, _catalog.size()])
	else:
		_set_status("Loaded %d decals. Couldn't parse: %s" % [total, ", ".join(failed)])

	_busy = false
	_set_controls_locked(false)
	_thumbs_loaded.clear()
	catalog_refreshed.emit(total)
	_ensure_thumbnails_for_current_tab()

func _parse_catalog_page(html: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	var blocks := html.split("<li")
	for i in range(1, blocks.size()):
		var block: String = blocks[i]

		var end := block.findn("</ul>")
		if end != -1:
			block = block.substr(0, end)

		var src := ""
		var m := _re_src.search(block)
		if m:
			src = m.get_string(1)

		var full := ""
		m = _re_copytext.search(block)
		if m:
			full = m.get_string(1)

		var title := ""
		var uploader := ""
		for h in _re_heading.search_all(block):
			var text := _clean_text(h.get_string(1))
			if text.is_empty():
				continue
			var lower := text.to_lower()
			if lower.begins_with("uploaded by"):
				var colon := text.find(":")
				uploader = text.substr(colon + 1).strip_edges() if colon != -1 else text
			elif lower.begins_with("http://") or lower.begins_with("https://"):
				if full.is_empty():
					full = text
			elif title.is_empty():
				title = text

		if src.is_empty() and full.is_empty():
			continue

		var full_url := _absolutize(full if not full.is_empty() else src)
		var thumb_url := _absolutize(src if not src.is_empty() else full)

		if not _is_image_url(full_url):
			continue
		if seen.has(full_url):
			continue
		seen[full_url] = true

		if title.is_empty():
			title = full_url.get_file().get_basename().replace("_", " ")

		out.append({
			"name": title,
			"url": full_url,
			"thumb_url": thumb_url,
			"uploader": uploader,
		})

	return out

const HTML_ENTITIES := {
	"&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
	"&quot;": "\"", "&#39;": "'", "&apos;": "'",
}

func _clean_text(raw: String) -> String:
	var s := _re_tags.sub(raw, "", true)
	for entity in HTML_ENTITIES:
		s = s.replace(entity, HTML_ENTITIES[entity])
	return s.strip_edges()


func _absolutize(raw: String) -> String:
	var u := raw.strip_edges()
	if not (u.begins_with("http://") or u.begins_with("https://")):
		while u.begins_with("./"):
			u = u.substr(2)
		if u.begins_with("/"):
			u = u.substr(1)
		u = BASE_URL + u
	return u.replace(" ", "%20")

func _is_image_url(url: String) -> bool:
	var ext := url.get_file().get_extension().to_lower()
	return IMAGE_EXTENSIONS.has(ext)

func _populate_all_lists() -> void:
	for category in _lists:
		_populate_list(category)

func _populate_list(category: String) -> void:
	var list: ItemList = _lists[category]
	list.clear()

	var entries: Array = _catalog.get(category, [])
	var filter = filter_edit.text.strip_edges().to_lower()

	for entry in entries:
		if not filter.is_empty():
			var haystack: String = (entry["name"] + " " + entry["uploader"]).to_lower()
			if not haystack.contains(filter):
				continue
		var idx := list.add_item(entry["name"])
		list.set_item_metadata(idx, entry)
		var tooltip: String = entry["url"]
		if not entry["uploader"].is_empty():
			tooltip += "\nUploaded by: " + entry["uploader"]
		tooltip += "\n\nClick to copy the URL."
		list.set_item_tooltip(idx, tooltip)

		var tex: ImageTexture = _textures.get(entry["thumb_url"])
		if tex:
			list.set_item_icon(idx, tex)

	var tab_idx = decals_container.get_tab_idx_from_control(list)
	if tab_idx != -1:
		decals_container.set_tab_title(tab_idx, "%s (%d)" % [category, list.item_count])


func _on_filter_changed(_text: String) -> void:
	_populate_all_lists()


func _on_tab_changed(_tab: int) -> void:
	_ensure_thumbnails_for_current_tab()


func _current_category() -> String:
	var ctrl = decals_container.get_current_tab_control()
	if ctrl == null:
		return ""
	for category in _lists:
		if _lists[category] == ctrl:
			return category
	return ""


func _on_item_selected(index: int, category: String) -> void:
	var list: ItemList = _lists[category]
	var entry = list.get_item_metadata(index)
	if entry == null:
		return
	DisplayServer.clipboard_set(entry["url"])
	var msg := "Copied URL for \"%s\"" % entry["name"]
	if not entry["uploader"].is_empty():
		msg += " (by %s)" % entry["uploader"]
	msg += " -- paste it into Sprocket's decal URL field."
	_set_status(msg)
	decal_selected.emit(entry["name"], entry["url"])

func _ensure_thumbnails_for_current_tab() -> void:
	var category := _current_category()
	if category.is_empty():
		return
	if _thumbs_loaded.get(category, false):
		return
	_thumbs_loaded[category] = true
	_load_thumbnails(category)


func _load_thumbnails(category: String) -> void:
	var entries: Array = _catalog.get(category, [])
	if entries.is_empty():
		return

	var pending: Array[Dictionary] = []

	for entry in entries:
		var thumb_url: String = entry["thumb_url"]
		if _textures.has(thumb_url):
			continue
		var path := _thumb_cache_path(thumb_url)
		if FileAccess.file_exists(path):
			var img := Image.new()
			if img.load(path) == OK:
				_textures[thumb_url] = ImageTexture.create_from_image(img)
				continue
		pending.append(entry)

	_populate_list(category)

	if pending.is_empty():
		return
	if not _network_enabled():
		_set_status("Showing %d decals. Enable network features to download previews." % entries.size())
		return
	if _busy:
		return

	_busy = true
	_set_controls_locked(true)
	_set_status("Downloading %d previews for %s..." % [pending.size(), category])

	_queue.clear()
	for entry in pending:
		_queue.append({
			"url": entry["thumb_url"],
			"callback": func(job: Dictionary, res: Dictionary) -> void:
				if not res["ok"]:
					return
				var img := _image_from_buffer(res["body"], String(job["url"]).get_file().get_extension())
				if img == null:
					return
				_downscale(img)
				img.save_png(_thumb_cache_path(job["url"]))
				_textures[job["url"]] = ImageTexture.create_from_image(img)
		})

	await _drain_queue()

	_busy = false
	_set_controls_locked(false)
	_populate_list(category)
	_set_status("%s: %d decals. Click one to copy its URL." % [category, entries.size()])


func _thumb_cache_path(url: String) -> String:
	return THUMB_DIR + url.sha256_text() + ".png"


func _image_from_buffer(buffer: PackedByteArray, ext: String) -> Image:
	if buffer.is_empty():
		return null

	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match ext.to_lower():
		"png": err = img.load_png_from_buffer(buffer)
		"jpg", "jpeg": err = img.load_jpg_from_buffer(buffer)
		"webp": err = img.load_webp_from_buffer(buffer)
		"bmp": err = img.load_bmp_from_buffer(buffer)
		_:
			_log("Skipping preview: unsupported image format (ext '%s')." % ext)
			return null
	if err == OK and img.get_width() > 0:
		return img
	return null

func _downscale(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if w <= THUMB_MAX_DIM and h <= THUMB_MAX_DIM:
		return
	var scale := float(THUMB_MAX_DIM) / float(maxi(w, h))
	img.resize(maxi(1, int(w * scale)), maxi(1, int(h * scale)), Image.INTERPOLATE_LANCZOS)

func _cache_dir() -> String:
	return OS.get_executable_path().get_base_dir().path_join("data").path_join("cache")


func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(_manifest_path):
		return {}
	var file := FileAccess.open(_manifest_path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_log("Cached manifest is corrupt; ignoring it.")
		return {}
	return json.data if json.data is Dictionary else {}


func _load_cached_manifest() -> bool:
	var data := _read_manifest()
	if int(data.get("version", 0)) != MANIFEST_VERSION:
		return false
	var categories = data.get("categories", {})
	if not categories is Dictionary or categories.is_empty():
		return false
	_catalog = categories
	return true


func _save_manifest() -> void:
	DirAccess.make_dir_recursive_absolute(_cache_dir())
	var file := FileAccess.open(_manifest_path, FileAccess.WRITE)
	if file == null:
		_log("Couldn't write the manifest cache.")
		return
	file.store_string(JSON.stringify({
		"version": MANIFEST_VERSION,
		"fetched_at": int(Time.get_unix_time_from_system()),
		"categories": _catalog,
	}, "\t"))


func _cache_is_stale() -> bool:
	var data := _read_manifest()
	if data.is_empty():
		return true
	var fetched := int(data.get("fetched_at", 0))
	return Time.get_unix_time_from_system() - fetched > CACHE_TTL_SECONDS


func _count_cached_thumbnails() -> int:
	var dir := DirAccess.open(THUMB_DIR)
	if dir == null:
		return 0
	return dir.get_files().size()

func clear_thumbnail_cache() -> void:
	if _busy:
		return

	var removed := 0
	var failed := 0
	var dir := DirAccess.open(THUMB_DIR)
	if dir:
		for f in dir.get_files():
			if dir.remove(f) == OK:
				removed += 1
			else:
				failed += 1

	_textures.clear()
	_thumbs_loaded.clear()
	_populate_all_lists()

	_ensure_thumbnails_for_current_tab()

	if not _busy:
		if failed > 0:
			_set_status("Cleared %d decal previews (%d couldn't be deleted)." % [removed, failed])
		else:
			_set_status("Cleared %d decal previews." % removed)

func clear_cache() -> void:
	clear_thumbnail_cache()
	DirAccess.remove_absolute(_manifest_path)
	_catalog.clear()
	_populate_all_lists()
	_set_status("Cache cleared.")

func _count_decals() -> int:
	var n := 0
	for category in _catalog:
		n += (_catalog[category] as Array).size()
	return n

func _drain_queue() -> void:
	if _queue.is_empty():
		return
	_cancelled = false
	_workers_active = mini(MAX_CONCURRENT, _queue.size())
	for i in _workers_active:
		_worker()
	await _queue_drained


func _worker() -> void:
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	http.use_threads = false
	_http_root.add_child(http)

	while not _queue.is_empty() and not _cancelled:
		var job: Dictionary = _queue.pop_front()
		var result := await _fetch(http, job["url"])
		if _cancelled:
			break
		if job.has("callback"):
			(job["callback"] as Callable).call(job, result)

	http.queue_free()
	_workers_active -= 1
	if _workers_active == 0:
		_queue_drained.emit()


func _fetch(http: HTTPRequest, url: String) -> Dictionary:
	var err := http.request(url)
	if err != OK:
		await get_tree().process_frame
		_log("Request failed to start for %s (%s)" % [url, error_string(err)])
		return {"ok": false, "code": 0, "body": PackedByteArray()}

	var out: Array = await http.request_completed
	var result: int = out[0]
	var code: int = out[1]
	var body: PackedByteArray = out[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		_log("Transport error %d for %s" % [result, url])
		return {"ok": false, "code": code, "body": PackedByteArray()}
	if code != 200:
		_log("HTTP %d for %s" % [code, url])
		return {"ok": false, "code": code, "body": PackedByteArray()}

	return {"ok": true, "code": code, "body": body}
