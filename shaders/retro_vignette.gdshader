shader_type canvas_item;

// Darkens the corners of the screen. Pure alpha, so it never samples the screen.

uniform float strength : hint_range(0.0, 1.0) = 0.4;
uniform float inner : hint_range(0.0, 1.0) = 0.35;
uniform float outer : hint_range(0.1, 1.5) = 0.95;

void fragment() {
	float d = length((UV - 0.5) * vec2(1.0, 0.9));
	COLOR = vec4(0.0, 0.0, 0.0, strength * smoothstep(inner, outer, d));
}
