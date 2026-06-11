extends Node2D

const EFFECT_RUNNER_SCRIPT := preload("res://BattleAssets/ScriptShader/BattleEffectRunner.gd")

var director = null
var source = null
var attack: Dictionary = {}
var context: Dictionary = {}
var effect_runner = EFFECT_RUNNER_SCRIPT.new()

var age := 0.0
var duration := 1.0
var motion_mode := "static"
var hit_rule_mode := "on_contact"
var hit_shape_mode := "circle"
var velocity := Vector2.ZERO
var direction := Vector2.RIGHT
var radius := 24.0
var base_radius := 24.0
var width := 48.0
var base_width := 48.0
var length := 240.0
var base_length := 240.0
var angle := 90.0
var tick_interval := 0.2
var tick_timer := 0.0
var destroy_on_hit := false
var applied_spawn_once := false
var hit_same_target_delay := 999.0
var hit_timers: Dictionary = {}
var effects: Array = []
var target_filter: Dictionary = {}
var visual: CanvasItem = null
var trail: Line2D = null
var trail_points: Array[Vector2] = []
var trail_max_points := 12
var start_position := Vector2.ZERO
var max_distance := 0.0
var orbit_angle := 0.0
var returning := false
var follow_source := false
var track_aim := false
var origin_point := "center"
var origin_offset = [0, 0]
var lob_start := Vector2.ZERO
var lob_end := Vector2.ZERO
var released_from_orbit := false
var pierce_left := 0

func setup(new_director, new_source, new_attack: Dictionary, new_context: Dictionary = {}) -> void:
	director = new_director
	source = new_source
	attack = new_attack
	context = new_context

	var motion: Dictionary = attack.get("motion", {})
	var hit_shape: Dictionary = attack.get("hit_shape", {})
	var hit_rule: Dictionary = attack.get("hit_rule", {})

	motion_mode = str(motion.get("mode", attack.get("motion", "static")))
	duration = float(motion.get("duration", motion.get("life_time", attack.get("life_time", 1.0))))
	max_distance = float(motion.get("max_distance", 0.0))
	follow_source = bool(motion.get("follow_source", false))
	track_aim = bool(motion.get("track_aim", false))
	hit_shape_mode = str(hit_shape.get("mode", "circle"))
	radius = float(hit_shape.get("radius", attack.get("radius", radius)))
	base_radius = radius
	width = float(hit_shape.get("width", radius * 2.0))
	base_width = width
	length = float(hit_shape.get("length", 240.0))
	base_length = length
	angle = float(hit_shape.get("angle", 90.0))
	hit_rule_mode = str(hit_rule.get("mode", "on_contact"))
	tick_interval = float(hit_rule.get("tick_interval", 0.2))
	hit_same_target_delay = float(hit_rule.get("hit_same_target_delay", 999.0))
	destroy_on_hit = bool(hit_rule.get("destroy_on_hit", false))
	pierce_left = int(attack.get("pierce", 0))
	effects = attack.get("effects", [])
	target_filter = attack.get("target_filter", {})

	var origin: Dictionary = attack.get("origin", {})
	origin_point = str(origin.get("point", "center"))
	origin_offset = origin.get("offset", [0, 0])

	global_position = resolve_origin()
	start_position = global_position
	direction = resolve_direction()
	velocity = direction * float(motion.get("speed", attack.get("speed", 0.0)))
	orbit_angle = direction.angle()
	rotation = direction.angle()
	setup_lob_motion(motion)

	create_visual()

	if hit_rule_mode == "on_spawn_once":
		apply_hits(0.0)
		applied_spawn_once = true

func _physics_process(delta: float) -> void:
	age += delta
	update_hit_timers(delta)
	update_motion(delta)

	if max_distance > 0.0 and global_position.distance_to(start_position) >= max_distance:
		if hit_rule_mode == "on_arrive":
			apply_hits(delta)
		queue_free()
		return

	if age >= duration:
		if hit_rule_mode == "on_expire":
			apply_hits(delta)
		queue_free()
		return

	if hit_rule_mode == "while_active_tick":
		tick_timer -= delta
		if tick_timer <= 0.0:
			tick_timer = tick_interval
			apply_hits(delta)
	elif hit_rule_mode == "on_contact":
		apply_hits(delta)

