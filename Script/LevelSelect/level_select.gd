extends Node2D

const LEVEL_CSV_PATH := "res://Level/Level.csv"
const BASEMENT_SCENE := "res://scenes/Basement.tscn"
const CHAMBER_SCENE := "res://scenes/Chamber/Chamber.tscn"
const VIEW_SIZE := Vector2(1600.0, 900.0)
const MAP_SIZE := Vector2(1536.0, 1024.0)

@onready var map_viewport: Node2D = $Node2DMapViewport
@onready var big_map: Sprite2D = $Node2DMapViewport/Sprite2DBigMap
@onready var lines_root: Node2D = $Node2DMapViewport/Node2DLinesRoot
@onready var nodes_root: Node2D = $Node2DMapViewport/Node2D2NodesRoot
@onready var arrow: Sprite2D = $Node2DMapViewport/Sprite2DArrow

@onready var level_info: Control = $CanvasLayerUI/ControlLevelInfo
@onready var label_level_id: Label = $CanvasLayerUI/ControlLevelInfo/LabelLevelID
@onready var label_level_name: Label = $CanvasLayerUI/ControlLevelInfo/LabelLevelName
@onready var label_level_desc: Label = $CanvasLayerUI/ControlLevelInfo/LabelLevelDesc
@onready var label_bonus: Label = $CanvasLayerUI/ControlLevelInfo/LabelBonus

@onready var sortie_button: Button = $CanvasLayerUI/ButtonSortieButton
@onready var cancel_button: Button = $CanvasLayerUI/ButtonCancelButton
@onready var back_basement: TextureRect = $CanvasLayerUI/TextureRectBackBasement

@onready var select_sfx: AudioStreamPlayer = $CanvasLayerUI/AudioStreamPlayerSelect
@onready var sortie_sfx: AudioStreamPlayer = $CanvasLayerUI/AudioStreamPlayerSortie
@onready var cancel_sfx: AudioStreamPlayer = $CanvasLayerUI/AudioStreamPlayerCancel

var levels: Dictionary = {}
var selected_id := ""
var line_items: Array[Dictionary] = []
var line_time := 0.0

