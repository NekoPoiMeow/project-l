extends CheckButton

@onready var audio_on = $AudioStreamPlayer切换音开
@onready var audio_off = $AudioStreamPlayer切换音关

func get_file_path() -> String:
	return OS.get_executable_path().get_base_dir().path_join("Config/Window_FullScreen.txt")

func _ready() -> void:
	var file = FileAccess.open(get_file_path(), FileAccess.READ)
	if file:
		var raw_text = file.get_as_text().strip_edges()
		file.close()
		if "=" in raw_text:
			var val = raw_text.split("=")[1].to_int()
			self.button_pressed = (val == 1)
			# 注意：_ready里调用时，根据你的需求决定是否要播放音频
			# 如果不希望启动时播放声音，这里就别调用更新模式里的声音逻辑
			update_window_mode(val == 1)
	
	self.toggled.connect(_on_toggled)

func _on_toggled(toggled_on: bool) -> void:
	# 1. 执行窗口模式逻辑
	update_window_mode(toggled_on)
	
	# 2. 执行文件保存逻辑
	var file = FileAccess.open(get_file_path(), FileAccess.WRITE)
	if file:
		var val_to_write = 1 if toggled_on else 0
		file.store_string("Window_FullScreen=" + str(val_to_write))
		file.close()
		
	# 3. 执行音频播放逻辑 (合并到这里)
	if toggled_on:
		audio_on.stop()
		audio_on.play()
	else:
		audio_off.stop()
		audio_off.play()

func update_window_mode(is_fullscreen: bool) -> void:
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
