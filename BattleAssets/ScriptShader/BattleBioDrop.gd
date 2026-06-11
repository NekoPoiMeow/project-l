extends Node2D

var director = null
var value: int = 1
var magnet_radius: float = 260.0
var collect_radius: float = 36.0
var speed: float = 360.0
var target = null

func setup(new_director, pos: Vector2, bio_value: int, texture_path: String) -> void:
	director = new_director
	value = bio_value
	global_position = pos

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2DBio"
	add_child(sprite)
	sprite.texture = load(texture_path)
	sprite.centered = true
	sprite.z_index = 20

func _physics_process(delta: float) -> void:
	if director == null:
		return

	target = director.find_bio_collector_for(global_position, magnet_radius)
	if target == null or !is_instance_valid(target):
		return

	var dist: float = global_position.distance_to(target.global_position)
	if target.bio_cargo >= target.bio_cargo_max:
		return

	if dist <= collect_radius:
		var accepted: int = target.collect_bio_amount(value)
		if accepted > 0:
			value -= accepted
		if value <= 0:
			queue_free()
		return

	if dist <= magnet_radius:
		var dir: Vector2 = (target.global_position - global_position).normalized()
		global_position += dir * speed * delta
