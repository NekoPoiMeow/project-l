extends Control

const UPGRADE_CSV := "res://Config/OutGameUpgrades.csv"
const BASEMENT_SCENE_PATH := "res://scenes/Basement.tscn"

var rows: Array[Dictionary] = []
var rows_by_id: Dictionary = {}
var current_tab := "player"
var selected_id := ""
var node_buttons: Dictionary = {}

var lust_label: Label
var result_label: Label
var graph_panel: Control
var detail_label: RichTextLabel
var upgrade_button: Button
var tab_box: VBoxContainer

const NODE_SIZE := Vector2(210, 78)
const GRID_STEP := Vector2(260, 125)
const GRAPH_MARGIN := Vector2(70, 60)

func _ready() -> void:
	GameState.ensure_loaded()
	load_upgrade_rows()
	build_ui()
	select_tab("player")

func _draw() -> void:
	if graph_panel == null:
		return
	for row in rows:
		if get_tab(row) != current_tab:
			continue
		var id := str(row.get("id", ""))
		if !node_buttons.has(id):
			continue
		var prereq_text := str(row.get("prereq", "")).strip_edges()
		if prereq_text == "":
			continue
		var to_button: Button = node_buttons[id]
		var to_pos := canvas_to_self(to_button.global_position + to_button.size * 0.5)
		for req in prereq_text.split("|", false):
			var req_id := str(req).strip_edges()
			if ":" in req_id:
				req_id = req_id.split(":", false, 1)[0]
			if node_buttons.has(req_id):
				var from_button: Button = node_buttons[req_id]
				var from_pos := canvas_to_self(from_button.global_position + from_button.size * 0.5)
				draw_line(from_pos, to_pos, Color(0.82, 0.38, 0.9, 0.75), 3.0)

func canvas_to_self(canvas_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * canvas_pos

func load_upgrade_rows() -> void:
	rows.clear()
	rows_by_id.clear()
	if !FileAccess.file_exists(UPGRADE_CSV):
		push_error("Missing upgrade csv: " + UPGRADE_CSV)
		return
	var file := FileAccess.open(UPGRADE_CSV, FileAccess.READ)
	if file == null:
		return
	var headers := file.get_csv_line()
	while !file.eof_reached():
		var columns := file.get_csv_line()
		if columns.is_empty():
			continue
		var row: Dictionary = {}
		for i in range(headers.size()):
			var key := headers[i].strip_edges()
			var value := ""
			if i < columns.size():
				value = columns[i].strip_edges()
			row[key] = value
		var id := str(row.get("id", "")).strip_edges()
		if id == "":
			continue
		rows.append(row)
		rows_by_id[id] = row
	file.close()

func build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.035, 0.075, 1.0)
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
	left.custom_minimum_size = Vector2(190, 0)
	root.add_child(left)

	var title := Label.new()
	title.text = "局外升级"
	title.add_theme_font_size_override("font_size", 30)
	left.add_child(title)

	lust_label = Label.new()
	lust_label.add_theme_font_size_override("font_size", 20)
	left.add_child(lust_label)

	result_label = Label.new()
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size = Vector2(190, 180)
	left.add_child(result_label)

	tab_box = VBoxContainer.new()
	tab_box.add_theme_constant_override("separation", 8)
	left.add_child(tab_box)
	add_tab_button("player", "玩家")
	add_tab_button("base", "基地")
	add_tab_button("minion", "小兵")
	add_tab_button("dungeon", "地窖")
	add_tab_button("merchant", "商人")

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	var basement_btn := Button.new()
	basement_btn.text = "返回营地"
	basement_btn.pressed.connect(_on_return_basement_pressed)
	left.add_child(basement_btn)

	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_child(scroll)

	graph_panel = Control.new()
	graph_panel.custom_minimum_size = Vector2(1700, 1050)
	scroll.add_child(graph_panel)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(360, 0)
	right.add_theme_constant_override("separation", 10)
	root.add_child(right)

	var detail_title := Label.new()
	detail_title.text = "节点详情"
	detail_title.add_theme_font_size_override("font_size", 24)
	right.add_child(detail_title)

	detail_label = RichTextLabel.new()
	detail_label.bbcode_enabled = true
	detail_label.fit_content = false
	detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_label)

	upgrade_button = Button.new()
	upgrade_button.text = "升级"
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	right.add_child(upgrade_button)

	refresh_header()

