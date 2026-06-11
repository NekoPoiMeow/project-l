extends Node2D

var label: Label = null
var velocity := Vector2.ZERO
var life_time := 1.05
var age := 0.0

func setup(text: String, color: Color, start_pos: Vector2) -> void:
	global_position = start_pos
	velocity = Vector2(randf_range(-26.0, 26.0), randf_range(-118.0, -84.0))

	label = Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.0, 0.05, 0.9))
	label.add_theme_constant_override("outline_size", 7)
	label.position = Vector2(-44.0, -28.0)
	add_child(label)

func _physics_process(delta: float) -> void:
	age += delta
	global_position += velocity * delta
	velocity.y += 90.0 * delta

	var ratio: float = clamp(age / life_time, 0.0, 1.0)
	if label != null:
		label.modulate.a = 1.0 - ratio
		label.scale = Vector2.ONE * lerp(1.28, 0.92, ratio)

	if age >= life_time:
		queue_free()
