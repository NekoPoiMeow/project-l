shader_type canvas_item;

uniform float darken_amount : hint_range(0.0, 1.0) = 0.42;
uniform vec4 shadow_tint : source_color = vec4(0.18, 0.13, 0.24, 1.0);
uniform float saturation : hint_range(0.0, 1.5) = 0.78;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desat = mix(vec3(gray), tex.rgb, saturation);
	vec3 dark = mix(desat, desat * shadow_tint.rgb, darken_amount);
	COLOR = vec4(dark, tex.a);
}
