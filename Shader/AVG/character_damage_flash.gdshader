shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 0.72, 0.86, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.75;
uniform float white_boost : hint_range(0.0, 1.0) = 0.55;
uniform bool pulse = true;
uniform float speed : hint_range(0.0, 20.0) = 8.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float amount = pulse ? flash_amount * (sin(TIME * speed) * 0.5 + 0.5) : flash_amount;
	vec3 flash_rgb = mix(flash_color.rgb, vec3(1.0), white_boost);
	tex.rgb = mix(tex.rgb, flash_rgb, amount) * (1.0 + amount * 0.25);
	COLOR = tex;
}
