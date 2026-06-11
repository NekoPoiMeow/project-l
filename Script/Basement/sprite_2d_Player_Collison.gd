extends GIFPlayer

@export var speed := 250.0
@export var arrive_distance := 8.0
@export var path_cell_size := 16
@export var nearest_search_radius := 160
@export var alpha_limit := 0.1
@export var held_mouse_refresh_time := 0.08

const GIF_LEFT = preload("res://GraphicAssets/Character/Test_Player_1.gif")
const GIF_RIGHT = preload("res://GraphicAssets/Character/Test_Player_2.gif")

var mask_sprite: Sprite2D = null
var mask_image: Image = null
var astar := AStarGrid2D.new()
var path_points: Array[Vector2] = []
var path_index := 0
var facing := "left"
var mouse_is_held := false
var held_mouse_timer := 0.0

func _ready() -> void:
	gif = GIF_LEFT
	facing = "left"

	mask_sprite = find_collision_mask_sprite()

	if mask_sprite != null:
		mask_image = mask_sprite.texture.get_image()
		build_path_grid()

	if has_node("/root/GameState"):
		GameState.on_basement_loaded()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_is_held = true
				held_mouse_timer = 0.0
				set_mouse_target(get_global_mouse_position())
			else:
				mouse_is_held = false

func _process(delta: float) -> void:
	var key_dir = get_keyboard_direction()

	if key_dir != Vector2.ZERO:
		mouse_is_held = false
		path_points.clear()
		path_index = 0
		move_keyboard(key_dir, delta)
		return

	if mouse_is_held:
		held_mouse_timer -= delta

		if held_mouse_timer <= 0.0:
			held_mouse_timer = held_mouse_refresh_time
			set_mouse_target(get_global_mouse_position())

	move_along_path(delta)

func find_collision_mask_sprite() -> Sprite2D:
	var parent_node = get_parent()

	if parent_node == null:
		return null

	for child in parent_node.get_children():
		if child is Sprite2D:
			if "碰撞" in child.name:
				return child
			if "识别" in child.name:
				return child
			if child.texture != null:
				var texture_path = child.texture.resource_path
				if texture_path == "res://GraphicAssets/05_Basement/02_Collision.png":
					return child

	return null

func get_keyboard_direction() -> Vector2:
	var dir := Vector2.ZERO

	if Input.is_action_pressed("ui_right"):
		dir.x += 1
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_action_pressed("ui_down"):
		dir.y += 1
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1

	return dir.normalized()

func move_keyboard(dir: Vector2, delta: float) -> void:
	if dir.x > 0:
		set_facing_right()
	elif dir.x < 0:
		set_facing_left()

	var current_foot = get_foot_global_position()
	var next_foot = current_foot + dir * speed * delta

	if can_move_between(current_foot, next_foot):
		set_foot_global_position(next_foot)

func set_mouse_target(click_pos: Vector2) -> void:
	var start_foot = get_foot_global_position()
	var target_foot = click_pos

	if click_pos.x >= start_foot.x:
		set_facing_right()
	else:
		set_facing_left()

	if !can_stand_at(target_foot):
		target_foot = find_nearest_walkable_point(target_foot)

	if !can_stand_at(target_foot):
		path_points.clear()
		path_index = 0
		return

	path_points = make_path(start_foot, target_foot)
	path_index = 0

	if path_points.is_empty():
		path_points.append(target_foot)

func move_along_path(delta: float) -> void:
	if path_points.is_empty():
		return

	if path_index >= path_points.size():
		path_points.clear()
		path_index = 0
		return

	var current_foot = get_foot_global_position()
	var target_foot = path_points[path_index]
	var to_target = target_foot - current_foot

	if to_target.length() <= arrive_distance:
		path_index += 1
		return

	var dir = to_target.normalized()

	if dir.x > 0:
		set_facing_right()
	elif dir.x < 0:
		set_facing_left()

	var next_foot = current_foot + dir * speed * delta

	if can_move_between(current_foot, next_foot):
		set_foot_global_position(next_foot)
	else:
		path_points.clear()
		path_index = 0

func get_foot_global_position() -> Vector2:
	return global_position + Vector2(size.x * 0.5, size.y)

func set_foot_global_position(foot_pos: Vector2) -> void:
	global_position = foot_pos - Vector2(size.x * 0.5, size.y)

