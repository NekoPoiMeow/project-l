shader_type canvas_item;

uniform vec4 gloss_color : source_color = vec4(1.0, 0.72, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float width : hint_range(0.01, 0.5) = 0.16;
uniform float angle : hint_range(-1.0, 1.0) = 0.35;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform bool auto_sweep = true;
uniform float speed : hint_range(0.0, 5.0) = 0.7;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float line = UV.x + UV.y * angle;
	float sweep = auto_sweep ? fract(TIME * speed + progress) : progress;
	float pos = mix(-width, 1.0 + width, sweep);
	float band = smoothstep(pos - width, pos, line) - smoothstep(pos, pos + width, line);
	band *= tex.a;
	vec3 lit = tex.rgb + gloss_color.rgb * band * strength;
	COLOR = vec4(lit, tex.a);
}
