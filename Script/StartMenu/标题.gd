extends TextureRect

func _ready():
	# 一上来直接进入摇摆，不修改你的任何位置、大小和透明度
	start_pure_rotation_loop()

func start_pure_rotation_loop():
	# 建立无限循环大导演
	var loop_tween = create_tween().set_loops()
	
	# 1. 用 2.2 秒时间，往右极其轻柔地只旋转一个微小的角度（0.04 弧度 ≈ 2.3 度）
	loop_tween.tween_property(self, "rotation", 0.04, 2.2).set_trans(Tween.TRANS_SINE)
	
	# 2. 再用 2.2 秒时间，往左晃动到对称的相反角度
	loop_tween.tween_property(self, "rotation", -0.04, 2.2).set_trans(Tween.TRANS_SINE)
