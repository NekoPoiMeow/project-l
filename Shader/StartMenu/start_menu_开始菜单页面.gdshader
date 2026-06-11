shader_type canvas_item;

uniform float wave_speed = 3.0;
uniform float wave_freq = 15.0;
uniform float wave_amp = 0.01;

// --- 新增：金属光泽控制参数 ---
uniform float shine_speed = 1.5;     // 光泽划过的速度
uniform float shine_width = 0.2;     // 光泽的宽度
uniform float shine_interval = 4.0;  // 每隔多少秒划过一次

void fragment() {
	// 【核心一：原有的水波局部扭曲计算】
	vec2 center = vec2(0.5, 0.5);
	vec2 uv = UV - center;
	float dist = length(uv);
	float wave = sin(dist * wave_freq - TIME * wave_speed) * wave_amp;
	wave *= (1.0 - dist * 2.0);
	vec2 distorted_uv = UV + (uv / dist) * wave;
	
	// 获取扭曲后的基础图片颜色
	vec4 text_color = texture(TEXTURE, distorted_uv);
	
	// 【核心二：金属流光（不时变色）计算】
	// 使用周期函数让光泽每隔 shine_interval 秒从左往右刷过去一次
	float time_cycle = mod(TIME * shine_speed, shine_interval);
	
	// 建立一条倾斜的斜线（X + Y 形成倾斜角度）
	float shine_line = distorted_uv.x + distorted_uv.y;
	
	// 计算当前像素是否刚好处于光泽带上
	float shine_factor = smoothstep(time_cycle - shine_width, time_cycle, shine_line) - 
	                     smoothstep(time_cycle, time_cycle + shine_width, shine_line);
	
	// 确保只把光泽加在有字的肉体上（透明的地方不发光）
	shine_factor = clamp(shine_factor, 0.0, 1.0) * text_color.a;
	
	// 给划过的地方叠加上亮白金色的金属反光（Color后面的四个数字代表红、绿、蓝、亮度）
	vec4 shine_color = vec4(1.0, 0.95, 0.8, 1.0) * shine_factor * 0.4;
	
	// 最终输出：水波图 + 划过的高光
	COLOR = text_color + shine_color;
}