func resolve_origin() -> Vector2:
	var origin: Dictionary = attack.get("origin", {})
	var mode: String = str(origin.get("mode", "self_center"))

	if context.has("position"):
		return context["position"]

	if mode == "target_center":
		var trigger_target = context.get("trigger_target", null)
		if trigger_target != null and is_instance_valid(trigger_target):
			return trigger_target.global_position

	if mode == "camera_random_inside" and director != null and director.battle_camera != null:
		var half_view := Vector2(800.0, 450.0)
		var center: Vector2 = director.battle_camera.global_position
		return center + Vector2(randf_range(-half_view.x, half_view.x), randf_range(-half_view.y, half_view.y))

	if mode == "camera_edge" and director != null and director.battle_camera != null:
		var half_view := Vector2(800.0, 450.0)
		var center: Vector2 = director.battle_camera.global_position
		var side: int = randi() % 4
		if side == 0:
			return center + Vector2(-half_view.x, randf_range(-half_view.y, half_view.y))
		if side == 1:
			return center + Vector2(half_view.x, randf_range(-half_view.y, half_view.y))
		if side == 2:
			return center + Vector2(randf_range(-half_view.x, half_view.x), -half_view.y)
		return center + Vector2(randf_range(-half_view.x, half_view.x), half_view.y)

	if mode == "aim_offset" and source != null and is_instance_valid(source):
		var aim_dir: Vector2 = source.get_global_mouse_position() - source.global_position
		if aim_dir.length() <= 0.01:
			aim_dir = Vector2.RIGHT if bool(source.get("facing_right")) else Vector2.LEFT
		var dist: float = float(origin.get("distance", 320.0))
		var lateral: float = float(origin.get("lateral", 0.0))
		var dir_n: Vector2 = aim_dir.normalized()
		var side: Vector2 = Vector2(-dir_n.y, dir_n.x)
		return source.global_position + dir_n * dist + side * lateral

	if source != null and is_instance_valid(source):
		return source.get_attack_point(str(origin.get("point", "center")), origin.get("offset", [0, 0]))

	return Vector2.ZERO

func resolve_direction() -> Vector2:
	if context.has("direction"):
		var context_dir: Vector2 = context["direction"]
		if context_dir.length() > 0.01:
			return context_dir.normalized()

	var aim: Dictionary = attack.get("aim", {})
	var mode: String = str(aim.get("mode", "target"))
	var target_pos: Vector2 = global_position + Vector2.RIGHT

	if mode == "random_dir":
		return Vector2.RIGHT.rotated(randf() * TAU)

	if mode == "fixed_angle":
		return Vector2.RIGHT.rotated(deg_to_rad(float(aim.get("angle", 0.0))))

	if mode == "facing" and source != null and is_instance_valid(source):
		if source.has_method("get_facing_direction"):
			return source.get_facing_direction()
		return Vector2.RIGHT if bool(source.get("facing_right")) else Vector2.LEFT

	if mode == "mouse" and source != null and is_instance_valid(source):
		var mouse_dir: Vector2 = source.get_global_mouse_position() - global_position
		if mouse_dir.length() > 0.01:
			return mouse_dir.normalized()

	if mode == "player" and director != null and director.player_entity != null and is_instance_valid(director.player_entity):
		target_pos = director.player_entity.global_position
	elif mode == "nearest_enemy" and director != null and source != null and is_instance_valid(source):
		var found = director.find_target_for(source, source.target_factions, source.sense_radius)
		if found != null and is_instance_valid(found):
			target_pos = found.global_position
	elif context.has("trigger_target"):
		var trigger_target = context.get("trigger_target", null)
		if trigger_target != null and is_instance_valid(trigger_target):
			target_pos = trigger_target.global_position

	var dir: Vector2 = target_pos - global_position
	if dir.length() <= 0.01:
		return Vector2.RIGHT
	return dir.normalized()

