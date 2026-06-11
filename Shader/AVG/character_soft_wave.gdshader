shader_type canvas_item;

uniform float speed : hint_range(0.0, 10.0) = 2.0;
uniform float frequency : hint_range(1.0, 80.0) = 22.0;
uniform float amplitude : hint_range(0.0, 0.05) = 0.018;
uniform float top_fixed : hint_range(0.0, 1.0) = 0.18;
uniform float bottom_strength : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	float weight = smoothstep(top_fixed, 1.0, UV.y) * bottom_strength;
	vec2 uv = UV;
	uv.x += sin(UV.y * frequency + TIME * speed) * amplitude * weight;
	uv.y += cos(UV.x * frequency * 0.65 + TIME * speed * 0.7) * amplitude * 0.35 * weight;
	COLOR = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
}
