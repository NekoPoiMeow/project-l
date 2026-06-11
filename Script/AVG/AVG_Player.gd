extends Node2D

@export var avg_id := "AVG_Test"
@export_file("*.csv") var csv_path := ""

@export var auto_pause_game := true
@export var close_when_finished := true

@export var screen_size := Vector2(1600, 900)

@export var portrait_target_height := 840.0
@export var portrait_max_width := 540.0
@export var portrait_top_y := 20.0

@export var gif_input_cooldown_time := 0.15

@export var default_a_position := "far_left"
@export var default_b_position := "left"
@export var default_c_position := "right"
@export var default_d_position := "far_right"

var layer: CanvasLayer = null
var click_layer: ColorRect = null

var bg_texture: TextureRect = null
var bg_gif = null
var movie_player: VideoStreamPlayer = null

var portrait_a: TextureRect = null
var portrait_b: TextureRect = null
var portrait_c: TextureRect = null
var portrait_d: TextureRect = null

var label_box: TextureRect = null
var role_name_label: Label = null
var dialog_text: RichTextLabel = null

var bgm_player: AudioStreamPlayer = null
var sfx_player: AudioStreamPlayer = null
var voice_player: AudioStreamPlayer = null

var rows: Array[Dictionary] = []
var row_index := -1
var asset_dir := ""
var current_bgm_path := ""
var history: Array[Dictionary] = []
var input_cooldown := 0.0

func set_avg_id(new_avg_id: String) -> void:
	avg_id = new_avg_id
	csv_path = "res://AVG/" + avg_id + ".csv"
	asset_dir = "res://AVG/" + avg_id

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	find_nodes()

	if csv_path == "":
		set_avg_id(avg_id)
	else:
		asset_dir = csv_path.get_base_dir().path_join(csv_path.get_file().get_basename())

	if auto_pause_game:
		get_tree().paused = true

	setup_audio_buses()
	setup_layout()
	setup_initial_visibility()
	load_csv()
	show_next_row()

func _process(delta: float) -> void:
	if input_cooldown > 0.0:
		input_cooldown -= delta

func find_nodes() -> void:
	layer = find_first_child_type(self, CanvasLayer)

	if layer == null:
		return

	click_layer = find_child_contains(layer, "点击推进层", ColorRect)

	bg_texture = find_child_contains(layer, "背景AVG", TextureRect)
	bg_gif = find_child_contains(layer, "背景AVG", GIFPlayer)
	movie_player = find_child_contains(layer, "电影AVG", VideoStreamPlayer)

	portrait_a = find_child_contains(layer, "角色A", TextureRect)
	portrait_b = find_child_contains(layer, "角色B", TextureRect)
	portrait_c = find_child_contains(layer, "角色C", TextureRect)
	portrait_d = find_child_contains(layer, "角色D", TextureRect)

	label_box = find_child_contains(layer, "对话框", TextureRect)
	role_name_label = find_child_contains(layer, "角色名", Label)
	dialog_text = find_child_contains(layer, "对话文本", RichTextLabel)

	bgm_player = find_child_contains(layer, "BGM", AudioStreamPlayer)
	sfx_player = find_child_contains(layer, "SFX", AudioStreamPlayer)
	voice_player = find_child_contains(layer, "Voice", AudioStreamPlayer)

	if click_layer and !click_layer.gui_input.is_connected(_on_click_layer_gui_input):
		click_layer.gui_input.connect(_on_click_layer_gui_input)

func _on_click_layer_gui_input(event: InputEvent) -> void:
	if input_cooldown > 0.0:
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			show_next_row()

func _unhandled_input(event: InputEvent) -> void:
	if input_cooldown > 0.0:
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			show_next_row()
			return

	if event is InputEventKey:
		if event.pressed and !event.echo:
			if event.keycode == KEY_ENTER or event.keycode == KEY_Z or event.keycode == KEY_SPACE:
				get_viewport().set_input_as_handled()
				show_next_row()
				return

func setup_audio_buses() -> void:
	if bgm_player:
		bgm_player.bus = "Music"

	if sfx_player:
		sfx_player.bus = "SFX"

	if voice_player:
		voice_player.bus = "Voice"

