shader_type canvas_item;

uniform float zoom_speed = 0.2;
uniform float zoom_amount = 0.015;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    vec2 u = f*f*(3.0-2.0*f);
    return mix(mix(hash(i + vec2(0,0)), hash(i + vec2(1,0)), u.x),
               mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0; float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * noise(p); p *= 2.0; a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 uv = UV - 0.5;
    // 1. 希区柯克呼吸变焦
    uv *= 1.0 + sin(TIME * zoom_speed) * zoom_amount;
    
    // 采样原图 (必须先定义 tex)
    vec4 tex = texture(TEXTURE, uv + 0.5);
    
    // 2. 不规则扫射光影
    float light_fbm = fbm(uv * 2.0 + TIME * 0.3);
    float light = smoothstep(0.3, 0.7, light_fbm) * 0.8 + 0.4;
    
    // 3. 浅淡液态油彩 (色相偏移)
    float color_fbm = fbm(uv * 4.0 + vec2(TIME * 0.2, TIME * -0.1));
    // 极其浅淡的油彩色调 (降低强度)
    vec3 oil_color = vec3(
        sin(color_fbm * 10.0 + TIME) * 0.1 + 0.2,
        sin(color_fbm * 10.0 + TIME * 1.5 + 2.0) * 0.1 + 0.2,
        sin(color_fbm * 10.0 + TIME * 0.8 + 4.0) * 0.1 + 0.2
    );
    
    // 4. 合成计算
    vec3 final_rgb = tex.rgb * light;
    final_rgb = mix(final_rgb, final_rgb + oil_color * 0.2, smoothstep(0.5, 0.8, color_fbm));
    
    COLOR = vec4(final_rgb, tex.a);
}