extends Control

@onready var visual_effect = $Sprite2D选项框

# 用一个变量把编辑器里设置好的“初始状态”存起来
var original_scale: Vector2

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	visual_effect.centered = true
	
	# 【关键点】在游戏一开始，立刻记住它在编辑器里的原始大小
	original_scale = visual_effect.scale
	
	visual_effect.modulate.a = 0.0
	visual_effect.visible = false
	
	self.mouse_entered.connect(_on_hover)
	self.mouse_exited.connect(_on_unhover)
	self.gui_input.connect(_on_click)

func _on_hover():
	visual_effect.visible = true
	
	# 淡入动画
	var tween = create_tween()
	tween.tween_property(visual_effect, "modulate:a", 1.0, 0.2)
	
	# 呼吸动画：在 original_scale 的基础上微调
	# 比如放大 2%： original_scale * 1.02
	var breath_tween = create_tween().set_loops()
	breath_tween.tween_property(visual_effect, "scale", original_scale * 1.02, 1.5).set_trans(Tween.TRANS_SINE)
	breath_tween.tween_property(visual_effect, "scale", original_scale, 1.5).set_trans(Tween.TRANS_SINE)

func _on_unhover():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(visual_effect, "modulate:a", 0.0, 0.2)
	# 恢复到最原始的状态，不带任何偏移
	tween.tween_property(visual_effect, "scale", original_scale, 0.2)
	
	tween.tween_callback(func(): visual_effect.visible = false)

func _on_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SceneTransition.change_scene("res://start_menu_标题页面.tscn")
