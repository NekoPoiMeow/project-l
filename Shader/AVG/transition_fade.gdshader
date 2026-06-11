shader_type canvas_item;

uniform sampler2D next_texture : source_color;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float color_hold : hint_range(0.0, 0.9) = 0.18;
uniform bool use_next_texture = true;

void fragment() {
	vec4 from_color = texture(TEXTURE, UV);
	vec4 to_color = use_next_texture ? texture(next_texture, UV) : from_color;
	float edge = 0.5 - color_hold * 0.5;
	float fade_out = smoothstep(0.0, edge, progress);
	float fade_in = smoothstep(1.0 - edge, 1.0, progress);
	vec4 mid_color = mix(from_color, fade_color, fade_out);
	COLOR = mix(mid_color, to_color, fade_in);
}