func update_motion(delta: float) -> void:
	update_follow_source()
	update_tracked_aim()
	update_shape_over_life()

	if motion_mode == "static" or motion_mode == "beam":
		update_visual_fx(delta)
		return

	var motion: Dictionary = attack.get("motion", {})

	if motion_mode == "orbit" and source != null and is_instance_valid(source):
		var orbit_radius: float = float(motion.get("orbit_radius", 150.0))
		var orbit_speed: float = float(motion.get("orbit_speed", 4.0))
		orbit_angle += orbit_speed * delta
		global_position = source.global_position + Vector2.RIGHT.rotated(orbit_angle) * orbit_radius
		rotation = orbit_angle + PI * 0.5
		update_visual_fx(delta)
		return

	if motion_mode == "orbit_then_homing" and source != null and is_instance_valid(source):
		if !released_from_orbit:
			var found = null
			if director != null:
				found = director.find_target_for(source, source.target_factions, source.sense_radius)
			var release_after: float = float(motion.get("release_after", 0.8))
			if found != null and is_instance_valid(found) and age >= release_after:
				released_from_orbit = true
				direction = (found.global_position - global_position).normalized()
				velocity = direction * float(motion.get("speed", attack.get("speed", 360.0)))
			else:
				var orbit_radius: float = float(motion.get("orbit_radius", 110.0))
				var orbit_speed: float = float(motion.get("orbit_speed", 4.8))
				orbit_angle += orbit_speed * delta
				global_position = source.global_position + Vector2.RIGHT.rotated(orbit_angle) * orbit_radius
				rotation = orbit_angle + PI * 0.5
				update_visual_fx(delta)
				return

	if motion_mode == "lob":
		var ratio: float = clamp(age / max(duration, 0.001), 0.0, 1.0)
		var height: float = float(motion.get("arc_height", 140.0))
		global_position = lob_start.lerp(lob_end, ratio)
		global_position.y -= sin(ratio * PI) * height
		if ratio >= 1.0:
			if hit_rule_mode == "on_arrive":
				apply_hits(delta)
			queue_free()
		update_visual_fx(delta)
		return

	if motion_mode == "homing" and director != null and source != null and is_instance_valid(source):
		var found = director.find_target_for(source, source.target_factions, source.sense_radius)
		if found != null and is_instance_valid(found):
			var desired: Vector2 = (found.global_position - global_position).normalized() * velocity.length()
			velocity = velocity.lerp(desired, float(attack.get("turn_rate", 0.12)))

	if motion_mode == "boomerang" and source != null and is_instance_valid(source):
		var return_after: float = float(motion.get("return_after", duration * 0.45))
		if age >= return_after:
			returning = true
		if returning:
			var back_dir: Vector2 = source.global_position - global_position
			if back_dir.length() > 0.01:
				velocity = velocity.lerp(back_dir.normalized() * float(motion.get("speed", attack.get("speed", 320.0))), 0.16)
		if returning and global_position.distance_to(source.global_position) <= 34.0:
			queue_free()
			return

	global_position += velocity * delta
	if motion_mode == "bounce_wall":
		if global_position.x <= 0.0 or global_position.x >= director.map_size.x:
			velocity.x = -velocity.x
			global_position.x = clamp(global_position.x, 0.0, director.map_size.x)
		if global_position.y <= 0.0 or global_position.y >= director.map_size.y:
			velocity.y = -velocity.y
			global_position.y = clamp(global_position.y, 0.0, director.map_size.y)
	if velocity.length() > 0.01:
		rotation = velocity.angle()
	update_visual_fx(delta)

func update_shape_over_life() -> void:
	var shape_scale = attack.get("shape_over_life", {})
	if typeof(shape_scale) != TYPE_DICTIONARY:
		return

	var ratio: float = clamp(age / max(duration, 0.001), 0.0, 1.0)
	var from_value: float = float(shape_scale.get("from", 1.0))
	var to_value: float = float(shape_scale.get("to", 1.0))
	var scale_value: float = lerp(from_value, to_value, ratio)
	radius = base_radius * scale_value
	width = base_width * scale_value
	length = base_length * scale_value

func update_follow_source() -> void:
	if !follow_source:
		return

	if source == null or !is_instance_valid(source):
		return

	global_position = source.get_attack_point(origin_point, origin_offset)

func update_tracked_aim() -> void:
	if !track_aim:
		return

	var new_direction: Vector2 = resolve_direction()
	if new_direction.length() <= 0.01:
		return

	direction = new_direction.normalized()
	rotation = direction.angle()

