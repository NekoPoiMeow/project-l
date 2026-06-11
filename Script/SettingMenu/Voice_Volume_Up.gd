extends TextureButton

var hold_timer: float = 0.0
var click_gate: bool = false
var has_changed_during_hold: bool = false 

func _process(delta: float) -> void:
	if self.button_pressed:
		if not click_gate:
			trigger_plus()
			click_gate = true
			hold_timer = 0.0
			has_changed_during_hold = true
			
		hold_timer += delta
		if hold_timer >= 0.3:
			if hold_timer >= 0.3 + 0.05:
				trigger_plus()
				hold_timer = 0.3
				has_changed_during_hold = true
	else:
		# 鼠标一松（Release）的瞬间，触发试听
		if click_gate and has_changed_during_hold:
			var voice_line_edit = $"../LineEdit语音Voice音量编辑框"
			if voice_line_edit and voice_line_edit.has_method("play_voice_test"):
				voice_line_edit.play_voice_test()
		click_gate = false
		has_changed_during_hold = false
		hold_timer = 0.0

func trigger_plus() -> void:
	var voice_line_edit = $"../LineEdit语音Voice音量编辑框"
	if voice_line_edit:
		var current_val = voice_line_edit.text.to_int()
		if current_val >= 100: return
		voice_line_edit.update_and_save_volume(current_val + 1)