func setup_layout() -> void:
	if bg_texture:
		setup_control_rect(bg_texture, Vector2.ZERO, screen_size)
		bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if bg_gif:
		setup_control_rect(bg_gif, Vector2.ZERO, screen_size)
		bg_gif.scale = Vector2.ONE

	if movie_player:
		setup_control_rect(movie_player, Vector2.ZERO, screen_size)
		movie_player.expand = true
		movie_player.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if click_layer:
		setup_control_rect(click_layer, Vector2.ZERO, screen_size)
		click_layer.color = Color(1, 1, 1, 0)
		click_layer.mouse_filter = Control.MOUSE_FILTER_STOP

	setup_portrait_rect(portrait_a)
	setup_portrait_rect(portrait_b)
	setup_portrait_rect(portrait_c)
	setup_portrait_rect(portrait_d)

func setup_control_rect(node: Control, pos: Vector2, rect_size: Vector2) -> void:
	if node == null:
		return

	node.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	node.position = pos
	node.size = rect_size

func setup_portrait_rect(node: TextureRect) -> void:
	if node == null:
		return

	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup_initial_visibility() -> void:
	if bg_texture:
		bg_texture.visible = false

	if bg_gif:
		bg_gif.visible = false

	if movie_player:
		movie_player.visible = false
		movie_player.stop()

	set_portrait_visible(portrait_a, false)
	set_portrait_visible(portrait_b, false)
	set_portrait_visible(portrait_c, false)
	set_portrait_visible(portrait_d, false)

	if role_name_label:
		role_name_label.text = ""

	if dialog_text:
		dialog_text.text = ""

func load_csv() -> void:
	rows.clear()

	if !FileAccess.file_exists(csv_path):
		return

	var file = FileAccess.open(csv_path, FileAccess.READ)

	if file == null:
		return

	if file.eof_reached():
		file.close()
		return

	var headers = file.get_csv_line()

	while !file.eof_reached():
		var columns = file.get_csv_line()

		if columns.is_empty():
			continue

		var row: Dictionary = {}

		for i in range(headers.size()):
			var key = headers[i].strip_edges()
			var value = ""

			if i < columns.size():
				value = columns[i].strip_edges()

			row[key] = value

		if is_empty_row(row):
			continue

		rows.append(row)

	file.close()

func is_empty_row(row: Dictionary) -> bool:
	for key in row.keys():
		if str(row[key]).strip_edges() != "":
			return false

	return true

func show_next_row() -> void:
	row_index += 1

	if row_index >= rows.size():
		finish_avg()
		return

	show_row(rows[row_index])

func show_row(row: Dictionary) -> void:
	var text_id = get_value(row, "Text_ID").to_lower()
	var script_type = get_value(row, "Script_Type").to_lower()

	if text_id == "endall" or script_type == "end":
		finish_avg()
		return

	apply_audio(row)
	apply_background(row)
	apply_movie(row)
	apply_portraits(row)
	apply_text(row)
	apply_row_effect(row)

func apply_text(row: Dictionary) -> void:
	var role_name = get_value(row, "Role_Name")
	var text = get_value(row, "Text")

	if text.to_lower() == "null":
		if label_box:
			label_box.visible = false

		if role_name_label:
			role_name_label.visible = false
			role_name_label.text = ""

		if dialog_text:
			dialog_text.visible = false
			dialog_text.text = ""

		return

	if label_box:
		label_box.visible = true

	if role_name_label:
		role_name_label.visible = true
		role_name_label.text = role_name

	if dialog_text:
		dialog_text.visible = true
		dialog_text.text = text

	if text != "":
		push_history(role_name, text)

func push_history(role_name: String, text: String) -> void:
	history.append({
		"role_name": role_name,
		"text": text
	})

	while history.size() > 20:
		history.pop_front()

func apply_audio(row: Dictionary) -> void:
	var bgm_name = get_value(row, "BGM")
	var sfx_name = get_value(row, "SFX")
	var voice_name = get_value(row, "Voice")

	if bgm_name != "":
		if bgm_name.to_lower() == "end" or bgm_name.to_lower() == "stop":
			current_bgm_path = ""

			if bgm_player:
				bgm_player.stop()
		else:
			var bgm_path = resolve_asset_path(bgm_name)

			if bgm_path != current_bgm_path:
				current_bgm_path = bgm_path

				if bgm_player:
					bgm_player.stop()
					bgm_player.stream = load_audio_stream(bgm_path)

					if bgm_player.stream:
						bgm_player.play()

	if sfx_player:
		sfx_player.stop()

	if sfx_name != "":
		var sfx_path = resolve_asset_path(sfx_name)

		if sfx_player:
			sfx_player.stream = load_audio_stream(sfx_path)

			if sfx_player.stream:
				sfx_player.play()

	if voice_player:
		voice_player.stop()

	if voice_name != "":
		var voice_path = resolve_asset_path(voice_name)

		if voice_player:
			voice_player.stream = load_audio_stream(voice_path)

			if voice_player.stream:
				voice_player.play()

