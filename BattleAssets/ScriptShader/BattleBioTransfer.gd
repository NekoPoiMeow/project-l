extends Node2D

var director = null
var target_base = null
var value: int = 1
var speed: float = 640.0
var arrive_radius: float = 18.0
var sprite: Sprite2D = null
var life_time: float = 2.2

func setup(new_director, start_pos: Vector2, new_target_base, bio_value: int, texture_path: String) -> void:
	director = new_director
	target_base = new_target_base
	value = bio_value
	global_position = start_pos

	sprite = Sprite2D.new()
	sprite.name = "Sprite2DBioTransfer"
	add_child(sprite)
	sprite.texture = load(texture_path)
	sprite.centered = true
	sprite.scale = Vector2(0.85, 0.85)
	sprite.modulate = Color(1.0, 0.76, 0.98, 0.95)
	sprite.z_index = 40

func _physics_process(delta: float) -> void:
	life_time -= delta

	if target_base == null or !is_instance_valid(target_base):
		queue_free()
		return

	var target_pos: Vector2 = target_base.global_position
	var to_target: Vector2 = target_pos - global_position
	var dist: float = to_target.length()

	if dist <= arrive_radius or life_time <= 0.0:
		target_base.receive_bio(value)
		if director != null and director.has_method("on_bio_delivered_to_base"):
			director.on_bio_delivered_to_base(target_base, value)
		queue_free()
		return

	var dir: Vector2 = to_target / max(dist, 0.001)
	global_position += dir * speed * delta

	var pulse: float = sin(Time.get_ticks_msec() * 0.018) * 0.5 + 0.5
	if sprite != null:
		sprite.scale = Vector2.ONE * lerp(0.72, 1.05, pulse)
		sprite.rotation += delta * 7.0
