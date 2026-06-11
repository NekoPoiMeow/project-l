shader_type canvas_item;

uniform sampler2D next_texture : source_color;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float softness : hint_range(0.0, 0.25) = 0.04;
uniform int shape : hint_enum("Circle", "Heart", "Magic Ring") = 0;
uniform vec4 edge_color : source_color = vec4(0.98, 0.75, 1.0, 1.0);
uniform float edge_strength : hint_range(0.0, 3.0) = 0.5;

float heart_distance(vec2 p) {
	p.x *= 1.15;
	p.y = -p.y * 1.25 + 0.18;
	float a = p.x * p.x + p.y * p.y - 0.28;
	return a * a * a - p.x * p.x * p.y * p.y * p.y;
}

void fragment() {
	vec2 p = UV - center;
	float d = length(p);
	if (shape == 1) {
		d = heart_distance(p) * 1.8 + 0.35;
	} else if (shape == 2) {
		float angle = atan(p.y, p.x);
		d += sin(angle * 12.0 + TIME * 2.0) * 0.025;
	}
	float radius = mix(0.0, 0.82, progress);
	float mask = smoothstep(radius - softness, radius + softness, d);
	vec4 from_color = texture(TEXTURE, UV);
	vec4 to_color = texture(next_texture, UV);
	float edge = 1.0 - smoothstep(0.0, max(softness, 0.0001), abs(d - radius));
	COLOR = mix(to_color, from_color, mask);
	COLOR.rgb += edge_color.rgb * edge * edge_strength * COLOR.a;
}
