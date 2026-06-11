# 挂在 Control情报说明弹窗 上的独立脚本
extends Control

# 当这个弹窗自己被 .show() 或者是 visible 变成 true 的时候，Godot 会自动触发这个通知
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		# 如果变成了显示状态
		if visible:
			# 强行抢走当前所有的输入焦点，防止后面的菜单按钮搞事
			grab_click_focus()

# 只要它显示着，任何风吹草动（键鼠手柄）都会先经过它自己
func _input(event: InputEvent) -> void:
	# 防御：如果自己本来就是隐藏的，直接收工，不拦截任何输入
	if not visible:
		return
		
	# 只要玩家动了键盘、手柄、或者点了鼠标
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		if event.is_pressed():
			hide() # 1. 无脑隐藏自己！
			
			# 2. 核心鲁棒性：把这一帧的输入信号当场吃掉、销毁！
			# 这样绝对不会穿透到后面去触发你根节点的其他键盘/鼠标逻辑！
			get_viewport().set_input_as_handled()
			
			# 3. 尝试把焦点还给外面主菜单的“情报”按钮（如果能找到的话）
			var btn_qingbao = get_node_or_null("../Control开始菜单/VBoxContainer垂直自动排列控制按钮/TextureButton情报")
			if btn_qingbao:
				btn_qingbao.grab_focus()
