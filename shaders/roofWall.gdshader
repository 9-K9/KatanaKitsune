shader_type canvas_item;

// Re-skins the Crocotile roof blocks in the floor's own wall material, so a
// shrine's roof is built from the same stone, plaster or timber as its walls.
//
// Every roof tile is the same 960px cube drawn at the same spot in its texture,
// and every wall tile the same slab, so each cube face maps onto the slab's
// front face with one fixed affine transform. The roof's own lighting is kept
// as a blurred brightness, which is what still shows the crenellations and
// the shaded side faces once the brick pattern is gone.

uniform sampler2D wall_right : filter_nearest, repeat_enable; // dir3 — rises to the right
uniform sampler2D wall_left : filter_nearest, repeat_enable;  // dir5 — falls to the right
uniform float top_gain = 1.2;
uniform float left_gain = 0.8;
uniform float right_gain = 1.0;

// Cube corners in roof texture pixels.
const vec2 TOP_L = vec2(311.0, 357.0);
const vec2 BOTTOM = vec2(480.0, 441.0);
const vec2 TOP_T = vec2(480.0, 273.0);
const vec2 BASE_L = vec2(311.0, 562.0);
const vec2 BASE_C = vec2(480.0, 647.0);
const vec2 BASE_R = vec2(649.0, 562.0);
// Mean brightness of each face of the original art, to normalise its shading.
const vec3 FACE_MEAN = vec3(219.0, 132.0, 167.0) / 255.0;
// The slab's front face in wall texture pixels: bottom-left corner, along, up.
const vec2 WALL_SIZE = vec2(240.0, 384.0);
const vec2 RIGHT_O = vec2(34.0, 356.0);
const vec2 RIGHT_U = vec2(162.0, -66.0);
const vec2 RIGHT_V = vec2(0.0, -244.0);
const vec2 LEFT_O = vec2(44.0, 290.0);
const vec2 LEFT_U = vec2(162.0, 66.0);
const vec2 LEFT_V = vec2(0.0, -244.0);

// u and v of p in the frame (o, a, b).
vec2 solve(vec2 p, vec2 o, vec2 a, vec2 b) {
	mat2 m = mat2(a, b);
	return inverse(m) * (p - o);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	float edge = px.x < BOTTOM.x
			? TOP_L.y + (px.x - TOP_L.x) * (BOTTOM.y - TOP_L.y) / (BOTTOM.x - TOP_L.x)
			: BOTTOM.y - (px.x - BOTTOM.x) * (BOTTOM.y - TOP_L.y) / (BOTTOM.x - TOP_L.x);

	vec3 wall;
	float gain;
	float mean;
	if (px.y < edge) {
		// Top: the diamond as a square of wall face, tiled for the merlons
		// standing above it.
		vec2 uv = fract(solve(px, TOP_L, BOTTOM - TOP_L, TOP_T - TOP_L));
		wall = texture(wall_right, (RIGHT_O + uv.x * RIGHT_U + uv.y * RIGHT_V) / WALL_SIZE).rgb;
		gain = top_gain;
		mean = FACE_MEAN.x;
	} else if (px.x < BOTTOM.x) {
		vec2 uv = clamp(solve(px, BASE_L, BASE_C - BASE_L, TOP_L - BASE_L), 0.0, 1.0);
		wall = texture(wall_left, (LEFT_O + uv.x * LEFT_U + uv.y * LEFT_V) / WALL_SIZE).rgb;
		gain = left_gain;
		mean = FACE_MEAN.y;
	} else {
		vec2 uv = clamp(solve(px, BASE_C, BASE_R - BASE_C, BOTTOM - BASE_C), 0.0, 1.0);
		wall = texture(wall_right, (RIGHT_O + uv.x * RIGHT_U + uv.y * RIGHT_V) / WALL_SIZE).rgb;
		gain = right_gain;
		mean = FACE_MEAN.z;
	}

	// The roof's lighting without its brick pattern: brightness averaged over
	// a few pixels either way, which is wider than the mortar lines.
	vec2 s = TEXTURE_PIXEL_SIZE * 6.0;
	float light = 0.0;
	float weight = 0.0;
	for (int i = -2; i <= 2; i++) {
		for (int j = -2; j <= 2; j++) {
			vec4 t = texture(TEXTURE, UV + vec2(float(i), float(j)) * s);
			light += luma(t.rgb) * t.a;
			weight += t.a;
		}
	}
	light = weight > 0.0 ? light / weight : mean;
	vec3 colour = wall * gain * clamp(light / mean, 0.35, 1.6);
	COLOR = vec4(colour * COLOR.rgb, base.a * COLOR.a);
}
