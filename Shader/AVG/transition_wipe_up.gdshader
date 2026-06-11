shader_type canvas_item;

uniform sampler2D next_texture : source_color;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.0, 0.25) = 0.04;
uniform vec4 edge_color : source_color = vec4(1.0, 0.86, 1.0, 1.0);
uniform float edge_strength : hint_range(0.0, 2.0) = 0.25;

void fragment() {
	float threshold = 1.0 - progress;
	float mask = smoothstep(threshold - softness, threshold + softness, UV.y);
	vec4 from_color = texture(TEXTURE, UV);
	vec4 to_color = texture(next_texture, UV);
	float edge = 1.0 - smoothstep(0.0, max(softness, 0.0001), abs(UV.y - threshold));
	COLOR = mix(from_color, to_color, mask);
	COLOR.rgb += edge_color.rgb * edge * edge_strength * COLOR.a;
}
