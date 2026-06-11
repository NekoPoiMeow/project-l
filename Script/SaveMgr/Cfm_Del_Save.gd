extends TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	self.modulate.a = 0.0
	self.mouse_entered.connect(_on_mouse_entered)
	self.mouse_exited.connect(_on_mouse_exited)
	self.gui_input.connect(_on_gui_input)

func _on_mouse_entered() -> void: self.modulate.a = 1.0
func _on_mouse_exited() -> void: self.modulate.a = 0.0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		execute_final_delete()

func execute_final_delete() -> void:
	var target = SaveManager.selected_save_node

	if target:

		var target_save = target.SAVE_FILE
		var target_png = target_save.replace(".txt", ".png")

		var dir = DirAccess.open("res://Save/")

		if dir and FileAccess.file_exists("res://Save/Save0.txt"):

			dir.copy("res://Save/Save0.txt", target_save)

			if FileAccess.file_exists("res://Save/Save0.png"):
				dir.copy("res://Save/Save0.png", target_png)

			target.load_save_file(target_save)

			await get_tree().process_frame

			var img = Image.new()
			var err = img.load(target_png)

			if err == OK:

				var tex = ImageTexture.new()
				tex.set_image(img)

				target.target_rect.texture = null
				await get_tree().process_frame
				target.target_rect.texture = tex

		SaveManager.selected_save_node = null
		get_parent().visible = false

	else:
		print("DEBUG: 找不到 SaveManager 中的选中节点")

func _process(_delta):
	if get_parent().visible:
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
