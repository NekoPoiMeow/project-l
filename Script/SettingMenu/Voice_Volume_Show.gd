extends LineEdit

# 1. 规范化后的 语音 专属路径
const SAVE_PATH = "res://Config/Voice_Volume.txt"

# ==================== 【精准替换：预载语音需要的音效喇叭图】 ====================
const ICON_NORMAL = preload("res://GraphicAssets/02_SettingMenu/04_SFX_icon2.png")
const ICON_MUTE = preload("res://GraphicAssets/02_SettingMenu/04_SFX_icon3.png")
# ====================================================================

# 记录上一次的音量，用来防止键盘打字时疯狂高频爆音
var last_volume: int = -1

func _ready() -> void:
	# 2. 纯代码强行关闭尺寸限制，确保自定义大小生效
	self.custom_minimum_size = Vector2.ZERO
	
	# 3. 初始化：读取纯文本 Voice 配置
	var final_volume: int = 50
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var raw_line = file.get_line().strip_edges()
			file.close()
			if "=" in raw_line:
				# 切开等号拿右边[1]，强转数字
				final_volume = raw_line.split("=")[1].strip_edges().to_int()
				
	# 初始化时不主动播放声音（让 last_volume 一开始等于读到的数字）
	last_volume = final_volume
	update_and_save_volume(final_volume)
	
	# 4. 当输入框里面的字发生改变时自动实时同步
	self.text_changed.connect(_on_text_changed)

# ==================== 唯一的、无脑覆盖和同步的触发核心 ====================
func update_and_save_volume(target_value: int) -> void:
	# 卡死在 0 到 100 之间的阿拉伯数字
	var clean_volume = clampi(target_value, 0, 100)
	self.text = str(clean_volume)
	
	# ==================== 【精准对齐场景树：注意你的节点带个数字 2 】 ====================
	var icon_node = $"../TextureRect2语音音量图标icon"
	if icon_node:
		if clean_volume == 0:
			icon_node.texture = ICON_MUTE      # =0 时变成禁止图 icon3
		else:
			icon_node.texture = ICON_NORMAL    # !=0 时变回正常的喇叭图 icon2
	# ====================================================================
	
	# 【不管数字变没变，无脑复写 Voice 配置文件】
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# 写入规范的 Key-Value
		file.store_line("Voice_Volume = " + str(clean_volume))
		file.close()
		
	# ==================== 【精准替换：修改 Godot 语音总线 Bus: Voice】 ====================
	# 注意：请确保你在 Godot 音频面板（Audio）里创建了名为 "Voice" 的声道
	var bus_index = AudioServer.get_bus_index("Voice")
	if bus_index != -1:
		if clean_volume == 0:
			AudioServer.set_bus_volume_db(bus_index, -80.0) # 完全静音
		else:
			# 将 1-100 映射到符合人类听觉的音频分贝范围
			var db_value = remap(clean_volume, 0, 100, -40.0, 0.0)
			AudioServer.set_bus_volume_db(bus_index, db_value)
	# ====================================================================

	# ==================== 【试听逻辑：文本变动、且数字真的改变了才放】 ====================
	if clean_volume != last_volume:
		last_volume = clean_volume # 刷新变动记忆
		play_voice_test()
	# ====================================================================

# 傻瓜式就地播放函数
func play_voice_test() -> void:
	var player = $"../AudioStreamPlayer语音试听"
	if player:
		player.play() # 喂~ 喂~（播放Voice_Test.mp3）

# ==================== 键盘打字时的傻瓜过滤 ====================
func _on_text_changed(new_text: String) -> void:
	if new_text == "" or not new_text.is_valid_int():
		update_and_save_volume(0)
		return
		
	var val = new_text.to_int()
	update_and_save_volume(val)
	self.caret_column = self.text.length()
