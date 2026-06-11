extends TextureRect

func _process(_delta):
	var mat = get_material()
	if mat is ShaderMaterial:
		# 光影扫射（探照灯）
		mat.set_shader_parameter("light_speed", 0.4)
		# 色斑游走（液态小团）
		mat.set_shader_parameter("fluid_speed", 1.8)
