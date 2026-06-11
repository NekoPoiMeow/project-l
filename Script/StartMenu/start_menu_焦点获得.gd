extends Node2D

var first_button: TextureButton = null
var vbox_container: VBoxContainer = null

# 3个雷打不动的纯净路径
const BGM_CFG_PATH = "res://Config/BGM_Volume.txt"
const SFX_CFG_PATH = "res://Config/SFX_Volume.txt"
const VOICE_CFG_PATH = "res://Config/Voice_Volume.txt"

func _ready() -> void:
	await get_tree().process_frame
	
	# 自动寻找 VBox 和第一个按钮
	vbox_container = find_vbox_inside(self)
	if vbox_container:
		for child in vbox_container.get_children():
			if child is TextureButton:
				first_button = child
				break
	
	# 开局强行设置无焦点
	if get_viewport().gui_get_focus_owner():
		get_viewport().gui_get_focus_owner().release_focus()
		
	# ==================== 【1. 读 BGM 配置并拍给引擎】 ====================
	if FileAccess.file_exists(BGM_CFG_PATH):
		var file = FileAccess.open(BGM_CFG_PATH, FileAccess.READ)
		var val = file.get_line().split("=")[1].strip_edges().to_int()
		file.close()
		
		var db = remap(val, 0, 100, -40.0, 0.0) if val > 0 else -80.0
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db)
		
	# ==================== 【2. 读 SFX 配置并拍给引擎】 ====================
	if FileAccess.file_exists(SFX_CFG_PATH):
		var file = FileAccess.open(SFX_CFG_PATH, FileAccess.READ)
		var val = file.get_line().split("=")[1].strip_edges().to_int()
		file.close()
		
		var db = remap(val, 0, 100, -40.0, 0.0) if val > 0 else -80.0
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db)
		
	# ==================== 【3. 读 Voice 配置并拍给引擎】 ====================
	if FileAccess.file_exists(VOICE_CFG_PATH):
		var file = FileAccess.open(VOICE_CFG_PATH, FileAccess.READ)
		var val = file.get_line().split("=")[1].strip_edges().to_int()
		file.close()
		
		var db = remap(val, 0, 100, -40.0, 0.0) if val > 0 else -80.0
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), db)


# ==================== 【修复修复：完美对立的交替防冲突逻辑】 ====================
func _input(event: InputEvent) -> void:
	# 【动作 1】：如果玩家按了键盘或手柄
	if event is InputEventKey or event is InputEventJoypadMotion or event is InputEventJoypadButton:
		if event.is_pressed():
			var current_focus = get_viewport().gui_get_focus_owner()
			
			# 如果之前是鼠标模式（当前没有键盘焦点），准备切换至键盘模式
			if current_focus == null:
				if first_button:
					first_button.grab_focus()
					current_focus = first_button
			
			# 【核心清障】：只要换到键盘操作，立刻遍历所有按钮
			# 强行重置鼠标响应，物理震碎那些因为鼠标没挪开而卡住的悬停（Hover）伪焦点！
			if vbox_container:
				for child in vbox_container.get_children():
					if child is TextureButton and child != current_focus:
						# 闪击刷新法：关掉再开启鼠标过滤，强迫引擎卸载该按钮当前的 Hover 亮光
						var old_filter = child.mouse_filter
						child.mouse_filter = Control.MOUSE_FILTER_IGNORE
						child.mouse_filter = old_filter

	# 【动作 2】：如果玩家动了鼠标
	elif event is InputEventMouseMotion:
		# 防抖：只有鼠标单帧位移大于 2 像素，确定玩家是真的想换鼠标操作
		if event.relative.length() > 2.0:
			var current_focus = get_viewport().gui_get_focus_owner()
			# 鼠标只要一动，立刻执行你最开始的完美防御：释放键盘焦点，彻底让路给鼠标的自动 Hover
			if current_focus != null:
				current_focus.release_focus()
# ===================================================================================


func find_vbox_inside(node: Node) -> VBoxContainer:
	if node is VBoxContainer:
		return node
	for child in node.get_children():
		var result = find_vbox_inside(child)
		if result:
			return result
	return null

@onready var control情报说明弹窗: Control = $CanvasLayer开始菜单/Control情报说明弹窗

func _on_texture_button_情报_pressed() -> void:
	control情报说明弹窗.show()
