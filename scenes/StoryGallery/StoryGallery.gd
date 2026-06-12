extends Control

const STORY_EVENTS_CSV := "res://Config/StoryEvents.csv"
const BASEMENT_SCENE_PATH := "res://scenes/Basement.tscn"

var rows: Array[Dictionary] = []
var list: ItemList
var detail: RichTextLabel
var open_button: Button

func _ready() -> void:
	GameState.ensure_loaded()
	load_rows()
	build_ui()
	refresh_list()

func load_rows() -> void:
	rows.clear()
	if !FileAccess.file_exists(STORY_EVENTS_CSV):
		return
	var file := FileAccess.open(STORY_EVENTS_CSV, FileAccess.READ)
	if file == null:
		return
	var headers := file.get_csv_line()
	while !file.eof_reached():
		var cols := file.get_csv_line()
		if cols.is_empty():
			continue
		var row: Dictionary = {}
		for i in range(headers.size()):
			row[headers[i].strip_edges()] = cols[i].strip_edges() if i < cols.size() else ""
		if str(row.get("id", "")).strip_edges() != "":
			rows.append(row)
	file.close()

func build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.045, 0.03, 0.06, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_top = 24
	root.offset_right = -24
	root.offset_bottom = -24
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	root.add_child(left)
	var title := Label.new()
	title.text = "CG / 剧情回想"
	title.add_theme_font_size_override("font_size", 30)
	left.add_child(title)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(_on_selected)
	left.add_child(list)
	var back := Button.new()
	back.text = "返回营地"
	back.pressed.connect(_on_back)
	left.add_child(back)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail)
	open_button = Button.new()
	open_button.text = "播放/查看占位"
	open_button.pressed.connect(_on_open_pressed)
	right.add_child(open_button)

func refresh_list() -> void:
	list.clear()
	rows.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	for row: Dictionary in rows:
		var id: String = str(row.get("id", ""))
		var unlocked: bool = GameState.is_story_event_unlocked(id)
		var prefix := "✓ " if unlocked else "？ "
		var idx := list.item_count
		list.add_item(prefix + str(row.get("name", id)) + " [" + str(row.get("kind", "")) + "]")
		list.set_item_metadata(idx, id)
		if !unlocked:
			list.set_item_custom_fg_color(idx, Color(0.45, 0.42, 0.50, 1.0))
	if list.item_count > 0:
		list.select(0)
		_on_selected(0)

func _on_selected(index: int) -> void:
	if index < 0 or index >= list.item_count:
		return
	var id: String = str(list.get_item_metadata(index))
	var row: Dictionary = get_row(id)
	var unlocked: bool = GameState.is_story_event_unlocked(id)
	var text := "[b]" + str(row.get("name", id)) + "[/b]\n"
	text += "ID：" + id + "\n类型：" + str(row.get("kind", "")) + "\n状态：" + ("已解锁" if unlocked else "未解锁") + "\n\n"
	text += str(row.get("description", "")) + "\n\n"
	text += "CG：" + str(row.get("cg_path", "")) + "\nAVG：" + str(row.get("avg_scene_path", "")) + "\n\n"
	text += "[b]占位文本[/b]\n" + str(row.get("placeholder_text", ""))
	detail.text = text
	open_button.disabled = !unlocked

func get_row(id: String) -> Dictionary:
	for row: Dictionary in rows:
		if str(row.get("id", "")) == id:
			return row
	return {}

func _on_open_pressed() -> void:
	var selected := list.get_selected_items()
	if selected.is_empty():
		return
	var id: String = str(list.get_item_metadata(selected[0]))
	GameState.clear_pending_story_event(false)
	get_tree().root.set_meta("pending_avg_event", id)
	_on_selected(selected[0])

func _on_back() -> void:
	GameState.set_last_scene(BASEMENT_SCENE_PATH, false)
	GameState.save_progress_now("return_basement_from_gallery")
	get_tree().change_scene_to_file(BASEMENT_SCENE_PATH)
