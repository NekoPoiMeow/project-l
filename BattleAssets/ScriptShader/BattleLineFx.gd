extends Node2D

var line: Line2D = null
var life_time := 0.18
var age := 0.0

func setup(start_pos: Vector2, end_pos: Vector2, color: Color, width: float = 8.0, lifetime: float = 0.18) -> void:
	life_time = lifetime
	global_position = Vector2.ZERO

	line = Line2D.new()
	line.width = width
	line.default_color = color
	line.z_index = 80
	line.add_point(start_pos)
	line.add_point((start_pos + end_pos) * 0.5 + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0)))
	line.add_point(end_pos)
	add_child(line)

func _physics_process(delta: float) -> void:
	age += delta
	if line != null:
		var ratio: float = clamp(age / max(life_time, 0.001), 0.0, 1.0)
		var color: Color = line.default_color
		color.a = 1.0 - ratio
		line.default_color = color
		line.width = lerp(line.width, 1.0, ratio)

	if age >= life_time:
		queue_free()
