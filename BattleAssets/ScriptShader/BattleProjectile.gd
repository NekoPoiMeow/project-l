extends Node2D

const EFFECT_RUNNER_SCRIPT := preload("res://BattleAssets/ScriptShader/BattleEffectRunner.gd")

const ROCKET_TEXTURE_CANDIDATES := [
	"res://BattleAssets/Textures/RPG.png",
	"res://BattleAssets/Texture/RPG.png",
	"res://BattleAssets/RPG.png",
	"res://scenes/Battle/Battle_00/RPG.png",
	"res://Art/RPG.png",
	"res://RPG.png"
]

const ROCKET_AREA_TEXTURE_CANDIDATES := [
	"res://BattleAssets/Textures/RPGArea.png",
	"res://BattleAssets/Texture/RPGArea.png",
	"res://BattleAssets/RPGArea.png",
	"res://scenes/Battle/Battle_00/RPGArea.png",
	"res://Art/RPGArea.png",
	"res://RPGArea.png"
]

var director = null
var projectile_owner = null
var target = null
var attack: Dictionary = {}
var effect_runner = EFFECT_RUNNER_SCRIPT.new()

var speed := 300.0
var damage := 10.0
var radius := 10.0
var life_time := 2.0
var motion := "linear"
var velocity := Vector2.ZERO
var age := 0.0
var start_position := Vector2.ZERO
var travel_direction := Vector2.RIGHT
var curve_side := Vector2.UP
var curve_travelled := 0.0

var visual: Node = null
var hit_targets: Array = []
var exploded := false

func setup(new_director, new_owner, new_target, new_attack: Dictionary, target_pos: Vector2) -> void:
	director = new_director
	projectile_owner = new_owner
	target = new_target
	attack = new_attack

	speed = float(attack.get("speed", 300.0))
	damage = float(attack.get("damage", 10.0))
	radius = float(attack.get("radius", 10.0))
	life_time = float(attack.get("life_time", 2.0))
	var motion_value = attack.get("motion", "linear")
	if typeof(motion_value) == TYPE_DICTIONARY:
		motion = str(motion_value.get("mode", "linear"))
	else:
		motion = str(motion_value)

	create_visual()
	start_position = global_position
	if target_pos.distance_to(global_position) > 0.01:
		travel_direction = (target_pos - global_position).normalized()
	else:
		travel_direction = Vector2.RIGHT
	curve_side = Vector2(-travel_direction.y, travel_direction.x) * (1.0 if bool(attack.get("curve_clockwise", false)) else -1.0)
	velocity = travel_direction * speed

func _physics_process(delta: float) -> void:
	if projectile_owner == null or !is_instance_valid(projectile_owner):
		queue_free()
		return

	age += delta
	life_time -= delta
	if life_time <= 0.0:
		if bool(attack.get("explode_on_expire", false)):
			explode(global_position, null, "expire")
		queue_free()
		return

	if motion == "homing" and target != null and is_instance_valid(target) and !target.is_dead:
		var target_pos: Vector2 = target.get_attack_point(str(attack.get("target_point", "center")), attack.get("target_offset", [0, 0]))
		var desired: Vector2 = (target_pos - global_position).normalized() * speed
		velocity = velocity.lerp(desired, float(attack.get("turn_rate", 0.12)))

	if motion == "parabola" or motion == "parabola_drop":
		var prev_pos: Vector2 = global_position
		curve_travelled += speed * delta
		var range_dist: float = max(float(attack.get("curve_range", attack.get("projectile_range", attack.get("range", 430.0)))), 1.0)
		var t: float = clamp(curve_travelled / range_dist, 0.0, 1.0)
		var amp: float = float(attack.get("curve_amplitude", 190.0))
		var drop: float = float(attack.get("curve_drop", 330.0))
		# Cheap thrown arc: forward a short distance, then drops down through the front of the camera.
		# This is not a side sine and not a far-map projectile.
		global_position = start_position + travel_direction * curve_travelled + Vector2.UP * sin(t * PI) * amp + Vector2.DOWN * (t * t) * drop
		velocity = (global_position - prev_pos) / max(delta, 0.0001)
		if curve_travelled >= range_dist:
			queue_free()
			return
	elif motion == "curve" or motion == "arc":
		var prev_pos_curve: Vector2 = global_position
		curve_travelled += speed * delta
		var range_dist_curve: float = max(float(attack.get("curve_range", attack.get("projectile_range", attack.get("range", 950.0)))), 1.0)
		var t_curve: float = clamp(curve_travelled / range_dist_curve, 0.0, 1.0)
		var amp_curve: float = float(attack.get("curve_amplitude", 220.0))
		global_position = start_position + travel_direction * curve_travelled + curve_side * sin(t_curve * PI) * amp_curve
		velocity = (global_position - prev_pos_curve) / max(delta, 0.0001)
		if curve_travelled >= range_dist_curve:
			queue_free()
			return
	else:
		global_position += velocity * delta

	if velocity.length() > 0.01:
		rotation = velocity.angle()

	if global_position.x < 0.0 or global_position.y < 0.0:
		if bool(attack.get("explode_on_expire", false)):
			explode(global_position, null, "out_of_bounds")
		queue_free()
		return

	if global_position.x > director.map_size.x or global_position.y > director.map_size.y:
		if bool(attack.get("explode_on_expire", false)):
			explode(global_position, null, "out_of_bounds")
		queue_free()
		return

	check_hits()

