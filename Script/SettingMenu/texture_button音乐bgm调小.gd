extends TextureButton

var hold_timer: float = 0.0
var click_gate: bool = false

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if self.button_pressed:
		if not click_gate:
			trigger_minus()
			click_gate = true
			hold_timer = 0.0
			
		hold_timer += delta
		if hold_timer >= 0.3:
			if hold_timer >= 0.3 + 0.05:
				trigger_minus()
				hold_timer = 0.3
	else:
		click_gate = false
		hold_timer = 0.0

# 检查你 调小-图标 按钮脚本里的这个函数，把它全选替换成下面这样：
func trigger_minus() -> void:
	# 彻底删掉之前带有下划线 "_" 的那行废码！
	# 只留下下面这行完全和你的场景树一模一样、没有下划线的干净路径：
	var real_line_edit = $"../LineEdit音乐BGM音量数值显示与编辑框"
	
	if real_line_edit:
		var current_val = real_line_edit.text.to_int()
		if current_val <= 0:
			return
		real_line_edit.update_and_save_volume(current_val - 1)
