extends Area2D

@export var npc_name := "御所"
@export var default_place_name := "营地"
@export var target_scene := "res://scenes/Basement.tscn"

@export var max_visible_distance := 180.0
@export var min_alpha_255 := 100
@export var max_alpha_255 := 255

@export var bob_height := 8.0
@export var bob_speed := 5.0
@export var squeeze_speed := 7.0
@export var squeeze_power := 0.08

var bubble: CanvasItem = null
var sound: AudioStreamPlayer = null
var place_label: Label = null
var npc_shape: CollisionShape2D = null
var player_area: Area2D = null
var player_shape: CollisionShape2D = null
var player_inside := false

var bubble_base_position := Vector2.ZERO
var bubble_base_scale := Vector2.ONE
var anim_time := 0.0

func _ready() -> void:
	bubble = find_bubble_node()
	sound = find_sound_node()
	npc_shape = find_first_child_type(self, CollisionShape2D)
	place_label = find_place_label()

	if bubble:
		bubble.visible = false
		bubble_base_position = bubble.position
		bubble_base_scale = bubble.scale
		bubble.modulate.a = 0.0

	if place_label:
		place_label.text = default_place_name

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	input_event.connect(_on_input_event)

func _process(delta: float) -> void:
	if player_inside:
		update_bubble_effect(delta)

		if is_interact_pressed():
			get_viewport().set_input_as_handled()
			AVGManager.play("AVG_Test")
	else:
		anim_time = 0.0

func _on_area_entered(area: Area2D) -> void:
	if !area.is_in_group("PlayerFoot"):
		return

	player_inside = true
	player_area = area
	player_shape = find_first_child_type(player_area, CollisionShape2D)

	if bubble:
		bubble.visible = true

	if sound:
		sound.stop()
		sound.play()

	if place_label:
		place_label.text = npc_name

func _on_area_exited(area: Area2D) -> void:
	if !area.is_in_group("PlayerFoot"):
		return

	player_inside = false
	player_area = null
	player_shape = null

	if bubble:
		bubble.visible = false
		bubble.position = bubble_base_position
		bubble.scale = bubble_base_scale
		bubble.modulate.a = 0.0

	if place_label:
		place_label.text = default_place_name

func update_bubble_effect(delta: float) -> void:
	if bubble == null:
		return

	if player_area == null:
		return

	anim_time += delta

	var npc_center = get_npc_center_position()
	var player_center = get_player_center_position()
	var distance = player_center.distance_to(npc_center)
	var closeness = 1.0 - clamp(distance / max_visible_distance, 0.0, 1.0)

	var min_alpha = clamp(float(min_alpha_255) / 255.0, 0.0, 1.0)
	var max_alpha = clamp(float(max_alpha_255) / 255.0, 0.0, 1.0)
	var alpha = lerp(min_alpha, max_alpha, closeness)

	bubble.modulate.a = alpha

	var bob = sin(anim_time * bob_speed) * bob_height
	var squeeze = sin(anim_time * squeeze_speed) * squeeze_power

	var scale_x = bubble_base_scale.x * (1.0 - squeeze)
	var scale_y = bubble_base_scale.y * (1.0 + squeeze)

	bubble.position = bubble_base_position + Vector2(0.0, bob)
	bubble.scale = Vector2(scale_x, scale_y)

func get_npc_center_position() -> Vector2:
	if npc_shape:
		return npc_shape.global_position

	return global_position

func get_player_center_position() -> Vector2:
	if player_shape:
		return player_shape.global_position

	if player_area:
		return player_area.global_position

	return Vector2.ZERO

func _on_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if !player_inside:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				get_viewport().set_input_as_handled()
				AVGManager.play("AVG_Test")

func is_interact_pressed() -> bool:
	if InputMap.has_action("Interact_NPC"):
		if Input.is_action_just_pressed("Interact_NPC"):
			return true

	if InputMap.has_action("ui_accept"):
		if Input.is_action_just_pressed("ui_accept"):
			return true

	if Input.is_key_pressed(KEY_ENTER):
		return true

	if Input.is_key_pressed(KEY_Z):
		return true

	return false

func find_bubble_node() -> CanvasItem:
	for child in get_children():
		if child is CanvasItem:
			var child_name = str(child.name)

			if "气泡" in child_name:
				return child

			if "姘旀场" in child_name:
				return child

			if "Bubble" in child_name:
				return child

	return null

func find_sound_node() -> AudioStreamPlayer:
	for child in get_children():
		if child is AudioStreamPlayer:
			return child

	return null

func find_place_label() -> Label:
	var root = get_parent()

	if root == null:
		return null

	return find_label_recursive(root)

func find_label_recursive(node: Node) -> Label:
	if node is Label:
		return node

	for child in node.get_children():
		var found = find_label_recursive(child)

		if found != null:
			return found

	return null

func find_first_child_type(node: Node, expected_type) -> Node:
	for child in node.get_children():
		if is_instance_of(child, expected_type):
			return child

	for child in node.get_children():
		var found = find_first_child_type(child, expected_type)

		if found != null:
			return found

	return null
