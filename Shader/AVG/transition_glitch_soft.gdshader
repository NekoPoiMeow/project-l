shader_type canvas_item;

uniform sampler2D next_texture : source_color;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.35;
uniform float slice_count : hint_range(4.0, 80.0) = 26.0;
uniform float color_shift : hint_range(0.0, 0.04) = 0.006;
uniform float jitter_speed : hint_range(0.0, 40.0) = 18.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	float phase = sin(progress * 3.14159265) * intensity;
	float slice = floor(UV.y * slice_count);
	float rnd = hash(slice + floor(TIME * jitter_speed));
	float offset = (rnd - 0.5) * 0.055 * phase;
	vec2 uv = clamp(UV + vec2(offset, 0.0), vec2(0.0), vec2(1.0));
	vec4 from_color = texture(TEXTURE, uv);
	vec4 to_color = texture(next_texture, uv);
	vec4 base_color = mix(from_color, to_color, smoothstep(0.25, 0.75, progress));
	float shift = color_shift * phase;
	base_color.r = mix(base_color.r, texture(TEXTURE, clamp(uv + vec2(shift, 0.0), vec2(0.0), vec2(1.0))).r, phase);
	base_color.b = mix(base_color.b, texture(next_texture, clamp(uv - vec2(shift, 0.0), vec2(0.0), vec2(1.0))).b, phase);
	COLOR = base_color;
}
