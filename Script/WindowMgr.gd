extends Node

func _ready() -> void:
	# 1. 设置物理分辨率，防止被系统拉伸
	get_window().size = Vector2i(1600, 900)
	get_window().position = (DisplayServer.screen_get_size() - Vector2i(1600, 900)) / 2.0
	
	# 2. 读取配置文件并应用模式
	var path = OS.get_executable_path().get_base_dir().path_join("Config/Window_FullScreen.txt")
	if FileAccess.file_exists(path):
		var content = FileAccess.get_file_as_string(path)
		# 确保只有包含 "=" 才解析，防止空文件报错
		if "=" in content:
			var val = content.split("=")[1].to_int()
			# 如果是 1 则设为全屏，否则窗口模式
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if val == 1 else DisplayServer.WINDOW_MODE_WINDOWED)
			# 如果是全屏，额外设置无边框，防止系统边框干扰
			if val == 1:
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
