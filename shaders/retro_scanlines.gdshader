shader_type canvas_item;

// Horizontal scanline overlay. Pure alpha, so it never samples the screen.

uniform float line_count : hint_range(60.0, 600.0) = 216.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	float band = 0.5 + 0.5 * cos(UV.y * line_count * 6.2831853);
	COLOR = vec4(0.0, 0.0, 0.0, intensity * band);
}
