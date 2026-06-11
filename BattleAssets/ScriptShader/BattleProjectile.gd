extends Node2D

const EFFECT_RUNNER_SCRIPT := preload("res://BattleAssets/ScriptShader/BattleEffectRunner.gd")

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

var visual: ColorRect = null
var hit_targets: Array = []

func setup(new_director, new_owner, new_target, new_attack: Dictionary, target_pos: Vector2) -> void:
	director = new_director
	projectile_owner = new_owner
	target = new_target
	attack = new_attack

	speed = float(attack.get("speed", 300.0))
	damage = float(attack.get("damage", 10.0))
	radius = float(attack.get("radius", 10.0))
	life_time = float(attack.get("life_time", 2.0))
	motion = str(attack.get("motion", "linear"))

	create_visual()

	if target_pos.distance_to(global_position) > 0.01:
		velocity = (target_pos - global_position).normalized() * speed
	else:
		velocity = Vector2.RIGHT * speed

func _physics_process(delta: float) -> void:
	if projectile_owner == null or !is_instance_valid(projectile_owner):
		queue_free()
		return

	life_time -= delta
	if life_time <= 0.0:
		queue_free()
		return

	if motion == "homing" and target != null and is_instance_valid(target) and !target.is_dead:
		var target_pos: Vector2 = target.get_attack_point(str(attack.get("target_point", "center")), attack.get("target_offset", [0, 0]))
		var desired: Vector2 = (target_pos - global_position).normalized() * speed
		velocity = velocity.lerp(desired, 0.12)

	global_position += velocity * delta

	if global_position.x < 0.0 or global_position.y < 0.0:
		queue_free()
		return

	if global_position.x > director.map_size.x or global_position.y > director.map_size.y:
		queue_free()
		return

	check_hits()

func create_visual() -> void:
	visual = ColorRect.new()
	add_child(visual)
	visual.color = Color(1.0, 0.45, 0.95, 0.85)
	visual.size = Vector2(radius * 2.0, radius * 2.0)
	visual.position = -visual.size * 0.5

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
			if attack.has("effects"):
				effect_runner.apply_effects(director, projectile_owner, entity, attack.get("effects", []), {
					"position": global_position,
					"direction": velocity.normalized() if velocity.length() > 0.01 else Vector2.RIGHT,
					"chain_depth": 0
				})
			else:
				var final_damage: float = projectile_owner.get_scaled_damage(damage, entity, attack)
				entity.take_damage(final_damage, projectile_owner)
			apply_on_hit_statuses(entity)
			queue_free()
			return

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
