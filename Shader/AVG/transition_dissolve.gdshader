shader_type canvas_item;

uniform sampler2D next_texture : source_color;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float grain_scale : hint_range(8.0, 300.0) = 90.0;
uniform float edge_width : hint_range(0.0, 0.25) = 0.08;
uniform vec4 edge_color : source_color = vec4(0.95, 0.72, 1.0, 1.0);
uniform float edge_strength : hint_range(0.0, 2.0) = 0.65;
uniform float drift : hint_range(0.0, 1.0) = 0.12;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 moving_uv = UV + vec2(TIME * drift * 0.13, -TIME * drift * 0.09);
	float n = noise(moving_uv * grain_scale);
	float mask = smoothstep(progress - edge_width, progress + edge_width, n);
	vec4 from_color = texture(TEXTURE, UV);
	vec4 to_color = texture(next_texture, UV);
	float rim = 1.0 - smoothstep(0.0, edge_width, abs(n - progress));
	vec4 mixed_color = mix(to_color, from_color, mask);
	mixed_color.rgb += edge_color.rgb * rim * edge_strength * mixed_color.a;
	COLOR = mixed_color;
}