func setup_lob_motion(motion: Dictionary) -> void:
	if motion_mode != "lob":
		return

	lob_start = global_position
	if context.has("target_position"):
		lob_end = context["target_position"]
		return

	var lob_range: float = float(motion.get("range", max_distance))
	if lob_range <= 0.0:
		lob_range = 520.0
	lob_end = global_position + direction * lob_range

func get_visual_size(visual_data: Dictionary, fallback: Vector2) -> Vector2:
	var result: Vector2 = fallback
	if visual_data.has("size") and typeof(visual_data["size"]) == TYPE_ARRAY and visual_data["size"].size() >= 2:
		result = Vector2(float(visual_data["size"][0]), float(visual_data["size"][1]))
	else:
		if visual_data.has("width"):
			result.x = float(visual_data.get("width", result.x))
		if visual_data.has("height"):
			result.y = float(visual_data.get("height", result.y))
	return Vector2(max(result.x, 1.0), max(result.y, 1.0))

func get_anchor_position(anchor: String, visual_size: Vector2) -> Vector2:
	if anchor == "left_center":
		return Vector2(visual_size.x * 0.5, 0.0)
	if anchor == "right_center":
		return Vector2(-visual_size.x * 0.5, 0.0)
	return Vector2.ZERO

func add_rect_indicator(parent: Node2D, visual_data: Dictionary, visual_size: Vector2) -> void:
	var indicator_path: String = str(visual_data.get("indicator_texture", ""))
	if indicator_path == "":
		return
	var tex = load(indicator_path)
	if tex == null:
		return
	var box := Sprite2D.new()
	box.name = "AttackAreaIndicator"
	box.texture = tex
	box.centered = true
	box.position = Vector2.ZERO
	box.modulate = Color(1.0, 1.0, 1.0, float(visual_data.get("indicator_alpha", 0.68)))
	box.z_index = -3
	var tex_size: Vector2 = tex.get_size()
	box.scale = Vector2(visual_size.x / max(tex_size.x, 1.0), visual_size.y / max(tex_size.y, 1.0))
	parent.add_child(box)

