shader_type canvas_item;

uniform float speed : hint_range(0.0, 5.0) = 0.85;
uniform float vertical_amount : hint_range(0.0, 0.08) = 0.012;
uniform float scale_amount : hint_range(0.0, 0.08) = 0.012;
uniform vec2 pivot = vec2(0.5, 0.82);

void fragment() {
	float breath = sin(TIME * speed * 6.2831853) * 0.5 + 0.5;
	float s = 1.0 + breath * scale_amount;
	vec2 uv = (UV - pivot) / vec2(1.0 + breath * scale_amount * 0.35, s) + pivot;
	uv.y += breath * vertical_amount;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, uv);
	}
}
