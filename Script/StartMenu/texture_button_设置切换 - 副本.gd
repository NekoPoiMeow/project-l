extends TextureButton

func _ready():
	# 1. 刷新随机数种子，确保每次开游戏蠕动节奏都不同
	randomize()
	
	# 2. 为每个按钮独自摇出一套“原地随机参数”
	var random_delay = randf_range(0.0, 1.5)      # 随机延迟起拍时间（错开动作，打破整齐感）
	var random_speed = randf_range(1.6, 2.6)      # 随机周期速度（有的扭得快，有的扭得慢）
	var random_rot = randf_range(0.03, 0.06)      # 随机摇晃角度幅度（微幅摇摆）
	var random_scale = randf_range(1.02, 1.04)    # 随机呼吸膨胀幅度
	
	# 3. 创建无限循环大导演
	var loop_tween = create_tween().set_loops()
	
	# 4. 注入起拍延迟，让 4 个按钮绝对不同步
	loop_tween.tween_interval(random_delay)
	
	# -------------------- 【去程：原地右扭 + 原地膨胀】 --------------------
	# 仅改变旋转和缩放，绝对不碰任何 position 坐标
	loop_tween.tween_property(self, "rotation", random_rot, random_speed).set_trans(Tween.TRANS_SINE)
	loop_tween.parallel().tween_property(self, "scale", Vector2(random_scale, random_scale), random_speed).set_trans(Tween.TRANS_SINE)
	
	# -------------------- 【回程：原地左扭 + 原地缩小复位】 --------------------
	loop_tween.tween_property(self, "rotation", -random_rot, random_speed).set_trans(Tween.TRANS_SINE)
	loop_tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), random_speed).set_trans(Tween.TRANS_SINE)


func _on_mouse_entered() -> void:
	pass # Replace with function body.


func _on_focus_entered() -> void:
	pass # Replace with function body.


func play() -> void:
	pass # Replace with function body.

# 当这个按钮自己被点击时（你需要在编辑器里把它的 pressed 信号连给自己，或者看下方 ready 里的新写法）
func _on_pressed() -> void:
	# 1. 核心大局观：让整个游戏世界当场进入“全局暂停”状态
	# 此时标题场景、以及这个按钮自己的 Tween 蠕动动画，会由于没有免死金牌，瞬间定格冻结！
	get_tree().paused = true
	
	# 2. 动态加载并生成你的设置场景实例
	# 记得把 "res://settings_scene.tscn" 换成你真正的设置场景路径！
	var settings_scene = load("res://scenes/Setting_Menu.tscn")
	var settings_instance = settings_scene.instantiate()
	
	# 3. 把设置场景直接塞进当前运行的场景树最顶层（直接挂在根节点或当前按钮所在的场景里）
	# 它自带 Layer 66，会当场横空出世盖住一切
	get_tree().current_scene.add_child(settings_instance)
