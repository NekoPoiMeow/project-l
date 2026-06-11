shader_type canvas_item;

uniform sampler2D next_texture : source_color;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float max_blur : hint_range(0.0, 0.04) = 0.012;
uniform float fade_bias : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	float blur_amount = sin(progress * 3.14159265) * max_blur;
	vec2 px = vec2(blur_amount);

	vec4 from_color = texture(TEXTURE, UV) * 0.22;
	from_color += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.13;
	from_color += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.13;
	from_color += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.13;
	from_color += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.13;
	from_color += texture(TEXTURE, UV + px) * 0.065;
	from_color += texture(TEXTURE, UV - px) * 0.065;
	from_color += texture(TEXTURE, UV + vec2(px.x, -px.y)) * 0.065;
	from_color += texture(TEXTURE, UV + vec2(-px.x, px.y)) * 0.065;

	vec4 to_color = texture(next_texture, UV) * 0.22;
	to_color += texture(next_texture, UV + vec2(px.x, 0.0)) * 0.13;
	to_color += texture(next_texture, UV - vec2(px.x, 0.0)) * 0.13;
	to_color += texture(next_texture, UV + vec2(0.0, px.y)) * 0.13;
	to_color += texture(next_texture, UV - vec2(0.0, px.y)) * 0.13;
	to_color += texture(next_texture, UV + px) * 0.065;
	to_color += texture(next_texture, UV - px) * 0.065;
	to_color += texture(next_texture, UV + vec2(px.x, -px.y)) * 0.065;
	to_color += texture(next_texture, UV + vec2(-px.x, px.y)) * 0.065;

	float mix_value = smoothstep(fade_bias - 0.35, fade_bias + 0.35, progress);
	COLOR = mix(from_color, to_color, mix_value);
}
