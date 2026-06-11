extends Node

const AVG_SCENE_PATH = "res://scenes/AVG.tscn"

var current_avg_id := ""
var current_avg_instance: Node = null

func play(avg_id: String) -> void:
	if avg_id.strip_edges() == "":
		return

	if current_avg_instance != null:
		if is_instance_valid(current_avg_instance):
			current_avg_instance.queue_free()
			current_avg_instance = null

	current_avg_id = avg_id.strip_edges()

	var avg_scene = load(AVG_SCENE_PATH)

	if avg_scene == null:
		return

	current_avg_instance = avg_scene.instantiate()

	if current_avg_instance == null:
		return

	get_tree().root.add_child(current_avg_instance)

	if current_avg_instance.has_method("set_avg_id"):
		current_avg_instance.set_avg_id(current_avg_id)

func stop() -> void:
	if current_avg_instance != null:
		if is_instance_valid(current_avg_instance):
			current_avg_instance.queue_free()

	current_avg_instance = null
	current_avg_id = ""

	get_tree().paused = false

func is_playing() -> bool:
	if current_avg_instance == null:
		return false

	return is_instance_valid(current_avg_instance)
