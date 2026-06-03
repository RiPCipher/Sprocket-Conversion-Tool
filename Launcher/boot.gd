extends Node

@onready var boot_splash = %SplashScreen
@onready var boot_timer = %BootTimer
@onready var boot_progress = %BootProgress

var boot_percentage : int

func _ready():
	_set_splash()
	DisplayServer.window_set_size(Vector2i(1080, 720))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	var screen_size = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position((screen_size - DisplayServer.window_get_size()) / 2)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	get_tree().get_root().set_transparent_background(true)

func _process(delta: float) -> void:
	boot_percentage = int((boot_timer.time_left / boot_timer.wait_time) * 100)
	boot_progress.value = 100 - boot_percentage
	
func _on_timer_timeout():
	# Proceed with application boot
	if Launcher.is_ready == true and boot_timer.time_left == 0:
		Launcher._boot()
		

func _set_splash():
	var exe_dir = OS.get_executable_path().get_base_dir()
	var data_dir = exe_dir.path_join("data")
	var ext_splash_path = data_dir.path_join("SplashScreen.png")
	
	if FileAccess.file_exists(ext_splash_path):
		var image = Image.new()
		image.load(ext_splash_path)
		boot_splash.texture = ImageTexture.create_from_image(image)
	else:
		var image = Image.new()
		image.load("res://SplashScreen/SplashScreen.png")
		boot_splash.texture = ImageTexture.create_from_image(image)