func create_visual() -> void:
	var visual_data: Dictionary = attack.get("visual", {}) if typeof(attack.get("visual", {})) == TYPE_DICTIONARY else {}
	var asset_path: String = str(visual_data.get("texture", visual_data.get("gif", "")))
	if bool(attack.get("is_rocket_projectile", false)) and asset_path == "":
		asset_path = find_existing_path(ROCKET_TEXTURE_CANDIDATES)
	elif asset_path != "" and !ResourceLoader.exists(asset_path):
		var rocket_fallback := find_existing_path(ROCKET_TEXTURE_CANDIDATES)
		if rocket_fallback != "":
			asset_path = rocket_fallback

	var visual_size := get_visual_size(visual_data, Vector2(max(radius * 2.0, 20.0), max(radius * 2.0, 20.0)))
	if bool(attack.get("is_rocket_projectile", false)):
		visual_size = Vector2(
			min(float(visual_size.x), float(attack.get("projectile_visual_max", 48.0))),
			min(float(visual_size.y), float(attack.get("projectile_visual_max", 48.0)))
		)

	if asset_path != "" and ResourceLoader.exists(asset_path):
		if asset_path.get_extension().to_lower() == "gif":
			var gif_visual = GIFPlayer.new()
			add_child(gif_visual)
			gif_visual.gif = load(asset_path)
			if gif_visual.has_method("set"):
				gif_visual.set("expand_mode", 1)
				gif_visual.set("stretch_mode", 0)
			gif_visual.size = visual_size
			gif_visual.position = -visual_size * 0.5
			visual = gif_visual
			return
		var sprite := Sprite2D.new()
		add_child(sprite)
		sprite.texture = load(asset_path)
		sprite.centered = true
		if sprite.texture != null:
			var tex_size: Vector2 = sprite.texture.get_size()
			sprite.scale = Vector2(visual_size.x / max(tex_size.x, 1.0), visual_size.y / max(tex_size.y, 1.0))
		visual = sprite
		return

	var fallback := ColorRect.new()
	add_child(fallback)
	fallback.color = Color(1.0, 0.45, 0.95, 0.85)
	fallback.size = visual_size
	fallback.position = -visual_size * 0.5
	visual = fallback

func get_visual_size(visual_data: Dictionary, fallback: Vector2) -> Vector2:
	var result := fallback
	if visual_data.has("size") and typeof(visual_data["size"]) == TYPE_ARRAY and visual_data["size"].size() >= 2:
		result = Vector2(float(visual_data["size"][0]), float(visual_data["size"][1]))
	elif visual_data.has("max_size") and typeof(visual_data["max_size"]) == TYPE_ARRAY and visual_data["max_size"].size() >= 2:
		result = Vector2(float(visual_data["max_size"][0]), float(visual_data["max_size"][1]))
	else:
		if visual_data.has("width"):
			result.x = float(visual_data.get("width", result.x))
		if visual_data.has("height"):
			result.y = float(visual_data.get("height", result.y))
	return Vector2(max(result.x, 1.0), max(result.y, 1.0))

func find_existing_path(candidates: Array) -> String:
	for path_value in candidates:
		var path := str(path_value)
		if path != "" and ResourceLoader.exists(path):
			return path
	return ""

func check_hits() -> void:
	if projectile_owner == null or !is_instance_valid(projectile_owner):
		queue_free()
		return

	var candidates: Array = director.entities
	if director.has_method("query_entities_near"):
		candidates = director.query_entities_near(global_position, radius + 96.0)

	for entity in candidates:
		if entity == null or !is_instance_valid(entity):
			continue
		if entity.is_dead:
			continue
		if entity == projectile_owner:
			continue
		if director.are_factions_allied(entity.faction, projectile_owner.faction):
			continue
		if hit_targets.has(entity):
			continue

		var dist: float = global_position.distance_to(entity.global_position)
		if dist <= radius + entity.radius:
			hit_targets.append(entity)
			if bool(attack.get("explode_on_hit", false)):
				explode(global_position, entity, "hit")
			else:
				apply_direct_hit(entity)
			apply_on_hit_statuses(entity)
			queue_free()
			return

