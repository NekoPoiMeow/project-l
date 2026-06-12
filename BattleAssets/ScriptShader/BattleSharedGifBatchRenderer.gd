extends Node2D

var director = null
var draw_margin := 180.0
var max_drawn_per_frame := 2000

# Render-budget culling. This is intentionally visual-only: logic entities still
# exist, move, take damage, and can wake back to their own Sprite2D. The goal is
# to stop a 300+ trash mob from submitting 300+ overlapping sprite draws inside
# the camera when most silhouettes are unreadable anyway.
var density_cull_enabled := true
var density_cell_size := 72.0
var density_cell_cap := 2
var density_far_cell_cap := 1
var density_far_from_focus := 360.0
var strict_entity_threshold := 280
var extreme_entity_threshold := 420
var ultra_entity_threshold := 620
var screen_draw_budget_medium := 360
var screen_draw_budget_strict := 260
var screen_draw_budget_extreme := 190
var screen_draw_budget_ultra := 140

func setup(new_director) -> void:
	director = new_director
	set_process(false)

func _get_visible_rect() -> Rect2:
	var visible_rect := Rect2(Vector2(-1000000, -1000000), Vector2(2000000, 2000000))
	if director != null and director.battle_camera != null and is_instance_valid(director.battle_camera):
		var viewport_size := get_viewport_rect().size
		var zoom = director.battle_camera.zoom
		if zoom.x != 0.0 and zoom.y != 0.0:
			viewport_size = Vector2(viewport_size.x / zoom.x, viewport_size.y / zoom.y)
		var center: Vector2 = director.battle_camera.global_position
		visible_rect = Rect2(center - viewport_size * 0.5 - Vector2(draw_margin, draw_margin), viewport_size + Vector2(draw_margin * 2.0, draw_margin * 2.0))
	return visible_rect

func _draw() -> void:
	if director == null:
		return
	var entities: Array = director.entities
	if entities.is_empty():
		return

	var entity_count: int = entities.size()
	var visible_rect := _get_visible_rect()
	var focus_pos: Vector2 = Vector2.ZERO
	var has_focus := false
	if director.player_entity != null and is_instance_valid(director.player_entity):
		focus_pos = director.player_entity.global_position
		has_focus = true
	elif director.tentacle_base != null and is_instance_valid(director.tentacle_base):
		focus_pos = director.tentacle_base.global_position
		has_focus = true

	# Dynamic visual budget. The previous fixed 54px/2-3 cap was too weak when
	# hundreds of units are stacked around the player. Larger cells + lower caps
	# behave like a survivor-game crowd illusion: nearby logic is dense, but the
	# renderer only shows readable representatives.
	var cell_size: float = density_cell_size
	var near_cap: int = density_cell_cap
	var far_cap: int = density_far_cell_cap
	var draw_budget: int = screen_draw_budget_medium
	if entity_count >= ultra_entity_threshold:
		cell_size = 112.0
		near_cap = 1
		far_cap = 1
		draw_budget = screen_draw_budget_ultra
	elif entity_count >= extreme_entity_threshold:
		cell_size = 96.0
		near_cap = 1
		far_cap = 1
		draw_budget = screen_draw_budget_extreme
	elif entity_count >= strict_entity_threshold:
		cell_size = 82.0
		near_cap = 2
		far_cap = 1
		draw_budget = screen_draw_budget_strict
	max_drawn_per_frame = draw_budget

	var batch: Array = []
	var density_counts: Dictionary = {}

	# Draw nearer/important silhouettes first so culling removes hidden interiors and
	# far-away duplicate bodies before it removes the readable front line.
	var candidates: Array = []
	for e in entities:
		if e == null or !is_instance_valid(e):
			continue
		if !e.has_method("is_batch_shared_gif_visible") or !bool(e.call("is_batch_shared_gif_visible")):
			continue
		var world_pos: Vector2 = e.global_position
		if !visible_rect.has_point(world_pos):
			continue
		var focus_dist: float = 0.0
		if has_focus:
			focus_dist = world_pos.distance_to(focus_pos)
		candidates.append({"entity": e, "dist": focus_dist, "y": world_pos.y})

	candidates.sort_custom(func(a, b):
		var da: float = float(a.get("dist", 0.0))
		var db: float = float(b.get("dist", 0.0))
		# Strict weak ordering: never return true for equal items.
		# Godot reports "bad comparison function" when ties can compare inconsistently.
		if abs(da - db) > 80.0:
			return da < db
		var ya: float = float(a.get("y", 0.0))
		var yb: float = float(b.get("y", 0.0))
		if abs(ya - yb) > 0.001:
			return ya < yb
		var ea = a.get("entity")
		var eb = b.get("entity")
		var ia: int = 0
		var ib: int = 0
		if ea != null and is_instance_valid(ea):
			ia = int(ea.get_instance_id())
		if eb != null and is_instance_valid(eb):
			ib = int(eb.get_instance_id())
		return ia < ib
	)

	for item in candidates:
		var e = item.get("entity")
		if e == null or !is_instance_valid(e):
			continue
		var world_pos: Vector2 = e.global_position
		if density_cull_enabled and cell_size > 1.0:
			var cell := Vector2i(int(floor(world_pos.x / cell_size)), int(floor(world_pos.y / cell_size)))
			var key := str(cell.x) + ":" + str(cell.y)
			var current_count: int = int(density_counts.get(key, 0))
			var cap: int = near_cap
			if has_focus and world_pos.distance_to(focus_pos) > density_far_from_focus:
				cap = far_cap
			if current_count >= cap:
				continue
			density_counts[key] = current_count + 1
		batch.append(e)
		if batch.size() >= max_drawn_per_frame:
			break

	batch.sort_custom(func(a, b):
		var ay: float = a.global_position.y
		var by: float = b.global_position.y
		if abs(ay - by) > 0.001:
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