func _ready() -> void:
	big_map.centered = false
	big_map.position = Vector2.ZERO

	arrow.visible = false
	level_info.visible = false
	sortie_button.visible = false
	cancel_button.visible = false
	sortie_button.disabled = true

	sortie_button.pressed.connect(_on_sortie_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	back_basement.gui_input.connect(_on_back_basement_gui_input)

	load_levels()
	build_lines()
	build_nodes()

func _process(delta: float) -> void:
	line_time += delta
	update_line_effects()
	update_arrow_effect(delta)

func load_levels() -> void:
	levels.clear()

	if !FileAccess.file_exists(LEVEL_CSV_PATH):
		return

	var file := FileAccess.open(LEVEL_CSV_PATH, FileAccess.READ)
	if file == null:
		return

	var headers := file.get_csv_line()

	while !file.eof_reached():
		var columns := file.get_csv_line()
		if columns.is_empty():
			continue

		var row := {}

		for i in range(headers.size()):
			var key := headers[i].strip_edges()
			var value := ""
			if i < columns.size():
				value = columns[i].strip_edges()
			row[key] = value

		var id := str(row.get("id", "")).strip_edges()
		if id != "":
			apply_saved_level_progress(id, row)
			levels[id] = row

	file.close()

func apply_saved_level_progress(level_id: String, row: Dictionary) -> void:
	if !GameState.is_loaded:
		return

	var progress: Dictionary = GameState.data.get("progress", {})
	var bonus_collect: Dictionary = progress.get("level_bonus_collect", {})
	var cleared_levels: Array = progress.get("cleared_levels", [])

	if bonus_collect.has(level_id):
		row["Bonus_Collect"] = str(int(bonus_collect[level_id]))

	if bonus_collect.has(level_id) or cleared_levels.has(level_id):
		row["unlocked"] = "TRUE"

func build_nodes() -> void:
	for child in nodes_root.get_children():
		child.queue_free()

	for id in levels.keys():
		var row: Dictionary = levels[id]
		var button := Button.new()

		button.name = "ButtonLevel" + str(row.get("level_no", id))
		button.text = str(row.get("level_no", id))
		button.custom_minimum_size = Vector2(72.0, 44.0)
		button.position = get_level_pos(row) - button.custom_minimum_size * 0.5
		button.disabled = !is_level_unlocked(row)

		nodes_root.add_child(button)
		button.pressed.connect(func() -> void:
			select_level(id)
		)

func build_lines() -> void:
	line_items.clear()

	for child in lines_root.get_children():
		child.queue_free()

	for id in levels.keys():
		var row: Dictionary = levels[id]
		var from_pos := get_level_pos(row)
		var next_ids := str(row.get("next_ids", "")).split("|", false)

		for next_id in next_ids:
			next_id = next_id.strip_edges()
			if !levels.has(next_id):
				continue

			var to_pos := get_level_pos(levels[next_id])

			var line := Line2D.new()
			line.name = "Line" + id + "To" + next_id
			line.width = 7.0
			line.default_color = Color(1.0, 0.43, 0.92, 0.72)
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			line.joint_mode = Line2D.LINE_JOINT_ROUND

			lines_root.add_child(line)

			line_items.append({
				"line": line,
				"from": from_pos,
				"to": to_pos,
				"phase": randf() * 10.0,
			})

func update_line_effects() -> void:
	for item in line_items:
		var line: Line2D = item["line"]
		var from_pos: Vector2 = item["from"]
		var to_pos: Vector2 = item["to"]
		var phase: float = item["phase"]

		line.clear_points()

		var dir := to_pos - from_pos
		var normal := Vector2(-dir.y, dir.x).normalized()
		var point_count := 16

		for i in range(point_count + 1):
			var t := float(i) / float(point_count)
			var base := from_pos.lerp(to_pos, t)
			var wave := sin(t * 10.0 + line_time * 2.8 + phase) * 8.0
			var pulse := sin(line_time * 4.0 + phase) * 0.5 + 0.5
			var pos := base + normal * wave * pulse
			line.add_point(pos)

		var shine := sin(line_time * 3.0 + phase) * 0.5 + 0.5
		line.width = lerp(5.0, 9.0, shine)
		line.default_color = Color(
			lerp(0.72, 1.0, shine),
			lerp(0.22, 0.68, shine),
			lerp(0.95, 0.78, shine),
			0.72
		)

func select_level(id: String) -> void:
	if !levels.has(id):
		return

	selected_id = id
	var row: Dictionary = levels[id]
	var pos := get_level_pos(row)

	arrow.visible = true
	arrow.position = pos + Vector2(0.0, -64.0)

	level_info.visible = true
	sortie_button.visible = true
	cancel_button.visible = true
	sortie_button.disabled = !is_level_unlocked(row)

	label_level_id.text = "No." + str(row.get("level_no", ""))
	label_level_name.text = str(row.get("name", ""))
	label_level_desc.text = str(row.get("description", ""))

	var bonus_collect := int(str(row.get("Bonus_Collect", "0")))
	var bonus1_mark := "□"
	var bonus2_mark := "□"
	if bonus_collect >= 1:
		bonus1_mark = "✓"
	if bonus_collect >= 2:
		bonus2_mark = "✓"
	label_bonus.text = bonus1_mark + " " + str(row.get("Bonus", "")) + "\n" + bonus2_mark + " " + str(row.get("Bonus2", ""))

	play_level_select_sfx(row)
	focus_map(pos)

func update_arrow_effect(_delta: float) -> void:
	if !arrow.visible:
		return

	arrow.offset.y = sin(Time.get_ticks_msec() * 0.006) * 8.0

func play_level_select_sfx(row: Dictionary) -> void:
	var sfx_path := str(row.get("SelectSFX", "")).strip_edges()

	select_sfx.stop()

	if sfx_path != "" and ResourceLoader.exists(sfx_path):
		select_sfx.stream = load(sfx_path)

	if select_sfx.stream:
		select_sfx.play()

func focus_map(level_pos: Vector2) -> void:
	var desired := VIEW_SIZE * 0.5 - level_pos
	var clamped := clamp_map_position(desired)

	var tween := create_tween()
	tween.tween_property(map_viewport, "position", clamped, 0.28)

func clamp_map_position(pos: Vector2) -> Vector2:
	var min_x := VIEW_SIZE.x - MAP_SIZE.x
	var max_x := 0.0
	var min_y := VIEW_SIZE.y - MAP_SIZE.y
	var max_y := 0.0

	if MAP_SIZE.x <= VIEW_SIZE.x:
		pos.x = (VIEW_SIZE.x - MAP_SIZE.x) * 0.5
	else:
		pos.x = clamp(pos.x, min_x, max_x)

	if MAP_SIZE.y <= VIEW_SIZE.y:
		pos.y = (VIEW_SIZE.y - MAP_SIZE.y) * 0.5
	else:
		pos.y = clamp(pos.y, min_y, max_y)

	return pos

func get_level_pos(row: Dictionary) -> Vector2:
	return Vector2(
		float(str(row.get("x", "0"))),
		float(str(row.get("y", "0")))
	)

func is_level_unlocked(row: Dictionary) -> bool:
	var value := str(row.get("unlocked", "FALSE")).to_upper()
	return value == "TRUE" or value == "1" or value == "YES"

func _on_sortie_pressed() -> void:
	if selected_id == "":
		return

	var row: Dictionary = levels[selected_id]
	if !is_level_unlocked(row):
		return

	if sortie_sfx.stream:
		sortie_sfx.play()

	var scene_path := str(row.get("scene_path", "")).strip_edges()
	get_tree().root.set_meta("pending_chamber_payload", {
		"level_id": selected_id,
		"level_name": str(row.get("name", "")),
		"description": str(row.get("description", "")),
		"battle_scene": scene_path,
	})
	get_tree().change_scene_to_file(CHAMBER_SCENE)

func _on_cancel_pressed() -> void:
	selected_id = ""
	arrow.visible = false
	level_info.visible = false
	sortie_button.visible = false
	cancel_button.visible = false

	if cancel_sfx.stream:
		cancel_sfx.play()

func _on_back_basement_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_tree().change_scene_to_file(BASEMENT_SCENE)
