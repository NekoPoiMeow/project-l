shader_type canvas_item;

// 触手蠕动、扭曲的速度
uniform float v_speed : hint_range(0.1, 10.0) = 1.0;
// 触手扭曲的波浪剧烈程度
uniform float v_frequency : hint_range(1.0, 50.0) = 15.0;
// 触手位移的幅度（太大会扯裂图片）
uniform float v_amplitude : hint_range(0.0, 0.1) = 0.02;

// 【新加参数】控制透明度闪烁、忽隐忽现的速度
uniform float alpha_flicker_speed : hint_range(0.1, 20.0) = 4.0;

void fragment() {
    // 1. 拿到图片原本的 UV 坐标
    vec2 uv = UV;
    
    // 2. 利用正弦波，让图片的 X 轴和 Y 轴坐标随着时间和位置一起扭动
    uv.x += sin(uv.y * v_frequency + TIME * v_speed) * v_amplitude;
    uv.y += cos(uv.x * v_frequency + TIME * v_speed * 1.2) * v_amplitude;
    
    // 3. 用扭曲后的全新坐标，去读取你塞进去的那张触手图的色彩
    vec4 tex_color = texture(TEXTURE, uv);
    
    // 4. 【核心增量】：用高频不规则正弦波，算出 0.66 到 1.0 之间的随机透明度
    // 这里的 3.7 和 2.1 是为了打破规律，制造伪随机感，alpha_flicker_speed 控制闪烁的总速度
    float alpha_noise = sin(TIME * alpha_flicker_speed * 0.9) * cos(TIME * alpha_flicker_speed * 0.5);
    float random_alpha = 0.16 + alpha_noise * 0.06;
    
    // 5. 将计算出来的随机透明度，强行乘以图片原本的透明度
    tex_color.a *= random_alpha;
    
    // 6. 把最终带有扭曲、且忽隐忽现的触手图片渲染出来
    COLOR = tex_color;
}