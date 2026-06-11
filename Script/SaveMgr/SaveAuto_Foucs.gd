extends Control

@onready var visual_effect = $Sprite2D选项框Auto
@onready var target_rect = $"../TextureRect存档图"
@onready var label_node = $Label存档Auto
@onready var click_se = get_parent().get_node("AudioStreamPlayer点击")
@onready var delete_btn = get_parent().get_node("Control删除存档/TextureRect删除按钮图片")

const SAVE_FILE = "res://Save/SaveAuto.txt"
const SAVE_IMG = "res://Save/SaveAuto.png"
const DEFAULT_IMG = "res://GraphicAssets/04_Save_Select/01_Save_img.png"

var is_hover = false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

	load_save_file(SAVE_FILE)

	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	gui_input.connect(_on_click)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

	_update_ui()

func _on_hover() -> void:
	is_hover = true
	_update_ui()

func _on_unhover() -> void:
	is_hover = false
	_update_ui()

func _on_focus_entered() -> void:
	select_this_save()

func _on_focus_exited() -> void:
	await get_tree().process_frame

	if !is_inside_tree():
		return

	var viewport = get_viewport()
	if viewport == null:
		return

	var focus_owner = viewport.gui_get_focus_owner()

	if focus_owner == null:
		clear_selected_save()
		return

	if is_save_or_action_focus(focus_owner):
		return

	clear_selected_save()

func is_save_or_action_focus(node: Node) -> bool:
	if node.name == "Control存档1":
		return true
	if node.name == "Control存档2":
		return true
	if node.name == "Control存档Auto":
		return true
	if node.name == "Control载入游戏":
		return true
	if node.name == "Control删除存档":
		return true

	return false

func select_this_save() -> void:
	var old = SaveManager.selected_save_node

	SaveManager.selected_save_node = self

	if delete_btn:
		delete_btn.visible = false

	if old != null:
		if is_instance_valid(old):
			if old.has_method("_update_ui"):
				old._update_ui()

	_update_ui()

func clear_selected_save() -> void:
	if SaveManager.selected_save_node == self:
		SaveManager.selected_save_node = null
		_update_ui()

func _update_ui() -> void:
	var is_selected = (SaveManager.selected_save_node == self)
	var show_me = is_hover or is_selected

	if visual_effect:
		visual_effect.visible = show_me

	if show_me:
		if FileAccess.file_exists(SAVE_IMG):
			target_rect.texture = load(SAVE_IMG)
		else:
			target_rect.texture = load(DEFAULT_IMG)
	else:
		if SaveManager.selected_save_node == null:
			target_rect.texture = load(DEFAULT_IMG)

	if delete_btn:
		if is_selected:
			delete_btn.visible = false

func _on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if click_se:
					click_se.play()

				grab_focus()
				select_this_save()

func load_save_file(path: String) -> void:
	if !FileAccess.file_exists(path):
		if label_node:
			label_node.text = "空存档\n-\n-"
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var data = {}

	for line in content.split("\n"):
		if "=" in line:
			var parts = line.split("=")
			data[parts[0].strip_edges()] = parts[1].strip_edges()

	if label_node:
		label_node.text = "%s\n%s\n%s" % [
			data.get("SaveName", "无名"),
			data.get("SaveTime", "无时间"),
			data.get("SaveChapterName", "无数据")
		]
