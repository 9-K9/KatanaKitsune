shader_type canvas_item;

// Full-screen CRT pass: barrel curvature, slight RGB split and a faint
// phosphor mask. Scanlines and vignette are separate shaders so each can be
// toggled on its own.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform float curvature : hint_range(0.0, 0.5) = 0.08;
uniform float aberration : hint_range(0.0, 0.01) = 0.0012;
uniform float mask_strength : hint_range(0.0, 0.5) = 0.10;
uniform float brightness : hint_range(0.5, 1.5) = 1.06;
uniform float corner_round : hint_range(0.0, 0.2) = 0.04;

vec2 warp(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + curvature * vec2(c.y * c.y, c.x * c.x) * 0.5;
	return c * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = warp(SCREEN_UV);

	// Past the curved edge of the glass: plain black bezel.
	vec2 edge = min(uv, 1.0 - uv);
	if (edge.x < 0.0 || edge.y < 0.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 col;
		col.r = texture(screen_tex, uv + vec2(aberration, 0.0)).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - vec2(aberration, 0.0)).b;

		// Phosphor triads, one colour per physical screen column.
		float triad = mod(floor(FRAGCOORD.x), 3.0);
		vec3 mask = vec3(1.0 - mask_strength);
		mask[int(triad)] = 1.0;
		col *= mask * brightness;

		// Soften the corners so the picture reads as a rounded tube.
		float fade = smoothstep(0.0, max(corner_round, 0.0001), min(edge.x, edge.y));
		COLOR = vec4(col * fade, 1.0);
	}
}
