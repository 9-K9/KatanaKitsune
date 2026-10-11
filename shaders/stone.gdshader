shader_type canvas_item;

// A monster turned to stone by the Stone scroll: the sprite's own shading kept,
// its colour drained to a cool grey with a little flattening so it reads as
// carved rather than merely desaturated.

uniform vec3 tint : source_color = vec3(0.80, 0.79, 0.76);
uniform float flatten : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	g = mix(g, 0.55, flatten);
	COLOR = vec4(vec3(g) * tint * 1.15, c.a);
}
