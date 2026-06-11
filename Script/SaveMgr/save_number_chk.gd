class_name SaveManager extends Node2D
static var selected_save_node = null
static var hovered_save_node = null

static func get_selected_slot_path() -> String:
	if selected_save_node == null or !is_instance_valid(selected_save_node):
		return "res://Save/SaveAuto.txt"
	return str(selected_save_node.SAVE_FILE)

static func is_selected_slot_empty() -> bool:
	var path := get_selected_slot_path()
	if !FileAccess.file_exists(path):
		return true

	var data := read_save_header(path)
	var chapter_id := int(data.get("SaveChapterID", 0))
	var json_text := str(data.get("SaveDataJSON", ""))
	if json_text != "":
		var parsed = JSON.parse_string(json_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			var meta: Dictionary = parsed.get("meta", {})
			return bool(meta.get("is_zero_progress", chapter_id <= 0))
	return chapter_id <= 0

static func read_save_header(path: String) -> Dictionary:
	var result: Dictionary = {}
	if !FileAccess.file_exists(path):
		return result

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result

	var content := file.get_as_text()
	file.close()

	for line in content.split("\n"):
		var clean_line := line.strip_edges()
		if clean_line == "" or not ("=" in clean_line):
			continue
		var parts := clean_line.split("=", false, 1)
		if parts.size() >= 2:
			result[parts[0].strip_edges()] = parts[1].strip_edges()

	return result
