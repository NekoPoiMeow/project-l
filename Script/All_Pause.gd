extends Node

var instance = null

func _init():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	# 【原子级核心】直接判断是否按下空格，且事件必须是未处理过的
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE and not event.echo:
		# 强制接管控制权，不让事件继续往下传给 UI 控件
		get_viewport().set_input_as_handled() 
		toggle_pause()

func toggle_pause():
	if instance == null:
		instance = load("res://scenes/PauseMenu.tscn").instantiate()
		add_child(instance)
		instance.process_mode = Node.PROCESS_MODE_ALWAYS
		# 关键：销毁旧焦点，防止 UI 拿着焦点不放
		get_viewport().gui_release_focus()
		get_tree().paused = true
	else:
		instance.queue_free()
		instance = null
		get_tree().paused = false
