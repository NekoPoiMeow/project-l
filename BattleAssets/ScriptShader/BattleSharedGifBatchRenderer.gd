extends Node2D

var director = null
var draw_margin := 180.0
var max_drawn_per_frame := 2000

func setup(new_director) -> void:
	director = new_director
	set_process(false)

func _draw() -> void:
	if director == null:
		return
	var entities: Array = director.entities
	if entities.is_empty():
		return

	var visible_rect := Rect2(Vector2(-1000000, -1000000), Vector2(2000000, 2000000))
	if director.battle_camera != null and is_instance_valid(director.battle_camera):
		var viewport_size := get_viewport_rect().size
		var zoom = director.battle_camera.zoom
		if zoom.x != 0.0 and zoom.y != 0.0:
			viewport_size = Vector2(viewport_size.x / zoom.x, viewport_size.y / zoom.y)
		var center: Vector2 = director.battle_camera.global_position
		visible_rect = Rect2(center - viewport_size * 0.5 - Vector2(draw_margin, draw_margin), viewport_size + Vector2(draw_margin * 2.0, draw_margin * 2.0))

	var batch: Array = []
	for e in entities:
		if e == null or !is_instance_valid(e):
			continue
		if !e.has_method("is_batch_shared_gif_visible") or !bool(e.call("is_batch_shared_gif_visible")):
			continue
		var world_pos: Vector2 = e.global_position
		if !visible_rect.has_point(world_pos):
			continue
		batch.append(e)
		if batch.size() >= max_drawn_per_frame:
			break

	batch.sort_custom(func(a, b):
		var ay: float = a.global_position.y
		var by: float = b.global_position.y
		if abs(ay - by) > 0.01:
			return ay < by
		return int(a.get_instance_id()) < int(b.get_instance_id())
	)

	var inv := global_transform.affine_inverse()
	for e in batch:
		if e == null or !is_instance_valid(e):
			continue
		var tex = e.call("get_shared_gif_batch_texture")
		if tex == null:
			continue
		var size: Vector2 = e.call("get_shared_gif_batch_size")
		if size.x <= 0.0 or size.y <= 0.0:
			continue
		var local_pos: Vector2 = inv * e.global_position
		var flip_x := !bool(e.get("facing_right"))
		if flip_x:
			draw_set_transform(local_pos, 0.0, Vector2(-1.0, 1.0))
		else:
			draw_set_transform(local_pos, 0.0, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-size * 0.5, size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
