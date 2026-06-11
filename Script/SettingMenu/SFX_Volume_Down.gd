extends TextureButton

var hold_timer: float = 0.0
var click_gate: bool = false
var has_changed_during_hold: bool = false

func _process(delta: float) -> void:
	if self.button_pressed:
		if not click_gate:
			trigger_minus()
			click_gate = true
			hold_timer = 0.0
			has_changed_during_hold = true
			
		hold_timer += delta
		if hold_timer >= 0.3:
			if hold_timer >= 0.3 + 0.05:
				trigger_minus()
				hold_timer = 0.3
				has_changed_during_hold = true
	else:
		# ==================== 【核心：鼠标松开（Release）的瞬间！】 ====================
		if click_gate and has_changed_during_hold:
			var sfx_line_edit = $"../LineEdit音乐BGM音量数值显示与编辑框"
			if sfx_line_edit and sfx_line_edit.has_method("play_sfx_test"):
				sfx_line_edit.play_sfx_test()
		# ====================================================================
		click_gate = false
		has_changed_during_hold = false
		hold_timer = 0.0

func trigger_minus() -> void:
	var sfx_line_edit = $"../LineEdit音乐BGM音量数值显示与编辑框"
	if sfx_line_edit:
		var current_val = sfx_line_edit.text.to_int()
		if current_val <= 0: return
		sfx_line_edit.update_and_save_volume(current_val - 1)
