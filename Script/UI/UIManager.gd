extends Node

signal theme_changed(theme_name)

var current_theme_name = "Default"
var config_manager = null

var themes = {
	"Default": preload("res://Textures/Resources/DefaultThemeResources/DefaultTheme.tres"),
	"Light": preload("res://Textures/Resources/LightThemeResources/LightTheme.tres"),
	"Purple": preload("res://Textures/Resources/PurpleThemeResources/RoyalPurpleTheme.tres"),
	"Legacy": preload("res://Textures/Resources/LegacyTheme.tres")
}

# Currently Handling TextureButton images since they cant be changed via resource
var theme_textures = {
	"Default": { 
		"settings": {
			"normal": preload("res://Textures/2D/Settings/DarkTheme/AdvancedSettings20x20.png"),
			"hover": preload("res://Textures/2D/Settings/DarkTheme/AdvancedSettings20x20Hover.png")
		},
		"gear": preload("res://Textures/2D/Gear.png")
	},
	"Light": {
		"settings": {
			"normal": preload("res://Textures/2D/Settings/LightTheme/AdvancedSettingsDark20x20.png"),
			"hover": preload("res://Textures/2D/Settings/LightTheme/AdvancedSettingsDark20x20Hover.png")
		},
		"gear": preload("res://Textures/2D/Gear.png")
	},
	"Purple": {
		"settings": {
			"normal": preload("res://Textures/2D/Settings/LightTheme/AdvancedSettingsDark20x20.png"),
			"hover": preload("res://Textures/2D/Settings/LightTheme/AdvancedSettingsDark20x20Hover.png")
		},
		"gear": preload("res://Textures/2D/Gear.png")
	},
	"Legacy": {
		"settings": {
			"normal": preload("res://Textures/2D/Settings/DarkTheme/AdvancedSettings20x20.png"),
			"hover": preload("res://Textures/2D/Settings/DarkTheme/AdvancedSettings20x20Hover.png")
		},
		"gear": preload("res://Textures/2D/Gear.png")
	},
}

func initialize(p_config_manager):
	config_manager = p_config_manager
	load_theme_preference()

func get_current_theme():
	return themes[current_theme_name]

func switch_theme(theme_name):
	if themes.has(theme_name):
		current_theme_name = theme_name
		
		get_tree().root.theme = themes[theme_name]
		
		update_all_texture_buttons()
		
		if config_manager:
			if not config_manager.settings.ui.has("theme"):
				config_manager.settings.ui["theme"] = theme_name
			else:
				config_manager.settings.ui.theme = theme_name
			config_manager.save_config()
		
		emit_signal("theme_changed", theme_name)
		return true
	
	return false

func get_themed_texture(texture_id, subtype = "normal"):
	if theme_textures.has(current_theme_name):
		var theme_set = theme_textures[current_theme_name]
		
		if theme_set.has(texture_id):
			if theme_set[texture_id] is Dictionary and theme_set[texture_id].has(subtype):
				return theme_set[texture_id][subtype]
			elif !(theme_set[texture_id] is Dictionary):
				return theme_set[texture_id]
	
	if current_theme_name != "Default" and theme_textures.has("Default"):
		var default_set = theme_textures["Default"]
		if default_set.has(texture_id):
			if default_set[texture_id] is Dictionary and default_set[texture_id].has(subtype):
				return default_set[texture_id][subtype]
			elif !(default_set[texture_id] is Dictionary):
				return default_set[texture_id]
	
	return null

func apply_themed_textures_to_button(button, texture_id):
	var normal = get_themed_texture(texture_id, "normal")
	var hover = get_themed_texture(texture_id, "hover")
	var pressed = get_themed_texture(texture_id, "pressed")
	
	if normal:
		button.texture_normal = normal
	if hover:
		button.texture_hover = hover
	if pressed:
		button.texture_pressed = pressed

func load_theme_preference():
	if config_manager and config_manager.settings.ui.has("theme"):
		var theme_name = config_manager.settings.ui.theme
		if themes.has(theme_name):
			current_theme_name = theme_name
			get_tree().root.theme = themes[theme_name]
			
			call_deferred("update_all_texture_buttons")

# Improve this
func update_all_texture_buttons():
	var advanced_settings_button = get_node_or_null("%AdvancedSettingsButton")
	var advanced_preview_settings_button = get_node_or_null("%PreviewAdvancedSettings")
	
	if advanced_settings_button:
		apply_themed_textures_to_button(advanced_settings_button, "settings")
		
	if advanced_preview_settings_button:
		apply_themed_textures_to_button(advanced_preview_settings_button, "settings")
	
	var gear_icon = get_parent().get_node_or_null("Background/Gear/Icon")
	if gear_icon:
		gear_icon.texture = get_themed_texture("gear")
