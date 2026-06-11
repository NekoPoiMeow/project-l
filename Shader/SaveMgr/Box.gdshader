shader_type canvas_item;
uniform float intensity = 1.0; // 控制总亮度
uniform float speed = 2.0;    // 心跳速度

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    // 1. 心脏搏动：根据时间改变大小/亮度
    float pulse = 0.8 + 0.2 * sin(TIME * speed);
    
    // 2. 金属光泽：简单的斜向扫描线
    float scanline = sin(UV.x * 10.0 + TIME * 2.0) * 0.1;
    
    // 合并效果
    COLOR = tex * pulse * (1.0 + scanline) * intensity;
}