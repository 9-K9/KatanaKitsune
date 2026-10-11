shader_type canvas_item;

// Slides a shoji door's two panels apart into the wall, along the wall's own
// isometric slant, and fades it like the wall it is set into.
//
// The texture holds only the doorway's paper interior, so its alpha doubles as
// the doorway mask: a panel pixel sampled from further along the slant is drawn
// only while it is still inside the doorway, and vanishes into the jamb.

// 0 closed, 1 fully open.
uniform float open : hint_range(0.0, 1.0) = 0.0;
// Doorway centre and half-width in texture pixels; the panels part here.
uniform float split_x = 120.0;
uniform float half_width = 60.0;
// Ground-line gradient of the wall, in texture pixels (dy per dx).
uniform float slope = 0.5;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

// Copied each frame from the wall layer's own wallFade material.
const int MAX_SUBJECTS = 8;
uniform vec2 subjects[MAX_SUBJECTS];
uniform int subject_count = 0;
uniform vec2 extents = vec2(52.0, 105.0);
uniform float rise = 86.0;
uniform float softness = 0.55;
uniform float min_alpha = 0.18;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 p = UV * size;
	float inside = texture(TEXTURE, UV).a;
	float d = open * half_width;
	bool left = p.x < split_x;
	vec2 src = left ? p + vec2(d, d * slope) : p - vec2(d, d * slope);
	bool same_side = left ? src.x < split_x : src.x >= split_x;
	vec4 c = texture(TEXTURE, src / size);
	c.a *= inside * (same_side ? 1.0 : 0.0);
	c.rgb = mix(c.rgb, vec3(1.0), flash_amount);

	float fade = 1.0;
	for (int i = 0; i < MAX_SUBJECTS; i++) {
		if (i >= subject_count) {
			break;
		}
		vec2 centre = subjects[i] - vec2(0.0, rise);
		float dist = length((world_pos - centre) / extents);
		fade = min(fade, mix(min_alpha, 1.0, smoothstep(1.0, 1.0 + softness, dist)));
	}
	c.a *= fade;
	COLOR = c * COLOR;
}