func apply_direct_hit(entity) -> void:
	var direct_attack: Dictionary = attack.duplicate(true)
	var falloff: Dictionary = direct_attack.get("distance_damage_falloff", {}) if typeof(direct_attack.get("distance_damage_falloff", {})) == TYPE_DICTIONARY else {}
	if !falloff.is_empty():
		var dist: float = start_position.distance_to(global_position)
		var near_dist: float = float(falloff.get("near", 120.0))
		var far_dist: float = max(float(falloff.get("far", 520.0)), near_dist + 1.0)
		var t: float = clamp((dist - near_dist) / (far_dist - near_dist), 0.0, 1.0)
		var mul: float = lerp(float(falloff.get("near_mul", 1.0)), float(falloff.get("far_mul", 0.45)), t)
		direct_attack["damage"] = float(direct_attack.get("damage", damage)) * mul
	if direct_attack.has("effects"):
		effect_runner.apply_effects(director, projectile_owner, entity, direct_attack.get("effects", []), {
			"position": global_position,
			"direction": velocity.normalized() if velocity.length() > 0.01 else Vector2.RIGHT,
			"chain_depth": 0,
			"attack": direct_attack
		})
	else:
		var final_damage: float = projectile_owner.get_scaled_damage(float(direct_attack.get("damage", damage)), entity, direct_attack)
		entity.take_damage(final_damage, projectile_owner)

func explode(position: Vector2, direct_target, reason: String = "hit") -> void:
	if exploded:
		return
	exploded = true

	var explosion_radius: float = float(attack.get("explosion_radius", 150.0))
	var explosion_damage: float = float(attack.get("explosion_damage", attack.get("damage", 0.0)))
	var edge_mul: float = clamp(float(attack.get("explosion_edge_damage_mul", 0.55)), 0.0, 1.0)
	spawn_explosion_visual(position, explosion_radius)
	print("[BattleProjectile][Explosion] id=", str(attack.get("id", "")), " reason=", reason, " pos=", position, " radius=", explosion_radius, " damage=", explosion_damage)

	var candidates: Array = director.entities
	if director.has_method("query_entities_near"):
		candidates = director.query_entities_near(position, explosion_radius + 96.0)

	var hit_count := 0
	for entity in candidates:
		if entity == null or !is_instance_valid(entity):
			continue
		if entity.is_dead:
			continue
		if entity == projectile_owner:
			continue
		if director.are_factions_allied(entity.faction, projectile_owner.faction):
			continue
		var dist: float = position.distance_to(entity.global_position)
		if dist > explosion_radius + entity.radius:
			continue
		var t: float = clamp(dist / max(explosion_radius, 1.0), 0.0, 1.0)
		var damage_mul: float = lerp(1.0, edge_mul, t)
		var scaled_attack: Dictionary = attack.duplicate(true)
		scaled_attack["damage"] = explosion_damage * damage_mul
		scaled_attack["is_explosion"] = true
		var final_damage: float = projectile_owner.get_scaled_damage(explosion_damage * damage_mul, entity, scaled_attack)
		entity.take_damage(final_damage, projectile_owner)
		hit_count += 1
	print("[BattleProjectile][ExplosionHit] count=", hit_count)

func spawn_explosion_visual(position: Vector2, explosion_radius: float) -> void:
	if director == null:
		return
	var parent: Node = director.effects_root if director.has_method("get") and director.get("effects_root") != null else get_parent()
	if parent == null:
		parent = get_parent()
	var root := Node2D.new()
	root.name = "RocketExplosionVisual"
	root.global_position = position
	root.z_index = int(position.y) + 12
	parent.add_child(root)

	var visual_size: float = float(attack.get("explosion_visual_size", explosion_radius * 2.0))
	var asset_path: String = str(attack.get("explosion_texture", ""))
	if asset_path == "" or !ResourceLoader.exists(asset_path):
		asset_path = find_existing_path(ROCKET_AREA_TEXTURE_CANDIDATES)

	if asset_path != "" and ResourceLoader.exists(asset_path):
		var sprite := Sprite2D.new()
		root.add_child(sprite)
		sprite.texture = load(asset_path)
		sprite.centered = true
		sprite.modulate = Color(1, 1, 1, 0.92)
		if sprite.texture != null:
			var tex_size: Vector2 = sprite.texture.get_size()
			sprite.scale = Vector2(visual_size / max(tex_size.x, 1.0), visual_size / max(tex_size.y, 1.0))
	else:
		var circle := ColorRect.new()
		root.add_child(circle)
		circle.color = Color(1.0, 0.42, 0.12, 0.42)
		circle.size = Vector2(visual_size, visual_size)
		circle.position = -circle.size * 0.5

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = float(attack.get("explosion_visual_time", 0.28))
	root.add_child(timer)
	timer.timeout.connect(root.queue_free)
	timer.start()

func apply_on_hit_statuses(entity) -> void:
	if entity == null or !is_instance_valid(entity) or entity.is_dead:
		return
	var statuses: Array = attack.get("on_hit_statuses", [])
	for status in statuses:
		if typeof(status) != TYPE_DICTIONARY:
			continue
		if entity.is_building and !bool(status.get("include_building", false)):
			continue
		var chance: float = float(status.get("chance", 1.0))
		if randf() > chance:
			continue
		entity.add_status_effect(status, projectile_owner)
