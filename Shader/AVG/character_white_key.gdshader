shader_type canvas_item;

uniform vec4 key_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tolerance : hint_range(0.0, 1.0) = 0.09;
uniform float softness : hint_range(0.0, 1.0) = 0.08;
uniform float edge_clean : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float d = distance(tex.rgb, key_color.rgb);
	float alpha_keep = smoothstep(tolerance, tolerance + softness, d);
	tex.a *= alpha_keep;
	tex.rgb = mix(tex.rgb, tex.rgb * tex.a, edge_clean * (1.0 - alpha_keep));
	COLOR = tex;
}
