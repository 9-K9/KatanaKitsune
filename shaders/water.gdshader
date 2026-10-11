shader_type canvas_item;

// Still pond water for the shrine gardens. Worked in world space and snapped to
// a pixel grid, so the ripples step like the pixel art around them rather than
// sliding smoothly, and the y axis is doubled to undo the isometric squash —
// ripples come out as circles on the ground, not as ovals on the screen.

uniform vec4 deep : source_color = vec4(0.05, 0.13, 0.20, 1.0);
uniform vec4 shallow : source_color = vec4(0.13, 0.30, 0.36, 1.0);
uniform vec4 glint : source_color = vec4(0.62, 0.80, 0.86, 1.0);
uniform float pixel = 4.0;
uniform float speed = 1.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = floor(world / pixel) * pixel;
	vec2 q = vec2(p.x, p.y * 2.0);
	float t = TIME * speed;
	float n = noise(q * 0.008 + vec2(t * 0.05, t * 0.03))
			+ 0.5 * noise(q * 0.021 - vec2(t * 0.07, -t * 0.04));
	float wave = sin((q.x + q.y) * 0.018 + t * 0.9 + n * 5.0);
	// Four flat bands rather than a gradient, to sit with the pixel art.
	float shade = floor(clamp(n / 1.5 + wave * 0.15, 0.0, 0.999) * 4.0) / 3.0;
	vec3 colour = mix(deep.rgb, shallow.rgb, shade);
	float sparkle = step(0.965, wave) * step(0.72, noise(q * 0.05 + t * 0.2));
	colour = mix(colour, glint.rgb, sparkle * 0.8);
	COLOR = vec4(colour, COLOR.a);
}
