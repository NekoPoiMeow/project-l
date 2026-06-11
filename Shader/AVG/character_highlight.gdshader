shader_type canvas_item;

uniform vec4 highlight_color : source_color = vec4(1.0, 0.82, 1.0, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float rim_width : hint_range(0.0, 0.03) = 0.012;
uniform float pearl : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = tex.a;
	float left_a = texture(TEXTURE, clamp(UV - vec2(rim_width, 0.0), vec2(0.0), vec2(1.0))).a;
	float right_a = texture(TEXTURE, clamp(UV + vec2(rim_width, 0.0), vec2(0.0), vec2(1.0))).a;
	float up_a = texture(TEXTURE, clamp(UV - vec2(0.0, rim_width), vec2(0.0), vec2(1.0))).a;
	float down_a = texture(TEXTURE, clamp(UV + vec2(0.0, rim_width), vec2(0.0), vec2(1.0))).a;
	float edge = clamp((left_a + right_a + up_a + down_a) - a * 4.0, 0.0, 1.0);
	float shine = smoothstep(0.15, 0.95, UV.y) * (sin((UV.x + UV.y) * 18.0 + TIME * 1.3) * 0.5 + 0.5);
	vec3 rgb = tex.rgb + highlight_color.rgb * edge * strength;
	rgb = mix(rgb, rgb + highlight_color.rgb * shine * tex.a, pearl);
	COLOR = vec4(rgb, tex.a);
}