func create_visual() -> void:
	var visual_data: Dictionary = attack.get("visual", {})
	var primary: Color = parse_color(visual_data.get("primary", "ff4f72"))
	var secondary: Color = parse_color(visual_data.get("secondary", "ffd8c8"))
	var alpha: float = float(visual_data.get("alpha", 0.82))
	trail_max_points = int(visual_data.get("trail_points", 12))

	var asset_path: String = str(visual_data.get("gif", visual_data.get("texture", "")))
	if asset_path != "":
		var asset_root := Node2D.new()
		add_child(asset_root)
		if hit_shape_mode == "beam_rect" and asset_path.get_extension().to_lower() != "gif":
			var beam_sprite := Sprite2D.new()
			asset_root.add_child(beam_sprite)
			beam_sprite.texture = load(asset_path)
			beam_sprite.centered = true
			beam_sprite.position = Vector2(length * 0.5, 0.0)
			beam_sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
			if beam_sprite.texture != null:
				var beam_tex_size: Vector2 = beam_sprite.texture.get_size()
				beam_sprite.scale = Vector2(length / max(beam_tex_size.x, 1.0), max(width, 8.0) / max(beam_tex_size.y, 1.0))
		elif asset_path.get_extension().to_lower() == "gif":
			var visual_size: Vector2 = get_visual_size(visual_data, Vector2(radius * 2.4, radius * 2.4))
			add_rect_indicator(asset_root, visual_data, visual_size)
			var gif_visual = GIFPlayer.new()
			asset_root.add_child(gif_visual)
			gif_visual.gif = load(asset_path)
			# The GIFPlayer addon needs explicit stretch settings for size to mean rendered size.
			if gif_visual.has_method("set"):
				gif_visual.set("expand_mode", 1)
				gif_visual.set("stretch_mode", 0)
			gif_visual.size = visual_size
			var anchor: String = str(visual_data.get("anchor", "center"))
			if anchor == "left_center":
				gif_visual.position = Vector2(0.0, -visual_size.y * 0.5)
			elif anchor == "right_center":
				gif_visual.position = Vector2(-visual_size.x, -visual_size.y * 0.5)
			else:
				gif_visual.position = -visual_size * 0.5
			gif_visual.modulate = Color(1.0, 1.0, 1.0, alpha)
		else:
			var visual_size: Vector2 = get_visual_size(visual_data, Vector2(max(radius * 2.2, 12.0), max(radius * 2.2, 12.0)))
			add_rect_indicator(asset_root, visual_data, visual_size)
			var sprite := Sprite2D.new()
			asset_root.add_child(sprite)
			sprite.texture = load(asset_path)
			sprite.centered = true
			sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
			if sprite.texture != null:
				var tex_size: Vector2 = sprite.texture.get_size()
				sprite.scale = Vector2(visual_size.x / max(tex_size.x, 1.0), visual_size.y / max(tex_size.y, 1.0))
				var anchor: String = str(visual_data.get("anchor", "center"))
				sprite.position = get_anchor_position(anchor, visual_size)
		visual = asset_root
		trail = Line2D.new()
		trail.width = max(3.0, float(visual_data.get("trail_width", radius * 0.30)))
		var asset_trail_color: Color = primary
		asset_trail_color.a = 0.35
		trail.default_color = asset_trail_color
		trail.z_index = -2
		get_parent().add_child(trail)
		return

	if hit_shape_mode == "beam_rect":
		var beam_root := Node2D.new()
		add_child(beam_root)
		for i in range(4):
			var rect := ColorRect.new()
			var band_alpha: float = alpha * lerp(0.22, 0.62, float(i) / 3.0)
			rect.color = primary.lerp(secondary, float(i) / 4.0)
			rect.color.a = band_alpha
			rect.size = Vector2(length, max(4.0, width * (1.0 - float(i) * 0.2)))
			rect.position = Vector2(0.0, -rect.size.y * 0.5 + randf_range(-3.0, 3.0))
			beam_root.add_child(rect)
		visual = beam_root
		return

	if hit_shape_mode == "rect":
		var rect_root := Node2D.new()
		add_child(rect_root)
		add_rect_indicator(rect_root, visual_data, Vector2(length, width))
		if rect_root.get_child_count() == 0:
			var outline := ColorRect.new()
			outline.color = Color(primary.r, primary.g, primary.b, alpha * 0.22)
			outline.size = Vector2(length, width)
			outline.position = -outline.size * 0.5
			rect_root.add_child(outline)
		visual = rect_root
		return

	if hit_shape_mode == "sector":
		var sector_root := Node2D.new()
		add_child(sector_root)
		var blade_count: int = 7
		for i in range(blade_count):
			var rect := ColorRect.new()
			var t: float = float(i) / float(max(blade_count - 1, 1))
			rect.color = primary.lerp(secondary, t)
			rect.color.a = alpha * lerp(0.45, 0.82, 1.0 - abs(t - 0.5))
			rect.size = Vector2(radius, 8.0)
			rect.position = Vector2(12.0, -4.0)
			rect.rotation = lerp(-deg_to_rad(angle) * 0.5, deg_to_rad(angle) * 0.5, t)
			sector_root.add_child(rect)
		visual = sector_root
		return

	var root := Node2D.new()
	add_child(root)
	var pixel_count: int = int(visual_data.get("pixel_count", 9))
	for i in range(pixel_count):
		var rect := ColorRect.new()
		var t: float = float(i) / float(max(pixel_count - 1, 1))
		var size: float = lerp(radius * 0.36, radius * 0.82, 1.0 - t)
		rect.color = primary.lerp(secondary, t)
		rect.color.a = alpha * lerp(0.32, 0.92, 1.0 - t)
		rect.size = Vector2(size, size)
		rect.position = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, radius * 0.55) - rect.size * 0.5
		root.add_child(rect)
	visual = root
	trail = Line2D.new()
	trail.width = max(3.0, float(visual_data.get("trail_width", radius * 0.35)))
	var trail_color: Color = primary
	trail_color.a = 0.42
	trail.default_color = trail_color
	trail.z_index = -2
	get_parent().add_child(trail)

