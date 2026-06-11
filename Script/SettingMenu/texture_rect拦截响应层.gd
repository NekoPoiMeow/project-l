extends TextureRect

# Godot 4 专属：当有任何输入事件没有被子节点（中央设置面板）拦截，漏到这一层时触发
func _gui_input(event: InputEvent) -> void:
	# 1. 检查是不是鼠标左键按下了
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			# 2. 核心大局观：触发解冻与返回逻辑
			trigger_return_and_resume()

func trigger_return_and_resume() -> void:
	# 1. 【时空解冻】让之前卡死定格的标题页面（或者任意前置场景）瞬间活过来
	get_tree().paused = false
	
	# 2. 【自我毁灭】把你整个 CanvasLayer 设置场景从屏幕上彻底拔掉并销毁
	# 因为当前脚本挂在 TextureRect 上，它的上上层根节点是 CanvasLayer，所以用 owner
	if owner:
		owner.queue_free()
	else:
		# 安全保底：如果不是独立场景，就直接销毁自己
		queue_free()
