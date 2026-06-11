shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(1.0, 0.96, 1.0, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.42, 0.82, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.62, 0.28, 1.0, 1.0);
uniform vec4 gold_color : source_color = vec4(1.0, 0.82, 0.28, 1.0);

uniform float wave_speed : hint_range(0.0, 10.0) = 2.2;
uniform float wave_frequency : hint_range(0.0, 40.0) = 16.0;
uniform float wave_amount : hint_range(0.0, 0.05) = 0.008;

uniform float shine_speed : hint_range(0.1, 10.0) = 1.4;
uniform float shine_width : hint_range(0.02, 0.5) = 0.13;
uniform float shine_power : hint_range(0.0, 2.0) = 0.65;

uniform float glow_power : hint_range(0.0, 2.0) = 0.35;

void fragment() {
	vec2 uv = UV;

	float wave = sin(uv.x * wave_frequency + TIME * wave_speed) * wave_amount;
	uv.y += wave;

	vec4 tex = texture(TEXTURE, uv);

	float vertical = clamp(uv.y, 0.0, 1.0);

	vec4 grad_a = mix(top_color, mid_color, smoothstep(0.0, 0.55, vertical));
	vec4 grad_b = mix(mid_color, bottom_color, smoothstep(0.35, 1.0, vertical));
	vec4 gradient_color = mix(grad_a, grad_b, smoothstep(0.35, 0.9, vertical));

	float gold_line = smoothstep(0.68, 0.78, vertical) - smoothstep(0.82, 0.92, vertical);
	gradient_color.rgb = mix(gradient_color.rgb, gold_color.rgb, gold_line * 0.45);

	float shine_position = mod(TIME * shine_speed, 2.2) - 0.6;
	float shine_axis = uv.x + uv.y * 0.45;
	float shine = smoothstep(shine_position - shine_width, shine_position, shine_axis);
	shine -= smoothstep(shine_position, shine_position + shine_width, shine_axis);
	shine = clamp(shine, 0.0, 1.0);

	vec3 color = gradient_color.rgb;
	color += vec3(1.0, 0.92, 0.72) * shine * shine_power;

	float pearl = sin((uv.x + uv.y) * 28.0 + TIME * 1.6) * 0.5 + 0.5;
	color += vec3(0.18, 0.08, 0.22) * pearl * glow_power;

	COLOR = vec4(color, tex.a);
}