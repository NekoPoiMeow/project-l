extends TextureRect

func _ready() -> void:
	# 确保点击检测正常
	mouse_filter = Control.MOUSE_FILTER_STOP
	self.modulate.a = 0.0
	self.mouse_entered.connect(_on_mouse_entered)
	self.mouse_exited.connect(_on_mouse_exited)
	self.gui_input.connect(_on_gui_input)

func _on_mouse_entered() -> void:
	self.modulate.a = 1.0

func _on_mouse_exited() -> void:
	self.modulate.a = 0.0

func _on_gui_input(event: InputEvent) -> void:
	# 监听左键点击
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		reload_scene()

func reload_scene() -> void:
	# 强制重载存档场景
	# 注意：如果你的路径不是 res://scenes/Save+Load.tscn 请按需修改
	var scene_path = "res://scenes/Save+Load.tscn"
	
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("错误：找不到场景文件 " + scene_path)


func play() -> void:
	pass # Replace with function body.
