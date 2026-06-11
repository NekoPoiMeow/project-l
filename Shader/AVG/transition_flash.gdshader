shader_type canvas_item;

uniform sampler2D next_texture : source_color;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.82, 1.0, 1.0);
uniform float flash_strength : hint_range(0.0, 2.0) = 1.0;
uniform float switch_point : hint_range(0.05, 0.95) = 0.5;

void fragment() {
	vec4 from_color = texture(TEXTURE, UV);
	vec4 to_color = texture(next_texture, UV);
	vec4 base_color = progress < switch_point ? from_color : to_color;
	float pulse = 1.0 - abs(progress - switch_point) / max(switch_point, 1.0 - switch_point);
	pulse = smoothstep(0.0, 1.0, clamp(pulse, 0.0, 1.0));
	COLOR = mix(base_color, flash_color, pulse * flash_strength);
	COLOR.a = max(base_color.a, flash_color.a * pulse);
}