func update_visual_fx(_delta: float) -> void:
	var pulse: float = sin(Time.get_ticks_msec() * 0.018 + get_instance_id() * 0.13) * 0.5 + 0.5
	if visual != null:
		var shape_scale_visual: float = 1.0
		if base_radius > 0.001:
			shape_scale_visual = radius / base_radius
		visual.scale = Vector2.ONE * shape_scale_visual * lerp(0.92, 1.12, pulse)

	if trail != null:
		trail_points.append(global_position)
		while trail_points.size() > trail_max_points:
			trail_points.pop_front()
		trail.clear_points()
		for point in trail_points:
			trail.add_point(point)

func _exit_tree() -> void:
	if trail != null and is_instance_valid(trail):
		trail.queue_free()

func parse_color(value) -> Color:
	if value is Color:
		return value
	var text: String = str(value)
	if text.begins_with("#"):
		text = text.substr(1)
	return Color.html("#" + text)

func apply_hits(delta: float) -> void:
	var candidates: Array = director.entities
	if director.has_method("query_entities_near"):
		candidates = director.query_entities_near(global_position, get_query_radius())

	for entity in candidates:
		if entity == null or !is_instance_valid(entity):
			continue

		if entity.is_dead:
			continue

		if !can_hit_entity(entity):
			continue

		if !is_entity_in_shape(entity):
			continue

		var key: String = str(entity.get_instance_id())
		if float(hit_timers.get(key, 0.0)) > 0.0:
			continue

		hit_timers[key] = hit_same_target_delay
		var hit_context: Dictionary = context.duplicate(true)
		hit_context["position"] = global_position
		hit_context["direction"] = direction
		hit_context["delta"] = delta
		hit_context["radius"] = radius
		hit_context["age"] = age
		hit_context["duration"] = duration
		hit_context["life_ratio"] = clamp(age / max(duration, 0.001), 0.0, 1.0)
		hit_context["attack"] = attack
		effect_runner.apply_effects(director, source, entity, effects, hit_context)

		if destroy_on_hit:
			if pierce_left > 0:
				pierce_left -= 1
				continue
			queue_free()
			return

func get_query_radius() -> float:
	if hit_shape_mode == "beam_rect":
		return length + width + 80.0
	if hit_shape_mode == "rect":
		return max(length, width) * 0.75 + 120.0
	if hit_shape_mode == "sector":
		return radius + 80.0
	return radius + 80.0

func can_hit_entity(entity) -> bool:
	if source != null and is_instance_valid(source) and entity == source and !bool(target_filter.get("include_self", false)):
		return false

	var relation: String = str(target_filter.get("relation", "enemy"))
	if source != null and is_instance_valid(source):
		var allied: bool = director.are_factions_allied(entity.faction, source.faction)
		if relation == "enemy" and allied:
			return false
		if relation == "ally" and !allied:
			return false

	if !bool(target_filter.get("include_building", true)) and entity.is_building:
		return false

	if target_filter.has("types"):
		var types: Array = target_filter.get("types", [])
		if !types.has(entity.entity_type):
			return false

	if target_filter.has("tags"):
		var required_tags: Array = target_filter.get("tags", [])
		var matched := false
		for tag in required_tags:
			if entity.tags.has(tag):
				matched = true
				break
		if !matched:
			return false

	return true

func is_entity_in_shape(entity) -> bool:
	if hit_shape_mode == "beam_rect":
		var local: Vector2 = (entity.global_position - global_position).rotated(-rotation)
		return local.x >= 0.0 and local.x <= length and abs(local.y) <= width * 0.5 + entity.radius

	if hit_shape_mode == "rect":
		var local_rect: Vector2 = (entity.global_position - global_position).rotated(-rotation)
		return abs(local_rect.x) <= length * 0.5 + entity.radius and abs(local_rect.y) <= width * 0.5 + entity.radius

	if hit_shape_mode == "sector":
		var to_entity: Vector2 = entity.global_position - global_position
		if to_entity.length() > radius + entity.radius:
			return false
		if to_entity.length() <= 0.01:
			return true
		var half_angle: float = deg_to_rad(angle) * 0.5
		return abs(direction.angle_to(to_entity.normalized())) <= half_angle

	var dist: float = global_position.distance_to(entity.global_position)
	return dist <= radius + entity.radius

func update_hit_timers(delta: float) -> void:
	for key in hit_timers.keys():
		hit_timers[key] = max(0.0, float(hit_timers[key]) - delta)
