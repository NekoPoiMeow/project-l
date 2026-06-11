extends TextureButton

# 计时器，用来控制长按加字的速度
var hold_timer: float = 0.0

# 当你刚按下时，需要一个开关来保证“单击只加1”，而不是刚点下去就狂滚数字
var click_gate: bool = false

func _ready() -> void:
	# 彻底清空所有乱七八糟的信号绑定，纯靠下面的帧循环来驱动
	pass

func _process(delta: float) -> void:
	# self.button_pressed 是 Godot 4 标准物理状态：只要鼠标按在按钮上，它就是 true
	if self.button_pressed:
		# 【情况 A：刚点下去的第一帧（单击动作）】
		if not click_gate:
			trigger_plus()     # 立刻触发一次加 1
			click_gate = true  # 关门，防止下一帧又触发单击
			hold_timer = 0.0   # 重置长按计时
			
		# 【情况 B：按住不放（长按动作）】
		hold_timer += delta
		# 按住超过 0.3 秒后，开始以每 0.05 秒一次的速度狂飙数字
		if hold_timer >= 0.3:
			# 每隔 0.05 秒触发一次加法
			if hold_timer >= 0.3 + 0.05:
				trigger_plus()
				hold_timer = 0.3 # 保持在长按触发线，循环计时
	else:
		# 鼠标一旦松开，全部状态瞬间归零复位
		click_gate = false
		hold_timer = 0.0

# 纯粹的核心加法，逻辑老死不动
func trigger_plus() -> void:
	var line_edit = $"../LineEdit音乐BGM音量数值显示与编辑框"
	if line_edit:
		var current_val = line_edit.text.to_int()
		if current_val >= 100:
			return
		line_edit.update_and_save_volume(current_val + 1)
