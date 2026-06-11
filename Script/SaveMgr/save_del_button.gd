extends Control

@onready var select_frame = $"../Sprite2D选项框删除存档选项框"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	self.modulate.a = 1.0

	if select_frame:
		select_frame.visible = false

	if !mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)

	if !mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	if !gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)

func _on_mouse_entered() -> void:
	if select_frame:
		select_frame.visible = true

func _on_mouse_exited() -> void:
	if select_frame:
		select_frame.visible = false

func _on_gui_input(event: InputEvent) -> void:

	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				trigger_delete_flow()

func trigger_delete_flow() -> void:

	if SaveManager.selected_save_node != null:
		if SaveManager.selected_save_node.name == "Control存档Auto":
			return

	var parent_node = get_parent().get_parent()

	for child in parent_node.get_children():
		if child.name.begins_with("Control存档"):
			if child.has_method("deselect"):
				child.deselect()

	var canvas_layer = parent_node.get_node_or_null("CanvasLayer删档确认")

	if canvas_layer:
		canvas_layer.visible = true