func apply_background(row: Dictionary) -> void:
	var bg_name = get_value(row, "BG_IMG")

	if bg_name == "":
		return

	var bg_shader = get_value(row, "BG_Shader")
	var bg_path = resolve_asset_path(bg_name)
	var ext = bg_path.get_extension().to_lower()

	if ext == "gif":
		show_gif_background(bg_path)
	else:
		show_texture_background(bg_path, bg_shader)

func apply_movie(row: Dictionary) -> void:
	var movie_name = get_value(row, "Movie")

	if movie_name == "":
		return

	if movie_name.to_lower() == "end" or movie_name.to_lower() == "stop":
		hide_movie()
		return

	var movie_path = resolve_asset_path(movie_name)
	var ext = movie_path.get_extension().to_lower()

	if ext == "ogv":
		show_video_movie(movie_path)
		return

func show_texture_background(path: String, shader_name := "") -> void:
	hide_movie()

	if bg_gif:
		bg_gif.visible = false

	if bg_texture:
		bg_texture.visible = true
		setup_control_rect(bg_texture, Vector2.ZERO, screen_size)
		var next_texture = load_texture(path)

		if is_background_transition_shader(shader_name):
			if bg_texture.texture != null and next_texture != null:
				play_background_transition(next_texture, shader_name)
				return

			bg_texture.texture = next_texture
			bg_texture.material = null
			return

		bg_texture.texture = next_texture
		apply_shader_preset_to_background(shader_name)

func show_gif_background(path: String) -> void:
	hide_movie()

	if bg_texture:
		bg_texture.visible = false

	if bg_gif == null:
		return

	bg_gif.visible = true
	bg_gif.gif = load(path)
	fit_gif_to_screen(bg_gif)
	input_cooldown = gif_input_cooldown_time

func fit_gif_to_screen(gif_node) -> void:
	if gif_node == null:
		return

	setup_control_rect(gif_node, Vector2.ZERO, screen_size)
	gif_node.scale = Vector2.ONE

func show_video_movie(path: String) -> void:
	if bg_texture:
		bg_texture.visible = false

	if bg_gif:
		bg_gif.visible = false

	if movie_player == null:
		return

	movie_player.visible = true
	setup_control_rect(movie_player, Vector2.ZERO, screen_size)
	movie_player.expand = true
	movie_player.stop()
	movie_player.stream = load(path)

	if movie_player.stream:
		movie_player.play()

func hide_movie() -> void:
	if movie_player:
		movie_player.stop()
		movie_player.visible = false

func apply_portraits(row: Dictionary) -> void:
	apply_one_portrait(row, "A", portrait_a, default_a_position)
	apply_one_portrait(row, "B", portrait_b, default_b_position)
	apply_one_portrait(row, "C", portrait_c, default_c_position)
	apply_one_portrait(row, "D", portrait_d, default_d_position)

func apply_one_portrait(row: Dictionary, prefix: String, node: TextureRect, default_position_name: String) -> void:
	if node == null:
		return

	var img_name = get_value(row, prefix + "_IMG")

	if img_name == "":
		set_portrait_visible(node, false)
		return

	var img_path = resolve_asset_path(img_name)
	var texture = load_texture(img_path)

	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_portrait_visible(node, true)

	var position_name = get_value(row, prefix + "_IMG_Position")

	if position_name == "":
		position_name = default_position_name

	apply_portrait_position(node, position_name, texture)

	var shader_name = get_value(row, prefix + "_Shader")
	apply_shader_preset_to_portrait(node, shader_name)

func apply_portrait_position(node: TextureRect, position_name: String, texture: Texture2D) -> void:
	var normalized = normalize_position_name(position_name)
	var center_x = get_position_center_x(normalized)
	var target_size = get_portrait_display_size(texture)

	node.size = target_size
	node.position.x = center_x - target_size.x * 0.5
	node.position.y = portrait_top_y

