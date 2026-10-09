shader_type canvas_item;

// Two things, one shader, because a CanvasItem only takes one material:
//
// 1. Clothing-only elemental recolour for Katana Kitsune (unchanged from
//    before). The sprites carry their clothing as pure-red pixels (green and
//    blue at or near zero) with the RED VALUE encoding the shading ramp. This
//    reproduces exactly what tools/generate_kitsune_power_palettes.py does
//    offline, but on the GPU, so the twelve power states cost two colours
//    instead of 3168 PNGs. Gated by `enabled`, off by default so monsters
//    that share this shader just to get effect 2 never pay for it.
//
// 2. Highlight softening, for every sprite. The 16-frame PixelOver re-export
//    shades with single-pixel light-grey/white dither rather than a blended
//    ramp, which reads as sparkly noise once blown up to 768px cells. This
//    finds pixels that are a local brightness spike against their 8
//    neighbours - regardless of hue, so it catches hair, skin and clothing
//    alike - and blends each one toward its neighbourhood average in
//    proportion to how much of an outlier it is. A large, deliberate
//    highlight (the katana blade, an eye) has neighbours just as bright, so
// its spike is ~0 and it is left alone; an isolated dither pixel sits well
// above its surroundings, so it gets a large spike and is pulled down
// toward them.
//
// Known difference from the baked clothing PNGs: the Python version
// additionally excluded a detected face bounding box. A fragment shader
// cannot do that connected-component pass, so roughly 0.13% of character
// pixels - dark red shade near the face, red 36..90 - recolour here where the
// baked version left them alone. Measured on IdleStanding_dir1: 78 px of
// ~59,500.

uniform bool enabled = false;

// Raw sRGB values divided by 255. Deliberately NOT source_color: the maths
// below matches the offline script, which works on raw 8-bit values. A
// source_color hint would linearise these and break the match.
uniform vec3 shadow_color = vec3(0.282353, 0.015686, 0.003922);
uniform vec3 highlight_color = vec3(0.949020, 0.227451, 0.078431);

uniform bool soften_highlights = true;
// How much of the neighbourhood average to mix in for the spikiest pixels.
uniform float soften_amount : hint_range(0.0, 1.0) = 0.85;
// Spike below this (self luma minus neighbour-average luma) is left alone -
// ordinary smooth shading, not dither.
uniform float spike_threshold : hint_range(0.0, 1.0) = 0.10;
// Spike at or above this gets the full soften_amount; between threshold and
// this it ramps up.
uniform float spike_range : hint_range(0.01, 1.0) = 0.35;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Clothing recolour for one already-sampled texel, so it can be applied
// identically to the centre pixel and to each neighbour before they are
// averaged together.
vec3 recolour(vec4 c) {
	if (!enabled || c.a <= 0.0) {
		return c.rgb;
	}
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.00392157); // guard matches max(mx,1) at 8-bit

	bool is_clothing =
		c.r >= mx
		&& c.r > 0.137255          // red > 35 at 8-bit
		&& sat > 0.72
		&& c.g < c.r * 0.42
		&& c.b < c.r * 0.35;

	if (!is_clothing) {
		return c.rgb;
	}
	float amount = clamp((c.r * 255.0 - 45.0) / 85.0, 0.0, 1.0);
	return mix(shadow_color, highlight_color, amount);
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 color = recolour(t);

	if (soften_highlights && t.a > 0.0) {
		vec3 acc = vec3(0.0);
		float lum_acc = 0.0;
		float count = 0.0;

		for (int dx = -1; dx <= 1; dx++) {
			for (int dy = -1; dy <= 1; dy++) {
				if (dx == 0 && dy == 0) {
					continue;
				}
				vec2 offset = vec2(float(dx), float(dy)) * TEXTURE_PIXEL_SIZE;
				vec4 n = texture(TEXTURE, UV + offset);
				if (n.a > 0.0) {
					vec3 nc = recolour(n);
					acc += nc;
					lum_acc += luma(nc);
					count += 1.0;
				}
			}
		}

		if (count >= 3.0) {
			vec3 avg = acc / count;
			float avg_lum = lum_acc / count;
			float spike = max(0.0, luma(color) - avg_lum);
			float blend = clamp((spike - spike_threshold) / max(spike_range - spike_threshold, 0.001), 0.0, 1.0) * soften_amount;
			color = mix(color, avg, blend);
		}
	}

	COLOR = vec4(color, t.a);
}
