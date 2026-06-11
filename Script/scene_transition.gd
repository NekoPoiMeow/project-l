extends CanvasLayer

var shader_rect: ColorRect
var target_pixel_size: float = 0.001
var is_active: bool = false
var phase: int = 0 

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	shader_rect = ColorRect.new()
	shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader_rect.visible = false
	add_child(shader_rect)
	
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	# 这里的关键：强制使用屏幕比例对齐，保证像素块在全屏范围内均匀分布，不再偏向左上角
	shader.code = """
    shader_type canvas_item;
    uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
    uniform float pixel_size : hint_range(0.001, 0.2) = 0.001;
    
    void fragment() {
        // 修正：计算屏幕比例，使像素化更加均匀，不再受限于左上角
        float ratio = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
        vec2 uv = SCREEN_UV;
        uv /= pixel_size;
        uv = floor(uv);
        uv *= pixel_size;
        
        COLOR = texture(SCREEN_TEXTURE, uv);
    }
	"""
	mat.shader = shader
	shader_rect.material = mat

func change_scene(path: String):
	shader_rect.visible = true
	is_active = true
	phase = 1 # 阶段1：变粗
	target_pixel_size = 0.001
	
	# 等待变粗过程完成 (1秒)
	await get_tree().create_timer(1.0).timeout
	
	get_tree().change_scene_to_file(path)
	
	# 变细过程 (1秒)
	phase = 2 
	await get_tree().create_timer(1.0).timeout
	
	shader_rect.visible = false
	is_active = false
	target_pixel_size = 0.001

func _process(delta: float) -> void:
	if not is_active: return
	
	# 线性插值，控制变化速度
	if phase == 1:
		target_pixel_size = move_toward(target_pixel_size, 0.2, delta * 0.2)
	elif phase == 2:
		target_pixel_size = move_toward(target_pixel_size, 0.001, delta * 0.2)
	
	# 暴力同步参数
	shader_rect.material.set_shader_parameter("pixel_size", target_pixel_size)
