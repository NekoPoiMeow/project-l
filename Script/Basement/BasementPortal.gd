extends Area2D

@export var portal_name: String = "地点"
@export var target_scene: String = ""
@export var placeholder_message: String = "暂未搭建"
@export var interact_action: StringName = &"ui_accept"
@export var label_path: NodePath = NodePath("../CanvasLayer营地UI/Control营地地点NPC提示框/Label营地事件名")
@export var hint_box_path: NodePath = NodePath("../CanvasLayer营地UI/Control营地地点NPC提示框")
@export var show_action_hint: bool = true

var player_inside: bool = false
var message_timer: float = 0.0
var label_node: Label = null
var hint_box: CanvasItem = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	label_node = get_node_or_null(label_path) as Label
	hint_box = get_node_or_null(hint_box_path) as CanvasItem
	if hint_box != null:
		hint_box.visible = false

func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0 and not player_inside:
			_hide_hint()
	if player_inside and Input.is_action_just_pressed(interact_action):
		_activate_portal()

func _on_body_entered(body: Node) -> void:
	if _is_player_node(body):
		_set_inside(true)

func _on_body_exited(body: Node) -> void:
	if _is_player_node(body):
		_set_inside(false)

func _on_area_entered(area: Area2D) -> void:
	if _is_player_node(area):
		_set_inside(true)

func _on_area_exited(area: Area2D) -> void:
	if _is_player_node(area):
		_set_inside(false)

func _is_player_node(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group("PlayerFoot"):
		return true
	var parent: Node = node.get_parent()
	while parent != null:
		if parent.name.find("玩家") >= 0 or parent.name.find("Player") >= 0:
			return true
		parent = parent.get_parent()
	return false

func _set_inside(value: bool) -> void:
	player_inside = value
	if player_inside:
		_show_hint(_format_hint())
	else:
		_hide_hint()

func _format_hint() -> String:
	if show_action_hint:
		return "%s\n按确认键进入" % portal_name
	return portal_name

func _activate_portal() -> void:
	if target_scene.strip_edges() != "":
		var err: Error = get_tree().change_scene_to_file(target_scene)
		if err != OK:
			_show_message("%s\n场景跳转失败：%s" % [portal_name, str(err)], 2.0)
	else:
		_show_message("%s\n%s" % [portal_name, placeholder_message], 1.8)

func _show_message(text: String, seconds: float) -> void:
	_show_hint(text)
	message_timer = seconds

func _show_hint(text: String) -> void:
	if hint_box != null:
		hint_box.visible = true
	if label_node != null:
		label_node.text = text

func _hide_hint() -> void:
	if hint_box != null:
		hint_box.visible = false