func get_portrait_display_size(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2(portrait_max_width, portrait_target_height)

	var original_size = texture.get_size()

	if original_size.x <= 0.0 or original_size.y <= 0.0:
		return Vector2(portrait_max_width, portrait_target_height)

	var display_height = portrait_target_height
	var display_width = display_height * original_size.x / original_size.y

	if display_width > portrait_max_width:
		display_width = portrait_max_width
		display_height = display_width * original_size.y / original_size.x

	return Vector2(display_width, display_height)

func normalize_position_name(position_name: String) -> String:
	var name = position_name.strip_edges().to_lower()

	if name == "最左":
		return "far_left"

	if name == "靠左":
		return "left"

	if name == "中" or name == "中央" or name == "居中":
		return "center"

	if name == "靠右":
		return "right"

	if name == "右" or name == "最右":
		return "far_right"

	return name

func get_position_center_x(position_name: String) -> float:
	if position_name == "far_left":
		return 170.0

	if position_name == "left":
		return 485.0

	if position_name == "center":
		return 800.0

	if position_name == "right":
		return 1115.0

	if position_name == "far_right":
		return 1430.0

	return 800.0

func set_portrait_visible(node: CanvasItem, visible_value: bool) -> void:
	if node:
		node.visible = visible_value

func apply_row_effect(row: Dictionary) -> void:
	var effect_name = get_value(row, "BG_Shader")

	if effect_name == "":
		return

	call_effect_preset(effect_name)

func call_effect_preset(effect_name: String) -> void:
	var normalized = effect_name.to_lower()

	if normalized == "none":
		return

	if is_background_transition_shader(normalized):
		return

	if normalized == "shake":
		play_shake_effect()
		return

	if normalized == "fade":
		play_fade_effect()
		return

	if normalized == "flash" or normalized == "flash_pink":
		play_flash_effect(normalized)
		return

	if normalized == "wipe_left":
		play_fade_effect()
		return

	if normalized == "dissolve":
		play_fade_effect()
		return

	if normalized == "iris":
		play_fade_effect()
		return

	if normalized == "blur_fade":
		play_fade_effect()
		return

	if normalized == "wave_distort":
		play_fade_effect()
		return

func play_shake_effect() -> void:
	if layer == null:
		return

	var base_offset = layer.offset
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(layer, "offset", base_offset + Vector2(8, 0), 0.03)
	tween.tween_property(layer, "offset", base_offset + Vector2(-8, 0), 0.03)
	tween.tween_property(layer, "offset", base_offset + Vector2(4, 0), 0.03)
	tween.tween_property(layer, "offset", base_offset, 0.03)

func play_fade_effect() -> void:
	if click_layer == null:
		return

	click_layer.color = Color(0.0, 0.0, 0.0, 1.0)

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(click_layer, "color:a", 0.0, 0.25)

func play_flash_effect(effect_name: String) -> void:
	if click_layer == null:
		return

	if effect_name == "flash_pink":
		click_layer.color = Color(1.0, 0.55, 0.85, 0.85)
	else:
		click_layer.color = Color(1.0, 1.0, 1.0, 0.85)

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(click_layer, "color:a", 0.0, 0.18)

func apply_shader_preset_to_background(shader_name: String) -> void:
	if bg_texture == null:
		return

	if shader_name == "":
		return

	var normalized = shader_name.to_lower()

	if normalized == "none":
		bg_texture.material = null
		return

	if normalized == "wave_distort":
		bg_texture.material = load_shader_material("res://Shader/AVG/transition_wave_distort.gdshader")
		return

	if normalized == "blur_fade":
		bg_texture.material = load_shader_material("res://Shader/AVG/transition_blur_fade.gdshader")
		return

	if normalized == "glitch_soft":
		bg_texture.material = load_shader_material("res://Shader/AVG/transition_glitch_soft.gdshader")
		return

func is_background_transition_shader(shader_name: String) -> bool:
	var normalized = shader_name.strip_edges().to_lower()

	if normalized == "fade":
		return true

	if normalized == "dissolve":
		return true

	if normalized == "wipe_left":
		return true

	if normalized == "wipe_right":
		return true

	if normalized == "wipe_up":
		return true

	if normalized == "wipe_down":
		return true

	if normalized == "iris":
		return true

	if normalized == "flash":
		return true

	if normalized == "blur_fade":
		return true

	if normalized == "wave_distort":
		return true

	if normalized == "glitch_soft":
		return true

	return false

func get_background_transition_shader_path(shader_name: String) -> String:
	var normalized = shader_name.strip_edges().to_lower()

	if normalized == "fade":
		return "res://Shader/AVG/transition_fade.gdshader"

	if normalized == "dissolve":
		return "res://Shader/AVG/transition_dissolve.gdshader"

	if normalized == "wipe_left":
		return "res://Shader/AVG/transition_wipe_left.gdshader"

	if normalized == "wipe_right":
		return "res://Shader/AVG/transition_wipe_right.gdshader"

	if normalized == "wipe_up":
		return "res://Shader/AVG/transition_wipe_up.gdshader"

	if normalized == "wipe_down":
		return "res://Shader/AVG/transition_wipe_down.gdshader"

	if normalized == "iris":
		return "res://Shader/AVG/transition_iris.gdshader"

	if normalized == "flash":
		return "res://Shader/AVG/transition_flash.gdshader"

	if normalized == "blur_fade":
		return "res://Shader/AVG/transition_blur_fade.gdshader"

	if normalized == "wave_distort":
		return "res://Shader/AVG/transition_wave_distort.gdshader"

	if normalized == "glitch_soft":
		return "res://Shader/AVG/transition_glitch_soft.gdshader"

	return ""

func play_background_transition(next_texture: Texture2D, shader_name: String) -> void:
	if bg_texture == null:
		return

	var shader_path = get_background_transition_shader_path(shader_name)
	var material = load_shader_material(shader_path)

	if material == null:
		bg_texture.texture = next_texture
		bg_texture.material = null
		return

	bg_texture.material = material

	if material is ShaderMaterial:
		material.set_shader_parameter("next_texture", next_texture)
		material.set_shader_parameter("progress", 0.0)

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	if material is ShaderMaterial:
		tween.tween_method(
			func(value: float) -> void:
				material.set_shader_parameter("progress", value),
			0.0,
			1.0,
			0.45
		)

	tween.tween_callback(
		func() -> void:
			if bg_texture == null:
				return

			bg_texture.texture = next_texture
			bg_texture.material = null
	)

func apply_shader_preset_to_portrait(node: CanvasItem, shader_name: String) -> void:
	if node == null:
		return

	if shader_name == "":
		node.material = null
		return

	var normalized = shader_name.to_lower()

	if normalized == "none":
		node.material = null
		return

	if normalized == "white_key":
		node.material = load_shader_material("res://Shader/AVG/character_white_key.gdshader")
		return

	if normalized == "gloss":
		node.material = load_shader_material("res://Shader/AVG/character_gloss.gdshader")
		return

	if normalized == "breath":
		node.material = load_shader_material("res://Shader/AVG/character_breath.gdshader")
		return

	if normalized == "soft_wave":
		node.material = load_shader_material("res://Shader/AVG/character_soft_wave.gdshader")
		return

	if normalized == "damage_flash":
		node.material = load_shader_material("res://Shader/AVG/character_damage_flash.gdshader")
		return

	if normalized == "darken":
		node.material = load_shader_material("res://Shader/AVG/character_darken.gdshader")
		return

	if normalized == "highlight":
		node.material = load_shader_material("res://Shader/AVG/character_highlight.gdshader")
		return

func load_shader_material(path: String) -> Material:
	if ResourceLoader.exists(path):
		var resource = load(path)

		if resource is Shader:
			var material = ShaderMaterial.new()
			material.shader = resource
			return material

		if resource is Material:
			return resource

	return null

func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)

	return null

func load_audio_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)

	return null

func resolve_asset_path(file_name: String) -> String:
	var clean_name = file_name.strip_edges()

	if clean_name == "":
		return ""

	if clean_name.begins_with("res://"):
		return clean_name

	if clean_name.begins_with("user://"):
		return clean_name

	return asset_dir.path_join(clean_name)

func get_value(row: Dictionary, key: String) -> String:
	if !row.has(key):
		return ""

	return str(row[key]).strip_edges()

func finish_avg() -> void:
	if voice_player:
		voice_player.stop()

	if sfx_player:
		sfx_player.stop()

	if bgm_player:
		bgm_player.stop()

	hide_movie()

	if auto_pause_game:
		get_tree().paused = false

	if close_when_finished:
		queue_free()
	else:
		visible = false

func find_child_contains(root: Node, keyword: String, expected_type) -> Node:
	if root == null:
		return null

	for child in root.get_children():
		if is_instance_of(child, expected_type):
			if keyword in str(child.name):
				return child

	return null

func find_first_child_type(root: Node, expected_type) -> Node:
	if root == null:
		return null

	for child in root.get_children():
		if is_instance_of(child, expected_type):
			return child

	return null
