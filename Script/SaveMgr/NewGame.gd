extends Control

@onready var select_frame = $Sprite2D选项框载入游戏
@onready var click_se = $AudioStreamPlayer开始游戏

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

	if select_frame:
		select_frame.visible = false

	gui_input.connect(_on_gui_input)

func _process(_delta: float) -> void:
	var has_selected_save = SaveManager.selected_save_node != null

	if select_frame:
		select_frame.visible = has_selected_save

	if has_selected_save:
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_gui_input(event: InputEvent) -> void:
	if SaveManager.selected_save_node == null:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if click_se:
					click_se.play()

				var slot_path: String = SaveManager.get_selected_slot_path()
				if SaveManager.is_selected_slot_empty():
					GameState.start_new_game(slot_path)
				else:
					GameState.load_slot(slot_path)

				SceneTransition.change_scene("res://scenes/Basement.tscn")
