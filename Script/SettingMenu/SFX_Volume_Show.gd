extends LineEdit

const SAVE_PATH = "res://Config/SFX_Volume.txt"
const ICON_NORMAL = preload("res://GraphicAssets/02_SettingMenu/04_SFX_icon2.png")
const ICON_MUTE = preload("res://GraphicAssets/02_SettingMenu/04_SFX_icon3.png")

# 记录上一次的音量，用来防止打一个字就疯狂爆音
var last_volume: int = -1

func _ready() -> void:
	self.custom_minimum_size = Vector2.ZERO
	
	var final_volume: int = 50
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var raw_line = file.get_line().strip_edges()
			file.close()
			if "=" in raw_line:
				final_volume = raw_line.split("=")[1].strip_edges().to_int()
				
	# 初始化时不播放试听音（last_volume 和 final_volume 一样就不会播）
	last_volume = final_volume
	update_and_save_volume(final_volume)
	
	self.text_changed.connect(_on_text_changed)

func update_and_save_volume(target_value: int) -> void:
	var clean_volume = clampi(target_value, 0, 100)
	self.text = str(clean_volume)
	
	var icon_node = $"../TextureRect效果音音量图标icon"
	if icon_node:
		if clean_volume == 0:
			icon_node.texture = ICON_MUTE
		else:
			icon_node.texture = ICON_NORMAL
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_line("SFX_Volume = " + str(clean_volume))
		file.close()
		
	var bus_index = AudioServer.get_bus_index("SFX")
	if bus_index != -1:
		if clean_volume == 0:
			AudioServer.set_bus_volume_db(bus_index, -80.0)
		else:
			var db_value = remap(clean_volume, 0, 100, -40.0, 0.0)
			AudioServer.set_bus_volume_db(bus_index, db_value)

	# ==================== 【新加：文本变动、且数字真变了，立刻试听】 ====================
	if clean_volume != last_volume:
		last_volume = clean_volume # 刷新记忆
		play_sfx_test()
	# ====================================================================

# 傻瓜就地播放函数
func play_sfx_test() -> void:
	var player = $"../AudioStreamPlayer音效试听"
	if player:
		player.play() # 叮~ 

func _on_text_changed(new_text: String) -> void:
	if new_text == "" or not new_text.is_valid_int():
		update_and_save_volume(0)
		return
	var val = new_text.to_int()
	update_and_save_volume(val)
	self.caret_column = self.text.length()
