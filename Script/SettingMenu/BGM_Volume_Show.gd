extends LineEdit

# 1. 规范化后的专属路径
const SAVE_PATH = "res://Config/BGM_Volume.txt"

# ==================== 【已修正：将正常图路径精准替换为 icon2】 ====================
const ICON_NORMAL = preload("res://GraphicAssets/02_SettingMenu/03_BGM_icon2.png")
const ICON_MUTE = preload("res://GraphicAssets/02_SettingMenu/03_BGM_icon3.png")
# ====================================================================

func _ready() -> void:
	# 2. 纯代码强行关闭尺寸限制
	self.custom_minimum_size = Vector2.ZERO
	
	# 3. 初始化：读取纯文本
	var final_volume: int = 50
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var raw_line = file.get_line().strip_edges()
			file.close()
			if "=" in raw_line:
				final_volume = raw_line.split("=")[1].strip_edges().to_int()
				
	# 4. 把数字喂给刷新函数
	update_and_save_volume(final_volume)
	
	# 5. 当输入框里面的字发生改变时自动刷新
	self.text_changed.connect(_on_text_changed)

# ==================== 唯一的、无脑覆盖和同步的触发核心 ====================
func update_and_save_volume(target_value: int) -> void:
	var clean_volume = clampi(target_value, 0, 100)
	self.text = str(clean_volume)
	
	# ==================== 【核心需求：换图逻辑完全对齐路径】 ====================
	var icon_node = $"../TextureRect音乐BGM图标icon"
	if icon_node:
		if clean_volume == 0:
			icon_node.texture = ICON_MUTE      # =0 时变成禁止图 icon3
		else:
			icon_node.texture = ICON_NORMAL    # !=0 时变回正常的喇叭图 icon2
	# ====================================================================
	
	# 【不管数字变没变，无脑复写配置文件】
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_line("BGM_Volume = " + str(clean_volume))
		file.close()
		
	# 【同时修改 Bus: Music 的音量】
	var bus_index = AudioServer.get_bus_index("Music")
	if bus_index != -1:
		if clean_volume == 0:
			AudioServer.set_bus_volume_db(bus_index, -80.0) 
		else:
			var db_value = remap(clean_volume, 0, 100, -40.0, 0.0)
			AudioServer.set_bus_volume_db(bus_index, db_value)

# ==================== 键盘打字时的傻瓜过滤 ====================
func _on_text_changed(new_text: String) -> void:
	if new_text == "" or not new_text.is_valid_int():
		update_and_save_volume(0)
		return
		
	var val = new_text.to_int()
	update_and_save_volume(val)
	self.caret_column = self.text.length()
