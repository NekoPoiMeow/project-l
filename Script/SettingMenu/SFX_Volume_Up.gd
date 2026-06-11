extends TextureButton

var hold_timer: float = 0.0
var click_gate: bool = false
# 核心大局观：记录长按期间数字到底变过没有
var has_changed_during_hold: bool = false 

func _process(delta: float) -> void:
	if self.button_pressed:
		if not click_gate:
			trigger_plus()
			click_gate = true
			hold_timer = 0.0
			has_changed_during_hold = true # 确实变了
			
		hold_timer += delta
		if hold_timer >= 0.3:
			if hold_timer >= 0.3 + 0.05:
				trigger_plus()
				hold_timer = 0.3
				has_changed_during_hold = true
	else:
		# ==================== 【核心：鼠标松开（Release）的瞬间！】 ====================
		if click_gate and has_changed_during_hold:
			var sfx_line_edit = $"../LineEdit音乐BGM音量数值显示与编辑框"
			if sfx_line_edit and sfx_line_edit.has_method("play_sfx_test"):
				sfx_line_edit.play_sfx_test() # 松手，放声音！
		# ====================================================================
		click_gate = false
		has_changed_during_hold = false
		hold_timer = 0.0

func trigger_plus() -> void:
	var sfx_line_edit = $"../LineEdit音乐BGM音量数值显示与编辑框"
	if sfx_line_edit:
		var current_val = sfx_line_edit.text.to_int()
		if current_val >= 100: return
		# 注意：这里调用时，因为LineEdit脚本里加了判断，所以长按时内部不会疯狂放声音，而是等我们松手
		sfx_line_edit.update_and_save_volume(current_val + 1)
