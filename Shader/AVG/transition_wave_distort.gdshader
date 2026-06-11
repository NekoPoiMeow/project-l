shader_type canvas_item;

uniform sampler2D next_texture : source_color;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float amplitude : hint_range(0.0, 0.08) = 0.025;
uniform float frequency : hint_range(1.0, 80.0) = 24.0;
uniform float speed : hint_range(0.0, 12.0) = 3.0;
uniform vec4 tint : source_color = vec4(0.78, 0.45, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	float pulse = sin(progress * 3.14159265);
	vec2 wave;
	wave.x = sin(UV.y * frequency + TIME * speed) * amplitude * pulse;
	wave.y = cos(UV.x * frequency * 0.8 + TIME * speed * 1.17) * amplitude * pulse;
	vec2 uv = clamp(UV + wave, vec2(0.0), vec2(1.0));
	vec4 from_color = texture(TEXTURE, uv);
	vec4 to_color = texture(next_texture, uv);
	vec4 color = mix(from_color, to_color, smoothstep(0.15, 0.85, progress));
	color.rgb = mix(color.rgb, color.rgb * tint.rgb, tint_strength * pulse);
	COLOR = color;
}