func can_move_between(from_pos: Vector2, to_pos: Vector2) -> bool:
	var distance = from_pos.distance_to(to_pos)

	if distance <= 1.0:
		return can_stand_at(to_pos)

	var steps = int(ceil(distance / 4.0))

	for i in range(1, steps + 1):
		var check_pos = from_pos.lerp(to_pos, float(i) / float(steps))

		if !can_stand_at(check_pos):
			return false

	return true

func can_stand_at(world_pos: Vector2) -> bool:
	if mask_sprite == null:
		return true

	if mask_image == null:
		return true

	var pixel_pos = world_to_mask_pixel(world_pos)
	var x = int(pixel_pos.x)
	var y = int(pixel_pos.y)

	if x < 0:
		return false
	if y < 0:
		return false
	if x >= mask_image.get_width():
		return false
	if y >= mask_image.get_height():
		return false

	var color = mask_image.get_pixel(x, y)

	return color.a > alpha_limit

func world_to_mask_pixel(world_pos: Vector2) -> Vector2:
	var local_pos = mask_sprite.to_local(world_pos)
	var tex_size = mask_sprite.texture.get_size()

	return local_pos + tex_size * 0.5

func mask_pixel_to_world(pixel_pos: Vector2) -> Vector2:
	var tex_size = mask_sprite.texture.get_size()
	var local_pos = pixel_pos - tex_size * 0.5

	return mask_sprite.to_global(local_pos)

func build_path_grid() -> void:
	if mask_sprite == null:
		return

	if mask_image == null:
		return

	var grid_width = int(ceil(float(mask_image.get_width()) / float(path_cell_size)))
	var grid_height = int(ceil(float(mask_image.get_height()) / float(path_cell_size)))

	astar.region = Rect2i(0, 0, grid_width, grid_height)
	astar.cell_size = Vector2(path_cell_size, path_cell_size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astar.update()

	for y in range(grid_height):
		for x in range(grid_width):
			var cell = Vector2i(x, y)
			var pixel = cell_to_mask_pixel(cell)

			if !is_mask_pixel_walkable(pixel):
				astar.set_point_solid(cell, true)

func make_path(start_world: Vector2, target_world: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []

	if mask_sprite == null:
		return result

	var start_cell = world_to_cell(start_world)
	var target_cell = world_to_cell(target_world)

	if !astar.region.has_point(start_cell):
		return result

	if !astar.region.has_point(target_cell):
		return result

	if astar.is_point_solid(start_cell):
		return result

	if astar.is_point_solid(target_cell):
		return result

	var id_path = astar.get_id_path(start_cell, target_cell)

	for cell in id_path:
		var world_point = mask_pixel_to_world(cell_to_mask_pixel(cell))
		result.append(world_point)

	return result

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var pixel = world_to_mask_pixel(world_pos)

	return Vector2i(
		int(pixel.x / path_cell_size),
		int(pixel.y / path_cell_size)
	)

func cell_to_mask_pixel(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * path_cell_size + path_cell_size * 0.5,
		cell.y * path_cell_size + path_cell_size * 0.5
	)

func is_mask_pixel_walkable(pixel_pos: Vector2) -> bool:
	var x = int(pixel_pos.x)
	var y = int(pixel_pos.y)

	if x < 0:
		return false
	if y < 0:
		return false
	if x >= mask_image.get_width():
		return false
	if y >= mask_image.get_height():
		return false

	var color = mask_image.get_pixel(x, y)

	return color.a > alpha_limit

func find_nearest_walkable_point(target_world: Vector2) -> Vector2:
	if can_stand_at(target_world):
		return target_world

	var best_point = target_world
	var best_distance = 99999999.0

	for radius in range(path_cell_size, nearest_search_radius + path_cell_size, path_cell_size):
		for x in range(-radius, radius + path_cell_size, path_cell_size):
			for y in range(-radius, radius + path_cell_size, path_cell_size):
				if abs(x) != radius and abs(y) != radius:
					continue

				var check_point = target_world + Vector2(x, y)

				if can_stand_at(check_point):
					var distance = target_world.distance_to(check_point)

					if distance < best_distance:
						best_distance = distance
						best_point = check_point

		if best_distance < 99999999.0:
			return best_point

	return best_point

func set_facing_left() -> void:
	if facing == "left":
		return

	facing = "left"
	gif = GIF_LEFT

func set_facing_right() -> void:
	if facing == "right":
		return

	facing = "right"
	gif = GIF_RIGHT