func add_tab_button(tab: String, label_text: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.pressed.connect(select_tab.bind(tab))
	tab_box.add_child(button)

func select_tab(tab: String) -> void:
	current_tab = tab
	selected_id = ""
	rebuild_graph()
	refresh_header()
	refresh_detail()
	queue_redraw()

func rebuild_graph() -> void:
	node_buttons.clear()
	if graph_panel == null:
		return
	for child in graph_panel.get_children():
		graph_panel.remove_child(child)
		child.queue_free()

	# Draw prereq branches first so buttons sit above the branch art.
	rebuild_branch_lines()

	for row in rows:
		if get_tab(row) != current_tab:
			continue
		var id := str(row.get("id", ""))
		var button := Button.new()
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.position = parse_position(str(row.get("position", "0|0")))
		button.text = make_node_text(row)
		button.disabled = !is_prereq_met(row) and get_level(row) <= 0
		button.z_index = 5
		button.pressed.connect(_on_upgrade_node_pressed.bind(id))
		graph_panel.add_child(button)
		node_buttons[id] = button

func rebuild_branch_lines() -> void:
	for row in rows:
		if get_tab(row) != current_tab:
			continue
		var id := str(row.get("id", ""))
		var prereq_text := str(row.get("prereq", "")).strip_edges()
		if id == "" or prereq_text == "":
			continue
		var to_pos := parse_position(str(row.get("position", "0|0"))) + NODE_SIZE * 0.5
		for req in prereq_text.split("|", false):
			var req_id := str(req).strip_edges()
			if req_id == "":
				continue
			if ":" in req_id:
				req_id = req_id.split(":", false, 1)[0].strip_edges()
			if !rows_by_id.has(req_id):
				continue
			var req_row: Dictionary = rows_by_id[req_id]
			if get_tab(req_row) != current_tab:
				continue
			var from_pos := parse_position(str(req_row.get("position", "0|0"))) + NODE_SIZE * 0.5
			var unlocked := get_level(req_row) > 0 and is_prereq_met(row)
			add_branch_line(from_pos, to_pos, unlocked)

func add_branch_line(from_pos: Vector2, to_pos: Vector2, unlocked: bool) -> void:
	var color := Color(0.92, 0.42, 0.96, 0.78) if unlocked else Color(0.35, 0.24, 0.42, 0.62)
	var trunk := Line2D.new()
	trunk.width = 4.0 if unlocked else 2.5
	trunk.default_color = color
	trunk.z_index = 0
	var mid_x := (from_pos.x + to_pos.x) * 0.5
	trunk.add_point(from_pos)
	trunk.add_point(Vector2(mid_x, from_pos.y))
	trunk.add_point(Vector2(mid_x, to_pos.y))
	trunk.add_point(to_pos)
	graph_panel.add_child(trunk)

	# Small side twigs make the prerequisite graph read more like branches instead of plain tags.
	var dir: float = 1.0
	if to_pos.x < from_pos.x:
		dir = -1.0
	var twig_points: Array[float] = [0.35, 0.65]
	for t: float in twig_points:
		var branch_base: Vector2 = from_pos.lerp(to_pos, t)
		var twig := Line2D.new()
		twig.width = 2.0
		twig.default_color = Color(color.r, color.g, color.b, color.a * 0.65)
		twig.z_index = 0
		twig.add_point(branch_base)
		twig.add_point(branch_base + Vector2(28.0 * dir, -18.0))
		graph_panel.add_child(twig)

func refresh_header() -> void:
	if lust_label != null:
		lust_label.text = "淫能：" + str(GameState.get_lust())
	if result_label != null:
		var result: Dictionary = GameState.get_last_battle_result()
		if result.is_empty():
			result_label.text = "无最近战斗结算"
		else:
			var win_text: String = "胜利" if result.get("win", false) == true else "失败"
			var captive_text: String = ""
			if str(result.get("captive_id", "")) != "":
				captive_text = "\n通关俘虏：" + str(result.get("captive_id", ""))
			var reward_text: String = str(result.get("lust_reward", 0))
			var time_text: String = str(round(float(result.get("battle_time", 0.0))))
			result_label.text = "最近战斗结算" + "\n结果：" + win_text + "\n本次获得淫能：" + reward_text + "\n淫能基数：" + str(result.get("lust_base_score", result.get("kill_count", 0))) + "\n击杀：" + str(result.get("kill_count", 0)) + "\n战斗时间：" + time_text + "秒" + captive_text

func refresh_detail() -> void:
	if detail_label == null or upgrade_button == null:
		return
	if selected_id == "" or !rows_by_id.has(selected_id):
		detail_label.text = "选择一个升级节点。"
		upgrade_button.disabled = true
		return

	var row: Dictionary = rows_by_id[selected_id]
	var level := get_level(row)
	var max_level := int(row.get("max_level", 1))
	var cost := get_next_cost(row)
	var prereq_ok := is_prereq_met(row)
	var can_pay := GameState.get_lust() >= cost
	var effect_key := str(row.get("effect_key", ""))
	var values := parse_float_list(str(row.get("values", "")))
	var current_value := 0.0
	var next_value := 0.0
	if values.size() > 0:
		if level > 0:
			current_value = values[int(clamp(level - 1, 0, values.size() - 1))]
		if level < max_level:
			next_value = values[int(clamp(level, 0, values.size() - 1))]

	var text := "[b]" + str(row.get("name", selected_id)) + "[/b]\n"
	text += "等级：" + str(level) + "/" + str(max_level) + "\n"
	text += str(row.get("desc", row.get("description", ""))) + "\n\n"
	text += "效果：" + effect_key + "\n"
	text += "当前：" + str(current_value) + "  下级：" + str(next_value) + "\n"
	if str(row.get("prereq", "")).strip_edges() != "":
		text += "前置：" + str(row.get("prereq", "")) + (" [color=green]已满足[/color]\n" if prereq_ok else " [color=red]未满足[/color]\n")
	if level >= max_level:
		text += "\n[color=yellow]已满级[/color]"
	else:
		text += "\n花费：" + str(cost) + " 淫能"
		if !can_pay:
			text += " [color=red]不足[/color]"
	detail_label.text = text
	upgrade_button.disabled = level >= max_level or !prereq_ok or !can_pay
	upgrade_button.text = "升级：" + str(cost) + " 淫能" if level < max_level else "已满级"

func _on_upgrade_node_pressed(id: String) -> void:
	selected_id = id
	refresh_detail()
	queue_redraw()

func _on_upgrade_pressed() -> void:
	if selected_id == "" or !rows_by_id.has(selected_id):
		return
	var row: Dictionary = rows_by_id[selected_id]
	var level := get_level(row)
	var max_level := int(row.get("max_level", 1))
	if level >= max_level:
		return
	if !is_prereq_met(row):
		return
	var cost := get_next_cost(row)
	if !GameState.spend_lust(cost, false):
		refresh_header()
		refresh_detail()
		return
	GameState.set_upgrade_level(get_group(row), str(row.get("id", "")), level + 1, false)
	apply_unlock_side_effect(row, level + 1)
	GameState.save_progress_now("outgame_upgrade")
	rebuild_graph()
	refresh_header()
	refresh_detail()
	queue_redraw()



func apply_unlock_side_effect(row: Dictionary, new_level: int) -> void:
	var effect_key: String = str(row.get("effect_key", "")).strip_edges()
	if effect_key == "unlock_torture_item":
		var values_text: String = str(row.get("values", "")).strip_edges()
		var parts: PackedStringArray = values_text.split("|", false)
		var index: int = int(clamp(new_level - 1, 0, max(0, parts.size() - 1)))
		if parts.size() > 0:
			var item_id: String = str(parts[index]).strip_edges()
			if item_id != "":
				GameState.unlock_item("torture_items", item_id, false)
	elif effect_key == "unlock_event":
		var event_id: String = str(row.get("values", "")).strip_edges()
		if event_id != "":
			GameState.unlock_story_event(event_id, false)

func _on_return_basement_pressed() -> void:
	GameState.set_last_scene(BASEMENT_SCENE_PATH, false)
	GameState.save_progress_now("return_basement")
	get_tree().change_scene_to_file(BASEMENT_SCENE_PATH)

func get_tab(row: Dictionary) -> String:
	return str(row.get("tab", row.get("group", "player"))).strip_edges()

func get_group(row: Dictionary) -> String:
	return str(row.get("group", get_tab(row))).strip_edges()

func get_level(row: Dictionary) -> int:
	return GameState.get_upgrade_level(get_group(row), str(row.get("id", "")))

func get_next_cost(row: Dictionary) -> int:
	var level := get_level(row)
	var costs := parse_int_list(str(row.get("costs", "0")))
	if costs.is_empty():
		return 0
	return costs[int(clamp(level, 0, costs.size() - 1))]

func is_prereq_met(row: Dictionary) -> bool:
	var prereq_text := str(row.get("prereq", "")).strip_edges()
	if prereq_text == "":
		return true
	for item in prereq_text.split("|", false):
		var clean := str(item).strip_edges()
		if clean == "":
			continue
		var req_id := clean
		var req_level := 1
		if ":" in clean:
			var parts := clean.split(":", false, 1)
			req_id = parts[0].strip_edges()
			req_level = int(parts[1])
		if !rows_by_id.has(req_id):
			return false
		var req_row: Dictionary = rows_by_id[req_id]
		if get_level(req_row) < req_level:
			return false
	return true

func make_node_text(row: Dictionary) -> String:
	var level := get_level(row)
	var max_level := int(row.get("max_level", 1))
	var name := str(row.get("name", row.get("id", "")))
	if !is_prereq_met(row) and level <= 0:
		return name + "\n锁定"
	return name + "\n" + str(level) + "/" + str(max_level)

func parse_position(text: String) -> Vector2:
	var clean := text.strip_edges()
	clean = clean.replace(";", "|")
	clean = clean.replace(",", "|")
	var parts := clean.split("|", false)
	var x := 0.0
	var y := 0.0
	if parts.size() >= 2:
		x = float(parts[0])
		y = float(parts[1])
	return GRAPH_MARGIN + Vector2(x * GRID_STEP.x, y * GRID_STEP.y)

func parse_int_list(text: String) -> Array[int]:
	var result: Array[int] = []
	for part in text.split("|", false):
		var clean := part.strip_edges()
		if clean != "":
			result.append(int(clean))
	return result

func parse_float_list(text: String) -> Array[float]:
	var result: Array[float] = []
	for part in text.split("|", false):
		var clean := part.strip_edges()
		if clean != "":
			result.append(float(clean))
	return result
