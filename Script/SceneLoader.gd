extends Node

# MVP compatibility singleton for older scenes.
# Provides a minimal, safe wrapper around change_scene_to_file.

var last_scene_path := ""
var current_request := ""

func change_scene(scene_path: String) -> bool:
	return goto_scene(scene_path)

func goto_scene(scene_path: String) -> bool:
	var clean := scene_path.strip_edges()
	if clean == "":
		push_warning("[SceneLoader] empty scene path")
		return false
	if !ResourceLoader.exists(clean):
		push_warning("[SceneLoader] scene not found: " + clean)
		return false
	last_scene_path = _get_current_scene_path()
	current_request = clean
	var err := get_tree().change_scene_to_file(clean)
	if err != OK:
		push_warning("[SceneLoader] failed to change scene: " + clean + " err=" + str(err))
		return false
	return true

func back_to_basement() -> bool:
	return goto_scene("res://scenes/Basement.tscn")

func reload_current_scene() -> bool:
	var path := _get_current_scene_path()
	if path == "":
		return false
	return goto_scene(path)

func _get_current_scene_path() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path
